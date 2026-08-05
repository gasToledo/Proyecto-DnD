## Context

Ver `proposal.md` — *Why* para la motivación. Lo relevante para el diseño es el
estado actual medido sobre el código:

- `dnd_engine` tiene **cero dependencias de ejecución** y 21 archivos. Un solo
  archivo importa `dart:io`: `src/data/content_repository.dart`, y solo dentro
  de `loadFromDirectory`, que consumen **exclusivamente las pruebas** (47
  llamadas, ninguna en `lib/`).
- Ese archivo se exporta desde la barrera `lib/dnd_engine.dart`. Por lo tanto
  **hoy ningún build web que importe el motor compila**: es el primer bloqueo
  real, no una cuestión de estilo.
- La aplicación concentra `dart:io` en `lib/data/` (11 archivos, ~1.900 líneas)
  y `lib/ai/`. El resto —creación, homebrew, subida de nivel, tema y la práctica
  totalidad de `ui/`— ya es Flutter portable.
- Los únicos puntos de `ui/` atados al disco son tres renderizados de retrato:
  `dashboard_widgets.dart:235`, `sheet_navigation.dart:55` y
  `sheet_widgets.dart:40`.
- El paquete de contenido oficial pesa **665 KB**. No es un problema de carga
  inicial y sigue siendo un asset empaquetado.
- Los identificadores de personaje se generan como
  `microsecondsSinceEpoch-intento` y son únicos solo dentro de la colección
  local; `Character` no tiene campo de propietario.
- `writeJsonBatchAtomic` existe porque la atomicidad multi-documento ya es un
  requisito vivo: lo usan `character_store.dart:154` y `homebrew_store.dart:243`.

## Goals / Non-Goals

**Goals:**

- Una sola implementación de las reglas, compartida por cliente y servidor.
- Que la capa de datos local **no se porte**, sino que se reemplace.
- Conservar las garantías de integridad que ya tenía la aplicación de
  escritorio: versionado, migración secuencial, rechazo de versiones futuras y
  atomicidad multi-documento.
- Que el navegador nunca custodie tokens ni claves de proveedor.
- Que cambiar el medio de almacenamiento de retratos sea un cambio de una clase.

**Non-Goals:**

- Mantener una única base de código que compile a la vez para Windows y web.
- Abstraer el sistema de archivos del navegador (OPFS/IndexedDB). El diseño lo
  evita por completo.
- Optimizar el tamaño del bundle web o la primera carga más allá de lo que da
  la caché de borde.

## Decisions

### D1. El backend es Dart y reutiliza `dnd_engine` como dependencia de ruta

**Por qué:** el motor no tiene dependencias de ejecución, así que un servidor
Dart obtiene gratis el mismo `Character.fromJson`, la misma cadena de migración
versionada y la misma `validation.dart` que el cliente. Cualquier otro lenguaje
obliga a tratar el documento como opaco o a reimplementar el versionado, que es
justo la parte donde un desajuste corrompe datos en silencio.

**Alternativas consideradas:** Node/Go/Python tratando `Character` como blob
opaco. Es menos código y las migraciones ya corren del lado del cliente al leer,
así que no regresaría nada. Se descarta porque cierra la puerta a que el
servidor valide, y una API publicada en internet acabará necesitándolo.

### D2. PostgreSQL con `jsonb`, sin normalizar `Character`

**Por qué:** `Character.toJson()` es exhaustivo y versionado. Descomponerlo en
tablas destruiría la maquinaria de `schemaVersion` y la fidelidad de exportación
a cambio de consultas que esta aplicación no hace.

**Alternativas consideradas:** MongoDB. Se descarta por cuatro razones
concretas: (a) Zitadel exige PostgreSQL, así que Postgres ya está en el stack y
elegir Mongo significa operar **dos** motores; (b) las transacciones
multi-documento de Mongo requieren un *replica set*, de modo que un contenedor
único no da la garantía que `writeJsonBatchAtomic` ya necesita; (c) el
ecosistema de controladores Dart favorece claramente a `package:postgres`;
(d) usuarios, propiedad y sesiones son relaciones, no documentos.

