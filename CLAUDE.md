# CLAUDE.md

Guía técnica para trabajar con Claude Code u otros asistentes de desarrollo en
este repositorio.

## Producto

Aplicación web autoalojada, con cuenta por jugador, para crear, administrar y
usar fichas de personaje de **D&D 5e con reglas 2024 (SRD 5.2.1)**. Dejó de
ser offline-first: el cliente necesita conexión con el servidor propio para
leer y escribir fichas (ver `openspec/changes/migrate-to-self-hosted-webapp/`,
la migración que llevó el producto de escritorio local a este modelo).

Es un monorepo con tres paquetes:

- `packages/dnd_engine`: motor de reglas en Dart puro, sin Flutter. Sin
  dependencias de ejecución; lo comparten el cliente y el servidor.
- `packages/dnd_app`: cliente Flutter, compilado para navegador. Es la
  plataforma que se mantiene activamente.
- `packages/dnd_server`: API en Dart (persistencia en PostgreSQL,
  autenticación OIDC contra Zitadel, almacenamiento y generación de
  retratos). Sirve además el build web del cliente desde el mismo origen (ver
  `Arquitectura de la aplicación`, `Retratos IA` y `docs/despliegue.md`).

La **aplicación de escritorio de Windows quedó congelada** en su último
release publicado: no recibe funcionalidad nueva. Su única responsabilidad
restante es generar el respaldo ZIP que un jugador sube para migrar sus datos
a una cuenta del servidor (`docs/despliegue.md`, "Primer arranque"). Los
comandos `flutter run -d windows` / `flutter build windows --release` siguen
existiendo en el código pero ya no son la ruta de desarrollo activa.

El brief funcional original está en `brief-app-dnd5e.md`. Algunas secciones de
ese documento describen el alcance inicial; el código actual ya incluye clases
lanzadoras, conjuros, subclases, homebrew, respaldos y migraciones.

## Estado actual

- 13 clases y 53 subclases: 12 clases y 48 subclases del PHB 2024 (12 de esas
  subclases están además en el SRD 5.2.1), más la clase Artífice y sus 5
  subclases de *Forge of the Artificer*.
- 15 especies (9 del SRD, Aasimar del PHB 2024 y 5 de *Forge of the
  Artificer*), 24 linajes (8 SRD, 16 PHB 2024), 33 trasfondos, 183 dotes
  (10 SRD, 145 PHB 2024, 28 FoA), 28 Invocaciones Sobrenaturales del Brujo
  y 392 conjuros (177 SRD, 214 PHB 2024, 1 FoA).

  Las 183 dotes representan las 75 del capítulo 5: **una dote que deja elegir
  el bono de característica se carga como una variante por opción**, todas con
  el mismo `exclusiveGroup`, que es lo que impide tomar dos. Son 33 familias
  así. Nombrarlas es el nombre del manual más la característica entre
  paréntesis, y el id es el id base más la característica en inglés.
- Creación guiada, subida de nivel con wizard multi-paso (resumen, puntos de
  golpe, subclase, mejora de característica, elecciones abiertas, rasgos,
  conjuros y repaso, cada paso mostrado solo si aplica al nivel), combate,
  inventario, notas y retratos IA.
- Retratos IA con Pollinations, Azure AI Foundry (Flux) o Azure gpt-image-2
  como proveedor, además de importar un retrato desde archivo local.
- Persistencia en el servidor con migraciones secuenciales de esquema y
  escritura multi-documento transaccional (recuperación de archivos dañados
  era un concepto del almacenamiento local de la versión de escritorio; no
  tiene equivalente en Postgres, ver `### Persistencia y ciclo de datos`).
- Exportación individual y respaldos ZIP completos.
- Wizard de creación y ficha divididos en módulos durante la fase de
  mantenibilidad actual.
- Migración a webapp autoalojada completa a nivel de código: cliente web,
  servidor propio con persistencia en PostgreSQL, autenticación OIDC contra
  Zitadel y despliegue en contenedores (ver `docker-compose.yml` y
  `docs/despliegue.md`). El arranque en limpio de ese stack no se ejecutó
  todavía contra un dominio real; queda como siguiente paso operativo, no de
  código.

Limitaciones vigentes: cada personaje usa una sola clase; no hay Modo DM ni
funcionamiento sin conexión (ver el párrafo anterior: el cliente requiere el
servidor propio). `docs/auditoria-reglas-2024.md` mantiene el detalle de
pendientes mecánicos (Agotamiento/Inspiración Heroica sin efecto mecánico,
compra de puntos, precio/peso de equipo, objetos mágicos y compañeros con
estadísticas propias, entre otros).

