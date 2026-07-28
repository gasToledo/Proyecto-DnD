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
  Artificer*), 8 linajes, 33 trasfondos, 87 dotes, los 388 conjuros del
  capítulo 7 del PHB y 1 conjuro de *Forge of the Artificer*.
- Creación guiada, subida de nivel, combate, inventario, notas y retratos IA.
- Persistencia atómica, recuperación de archivos dañados y migraciones
  secuenciales de datos.
- Exportación individual y respaldos ZIP completos.
- Wizard de creación y ficha divididos en módulos durante la fase de
  mantenibilidad actual.

Limitaciones vigentes: cada personaje usa una sola clase; no hay sincronización
en la nube ni Modo DM.

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
sin clave; Hugging Face y Gemini usan claves configuradas por el usuario. Las
credenciales se envían por encabezado, nunca en la URL, se guardan en
`settings.json` y no se incluyen en los respaldos.

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