Forma prevista: el documento íntegro en una columna `jsonb`, con columnas
generadas para lo poco que se consulta o se ordena.

### D3. Clave primaria compuesta `(user_id, id)` — sin migración de identificadores

**Por qué:** los identificadores actuales ya son únicos por colección local.
Alcanzarlos con el usuario los vuelve únicos globalmente sin tocarlos. Evita
migrar a UUID, mantiene válidos los respaldos ya exportados y deja `Character`
sin noción de propietario: la propiedad vive en la fila, no en el documento, de
modo que un personaje exportado sigue siendo portable.

### D4. Los retratos van a un volumen de disco detrás de una interfaz, no a un
almacén de objetos

**Por qué:** el orden de magnitud es de cientos de megabytes, no de terabytes.
Con backend en Dart, `portrait_storage.dart` (27 líneas, ya con validación de
segmentos) **se traslada al servidor sin cambios**. Introducir un almacén de
objetos ahora suma un contenedor, una estrategia de respaldo aparte y
configuración, sin resolver ningún problema presente.

**Alternativas consideradas:** MinIO —cuya edición comunitaria viene recortando
funcionalidad, conviene verificar su estado actual antes de adoptarlo— y Garage,
más liviano y pensado para autoalojamiento. Se difieren ambos. La mitigación es
que el almacenamiento queda detrás de una interfaz, de modo que adoptarlos sea
una clase nueva y no una refactorización. `bytea` en Postgres se descarta:
infla cada respaldo de la base con datos que no cambian.

### D5. Autenticación por *backend-for-frontend*, no tokens en el navegador

**Por qué:** ya hay un backend propio, así que él hace el intercambio de código
y guarda los tokens; el navegador solo recibe una cookie de sesión `httpOnly`.
Elimina la discusión de dónde guardar tokens en una SPA y, como efecto
colateral, hace que servir retratos desde el mismo origen funcione sin ninguna
plumbing de autorización en el cliente.

**Nota operativa:** el emisor OIDC necesita su propio nombre público estable y
debe coincidir exactamente con el dominio externo configurado en Zitadel; si no,
el descubrimiento falla de formas poco descriptivas. Son dos nombres en el
túnel.

**Alternativa considerada:** Cloudflare Access autenticando en el borde, que
habría eliminado el IdP del stack por completo. Se descarta por decisión del
proyecto de usar identidad autoalojada, asumiendo el costo operativo de
mantener un IdP actualizado.

### D6. La capa `data/` no se porta: se reemplaza, y el escritorio queda congelado

**Por qué:** esta es la consecuencia de diseño más importante de congelar
Windows. Si el escritorio no evoluciona, **no hacen falta importaciones
condicionales ni una abstracción de almacenamiento con dos implementaciones**.
`lib/data/` se sustituye por un cliente HTTP y la aplicación de escritorio
sobrevive como el *release* ya publicado, que es exactamente el que genera el
ZIP de migración.

Esto convierte el trabajo de ~1.900 líneas de portado en unas pocas centenas de
cliente de API, y descarta de plano el riesgo de desalojo de almacenamiento del
navegador.

**Alternativa considerada:** mantener ambos objetivos con importaciones
condicionales. Se descarta: duplica las rutas de recuperación, respaldo y
migración, y solo tendría sentido si el escritorio siguiera vivo.

### D7. `loadFromDirectory` sale de la ruta compilable a web

**Por qué:** es el bloqueo duro. La barrera exporta el archivo que importa
`dart:io`, así que ningún build web compila hoy. La restricción de diseño es que
las 47 llamadas de prueba deben seguir funcionando: las pruebas corren sobre la
VM, donde `dart:io` existe, así que el objetivo es sacar ese punto de entrada de
lo que la web importa, no eliminarlo.

### D8. `portraitPaths` pasa a claves opacas mediante migración de esquema

**Por qué:** una ruta absoluta no significa nada fuera de su máquina, y hoy
viaja dentro de cada personaje exportado. El precedente ya existe en el código:
`transfer_service.dart:233-252` **ya reescribe `portraitPaths` al importar**, es
decir, el proyecto ya trata esas rutas como locales y reconstruibles.