## Elecciones abiertas

Estilo de Combate e Invocaciones Sobrenaturales son el mismo problema —"elegí N
opciones de un catálogo, con prerrequisitos, revisable al subir de nivel"— y los
resuelve un solo mecanismo.

El catálogo de opciones **son `Feat`s**, discriminadas por `category`: ya traen
efectos, `exclusiveGroup` y prerrequisitos que el validador sabe evaluar. La
declaración es `FeatureChoiceEffect`, un **marcador** (como `GrantFeatEffect`
sin `featId`) que vive dentro de un rasgo de clase y por eso hereda el nivel de
`featuresUpTo`. `count` es el total **acumulado** a ese nivel, no el incremento:
gana el mayor, igual que `ResourceEffect` y `WeaponMasterySlotsEffect`.

`ComputedSheet.featureChoiceSlots` es el contrato con la aplicación: la UI
pregunta a la ficha compilada qué falta elegir y **nunca** recorre
`klass.features` por su cuenta. Las elecciones se guardan en
`Character.featureChoices` (grupo → ids).

Agregar un catálogo nuevo es agregar dotes con su categoría: ni el motor ni la
aplicación llevan lista de ids, y `feature_choice_test.dart` lo prueba con
contenido inventado.

El motor aplica la regla 2024 de combate con dos armas. La mano secundaria se
marca por arma (`Character.weaponOffHand`), no se infiere del orden de equipado:
cambia el daño y la economía de acciones, así que adivinarla daría una ficha
distinta sin que el jugador lo pida. El ataque de esa mano pierde el modificador
al daño **solo si es positivo** —uno negativo se sigue restando— y lo recupera
con el estilo Combate con Dos Armas, que el compilador lee como
`OffHandAbilityDamageEffect` en vez de preguntar por el id de la dote. `Attack`
expone `offHand` y `action` ya resueltos para que la ficha no recalcule nada.

`nick` es la única maestría con efecto mecánico: mete ese ataque dentro de la
acción de Atacar. El resto del glosario sigue siendo descriptivo.

## Conjuros que concede un rasgo

Son **dos** efectos distintos y no hay que confundirlos:

- `GrantSpellEffect` → conjuro **innato**. Se lanza sin gastar espacio, con CD
  y bonificador propios y un límite de usos propio. Sale en
  `ComputedSheet.innateSpells`.
- `AlwaysPreparedSpellEffect` → conjuro **siempre preparado**. Se lanza con los
  espacios normales de la clase, como cualquier preparado; lo único que lo
  distingue es que no ocupa cupo de `preparedCount` y no se puede desmarcar.
  Sale en `ComputedSheet.alwaysPreparedSpellIds`.

Las dos listas se unen en un solo lugar: lo que un rasgo ya concede no se puede
volver a elegir con la magia de clase. La selección los oculta y una ficha vieja
que los traiga elegidos se poda al abrir el editor, para devolver el cupo en vez
de dejarlos atrapados sin chip que los saque.

Las tablas de conjuros de subclase se declaran **como un rasgo por nivel** bajo
el mismo nombre ("Conjuros de Alquimista" a 3, 5, 9, 13 y 17). Así heredan el
nivel de `featuresUpTo` sin campo extra. Es la única excepción permitida a la
regla de que una subclase no repite nombre de rasgo, y el test que la vigila la
acota a los rasgos cuyos efectos son *solo* esa tabla.

Los tramos los fija la progresión: lanzador completo 3/5/7/9, semi-lanzador
3/5/9/13/17. Las tienen 24 subclases. Que un conjuro sea **truco** en la tabla
es legítimo —el Patrón Celestial concede Llama Sagrada y Luz— y tampoco ocupa
cupo de trucos de clase.

## Comandos

Flutter está disponible en el `PATH` del usuario. Ejecutar cada grupo desde el
paquete indicado.

Motor:

```sh
cd packages/dnd_engine
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

Pruebas puntuales del motor:

```sh
dart test test/character_compiler_test.dart
dart test -n "Sagan nivel 1"
```

Aplicación (cliente web, plataforma mantenida):

```sh
cd packages/dnd_app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
```

`flutter run -d windows` y `flutter build windows --release` siguen
funcionando pero corresponden a la aplicación de escritorio **congelada**: no
es la ruta de desarrollo activa, ver `## Producto`.

