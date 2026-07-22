# Fichas D&D 5e

App de escritorio para crear y llevar personajes de **D&D 5ª edición con las reglas de 2024 (SRD 5.2)**. Funciona sin conexión: armás el personaje con un asistente paso a paso y la ficha calcula sola la CA, los PG, los ataques, las competencias y los conjuros a medida que subís de nivel. Todo se guarda en tu disco, en `~/FichasDnD/`, sin cuentas ni servidores. Lo único que pide internet es la generación opcional de retratos.

El brief funcional está en [`brief-app-dnd5e.md`](brief-app-dnd5e.md). La guía de arquitectura para desarrollo asistido por IA, en [`CLAUDE.md`](CLAUDE.md).

## Descargar (Windows)

La última versión compilada está en [**Releases**](https://github.com/gasToledo/Proyecto-DnD/releases/latest). Bajás el ZIP, lo extraés entero y corrés `dnd_app.exe`. Si Windows muestra el aviso de SmartScreen porque el ejecutable no está firmado, entrás por *Más información → Ejecutar de todas formas*. Si no abre, instalá el [Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe).

## Qué hace

Las 12 clases del PHB 2024 están cargadas, cada una con sus 4 subclases, que elegís al nivel 3. El motor de hechizos está completo: CD de salvación, bono de ataque, espacios por nivel, preparar y aprender conjuros, gastar y recuperar espacios, y concentración. El catálogo trae 172 conjuros de niveles 0 a 9 y 45 dotes, más las razas, trasfondos, armas y armaduras del SRD.

Lo que podés hacer con un personaje:

- **Crearlo** con el asistente guiado: especie, clase, trasfondo, características, equipo y, si lanza, conjuros.
- **Subir de nivel** a mano, eligiendo subclase, mejora de característica o dote, y re-preparando conjuros, con un resumen de lo ganado.
- **Jugar la partida** desde la ficha: daño y curación, PG temporales, condiciones, descansos corto y largo, salvaciones de muerte, recursos de clase y maestría de armas.
- **Generar un retrato** por IA (Pollinations gratis por defecto, o Hugging Face y Gemini con tu propia key).
- **Crear homebrew** (razas, dotes, armas, armaduras) con el mismo modelo que el contenido oficial.
- **Exportar e importar** fichas en JSON, o un respaldo completo.

La ficha nunca recalcula a mano: lee de una hoja derivada que produce el motor. Si algo no cierra con las reglas, la app te avisa con una advertencia pero te deja seguir. El DM manda.

## Cómo está hecho

Es un monorepo con dos paquetes.

**`packages/dnd_engine`** es el motor de reglas, en Dart puro, sin Flutter. Ahí viven los modelos de contenido, el compilador de ficha, la validación, el combate y los dados. Todo el diseño gira alrededor de una idea: un rasgo (una raza, una dote, un rasgo de clase, una subclase) es un dato que declara una lista de *efectos* serializables, y el compilador los interpreta para producir la ficha. Agregar contenido nuevo se hace escribiendo JSON, sin tocar el motor. Se testea aislado, sin levantar la app.

**`packages/dnd_app`** es la app Flutter, hoy con target de Windows escritorio. Trae la UI, la persistencia en archivos JSON, los retratos por IA y el editor de homebrew. Depende del motor por path, dentro del mismo repo.

No hay backend ni base de datos. Cada personaje es un JSON en disco, con escritura atómica para no corromper nada ante un cierre inesperado. Tampoco usa plugins nativos de Flutter, a propósito, para no arrastrar el requisito de "Modo Desarrollador" de Windows. Las imágenes salen de Pollinations por defecto, gratis y sin key.

## Alcance

Un personaje es de una sola clase. Todavía no hay multiclase. El contenido oficial del SRD 2024 viene precargado, y el homebrew usa exactamente el mismo modelo de datos, así que lo que creás corre por la misma maquinaria que lo oficial. La validación avisa pero nunca frena una acción. Quedan afuera por ahora, sin que la arquitectura los impida: multiclase, sincronización en la nube y un Modo DM.

## Comandos

Necesitás el SDK de Dart (`dart`) y Flutter (`flutter`) en el `PATH`.

Motor (`packages/dnd_engine`, Dart puro):

```sh
cd packages/dnd_engine
dart pub get
dart test                                    # todos los tests
dart test test/character_compiler_test.dart  # un archivo puntual
dart test -n "Sagan nivel 1"                 # por nombre de test
```

App (`packages/dnd_app`, Flutter):

```sh
cd packages/dnd_app
flutter pub get
flutter analyze                  # sin issues antes de commitear
flutter test
flutter run -d windows           # correr en escritorio
flutter build windows --release  # build de release
```

## Estructura

```
brief-app-dnd5e.md         # brief funcional completo
CLAUDE.md                  # guía de arquitectura para desarrollo asistido
packages/
  dnd_engine/              # motor de reglas (Dart puro)
    lib/assets/srd_2024/    # contenido: clases, subclases, razas, trasfondos, dotes, conjuros, armas, armaduras
    lib/src/domain/         # modelos: Ability, Effect, contenido, Character, ComputedSheet
    lib/src/engine/         # SheetBuilder, CharacterCompiler, CharacterValidator, combate, dados
    lib/src/data/           # ContentRepository (carga de packs de contenido)
    test/                   # tests del motor
  dnd_app/                 # app Flutter (Windows)
    lib/                     # UI, persistencia, IA, homebrew, tema
    test/                    # tests de la app
```

## Reglas y licencia

Contenido de reglas basado en el **SRD 5.2** de D&D, © Wizards of the Coast, bajo licencia CC-BY-4.0. Proyecto personal, sin fines comerciales.
