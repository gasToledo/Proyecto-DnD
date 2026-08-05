## Why

La aplicación solo existe como ejecutable de Windows: las fichas viven en
`<perfil>/FichasDnD/` de una única máquina, no se pueden abrir desde una tablet
en la mesa de juego ni desde otra computadora, y la única forma de moverlas es
exportar un ZIP a mano. Queremos que las fichas sean accesibles desde cualquier
dispositivo con un navegador, con una cuenta por jugador, sobre infraestructura
propia.

El motor de reglas ya es Dart puro y el personaje ya es un documento JSON
versionado, así que el costo de la migración se concentra en reemplazar la capa
de datos local por una API, no en reescribir reglas ni interfaz.

## What Changes

- **BREAKING**: la aplicación de escritorio de Windows queda **congelada**. Deja
  de recibir funcionalidad nueva; su última responsabilidad es generar el
  respaldo ZIP que el usuario sube para migrar sus datos a una cuenta.
- **BREAKING**: la aplicación deja de ser *offline-first*. El cliente web
  requiere conexión con el servidor para leer y escribir fichas. Se abandona la
  premisa de "aplicación personal y offline" que hoy declara `CLAUDE.md`.
- **BREAKING**: `Character.portraitPaths` deja de contener rutas absolutas del
  sistema de archivos y pasa a contener **claves opacas** de retrato, resueltas
  por cada plataforma. Los personajes exportados dejan de arrastrar rutas
  `C:\Users\...` que no significan nada fuera de la máquina que las creó.
- Se agrega un **paquete backend en Dart** (`packages/dnd_server`) que reutiliza
  `dnd_engine` sin duplicar reglas ni el parseo versionado de `Character`.
- Se agrega un **cliente web Flutter**: la misma interfaz, con la capa `data/`
  reemplazada por un cliente HTTP en lugar de portada a almacenamiento del
  navegador.
- Los personajes, el homebrew y los ajustes pasan a **PostgreSQL** como
  documentos JSONB, con propiedad por usuario y escrituras multi-documento
  transaccionales.
- Los retratos pasan a **almacenamiento de blobs del servidor**, servidos por la
  API con autorización, detrás de una interfaz que permita cambiar el backend
  sin tocar el resto.
- La **generación de retratos con IA se mueve al servidor**. Las claves de Azure
  dejan de vivir en la máquina del usuario y el navegador nunca habla con el
  proveedor, lo que elimina de raíz el problema de CORS y de claves expuestas.
- Autenticación con **Zitadel autoalojado** por OIDC, mediante un patrón
  *backend-for-frontend*: el navegador nunca recibe un token, solo una cookie de
  sesión `httpOnly`.
- Todo el stack se despliega como **contenedores Docker** y se publica por
  **Cloudflare Tunnel**, sin abrir puertos entrantes.
- Se elimina `update_service.dart` del producto web: el despliegue *es* la
  actualización.

### Non-goals

Quedan explícitamente fuera de este cambio, aunque la arquitectura los habilite:

- Modo DM / vista de la party por parte de un director de juego.
- Funcionamiento offline del cliente web, PWA o sincronización con conflictos.
- Compilaciones nativas de Android o iOS.
- Colaboración en tiempo real sobre una misma ficha.
- Multiclase, o cualquier pendiente mecánico de `docs/auditoria-reglas-2024.md`.

## Capabilities

### New Capabilities

- `user-accounts`: identidad por OIDC contra Zitadel, sesión de navegador y
  aislamiento de datos entre usuarios.
- `character-api`: persistencia de personajes, homebrew y ajustes como
  documentos versionados propiedad de un usuario, con atomicidad multi-documento.
- `web-client`: la aplicación Flutter compilada para navegador, qué conserva de
  la de escritorio y qué deja de ofrecer.
- `portrait-storage`: guardado, autorización y servido de los retratos como
  blobs del servidor, y las claves opacas que los referencian.
- `ai-portrait-generation`: generación de retratos mediada por el servidor, con
  las credenciales de proveedor bajo control del servidor.
- `account-data-import`: migración de los datos locales existentes de
  `FichasDnD` hacia una cuenta del servidor.
- `self-hosted-deployment`: el contrato operativo del stack de contenedores y su
  publicación por Cloudflare Tunnel.

### Modified Capabilities

Ninguna: `openspec/specs/` está vacío, así que todo lo anterior se declara como
capacidad nueva.

## Impact

**Código nuevo**

- `packages/dnd_server/`: API en Dart, acceso a PostgreSQL, almacenamiento de
  blobs, integración OIDC y los servicios de IA trasladados desde `dnd_app`.

**Código modificado**

- `packages/dnd_engine/lib/src/data/content_repository.dart`: `loadFromDirectory`
  usa `dart:io` y hoy solo la consumen las pruebas (47 llamadas). Debe salir de
  la ruta compilable a web sin romper esas pruebas.
- `packages/dnd_engine/lib/src/domain/character.dart`: `portraitPaths` cambia de
  significado; requiere migración de esquema versionada.
- `packages/dnd_app/lib/data/` (11 archivos, ~1.900 líneas): en el build web se
  reemplaza por un cliente de API, no se porta.
- `packages/dnd_app/lib/ai/`: se traslada al servidor.
- Los 3 puntos que renderizan retratos con `FileImage`/`Image.file`
  (`dashboard_widgets.dart`, `sheet_navigation.dart`, `sheet_widgets.dart`) pasan
  por un único widget que resuelve la clave del retrato.
- `packages/dnd_app/lib/data/update_service.dart`: se excluye del build web.

**Infraestructura nueva**

- PostgreSQL (base de la aplicación y base de Zitadel), Zitadel, contenedor de
  la API, `cloudflared`, volumen de retratos.
- Dos nombres públicos: uno para la aplicación y otro para el emisor OIDC.

**Documentación**

- `CLAUDE.md` y `README.md` deben reflejar que el producto ya no es
  offline-first, que Windows está congelado y que existe un tercer paquete.

**Riesgos**

- El estado de combate (`CombatState`) hoy se guarda con *debounce* de 400 ms;
  sobre la red, durante un combate, esa frecuencia es la primera cosa que puede
  sentirse mal.
- Zitadel es un IdP completo: mucha maquinaria operativa para un grupo pequeño,
  y hay que mantenerlo actualizado.
- El almacenamiento de retratos en volumen ata el contenedor de la API a un host
  concreto.