Servidor (`packages/dnd_server`, API + autenticación + persistencia; también
sirve el build web del cliente, ver `Arquitectura de la aplicación`):

```sh
cd packages/dnd_server
dart pub get
dart format --output=none --set-exit-if-changed lib bin test
dart analyze
dart test
dart run bin/server.dart
```

Despliegue autoalojado completo (los tres paquetes, contenedores y túnel de
Cloudflare; ver `docs/despliegue.md` para el procedimiento paso a paso):

```sh
cp .env.example .env               # completar secretos, nunca versionar
cp cloudflared/config.example.yml cloudflared/config.yml
docker compose up -d --build
```

Antes de cerrar un cambio de código, como mínimo deben pasar el análisis y los
tests del paquete afectado. Para cambios de UI, persistencia, dependencias o
integración del cliente web, generar además `flutter build web --release`; el
build de Windows ya no es parte del criterio de cierre porque esa plataforma
está congelada.

`.github/workflows/ci.yml` corre estos mismos comandos (los tres paquetes) en
cada push y pull request, en runners alojados por GitHub: es una red de
seguridad, no un reemplazo de correrlos localmente antes de pushear.
`.github/workflows/cd.yml` reconstruye y levanta el stack en el runner
autoalojado ante un push a `main`/`webapp` que toque una ruta relevante para
lo desplegado; ver `docs/despliegue.md` para el aprovisionamiento del runner
y `openspec/changes/add-ci-cd-pipeline/design.md` para las decisiones detrás
de ambos pipelines.

## Arquitectura del motor

El motor está dirigido por datos. La UI nunca debe duplicar reglas ni recalcular
la ficha por su cuenta.

- `domain/effects.dart`: `Effect` es la unión sellada y serializable que
  representa la consecuencia mecánica de un rasgo.
- `domain/content.dart`: especies, clases, subclases, trasfondos, dotes, armas,
  armaduras y conjuros son contenido.
- `domain/damage_type.dart`: los 13 tipos de daño con su nombre en español. El
  contenido los referencia por su id en inglés, que es la clave estable que
  viaja en JSON y en los personajes guardados; la traducción vive solo acá, no
  en la UI. `ImmunityEffect` también se usa hoy para inmunidad a **estados**
  (el Artífice es inmune a `poisoned`), así que `labelFor` los cubre y cae al
  id capitalizado ante cualquier otra cosa, para tolerar homebrew.
- `domain/proficiency_labels.dart`: lo mismo para entrenamiento con armadura,
  categorías de arma y las 25 herramientas del capítulo 6. Un test recorre el
  contenido oficial y falla si alguna competencia cae en la degradación al id
  capitalizado, que es la red para el homebrew, no para el catálogo.
- `data/content_repository.dart`: reúne el contenido oficial y homebrew.
- `engine/character_compiler.dart`: combina un `Character` con el repositorio y
  produce una `ComputedSheet` inmutable.
- `engine/sheet_builder.dart`: interpreta cada `Effect` mediante un `switch`
  exhaustivo.
- `engine/validation.dart`: genera advertencias no bloqueantes.
- `engine/combat_ops.dart`: daño, curación, descansos, recursos, espacios de
  conjuro y salvaciones de muerte.
- `engine/sheet_diff.dart`: calcula los cambios mostrados al subir de nivel.

Agregar contenido normalmente significa agregar o modificar datos JSON. Agregar
una mecánica nueva requiere un nuevo `Effect`, su serialización, el caso
correspondiente en `SheetBuilder` y tests.

### Fuente de verdad

`Character` es la fuente de verdad persistida y exportada. `ComputedSheet` es
siempre derivada. `CombatState` contiene el estado mutable de la partida:
puntos de golpe, condiciones, recursos consumidos y concentración.

`Character.copyWith` preserva `CombatState` por referencia salvo que se entregue
uno nuevo. No romper esta propiedad al editar equipo, conjuros o nivel.

## Arquitectura de la aplicación

### Inicio y contenido

`main.dart` primero resuelve la sesión contra `ApiClient.currentUserId()`; sin
sesión válida, redirige a `/auth/login` (ver capacidad `user-accounts`) y no
sigue arrancando. Con sesión, carga el pack oficial mediante
`AssetContentLoader` (sigue siendo un asset empaquetado en el cliente, no
viaja por red), incorpora el homebrew de la cuenta autenticada
(`HomebrewStore`, respaldado por `ApiClient` en vez de disco) al mismo
`ContentRepository` y luego inicia `CharactersController`.

