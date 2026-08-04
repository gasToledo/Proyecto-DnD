# Fichas D&D 5e

Aplicación web autoalojada para crear y llevar personajes de **D&D 5.ª
edición con las reglas de 2024 (SRD 5.2.1)**, con una cuenta por jugador.

Ya no es offline: el asistente guía la creación y el motor calcula la ficha
igual que siempre, pero la ficha se guarda en un servidor propio, no en el
equipo del usuario. Se despliega como contenedores Docker sobre
infraestructura propia, publicado por Cloudflare Tunnel sin abrir puertos
entrantes — ver [Despliegue](#despliegue).

El [brief funcional](brief-app-dnd5e.md) conserva la visión original del
producto. La [guía técnica](CLAUDE.md) documenta la arquitectura y las reglas
para contribuir. La [auditoría de reglas 2024](docs/auditoria-reglas-2024.md)
registra la fuente de verdad, los hallazgos y el avance por bloque. La
[propuesta de migración](openspec/changes/migrate-to-self-hosted-webapp/)
documenta por qué se dejó de ser una aplicación de escritorio offline.

## Aplicación de escritorio (congelada)

La aplicación de escritorio de Windows dejó de recibir funcionalidad nueva: el
último release publicado sigue disponible en
[Releases](https://github.com/gasToledo/Proyecto-DnD/releases/latest), pero su
única razón de ser hoy es la migración de datos (ver
[Migrar desde la aplicación de escritorio](#migrar-desde-la-aplicación-de-escritorio)).
No comprueba versiones nuevas ni las va a comprobar: `update_service.dart` se
retiró del cliente web.

1. Descargá el ZIP y extraelo completo.
2. Ejecutá `dnd_app.exe`.
3. Si SmartScreen avisa que el ejecutable no está firmado, elegí
   **Más información → Ejecutar de todas formas**.
4. Si no abre, instalá
   [Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe).

## Funcionalidades

- Creación guiada en ocho pasos.
- 13 clases y 53 subclases: 12 clases y 48 subclases del PHB 2024, más la
  clase Artífice y sus 5 subclases de *Forge of the Artificer*.
- 15 especies (9 del SRD, Aasimar del PHB 2024 y 5 de *Forge of the
  Artificer*), 24 linajes, 33 trasfondos, 183 dotes, 38 armas, 13 armaduras y
  392 conjuros.
- Subida de nivel guiada paso a paso (resumen, puntos de golpe, subclase,
  mejora de característica, rasgos, conjuros y repaso), mostrando solo lo que
  aplica en cada nivel, con resumen final de cambios.
- Ficha con panel lateral fijo (Personaje, Combate, Inventario, Notas) y
  contenido en tarjetas por sección, con daño, curación, PG temporales,
  descansos, condiciones, salvaciones de muerte, recursos, concentración y
  espacios de conjuro.
- Listado completo de habilidades y salvaciones con su modificador y
  competencia, inventario, notas, ataques y maestrías de armas.
- Retratos generados por IA mediante Pollinations, Azure AI Foundry (Flux) o
  Azure gpt-image-2 (generados por el servidor, sin que el navegador vea
  ninguna clave), o subidos desde un archivo local.
- Homebrew para armas, armaduras, dotes, especies, trasfondos y conjuros, por
  cuenta.
- Exportación individual e importación compatible con formatos anteriores.
- Respaldo ZIP completo de personajes, retratos, homebrew y preferencias, sin
  incluir credenciales.

La validación de reglas avisa cuando encuentra una inconsistencia, pero no
bloquea la partida: el DM conserva la última palabra.

## Datos, privacidad y cuentas

Los datos viven en el servidor propio, no en el dispositivo del jugador:
personajes, homebrew y ajustes se guardan en PostgreSQL, con propiedad por
cuenta (una cuenta nunca ve ni puede tocar los datos de otra, ver
`docs/despliegue.md` y la sección "Aislamiento de red" de esa guía). Los
retratos se guardan como blobs en un volumen del servidor, servidos con la
misma autorización de sesión que el resto de la API.

La sesión de navegador es una cookie `httpOnly` y `Secure`: el cliente nunca
recibe ni guarda un token del proveedor de identidad (Zitadel), y las claves
de los proveedores de retratos IA viven solo en la configuración del
servidor, nunca en el navegador ni en un respaldo.

Personajes, homebrew y ajustes tienen formatos versionados. Los documentos
históricos compatibles se migran al esquema vigente al leerlos; un documento
de una versión futura se rechaza sin modificarlo.

## Despliegue

El stack completo (API + cliente web, PostgreSQL, autenticación con Zitadel
autoalojado, almacenamiento de retratos y publicación por Cloudflare Tunnel)
se levanta con `docker compose up -d --build` a partir de `docker-compose.yml`
y `.env.example`. El procedimiento paso a paso —incluido el registro manual de
la aplicación cliente en Zitadel, que no tiene forma de automatizarse— está en
[docs/despliegue.md](docs/despliegue.md), junto con respaldo/restauración y
las comprobaciones de seguridad antes de publicar un dominio.

## Migrar desde la aplicación de escritorio

1. Abrir la aplicación de escritorio y generar un respaldo ZIP completo desde
   el menú de exportación.
2. Crear una cuenta en el servidor autoalojado (iniciar sesión redirige a
   Zitadel).
3. Subir el ZIP desde el dashboard del cliente web (`Importar respaldo`): sube
   el archivo tal cual, sin decodificarlo en el navegador, y el servidor lo
   valida e importa en una única transacción por cuenta.

Un id de personaje que ya exista en la cuenta se reasigna a uno libre en vez
de sobrescribirse; importar el mismo respaldo dos veces no duplica ni pierde
personajes.

## Arquitectura

El repositorio contiene tres paquetes:

- `packages/dnd_engine`: motor de reglas en Dart puro. Define los modelos, los
  efectos serializables, el contenido, el combate, la validación y el compilador
  que produce una `ComputedSheet`. Sin dependencias de ejecución: lo comparten
  el cliente y el servidor.
- `packages/dnd_app`: cliente Flutter compilado para navegador. Contiene la
  interfaz, el cliente de API, importación y respaldos vía descarga del
  navegador, y editores de homebrew. También compila para Windows (la
  aplicación de escritorio congelada), pero esa no es la plataforma mantenida.
- `packages/dnd_server`: API en Dart. Persistencia en PostgreSQL,
  autenticación OIDC contra Zitadel, almacenamiento y generación de retratos
  con IA, e importación de respaldos. Sirve además el build web del cliente
  desde el mismo origen.

El motor está dirigido por datos: especies, clases, subclases, trasfondos, dotes
y equipo declaran efectos que el compilador interpreta. El contenido oficial y
el homebrew recorren la misma maquinaria. La UI consume la ficha calculada y no
duplica las reglas; el servidor reutiliza el mismo motor, así que valida con
las mismas reglas que el cliente.

El código actual también incorpora una fase de mantenibilidad: los ocho pasos
del asistente, las secciones de la ficha, el flujo de subida de nivel, el
dashboard y los formularios de homebrew están separados por responsabilidad,
con pruebas de regresión para preservar sus flujos.

La ficha y el dashboard comparten el mismo patrón de navegación: panel lateral
fijo en ventanas anchas, que se colapsa a un menú desplegable en las angostas.

## Desarrollo

Requiere Dart y Flutter disponibles en el `PATH`. Docker y Docker Compose
hacen falta solo para levantar el stack completo (ver [Despliegue](#despliegue)),
no para trabajar en un paquete individual.

Motor:

```sh
cd packages/dnd_engine
dart pub get
dart analyze
dart test
```

Aplicación (cliente web, plataforma mantenida):

```sh
cd packages/dnd_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
```

Servidor:

```sh
cd packages/dnd_server
dart pub get
dart analyze
dart test
dart run bin/server.dart
```

Antes de enviar cambios, formateá el paquete afectado y verificá que el
análisis y los tests terminen correctamente; para cambios de UI, persistencia
o integración del cliente web, generá además `flutter build web --release`.
`CLAUDE.md` tiene el detalle completo de comandos, incluidos los que siguen
existiendo para la aplicación de escritorio congelada.

## Estructura principal

```text
brief-app-dnd5e.md
CLAUDE.md
docker-compose.yml       composición del stack autoalojado
.env.example             configuración de ejemplo, sin secretos
cloudflared/              config.example.yml del túnel de Cloudflare
docs/despliegue.md        runbook de despliegue, respaldo y restauración
packages/
  dnd_engine/
    lib/assets/srd_2024/  contenido oficial
    lib/src/domain/       modelos y efectos
    lib/src/engine/       compilador, combate, dados y validación
    lib/src/data/         repositorio de contenido
    test/                 pruebas del motor
  dnd_app/
    lib/creation/         asistente y sus pasos
    lib/api/               cliente de API (reemplaza a la persistencia local)
    lib/homebrew/         catálogo y formularios de contenido propio
    lib/levelup/          subida de nivel
    lib/ui/               dashboard, ficha y módulos de cada pantalla
    lib/theme/            tema y componentes visuales
    test/                 pruebas de la aplicación
  dnd_server/
    lib/src/repositories/  personajes, homebrew y ajustes en PostgreSQL
    lib/src/auth/          sesión y flujo OIDC contra Zitadel
    lib/src/portraits/     almacenamiento de blobs de retrato
    lib/src/ai/             generación de retratos con IA
    lib/src/import/         importación de respaldos ZIP
    test/                   pruebas del servidor
```

## Alcance actual

Cada personaje usa una sola clase. Todavía no hay multiclase ni Modo DM. La
arquitectura dirigida por efectos y contenido permite sumar esas capacidades
más adelante sin reescribir la ficha.

## Reglas y licencia

Esta obra incluye material procedente del documento de referencia del sistema
5.2.1 ("SRD 5.2.1") de Wizards of the Coast LLC, disponible en
<https://www.dndbeyond.com/srd>. La licencia sobre el SRD 5.2.1 se concede de
acuerdo con la licencia internacional de atribución/reconocimiento 4.0 de
Creative Commons, disponible en
<https://creativecommons.org/licenses/by/4.0/legalcode>.

El catálogo ampliado puede contener opciones del PHB 2024 que no forman parte
del SRD. Se identifican por separado y no se presentan como contenido CC.