Los tres puntos de renderizado pasan por un único widget que resuelve la clave,
en lugar de construir un `File`.

### D9. La generación con IA se traslada al servidor tal cual

**Por qué:** `ai/` ya está escrito como servicios con `http.Client` inyectable y
`Uint8List`, sin dependencias de Flutter en la parte de red. Moverlo al servidor
resuelve a la vez CORS y la exposición de claves, y **recupera los proveedores
de Azure**, que en un cliente web puro habrían quedado inviables.

### D10. El ZIP de respaldo existente es la herramienta de migración

**Por qué:** `backup_bundle.dart` ya produce el paquete y `transfer_service.dart`
ya sabe consumirlo, validar rutas y reescribir retratos. El servidor reutiliza
esa lógica en vez de inventar un formato de importación.

### D11. Una sola instancia de PostgreSQL con dos bases, no dos instancias

**Por qué:** Zitadel no exige una instancia dedicada; exige **una base**
PostgreSQL 14–18. Dos instancias del mismo motor duplican volumen, respaldo,
comprobación de salud y versión a mantener, que es la mitad exacta del costo que
D2 invoca para descartar Mongo ("elegir Mongo significa operar **dos**
motores"). El aislamiento que se pierde es nominal: es un host único con un solo
`docker compose`, así que si el motor cae, la identidad y los datos caen juntos
de todos modos.

La topología es un contenedor `db` con dos bases y dos roles: `dnd`, creada por
`POSTGRES_DB`, y `zitadel`, creada por un script montado en
`/docker-entrypoint-initdb.d/`. Ese script corre contra el servidor temporal
local de la inicialización, **antes** de que Postgres acepte conexiones
externas, de modo que cuando `pg_isready` pasa la base de Zitadel ya existe y
`depends_on: db: service_healthy` sigue siendo la única sincronización
necesaria. El DSN de Zitadel solo cambia de host (`zitadel-db` → `db`).

El aislamiento entre bases se declara, no se hereda del proceso, y es
**asimétrico**: `postgres-init/init-zitadel-db.sh` revoca `CONNECT` de
`PUBLIC` sobre cada base, porque PostgreSQL se lo concede por omisión, pero
eso solo le cierra el paso al rol `zitadel` hacia la base de la aplicación.
La imagen oficial crea `$APP_DB_USER` como **superusuario** de la instancia
(es el comportamiento documentado de `POSTGRES_USER`, no algo que este
proyecto configure); un superusuario salta todo chequeo de privilegios,
`CONNECT` incluido. La aplicación ya tenía acceso a toda la instancia antes
de que hubiera una segunda base — D11 no reduce ese alcance, solo le da un
destino nuevo. Ver Risks/Trade-offs.

**Cuándo:** antes de la tarea 5.1. El *stack* nunca arrancó en limpio, así que
hoy el cambio es editar la composición y no hay datos que migrar; después del
primer arranque real pasa a ser un volcado y restauración de dos bases sobre una
instancia compartida, con el init de Zitadel corriendo contra datos
preexistentes. No vuelve a ser tan barato.

**Alternativas consideradas:** (a) **dos instancias**, que es de dónde se parte,
heredado del `docker-compose.yml` de ejemplo de Zitadel sin una decisión que lo
respalde; su única ventaja real es desacoplar la actualización mayor de
PostgreSQL, libertad que el proyecto no usa —las dos imágenes se subieron de 16
a 18 en la misma edición—. (b) **Una sola base con esquemas separados**: Zitadel
se despliega sobre varios esquemas propios (`eventstore`, `projections`,
`system`, `auth`) y el servidor usa `public`; funcionaría, pero rompe la
granularidad del respaldo y ensucia los permisos sin ahorrar nada frente a dos
bases.

## Risks / Trade-offs

- **`CombatState` se guarda con *debounce* de 400 ms** → sobre la red, en
  combate, es la primera cosa que puede sentirse mal y la que peor tolera un
  corte. Mitigación: buffer local optimista con envío periódico y confirmación
  explícita; medirlo en juego real antes de ajustar el intervalo.
- **Se pierde el funcionamiento sin conexión, que era un rasgo declarado del
  producto** → no hay mitigación técnica dentro de este alcance; es una decisión
  de producto que debe quedar escrita en `CLAUDE.md` y `README.md` para que no
  se lea como una regresión accidental.
- **Zitadel es un IdP completo para un grupo pequeño** → mucha superficie
  operativa y otra cosa que mantener parcheada. Mitigación: respaldo
  documentado de su base y una ruta de recuperación probada.
- **La instancia única de PostgreSQL acopla la actualización mayor del motor**
  (D11) → subir de versión mayor obliga a volcar y restaurar las dos bases a la
  vez. Mitigación: ya se tratan como una unidad; el respaldo documentado cubre
  ambas y el procedimiento es el mismo, con un contenedor menos.
- **El aislamiento entre la base de la aplicación y la de Zitadel es
  asimétrico** (D11) → `$APP_DB_USER` es superusuario de la instancia (así
  crea la imagen oficial a `POSTGRES_USER`) y por lo tanto salta el `REVOKE
  CONNECT` que protege a la base de Zitadel; solo el sentido inverso
  (`zitadel` no puede leer la base de la aplicación) queda garantizado. No es
  una regresión — la aplicación ya tenía ese alcance sobre toda la instancia
  cuando era la única base — pero hay que verificar en el arranque desde
  cero (10.12) que el rol `zitadel` efectivamente no puede conectarse a la
  base de la aplicación.
- **El volumen de retratos ata el contenedor de la API a un host** → aceptable
  en una instalación de una sola máquina. Mitigación: la interfaz de D4.
- **Validación en servidor con motor compartido acopla los despliegues** → si el
  servidor valida con una versión del motor distinta a la del cliente, puede
  rechazar personajes que el cliente considera válidos. Mitigación: cliente y
  servidor se despliegan juntos desde el mismo commit del monorepo.
- **Caché de borde sobre el bundle de Flutter** → un `index.html` o un
  *service worker* cacheados agresivamente fijan a la gente en una versión
  vieja. Mitigación explícita en la capacidad de despliegue.
- **La superficie de seguridad cambia de categoría**: se pasa de una aplicación
  local a un servicio publicado en internet. El aislamiento entre cuentas deja
  de ser teórico y necesita pruebas propias, no solo revisión.

## Migration Plan

El *release* final de escritorio ya está publicado: es el artefacto Windows
definitivo y la herramienta que produce el ZIP de migración. Este plan parte de
ese punto.

1. Desbloquear la compilación web sacando `loadFromDirectory` de la ruta
   importable por web, sin tocar las 47 pruebas.
2. Migración de esquema de `portraitPaths` a claves, con su prueba de regresión.
3. Levantar el stack e implementar la API, verificando el aislamiento entre
   cuentas antes de cargar datos reales.
4. Reemplazar `lib/data/` por el cliente de API en la aplicación Flutter.
5. Importar el ZIP propio como primer caso real de migración.
6. Actualizar `CLAUDE.md` y `README.md`.

**Rollback:** mientras el ZIP de respaldo siga siendo importable y exportable,
la vuelta atrás es seguir usando el *release* de escritorio ya publicado con los
datos locales, que nunca se borran como parte de esta migración.

## Open Questions

- **¿La validación de reglas en el servidor se activa desde el principio o queda
  detrás de una bandera?** No cambia las especificaciones —el servidor valida
  estructura en ambos casos— ni el reparto de tareas; solo cuán estricto es el
  rechazo. Se puede decidir al implementar.
- **¿El homebrew podrá compartirse entre cuentas más adelante?** Este cambio lo
  define estrictamente por cuenta. Abrirlo sería una capacidad nueva y no
  condiciona el modelo de datos elegido.
- **¿Qué política de retención se aplica a los retratos huérfanos** cuando se
  borra un personaje o se reemplaza un retrato? Es una tarea de limpieza que no
  altera ningún contrato observable.