El contenido oficial vive en
`packages/dnd_engine/lib/assets/srd_2024/`. Su `manifest.json` declara la versión
del formato y la edición de reglas.

Hay dos referencias, que resuelven preguntas distintas. Las **reglas** las manda
el **Manual del Jugador 2024**, que es con el que juega la mesa: si difiere del
SRD, gana el PHB. La **licencia** la manda el **SRD 5.2.1**: solo lo que está
ahí queda cubierto por CC BY 4.0.

No etiquetar contenido PHB como `srd_2024`; el hecho de que una opción sea
oficial no implica que esté incluida en el SRD. Que algo falte en el SRD tampoco
es motivo para excluirlo del catálogo: es motivo para etiquetarlo `phb_2024`.

El detalle y el avance de la comprobación están en
`docs/auditoria-reglas-2024.md`.

*Forge of the Artificer* (2025) es una tercera procedencia, `foa_2025`. No está
en el SRD y no es el PHB, pero la razón de distinguirlo no es de licencia: no
todas las mesas usan esa expansión, así que el jugador tiene que reconocer que
una opción viene de otro libro **antes** de comprometer un personaje con ella.

`ContentSource` distingue `srd_2024`, `phb_2024` y `foa_2025`, y
`content_integrity_test` fija qué ids pertenecen al SRD. Un valor desconocido
degrada a `homebrew` sin
avisar, porque ese mismo parser procesa importaciones no confiables: la red de
seguridad del contenido oficial es el test, no una excepción al cargar. La app
muestra la procedencia con `SourceBadge` en las tarjetas de selección.

### UI

- `creation/creation_wizard.dart`: estado y navegación del asistente.
- `creation/steps/`: cada paso y sus widgets de selección.
- `ui/sheet_screen.dart`: shell y estado de la ficha.
- `ui/sheet/`: pestañas General, Combate, Conjuros, Inventario y Notas, más
  widgets compartidos.
- `ui/dashboard_screen.dart`: shell del dashboard; navegación, contenido,
  acciones y tarjetas viven en `ui/dashboard/`.
- `levelup/`: shell, secciones, widgets y resumen de subida de nivel.
- `homebrew/homebrew_screen.dart`: shell del catálogo; pestañas y acciones en
  `homebrew_tabs.dart`, formularios en `homebrew/forms/`.
- `theme/`: tema, paleta, visuales por clase y widgets reutilizables.

Los archivos divididos con `part` forman una sola biblioteca y pueden acceder al
estado privado de su pantalla. Mantener la lógica compartida en el archivo shell
o en el módulo de widgets; no crear cálculos de reglas dentro de las pestañas.

### Persistencia y ciclo de datos

`lib/data/` ya no toca disco: reemplaza a la capa de almacenamiento local de
la versión de escritorio en vez de portarla (ver `design.md`, decisión D6).
Todo pasa por `lib/api/api_client.dart`, que llama al mismo origen que sirvió
el cliente (`baseUrl` vacío) para que la cookie de sesión `httpOnly` viaje
sola:

- `CharactersController`: fuente de verdad en memoria de los personajes,
  respaldada por `GET/POST/PUT/DELETE /api/characters`. Mantiene el mismo
  patrón de **debounce de 400 ms** y cola de guardado serializada por
  personaje que tenía la versión de escritorio.
- `HomebrewStore` y `SettingsService`: análogos contra `/api/homebrew` y
  `/api/settings`.
- `backup_bundle.dart` / `transfer_service.dart`: siguen armando y leyendo el
  ZIP de respaldo, ahora resolviendo los retratos vía
  `GET /api/portraits/<key>` en lugar de leerlos de disco; el ZIP se
  descarga o sube desde el navegador (`lib/web/browser.dart`), el servidor no
  produce el archivo.

El servidor (`packages/dnd_server`) es quien persiste de verdad: personajes,
homebrew y ajustes viven en PostgreSQL como documentos `jsonb` con propiedad
por cuenta (clave primaria compuesta `(user_id, id)`, ver `design.md`,
decisión D3), migración secuencial de esquemas históricos y escritura
multi-documento transaccional. El detalle está en
`packages/dnd_server/lib/src/repositories/` y `lib/src/db/`, no en este
documento.

La aplicación de escritorio **congelada** seguía el modelo anterior
(`<perfil>/FichasDnD/` con reemplazo atómico y migración local); ese código
ya no existe en `lib/data/` porque no hace falta mantener las dos rutas a la
vez (D6). Quien necesite ese historial lo encuentra en el control de
versiones, no en este documento.

