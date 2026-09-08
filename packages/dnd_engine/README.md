# dnd_engine

Núcleo **Dart puro** (sin Flutter) de la app de fichas de D&D 5e: motor de
reglas dirigido por datos, modelos de contenido y validación no bloqueante.
Reglas de 2024: **SRD 5.2.1 (CC-BY-4.0)** y contenido ampliado identificado
por origen; ver [reglas y licencia](../../README.md#reglas-y-licencia).

## Idea central

Especies, clases, trasfondos, dotes, armas y armaduras son **datos** (JSON) que
declaran una lista de [`Effect`](lib/src/domain/effects.dart). El
[`CharacterCompiler`](lib/src/engine/character_compiler.dart) interpreta esos
efectos sobre las elecciones del personaje y produce una `ComputedSheet`
derivada (características, CA, PG, pasivas, ataques, recursos). Contenido oficial
y homebrew usan exactamente la misma maquinaria: **agregar contenido es cargar
JSON, no programar**.

## Estructura

- `lib/src/domain/` — contenido, efectos, personajes, fichas calculadas y
  documentos de campaña y combate.
- `lib/src/engine/` — compilación y validación de fichas, operaciones de
  combate e inventario, dados y Forma Salvaje.
- `lib/src/data/content_repository.dart` — repositorio en memoria + carga de packs.
- `lib/assets/srd_2024/` — clases, subclases, especies, linajes, trasfondos,
  dotes, equipo, objetos mágicos, conjuros y criaturas. Bajo `lib/` para usarlo como
  asset de Flutter vía `packages/dnd_engine/assets/srd_2024/...`. Su
  `manifest.json` declara el formato y el reglamento antes de cargar los datos.
- `test/` — reglas, serialización, migraciones e integridad del catálogo;
  `content_integrity_test.dart` fija los conteos y contratos del contenido.
- `tool/` — generación y parches del catálogo; el orden y las fuentes están
  descritos en [CLAUDE.md](../../CLAUDE.md#los-conteos-del-catálogo-son-aserciones).

Los modelos y las reglas no dependen de Flutter ni de `dart:io`. El cargador
de directorios usa una importación condicional para aislar `dart:io`; el
cliente web carga los assets y llama a `ContentRepository.fromJsonPacks`.

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
