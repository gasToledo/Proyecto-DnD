# dnd_engine

Núcleo **Dart puro** (sin Flutter) de la app de fichas de D&D 5e: motor de
reglas dirigido por datos, modelos de contenido y validación no bloqueante.
Baseline de reglas: **SRD 5.2 (2024, CC-BY-4.0)**.

## Idea central

Razas, clases, trasfondos, dotes, armas y armaduras son **datos** (JSON) que
declaran una lista de [`Effect`](lib/src/domain/effects.dart). El
[`CharacterCompiler`](lib/src/engine/character_compiler.dart) interpreta esos
efectos sobre las elecciones del personaje y produce una `ComputedSheet`
derivada (características, CA, PG, pasivas, ataques, recursos). Contenido oficial
y homebrew usan exactamente la misma maquinaria: **agregar contenido es cargar
JSON, no programar**.

## Estructura

- `lib/src/domain/` — modelos: `Ability`, `Effect` (unión sellada), contenido,
  `Character`, `ComputedSheet`.
- `lib/src/engine/` — `SheetBuilder`, `CharacterCompiler`, `CharacterValidator`.
- `lib/src/data/content_repository.dart` — repositorio en memoria + carga de packs.
- `lib/assets/srd_2024/` — pack semilla marcial (Humano, Guerrero, Soldado,
  dotes, armas, armaduras). Bajo `lib/` para poder empaquetarlo también como
  asset de Flutter vía `packages/dnd_engine/assets/srd_2024/...`. Su
  `manifest.json` declara el formato y el reglamento antes de cargar los datos.
- `test/` — tests del compilador contra el caso Sagan (brief §10) y subida a L2.

`Character` usa un esquema versionado con migraciones secuenciales. Una versión
futura lanza `UnsupportedDataVersionException` antes de interpretar o modificar
el documento.

## Correr los tests

Requiere el SDK de Dart (o Flutter, que lo incluye):

```sh
cd packages/dnd_engine
dart pub get
dart test
```