Las importaciones se siguen tratando como datos no confiables: el servidor
valida versiones, tipos, identificadores y segmentos de ruta antes de tocar
la cuenta (ver capacidad `account-data-import`).

### Retratos IA

La generación con IA se mudó entera a `packages/dnd_server` (ver `design.md`,
decisión D9): el navegador nunca habla con Pollinations ni con Azure, y
`dnd_app` ya no tiene servicios de proveedor propios. `PortraitProvider` sigue
siendo intercambiable, pero ahora del lado del servidor
(`lib/src/ai/portrait_provider.dart`); `GET /api/portraits/providers` le
informa al cliente qué proveedores están disponibles, ya filtrados a los que
tienen credenciales configuradas en el servidor (`AiProvidersConfig`, ver
`config.dart`) — un proveedor sin clave nunca aparece como opción.

Azure AI Foundry (Flux) y Azure gpt-image-2 siguen siendo **dos recursos
distintos de Azure**, cada uno con su propia key y su propia API: Flux habla
la ruta de Black Forest Labs (`/providers/blackforestlabs/`) y gpt-image-2 la
ruta estilo OpenAI (`/openai/deployments/`). gpt-image-2 es el único que
acepta imagen de referencia, vía `images/edits`.

Las credenciales viven en variables de entorno del servidor
(`DND_AZURE_FLUX_API_KEY`, `DND_AZURE_OPENAI_API_KEY`, ver `.env.example`),
nunca en el cliente ni en un respaldo: `AppSettings` (`settings_service.dart`)
solo guarda la preferencia de qué proveedor usar por defecto, no
credenciales.

También se puede subir un retrato propio desde un archivo local
(`POST /api/characters/<id>/portraits`), disponible aunque el servidor no
tenga ningún proveedor de IA configurado.

## Restricciones del entorno Windows

Esta sección solo aplica a quien necesite tocar la aplicación de escritorio
**congelada**; el cliente mantenido es el build web, ver `## Producto`.

- La ruta del proyecto no puede contener `&`; Flutter rechaza ese carácter al
  construir para Windows. El nombre correcto de la carpeta es `Proyecto DnD`.
- El Modo Desarrollador de Windows está habilitado para poder construir con
  plugins nativos (`file_picker`, usado para importar retratos desde archivo,
  es el primero). Sigue siendo buena práctica evitar sumar plugins nativos sin
  necesidad: cada uno agregado exige que cualquier máquina que compile el
  proyecto tenga el Modo Desarrollador activo. Antes de agregar una
  dependencia nueva, comprobar si introduce plugins o symlinks y si el mismo
  resultado se puede lograr sin ellos.
- Construir rutas con `package:path` (`p.join`), nunca concatenando `/`.
- No asumir que una comprobación visual queda cubierta por tests. Para cambios
  visibles, validar análisis, tests y build, y describir qué necesita revisar
  manualmente el usuario.

## Criterios para cambios

1. Leer el módulo afectado y sus tests antes de editar.
2. Mantener reglas en `dnd_engine` y presentación/orquestación en `dnd_app`.
3. Preservar compatibilidad de datos o agregar una migración versionada.
4. Agregar una prueba de regresión para cada comportamiento corregido.
5. No incluir credenciales, builds, datos personales ni contenido de
   `~/FichasDnD/` en Git. Esto incluye `.env`, `cloudflared/config.yml` y
   `cloudflared/creds.json` (ver `.env.example` y
   `cloudflared/config.example.yml` para las versiones sin secretos).
6. Formatear, analizar y probar antes del commit.
7. Mantener los commits acotados y actualizar este documento o el README cuando
   cambien arquitectura, alcance, comandos o formatos.

## Modularización completada

La fase de mantenibilidad redujo las pantallas monolíticas sin cambiar su
comportamiento:

- Pasos del wizard extraídos a `creation/steps/`.
- Pestañas de la ficha extraídas a `ui/sheet/`.
- Secciones y widgets de subida de nivel separados dentro de `levelup/`.
- Navegación, contenido, acciones y tarjetas del dashboard en `ui/dashboard/`.
- Pestañas y formularios de homebrew separados dentro de `homebrew/`.

Las extracciones conservan las pruebas existentes y agregan cobertura focalizada
para la ficha y la navegación de homebrew. Futuras divisiones deben seguir el
mismo criterio: estado en el shell, presentación agrupada por responsabilidad,
sin cálculos de reglas en la UI y con análisis, tests y build release.
