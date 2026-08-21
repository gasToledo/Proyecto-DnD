# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Idioma

**Todo el proyecto está en español rioplatense**: nombres de tests, mensajes de
UI, comentarios, documentación y mensajes de commit. Escribí en español salvo
que el identificador sea de una API ajena.

Los comentarios explican **por qué**, no qué hace la línea. El código de este
repositorio está densamente comentado con las decisiones y sus motivos —
seguí ese registro y sumale el tuyo cuando tomes una decisión no obvia.

## Comandos

Los tres paquetes se prueban por separado. No hay comando raíz.

```bash
cd packages/dnd_engine && dart pub get && dart analyze && dart test
```

```bash
cd packages/dnd_app && flutter pub get && dart analyze && flutter test
```

```bash
cd packages/dnd_server && dart pub get && dart analyze && dart test
```

Un archivo suelto, o un test por nombre:

```bash
cd packages/dnd_engine && dart test test/wild_shape_test.dart
```

```bash
cd packages/dnd_app && flutter test test/sheet_screen_test.dart --plain-name "Campaña"
```

Antes de cualquier commit, y obligatorio para que pase CI:

```bash
dart format .
```

```bash
cd packages/dnd_app && flutter build web --release
```

CI verifica el formato **antes que nada**, así que un commit sin formatear falla
sin llegar a decir nada útil sobre el código. Conviene instalar el hook:

```bash
git config core.hooksPath .githooks
```

`main` es el único tronco activo: se valida local, se commitea y se pushea
directo. El push dispara CI siempre, y CD cuando toca `packages/**`,
`docker-compose.yml` o `postgres-init/**`.

El stack completo (Postgres + Zitadel + servidor + cloudflared) se levanta con
`docker compose up -d --build`; el runbook está en
`docs/Informacion tecnica del proyecto/despliegue.md`.

## Los tres paquetes

```
packages/dnd_engine   Dart puro. Cero dependencias de runtime, cero Flutter.
packages/dnd_app      Flutter web. Depende del engine.
packages/dnd_server   shelf + Postgres. Depende del engine.
```

La dirección es estricta: **el engine no conoce a nadie**. Si algo necesita
`BuildContext` o `dart:io`, no va ahí.

## Lo que hay que entender antes de tocar nada

### El motor está dirigido por datos, no por código

El contenido de D&D vive en JSON (`packages/dnd_engine/lib/assets/srd_2024/`) y
declara listas de `Effect` (`domain/effects.dart`), que es una jerarquía sellada
y **serializable**. `CharacterCompiler` (`engine/character_compiler.dart`) los
interpreta y produce un `ComputedSheet`.

La consecuencia práctica: **agregar contenido es cargar JSON, no programar.** Una
dote homebrew pasa exactamente por la misma maquinaria que una del manual. Antes
de escribir un `if` para un rasgo nuevo, fijate si se puede expresar como efecto.

### La UI nunca recalcula una regla

Todo número que se muestra sale de `ComputedSheet`. Si una pantalla necesita un
cálculo que no está ahí, el cálculo va al engine con su test, no al widget.

### `schemaVersion` es solo para documentos de usuario

`Character`, `Campaign`, `Chapter`, `Note`, `Encounter` y `EncounterLog` llevan
`currentSchemaVersion` + `migrateJson`: se guardan en la base y hay que poder
migrarlos. El contrato es siempre el mismo — no mutar la entrada, y **rechazar
una versión futura** en vez de guardarla de vuelta perdiendo campos.

`Creature` (y el resto del catálogo) **no lo lleva, y está bien**: es contenido
que viaja con el build, no un documento de nadie. No le agregues maquinaria de
migración.

### La autorización vive adentro del `WHERE`

En el servidor, la comprobación de propiedad va en la consulta, nunca en el
handler:

```sql
DELETE FROM campaign_members
WHERE id = @memberId AND (dm_user_id = @userId OR owner_user_id = @userId)
```

Así no existe forma de llamar a un repositorio y saltearse la autorización, ni
siquiera desde un handler nuevo escrito con prisa. Consecuencia: **lo ajeno y lo
inexistente responden igual** (404, mensajes inespecíficos). Distinguirlos
convertiría la API en una forma de averiguar qué hay en otras cuentas.

`campaign_members` es **la única puerta** por la que una cuenta alcanza datos de
otra, y esa fila solo existe si el dueño del personaje emitió un código y
alguien lo canjeó. Todo esto está explicado en
`docs/Informacion tecnica del proyecto/vinculo-personaje-campania.md`, que es
lectura obligatoria antes de tocar rutas de campaña.

