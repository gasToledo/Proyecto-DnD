# Fichas D&D 5e

Aplicación de escritorio para crear y llevar personajes de **D&D 5.ª edición
con las reglas de 2024 (SRD 5.2.1)**.

Funciona offline y sin cuentas: el asistente guía la creación, el motor calcula
la ficha y todo se guarda en el equipo del usuario. Solo la generación opcional
de retratos por IA necesita conexión.

El [brief funcional](brief-app-dnd5e.md) conserva la visión original del
producto. La [guía técnica](CLAUDE.md) documenta la arquitectura y las reglas
para contribuir. La [auditoría de reglas 2024](docs/auditoria-reglas-2024.md)
registra la fuente de verdad, los hallazgos y el avance por bloque.

## Descargar para Windows

La última versión publicada está en
[Releases](https://github.com/gasToledo/Proyecto-DnD/releases/latest).

1. Descargá el ZIP y extraelo completo.
2. Ejecutá `dnd_app.exe`.
3. Si SmartScreen avisa que el ejecutable no está firmado, elegí
   **Más información → Ejecutar de todas formas**.
4. Si no abre, instalá
   [Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe).

## Funcionalidades

- Creación guiada en ocho pasos, con borrador recuperable y protección ante
  salidas accidentales.
- 12 clases y 48 subclases del PHB 2024.
- 9 especies del SRD más Aasimar del PHB 2024, 8 linajes, 12 trasfondos,
  57 dotes, 35 armas, 13 armaduras y 177 conjuros.
- Subida de nivel con elección de subclase, mejora de característica o dote,
  gestión de conjuros y resumen de cambios.
- Ficha con panel lateral fijo (Personaje, Combate, Inventario, Notas) y
  contenido en tarjetas por sección, con daño, curación, PG temporales,
  descansos, condiciones, salvaciones de muerte, recursos, concentración y
  espacios de conjuro.
- Listado completo de habilidades y salvaciones con su modificador y
  competencia, inventario, notas, ataques y maestrías de armas.
- Retratos generados por IA mediante Pollinations, Hugging Face o Gemini.
- Homebrew para armas, armaduras, dotes, especies, trasfondos y conjuros.
- Exportación individual e importación compatible con formatos anteriores.
- Respaldo ZIP completo de personajes, retratos, homebrew y preferencias, sin
  incluir credenciales.

La validación de reglas avisa cuando encuentra una inconsistencia, pero no
bloquea la partida: el DM conserva la última palabra.

## Datos, privacidad y recuperación

No hay backend ni base de datos. La aplicación guarda sus archivos bajo
`<perfil>/FichasDnD/`:

```text
FichasDnD/
  characters/           personajes
  homebrew/             contenido personalizado
  portraits/            retratos por personaje
  exports/              fichas y respaldos exportados
  recovery/             archivos dañados apartados
    migrations/         copias previas a migraciones automáticas
  settings.json         preferencias locales
```

Cada personaje se escribe de forma atómica para reducir el riesgo de corrupción.
Los cambios se guardan automáticamente y los pendientes se fuerzan al minimizar
o cerrar la aplicación de forma ordenada.

Personajes, ajustes, homebrew, borradores y paquetes de contenido tienen formatos
versionados. Los documentos históricos compatibles se migran al esquema actual
y conservan una copia previa. Los documentos creados por una versión futura no
se modifican ni se sobrescriben durante esa sesión.

Las claves de servicios de retratos permanecen en la configuración local y se
excluyen de los respaldos.

## Arquitectura

El repositorio contiene dos paquetes:

- `packages/dnd_engine`: motor de reglas en Dart puro. Define los modelos, los
  efectos serializables, el contenido, el combate, la validación y el compilador
  que produce una `ComputedSheet`.
- `packages/dnd_app`: aplicación Flutter para Windows. Contiene la interfaz,
  persistencia, importación y respaldos, retratos IA y editores de homebrew.

El motor está dirigido por datos: especies, clases, subclases, trasfondos, dotes
y equipo declaran efectos que el compilador interpreta. El contenido oficial y
el homebrew recorren la misma maquinaria. La UI consume la ficha calculada y no
duplica las reglas.

El código actual también incorpora una fase de mantenibilidad: los ocho pasos
del asistente, las secciones de la ficha, el flujo de subida de nivel, el
dashboard y los formularios de homebrew están separados por responsabilidad,
con pruebas de regresión para preservar sus flujos.

La ficha y el dashboard comparten el mismo patrón de navegación: panel lateral
fijo en ventanas anchas, que se colapsa a un menú desplegable en las angostas.

## Desarrollo

Requiere Dart y Flutter disponibles en el `PATH`, además de las herramientas de
compilación de Windows para Flutter Desktop.

Motor:

```sh
cd packages/dnd_engine
dart pub get
dart analyze
dart test
```

Aplicación:

```sh
cd packages/dnd_app
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

Antes de enviar cambios, formateá el paquete afectado y verificá que el análisis,
los tests y, para cambios de integración o UI, el build release terminen
correctamente.

## Estructura principal

```text
brief-app-dnd5e.md
CLAUDE.md
packages/
  dnd_engine/
    lib/assets/srd_2024/  contenido oficial
    lib/src/domain/       modelos y efectos
    lib/src/engine/       compilador, combate, dados y validación
    lib/src/data/         repositorio de contenido
    test/                 pruebas del motor
  dnd_app/
    lib/creation/         asistente y sus pasos
    lib/data/             persistencia, migraciones, importación y respaldos
    lib/homebrew/         catálogo y formularios de contenido propio
    lib/levelup/          subida de nivel
    lib/ui/               dashboard, ficha y módulos de cada pantalla
    lib/theme/            tema y componentes visuales
    test/                 pruebas de la aplicación
```

## Alcance actual

Cada personaje usa una sola clase. Todavía no hay multiclase, sincronización en
la nube ni Modo DM. La arquitectura dirigida por efectos y contenido permite
sumar esas capacidades más adelante sin reescribir la ficha.

## Reglas y licencia

Esta obra incluye material procedente del documento de referencia del sistema
5.2.1 (“SRD 5.2.1”) de Wizards of the Coast LLC, disponible en
<https://www.dndbeyond.com/srd>. La licencia sobre el SRD 5.2.1 se concede de
acuerdo con la licencia internacional de atribución/reconocimiento 4.0 de
Creative Commons, disponible en
<https://creativecommons.org/licenses/by/4.0/legalcode>.

El catálogo ampliado puede contener opciones del PHB 2024 que no forman parte
del SRD; se identifican por separado y no se presentan como contenido CC.
