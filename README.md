# Fichas D&D 5e

App personal (uso propio y de los jugadores de la mesa, no comercial) para crear, visualizar y editar
fichas de personaje de **D&D 5ª edición — reglas 2024 (SRD 5.2)**, con seguimiento en tiempo real durante
partidas y generación de retratos por IA. Offline-first: todo lo esencial funciona sin conexión.

El brief funcional completo está en [`brief-app-dnd5e.md`](brief-app-dnd5e.md). Guía de arquitectura para
desarrollo asistido por IA en [`CLAUDE.md`](CLAUDE.md).

## Tecnologías

Monorepo con dos paquetes:

- **`packages/dnd_engine`** — motor de reglas en **Dart puro** (sin Flutter). Modelos de contenido dirigidos
  por datos, compilador de ficha, validación, combate, dados. Se testea de forma aislada con `package:test`.
- **`packages/dnd_app`** — app **Flutter** (target actual: **Windows desktop**). UI, persistencia local en
  archivos JSON, generación de retratos por IA, editor de contenido homebrew. Depende de `dnd_engine` por
  path local (mismo repo).

Sin backend ni base de datos externa: la persistencia es JSON en disco (`~/FichasDnD/`), sin plugins nativos
de Flutter a propósito (para no depender del "Modo Desarrollador" de Windows). Generación de imágenes vía
Pollinations (gratis, sin key), con Hugging Face y Gemini como alternativas configurables.

## Scope

- Un personaje = una sola clase (sin multiclase).
- Reglas oficiales del SRD 2024 como base precargada; **homebrew** (razas, clases, dotes, objetos) con el
  mismo modelo de datos que el contenido oficial, sin distinción de motor.
- Validación de reglas **no bloqueante**: la app advierte, nunca impide la acción.
- Todo el módulo esencial (fichas, combate, inventario, descansos) funciona 100% offline. Solo la
  generación de retratos requiere conexión.
- **Fuera de alcance** (visión a futuro, no bloqueada por la arquitectura actual): motor de hechizos
  (clases mágicas), multiclase, sincronización en la nube, Modo DM.

## MVP subido

Motor de reglas dirigido por datos (`Effect` sellado y serializable, `CharacterCompiler` →
`ComputedSheet`) con contenido semilla del SRD 2024 centrado en la clase **Guerrero** (caso validado:
Sagan "The Red", Humano nivel 1). Incluye:

- Wizard de creación de personaje guiado (raza, clase, trasfondo, puntuación de habilidades, equipo).
- Ficha completa con cálculos automáticos: CA, PG, ataques, competencias, pasivas, maestría de armas.
- Seguimiento de partida: daño/curación, condiciones, descansos, salvaciones de muerte, recursos de clase.
- Subida de nivel manual con resumen de rasgos ganados.
- Persistencia local con guardado automático (debounce) y export/import de fichas.
- Generación de retratos por IA con proveedor configurable.
- Editor de contenido homebrew (razas, dotes, armas, armaduras) integrado al mismo motor de reglas.
- Tema visual propio (paleta oscura por defecto) para la app de escritorio.

## Comandos

Requiere el SDK de Dart (`dart`) y Flutter (`flutter`) en el `PATH`.

### Motor (`packages/dnd_engine`, Dart puro)

```sh
cd packages/dnd_engine
dart pub get
dart test                                    # todos los tests
dart test test/character_compiler_test.dart  # un archivo puntual
dart test -n "Sagan nivel 1"                 # por nombre de test
```

### App (`packages/dnd_app`, Flutter)

```sh
cd packages/dnd_app
flutter pub get
flutter analyze                  # debe quedar sin issues antes de commitear
flutter test
flutter run -d windows           # correr en escritorio
flutter build windows --release  # build de release
```

## Estructura

```
brief-app-dnd5e.md        # brief funcional completo
CLAUDE.md                 # guía de arquitectura para desarrollo asistido
packages/
  dnd_engine/              # motor de reglas (Dart puro)
    lib/src/domain/         # modelos: Ability, Effect, contenido, Character, ComputedSheet
    lib/src/engine/         # SheetBuilder, CharacterCompiler, CharacterValidator, combate, dados
    lib/src/data/           # ContentRepository (carga de packs de contenido)
    test/                   # tests del motor
  dnd_app/                # app Flutter
    lib/                     # UI, persistencia, IA, homebrew, tema
    test/                    # tests de la app
```
