# Vínculo entre un personaje y una campaña

Hasta la incorporación del Modo DM, Milantus era estrictamente de un solo
dueño: toda tabla tenía `user_id` y toda consulta filtraba por él. Este
documento describe la única excepción a esa regla y por qué está construida
así, porque es la parte del servidor donde una equivocación expone la ficha de
otra persona.

## La regla

> Una cuenta solo alcanza datos de otra a través de una fila de
> `campaign_members`, y esa fila solo puede existir si el **dueño del
> personaje** emitió un código y alguien lo canjeó.

No hay ninguna otra puerta. El DM no puede llegar a un personaje escribiendo su
id, ni averiguando el de otra cuenta, ni pidiendo una campaña que no es suya.

## Las tres tablas

| Tabla | Para qué |
|---|---|
| `campaigns` | Las mesas que dirige una cuenta. Misma forma que `characters`: clave `(dm_user_id, id)` y documento JSONB. |
| `campaign_members` | El vínculo. Guarda a qué personaje apuntar, nunca una copia de la ficha. |
| `character_share_codes` | Códigos emitidos y todavía sin canjear, guardados como hash. |

`campaign_members` tiene **clave sustituta** además de la combinación natural
porque el vínculo se corta desde las dos puntas: con un id opaco, la URL con la
que el jugador deja de compartir no necesita nombrar al DM.

Sus dos claves foráneas en cascada son intencionales:

- se va la cuenta del DM → se van sus campañas → se van estos vínculos;
- el jugador borra su personaje (o su cuenta) → se van sus vínculos.

Nunca queda una referencia apuntando a una ficha que ya no existe.

## Por qué una referencia y no una copia

La alternativa —guardar la ficha al vincular— obligaría a sincronizar dos
copias y a decidir cuál gana cuando difieran. Leer siempre la fila real elimina
el problema de raíz: el DM ve lo que el jugador tiene ahora, y no hay ningún
momento en que las dos versiones puedan discrepar.

El costo es que un mismo personaje vinculado a dos campañas comparte sus puntos
de golpe entre ambas. Es un límite **aceptado a conciencia**: modelar estado por
campaña complicaría el modelo para todos con tal de cubrir un caso de borde. El
rodeo, si aparece, es crear un segundo personaje.

## El canje, en una sola sentencia

Consumir el código y crear el vínculo ocurren en un único `INSERT ... SELECT`
alimentado por un `DELETE ... RETURNING` dentro de un CTE
(`PostgresCampaignRepository.redeemShareCode`). Es atómico sin abrir una
transacción, y tiene una propiedad que importa: si el `INSERT` falla por clave
foránea, la sentencia entera se revierte y **el código no se quema**. Intentar
contra una campaña ajena no le cuesta su código al jugador.

Cero filas devueltas significa código inexistente, vencido o ya usado. Los tres
casos responden lo mismo —404, `Código inválido o vencido.`— porque
distinguirlos solo le serviría a quien esté probando códigos.

## Dónde vive la autorización

**Dentro de la consulta, no en el handler.** `deleteMember` es el ejemplo:

```sql
DELETE FROM campaign_members
WHERE id = @memberId AND (dm_user_id = @userId OR owner_user_id = @userId)
```

No existe forma de llamar a ese método y saltearse la comprobación, ni siquiera
por equivocación desde un handler nuevo. Lo mismo vale para `listMembers`,
`findMemberLink` y `listSharesForCharacter`: todos llevan el dueño en el
`WHERE`.

La consecuencia práctica es que **lo ajeno y lo inexistente responden igual**.
Es la misma regla que ya seguía `CharacterRepository.find`: si un 404 y un 403
se distinguieran, la API se convertiría en una forma de averiguar qué personajes
existen en otras cuentas.

## Retratos

`_portraitHandler` deriva la propiedad de la sesión, así que un DM recibiría 404
en el retrato de una ficha ajena. En vez de enseñarle campañas a ese handler
—código de seguridad ya probado— hay una ruta aparte en el espacio de la
campaña que valida la membresía y recién entonces lee del almacenamiento **del
dueño**:

```
GET /api/campaigns/<campaignId>/members/<memberId>/portrait/<fileName>
```

## Códigos

Ocho caracteres de un alfabeto de 30 símbolos sin los pares que se confunden al
dictar (`I`/`1`, `L`, `O`/`0`, `U`/`V`): unos 39 bits. Se muestra como
`XXXX-XXXX` y se normaliza antes de hashear, así que da igual si llega en
minúscula, con guion o con espacios de más.

La base guarda **solo el SHA-256**, igual que con los tokens de sesión: un
volcado no entrega accesos válidos. Vencen a las 24 horas y se barren en el
camino de escritura, como las sesiones.

No hay límite de intentos. Con 39 bits y solo adivinación por HTTP alcanza de
sobra; si alguna vez esto se expone a internet abierta, conviene revisarlo.

## Avisos

Las acciones entre cuentas le llegan a la otra parte a través de `user_events`.
La regla es simple: **quien ejecuta recibe respuesta en el momento; quien no
estaba mirando recibe un aviso persistido.**

El servidor guarda qué pasó (`kind` más los datos del `payload`), nunca la frase
armada. El texto en español vive en `packages/dnd_app/lib/ui/user_event_messages.dart`,
así que corregir una redacción es cambiar una línea y no migrar la base. Un
`kind` que el cliente no conozca se ignora en silencio: el servidor puede ser
más nuevo que la pestaña abierta.

