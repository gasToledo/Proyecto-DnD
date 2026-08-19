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

## Qué probar al tocar esto

Las pruebas negativas de `packages/dnd_server/test/app_test.dart`, grupo
`/api/campaigns y compartir personajes`, son el contrato real:

- un código no se canjea dos veces;
- canjear contra una campaña ajena falla y no quema el código;
- sin vínculo, la campaña no muestra ninguna ficha;
- compartir un personaje ajeno responde como si no existiera;
- un tercero no puede cortar un vínculo del que no es parte;
- una cuenta no puede marcar vistos los avisos de otra.

Ninguna se puede relajar para hacer pasar otra cosa.