**La única excepción viva**, y hay que conocerla: `_listPlayerCampaignsHandler`
(la campaña vista por el jugador) le pasa a cuatro repositorios un `dmUserId`
que no es de quien pide. Es correcto porque salió de una fila ya autorizada por
`listSharesForCharacter`, pero invierte el supuesto del contrato.

### El DM no escribe la ficha de otra cuenta

Es la frontera de diseño del Modo DM, y se sostuvo incluso donde parecía natural
cruzarla: subir de nivel, repartir oro y entregar objetos son **avisos**, no
escrituras. El jugador los anota en su propia ficha. Hay pruebas negativas que
comparan el documento del personaje antes y después.

Lo único que el DM escribe son los PG de sus monstruos, que son suyos y
efímeros.

### Los conteos del catálogo son aserciones

`packages/dnd_engine/test/content_integrity_test.dart` fija cuántas clases,
dotes, conjuros y criaturas hay. Tocar el contenido rompe esos tests **a
propósito**: actualizalos con el número nuevo, y si la aserción que se rompe es
una regla y no un conteo (por ejemplo el techo de VD del pozo de Forma Salvaje),
tratala como un aviso y no como un test molesto.

Los catálogos grandes se generan con herramientas commiteadas en
`packages/dnd_engine/tool/`. No edites `creatures.json` a mano: corré
`generate_bestiary.dart`. Ojo que el PDF del SRD en español está **en metros** y
el catálogo en pies.

## Frontend

La guía completa es
`docs/Informacion tecnica del proyecto/guia-diseno-web.md`, y su §8 es el
catálogo de componentes: **antes de crear un widget visual nuevo, buscá ahí**.

Lo que más se olvida:

- Los colores salen de `context.palette` (`AppPalette`, un `ThemeExtension`).
  **Nunca un hex literal**, nunca `Colors.red` / `Colors.grey`.
- Hay **tres niveles de fondo y no más**: `scaffold` → `surface` → `plaque`. La
  placa siempre se hunde, nunca se eleva. Sin `elevation`, sin sombras para
  separar superficies.
- Georgia solo para títulos y valores de plaqueta. Un número pensado para
  comparar contra el de al lado va en sans negrita con
  `FontFeature.tabularFigures()`.
- Radio 12 para tarjetas, 20 para pills, 9 para el panel lateral.
- Para medir el ancho disponible, `LayoutBuilder` y **nunca `MediaQuery.size`**:
  el panel lateral de 236 px es invisible para `MediaQuery`.
- Todo `IconButton` lleva `tooltip`.

Los widgets de estado ya existen y se usan siempre los mismos: `AppErrorView`
(con `onRetry`), `AppBusyLabel` (el texto es obligatorio) y `AppEmptyState`,
que distingue «no hay nada» de «nada coincide con la búsqueda» — son
situaciones distintas y piden acciones distintas.

## Tests

Los tests de widget montan el árbol real contra `FakeApiServer`
(`packages/dnd_app/test/fakes/fake_api_server.dart`), un doble en memoria que
reproduce el **contrato observable** de cada endpoint. Cuando agregues una ruta
al servidor, agregala también ahí — y con las mismas podas, porque un doble más
permisivo deja pasar una pantalla que muestra lo que no debe.

Convenciones del repositorio: nombres de test en español, contenido SRD real
cargado en `setUpAll` con `ContentRepository.loadFromDirectory`, valores
esperados **derivados del catálogo** (`repo.creature('...')!`) y no literales, y
`expect(tester.takeException(), isNull)` al cierre.

## Deuda marcada

Buscá `ponytail:` en el código: son simplificaciones deliberadas, cada una con
su techo y su camino de salida escritos al lado. Antes de "arreglar" una,
leela — puede ser una decisión y no un olvido.

## Documentación

- `README.md` — qué hace la aplicación, para quien la usa.
- `docs/Informacion tecnica del proyecto/vinculo-personaje-campania.md` — el
  Modo DM entero: vínculo, autorización, capítulos, combate, cuaderno y la
  campaña vista por el jugador.
- `docs/Informacion tecnica del proyecto/guia-diseno-web.md` — tokens,
  componentes, accesibilidad, anti-patrones.
- `docs/Informacion tecnica del proyecto/despliegue.md` — runbook del stack.
- `docs/Auditorias/instrucciones-correccion-datos-dnd-2024.md` — la regla de
  precedencia entre fuentes de datos de D&D. Importa: 5etools es la fuente
  **estructural** (números, ids), y el PDF español del SRD es la autoridad de
  **mecánica y texto en español**.