`_deleteCharacterHandler` arma los avisos **antes** de borrar, porque la cascada
se lleva los vínculos y después ya no hay a quién avisarle.

## El combate y el turno

El combat tracker (Fase 2 de Modo DM) agrega la **segunda** consulta del
servidor que cruza cuentas — la primera fue el vínculo mismo. Vive en dos
tablas nuevas (migración `0007_encounters`):

| Tabla | Para qué |
|---|---|
| `encounters` | El combate abierto de una campaña. Clave `(dm_user_id, campaign_id)`: no hay forma de tener dos combates abiertos a la vez en la misma mesa. |
| `encounter_logs` | Lo que queda al cerrar uno. Se graba, no se muestra todavía — falta el Cuaderno de campaña. |

El documento de `encounters` se reemplaza entero en cada guardado
(`PUT /api/campaigns/<id>/encounter`), igual que una ficha. No hay rutas finas
de "avanzar turno" o "dañar monstruo": el cliente del DM es dueño del estado
completo, así que no hay nada que se pueda desincronizar entre dos rutas que
deberían ir juntas.

### `turnFor`, la consulta que ve el jugador

Es la única ruta de esta fase que ejecuta el **jugador**, no el DM
(`GET /api/characters/<id>/turn`). La autorización sigue la misma regla que
todo lo demás — dentro del `WHERE`, no en el handler:

```sql
SELECT m.id AS member_id, e.document
FROM campaign_members m
JOIN encounters e
  ON e.dm_user_id = m.dm_user_id AND e.campaign_id = m.campaign_id
WHERE m.owner_user_id = @userId AND m.character_id = @characterId
LIMIT 1
```

El `INNER JOIN` hace el trabajo: una membresía sin combate abierto no
devuelve fila, así que la falta de vínculo y la falta de combate responden
exactamente igual (`TurnStatus.none`). `LIMIT 1` resuelve el mismo borde ya
aceptado en el vínculo — un personaje en dos campañas con combate
simultáneo — quedándose con cualquiera de las dos, sin inventar una UI para
desempatar.

### Lo que el jugador nunca ve

`TurnStatus` (`packages/dnd_engine/lib/src/domain/encounter.dart`) tiene
deliberadamente cuatro valores y ninguno es "el orden completo" ni "quién más
está peleando": `none` / `waiting` / `next` / `active`. El servidor nunca le
manda al jugador el documento del combate, solo esa proyección de cuatro
estados. Es la misma frontera que ya separaba Modo DM del resto de la app,
aplicada a una superficie nueva.

### Por qué esto es lo único casi-en-vivo del proyecto

El resto de Milantus se refresca al entrar a una pantalla o después de una
acción propia — nunca con un timer. El turno es la excepción a propósito: el
aviso "preparate, seguís vos" solo sirve si llega mientras la ficha está
abierta, así que `SheetScreen._pollTurn` sondea cada 5 segundos con combate
abierto (20 si no hay ninguno), con un `Timer` que se reprograma solo y se
cancela en `dispose`. No usa la cola de avisos (`user_events`): esa cola es
para "esto pasó mientras no mirabas" y se entrega una sola vez; el turno es
"esto es verdad ahora", y si viajara por la misma vía se acumularían avisos de
rondas viejas sin vencer nunca. Ver el comentario de
`packages/dnd_app/lib/ui/pending_events_gate.dart` para la distinción completa.

Del lado del DM pasa lo mismo con los PG de los jugadores: mientras hay
combate abierto, `_CampaignDetail` vuelve a pedir `listCampaignMembers` cada 5
segundos —sin importar qué pestaña esté mirando el DM—, porque el vínculo es
referencia viva y el jugador puede anotarse el daño con la pestaña de Mesa al
frente.

### Los PG que el DM no toca

El DM **no** escribe la ficha del jugador en ningún momento — es una decisión
tomada explícitamente después de haber diseñado lo contrario, y vale la pena
dejar constancia de por qué se dio vuelta: en una mesa presencial el DM dice
"te pega por 8" y el jugador lo anota; que el DM edite en vivo la ficha ajena
es comportamiento de VTT, no de apoyo a la mesa. Cada jugador sigue anotando
sus propios PG. La única escritura del DM en toda esta fase son los PG de los
**monstruos**, que son suyos y efímeros — se pierden al cerrar el combate,
salvo el resumen que queda en `encounter_logs`.

## Qué probar al tocar esto

Las pruebas negativas de `packages/dnd_server/test/app_test.dart`, grupo
`/api/campaigns y compartir personajes`, son el contrato real:

- un código no se canjea dos veces;
- canjear contra una campaña ajena falla y no quema el código;
- sin vínculo, la campaña no muestra ninguna ficha;
- compartir un personaje ajeno responde como si no existiera;
- un tercero no puede cortar un vínculo del que no es parte;
- una cuenta no puede marcar vistos los avisos de otra.

El subgrupo `combate`, dentro del mismo archivo, agrega:

- un DM ajeno recibe 404 al leer o guardar el combate de otra cuenta;
- cerrar el combate borra el encuentro y deja el log grabado, incluso sin uno
  abierto (no hace nada, no es un error);
- borrar la campaña deja el combate inalcanzable;
- un jugador sin vínculo obtiene `none`, nunca un error que revele que el
  combate existe;
- un jugador no puede preguntar por el turno de un personaje ajeno.

Ninguna se puede relajar para hacer pasar otra cosa.
