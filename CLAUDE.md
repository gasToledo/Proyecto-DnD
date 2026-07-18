# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

App personal (offline-first) para crear y gestionar fichas de personaje de **D&D 5e, reglas 2024 (SRD 5.2)**. Monorepo con dos paquetes:

- `packages/dnd_engine` — **Dart puro, sin Flutter**: motor de reglas dirigido por datos, modelos de contenido, compilador de ficha, validación, combate, dados. Es el núcleo y se testea aislado.
- `packages/dnd_app` — app **Flutter** (hoy solo target **Windows desktop**): UI, persistencia, retratos IA, homebrew. Depende de `dnd_engine` por path.

El brief funcional está en `brief-app-dnd5e.md`.

## Comandos

Flutter está en `C:\dev\flutter\bin\flutter.bat` (y en el PATH de usuario); el SDK de Dart (winget) provee `dart`.

Motor (Dart puro):
```sh
cd packages/dnd_engine
dart pub get
dart test                                   # todos
dart test test/character_compiler_test.dart # un archivo
dart test -n "Sagan nivel 1"                # por nombre
```

App (Flutter):
```sh
cd packages/dnd_app
flutter pub get
flutter analyze                 # debe quedar sin issues antes de commitear
flutter test                    # todos; o: flutter test test/portrait_test.dart
flutter run -d windows          # correr en escritorio
flutter build windows --release # el acceso directo del Escritorio apunta al exe release; recompilar para actualizarlo
```

## Gotchas del entorno (importantes)

- **La ruta del proyecto NO puede contener `&`**: el build de Windows de Flutter rechaza rutas con caracteres inválidos (`'#!$^&*=|,;<>?`). La carpeta se renombró de "Proyecto D&D" a **"Proyecto DnD"** por esto. Los espacios sí están permitidos.
- **Sin plugins nativos, a propósito**: usar plugins de Flutter (path_provider, file_picker, etc.) dispara el requisito de "Modo Desarrollador" de Windows (symlinks) y rompe `pub get`. En su lugar se usan solo paquetes Dart puros (`http`, `path`) y `dart:io` con variables de entorno (`%LOCALAPPDATA%`, `%USERPROFILE%`). Al portar a Android/iOS habrá que reintroducir path_provider detrás de las interfaces ya existentes.
- **Construir rutas con `package:path` (`p.join`)**, nunca concatenando con `/`. Mezclar `\` y `/` rompe `explorer.exe` (abrir carpeta) en Windows.
- La UI de escritorio **no se puede capturar** en este entorno. Verificar con: `flutter analyze` + `flutter build` + lanzar el exe (chequear que no crashea) + los tests del motor. Para lo visual, hace falta el ojo del usuario.

## Arquitectura: motor dirigido por datos (lo central)

Todo el diseño gira alrededor de esto. Entenderlo requiere leer `dnd_engine/lib/src/`.

- **`Effect`** (`domain/effects.dart`) es una **unión sellada, serializable a JSON**: la unidad atómica de "lo que un rasgo hace" (bonus a característica, visión en la oscuridad, resistencia, competencia, +CA, PG por nivel, recurso, rasgo pasivo, maestría de arma, etc.).
- Las entidades de contenido — `Race`, `CharacterClass`, `Background`, `Feat`, `Weapon`, `Armor` (`domain/content.dart`) — son **datos** que declaran listas de `Effect`.
- **`CharacterCompiler`** (`engine/character_compiler.dart`) toma un `Character` (con todas las elecciones ya resueltas) + el `ContentRepository` y produce una **`ComputedSheet`** inmutable (características finales, CA, PG, competencias, pasivas, ataques, recursos). La UI **lee de la `ComputedSheet`; nunca recalcula a mano**.
- El compilador delega la semántica de cada efecto a `SheetBuilder.applyEffect` (`engine/sheet_builder.dart`), un `switch` **exhaustivo** sobre el sellado `Effect`. **Agregar una mecánica nueva = agregar una subclase de `Effect` y su caso en ese switch.** Agregar *contenido* (una raza, un arma) = solo datos/JSON, sin tocar código.
- **Oficial y homebrew comparten exactamente los mismos modelos.** El homebrew es contenido con `source: homebrew` que se fusiona en el mismo `ContentRepository` (`repo.addAll`). Por eso lo que crea el usuario funciona igual que lo del SRD.
- **Validación no bloqueante** (`engine/validation.dart`): produce advertencias, nunca impide una acción.
- La **edición de reglas es un dato de configuración**, no está cableada (baseline 2024; se podría sumar un pack 2014).

Otras piezas puras del motor, todas testeadas: `combat_ops.dart` (daño/curación/descansos/salvaciones de muerte), `dice.dart` (4d6, array estándar, dado de golpe), `sheet_diff.dart` (diff antes/después para el resumen de subida de nivel).

### Character como fuente de verdad y formato de export

`Character` (`domain/character.dart`) es la fuente de verdad **y**, serializado, el formato de exportación. Su `CombatState` mutable (PG, condiciones, death saves, recursos usados) es estado de partida y vive aparte de las entradas de construcción. `copyWith` preserva el `CombatState` por referencia salvo que se pase uno nuevo — clave para editar equipo/nivel sin perder el estado de combate.

## Arquitectura de la app (Flutter)

- **Contenido**: `AssetContentLoader` carga el pack oficial (`packages/dnd_engine/assets/srd_2024/*.json`, empaquetado como asset del paquete engine vía `rootBundle`) y `HomebrewStore` el homebrew; se fusionan al arrancar en `main.dart` (`_init`).
- **Persistencia**: `CharacterStore` guarda un JSON por personaje en `~/FichasDnD/characters` (escritura atómica: temp + rename). `CharactersController` (ChangeNotifier) es la fuente de verdad en memoria y persiste con **debounce de 400 ms** ante cada cambio relevante (criterio del brief §8).
- **Directorios de datos** (todos bajo `~/FichasDnD/`): `characters/`, `exports/`, `portraits/<charId>/`, `homebrew/`, `settings.json`. El helper es `data/app_paths.dart`.
- **Export/import** (`data/transfer_service.dart`): JSON versionado con envoltorios `dnd_character` y `dnd_backup`. Import no destructivo (colisión de id → id nuevo). Parseo puro y testeable.
- **Retratos IA** (`ai/`): `PortraitProvider` **enchufable**. Default **Pollinations** (gratis, sin key, secuencial + reintento ante 429). También Hugging Face (token, endpoint `router.huggingface.co/hf-inference/...`, modelo editable) y Gemini (billing). Las keys viajan por header, nunca en URL, y se guardan en settings.json.
- **Tema** (`theme/`): `AppTheme` + `AppPalette` (ThemeExtension con oro/carmesí/tinta). **El oscuro es el tema por defecto y el prioritario** (`themeMode: ThemeMode.dark`) — el usuario siempre usa oscuro. Widgets temáticos reutilizables en `theme/app_widgets.dart`.

## Fuera de alcance (visión futura)

Motor de hechizos (habilita clases mágicas y multiclase mágica), multiclase, sincronización en la nube y Modo DM están **fuera del MVP**. La arquitectura de `Effect`/contenido se diseñó para no bloquearlos. El MVP es **marcial** (Guerrero como caso validado; ver brief §10).
