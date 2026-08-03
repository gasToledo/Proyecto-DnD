# CLAUDE.md

Guía técnica para trabajar con Claude Code u otros asistentes de desarrollo en
este repositorio.

## Producto

Aplicación personal y offline-first para crear, administrar y usar fichas de
personaje de **D&D 5e con reglas 2024 (SRD 5.2.1)**.

Es un monorepo con dos paquetes:

- `packages/dnd_engine`: motor de reglas en Dart puro, sin Flutter.
- `packages/dnd_app`: aplicación Flutter. El producto distribuido actualmente
  tiene como plataforma principal Windows.

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
- Persistencia atómica, recuperación de archivos dañados y migraciones
  secuenciales de datos.
- Exportación individual y respaldos ZIP completos.
- Wizard de creación y ficha divididos en módulos durante la fase de
  mantenibilidad actual.

Limitaciones vigentes: cada personaje usa una sola clase; no hay sincronización
en la nube ni Modo DM. `docs/auditoria-reglas-2024.md` mantiene el detalle de
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

Aplicación:

```sh
cd packages/dnd_app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

Antes de cerrar un cambio de código, como mínimo deben pasar el análisis y los
tests del paquete afectado. Para cambios de UI, persistencia, dependencias o
integración, también generar el build release de Windows.

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

`main.dart` carga el pack oficial mediante `AssetContentLoader`, incorpora el
contenido de `HomebrewStore` al mismo `ContentRepository` y luego inicia
`CharactersController`.

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

**Nada de 2014.** Este proyecto es de reglas 2024 y punto. Cualquier material
que sea de la edición 2014 —el PHB viejo, un SRD 5.1 o anterior, *Eberron:
Rising from the Last War* (2019), un wiki o un blog que no diga de qué edición
habla— **no es fuente válida**: se ignora y se busca la versión 2024 del mismo
contenido. Si esa versión no existe, el contenido no entra; no se porta a mano
desde 2014.

Esto no es purismo: es la causa concreta de los peores defectos que encontró la
auditoría. Furia Implacable, Golpes Potenciados, Presencia Dracónica,
`feeblemind` y diez descripciones de dote llegaron al catálogo con el **nombre
correcto de 2024 y el texto de 2014**, que es justo lo que ninguna verificación
por tabla puede ver: el id apunta bien, la tabla cuadra, y lo que está mal es la
regla. Por eso la sospecha va sobre el texto y no sobre el nombre.

Al leer una fuente de Eberron esto se vuelve el criterio de desempate: manda
*Forge of the Artificer* (2025), y RftLW (2019) solo aporta lo que FoA no
contradiga —ambientación, casas, nombres—, nunca mecánica. Las marcas
dracónicas son el ejemplo: en RftLW son variantes de raza y en FoA son dotes
sin prerrequisito de especie. Gana FoA.

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

Los datos se guardan bajo `<perfil>/FichasDnD/`, usando `app_paths.dart` y
`package:path`:

- `characters/`: un JSON por personaje.
- `homebrew/`: contenido creado por el usuario.
- `portraits/<characterId>/`: retratos.
- `exports/`: exportaciones y respaldos.
- `recovery/`: archivos dañados apartados.
- `recovery/migrations/`: copia exacta previa a cada migración.
- `settings.json`: preferencias y configuración de retratos.

Las escrituras importantes usan reemplazo atómico. `CharactersController`
mantiene la fuente de verdad en memoria, guarda con debounce de 400 ms y hace
`flush` cuando la aplicación pasa a segundo plano o se cierra ordenadamente.

Personajes, ajustes, homebrew, borradores y paquetes declaran versión. Los datos
históricos compatibles se migran de forma secuencial; una versión futura debe
rechazarse sin modificar ni sobrescribir el archivo.

Las importaciones se tratan como datos no confiables: validar versiones, tipos,
identificadores y segmentos de ruta. Los respaldos ZIP no deben permitir que una
ruta escape de `FichasDnD`.

### Retratos IA

`PortraitProvider` es intercambiable. Pollinations es la opción predeterminada
sin clave; Azure AI Foundry (Flux) y Azure gpt-image-2 usan claves configuradas
por el usuario. Son **dos recursos distintos de Azure**, cada uno con su propia
key y su propia API: Flux habla la ruta de Black Forest Labs
(`/providers/blackforestlabs/`, `azure_image_service.dart`) y gpt-image-2 la
ruta estilo OpenAI (`/openai/deployments/`, `azure_openai_image_service.dart`).
Por eso son dos servicios y no un endpoint parametrizado.

gpt-image-2 es el único proveedor que acepta imagen de referencia, vía
`images/edits`. Hugging Face y Gemini fueron retirados; sus ids quedan en
`retiredProviderIds` para que un `settings.json` viejo degrade a Pollinations,
y la migración a la versión 4 de ajustes borra sus credenciales huérfanas.

Las credenciales se envían por encabezado, nunca
en la URL, se guardan en `settings.json` y no se incluyen en los respaldos
(`portableCredentialKeys` las filtra por nombre, incluidas las de proveedores
retirados).
También se puede importar un retrato desde un archivo local mediante
`file_picker`.

## Restricciones del entorno Windows

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
   `~/FichasDnD/` en Git.
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
