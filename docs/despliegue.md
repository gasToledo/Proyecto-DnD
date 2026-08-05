# Despliegue autoalojado

Runbook operativo del stack de contenedores (ver capacidad
`self-hosted-deployment` en
`openspec/changes/migrate-to-self-hosted-webapp/specs/self-hosted-deployment/spec.md`
y `design.md` para las decisiones detrás de cada elección).

> **Nota de esta sesión:** el entorno donde se escribió este documento no
> tiene Docker instalado, así que el `docker-compose.yml`, los `Dockerfile` y
> este runbook se armaron y revisaron por lectura (incluido el
> `docker-compose.yml` oficial de Zitadel v4, para que los nombres de
> variable y el healthcheck fueran los reales) pero **no se ejecutaron de
> punta a punta**. La primera vez que se levante el stack de verdad hay que
> tratarlo como un ensayo: seguir esta guía y anotar cualquier ajuste que
> haga falta.

## Prerrequisitos

- Docker y Docker Compose v2 en el host.
- Un dominio propio administrado por Cloudflare (Zero Trust habilitado en la
  cuenta, plan gratuito alcanza).
- `cloudflared` instalado en la máquina que arma el túnel (no hace falta que
  sea la misma que corre los contenedores, pero simplifica el primer
  arranque).

## Primer arranque

1. **Variables de entorno.** Copiar `.env.example` a `.env` y completar todo
   salvo `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` (paso 4). Generar
   contraseñas y `ZITADEL_MASTERKEY` (exactamente 32 caracteres) con
   `openssl rand -base64 32 | head -c 32`.

2. **Túnel de Cloudflare.**

   ```sh
   cloudflared tunnel login
   cloudflared tunnel create dnd-app
   ```

   Copiar el JSON de credenciales que genera a `cloudflared/creds.json`.
   Copiar `cloudflared/config.example.yml` a `cloudflared/config.yml`,
   completar `tunnel:` con el id devuelto y los dos hostnames reales. Crear
   los registros DNS:

   ```sh
   cloudflared tunnel route dns dnd-app fichas.tu-dominio.com
   cloudflared tunnel route dns dnd-app auth.tu-dominio.com
   ```

3. **Levantar el stack.**

   ```sh
   docker compose up -d --build
   docker compose ps
   ```

   Esperar a que `db`, `zitadel`, `zitadel-login` y `server` queden `healthy`
   (ver sección "Comprobación de salud" en cada servicio del
   `docker-compose.yml`). `zitadel-init` y `zitadel-setup` son contenedores de
   una sola vez: lo correcto es que aparezcan como `exited (0)`, no como
   `healthy` (ver el comentario sobre el arranque partido en
   `docker-compose.yml`). `server` no queda sano hasta que `zitadel` y
   `zitadel-login` lo estén: si se cuelga ahí, revisar `docker compose logs
   zitadel-setup` y `docker compose logs zitadel`, en ese orden. `db` sirve las
   dos bases (aplicación y Zitadel, ver design.md, decisión D11); si `zitadel`
   no arranca, revisar también `docker compose logs db` para confirmar que
   `postgres-init/init-zitadel-db.sh` corrió sin error.

4. **Registrar la aplicación cliente en Zitadel** (tarea 5.1, manual: Zitadel
   no tiene forma de declarar esto por configuración de arranque). Entrar a
   `https://auth.tu-dominio.com`, iniciar sesión con
   `ZITADEL_ADMIN_USERNAME` / `ZITADEL_ADMIN_PASSWORD`, crear un proyecto y
   una aplicación **web** con:
   - Tipo de autenticación: `Code` (Authorization Code + PKCE).
   - Redirect URI: `https://fichas.tu-dominio.com/auth/callback`.
   - Post-logout redirect URI: `https://fichas.tu-dominio.com/`.

   Zitadel devuelve un `Client ID` y un `Client Secret`. Completar
   `OIDC_CLIENT_ID` y `OIDC_CLIENT_SECRET` en `.env` con esos valores y
   reiniciar `server`:

   ```sh
   docker compose up -d server
   ```

5. **Verificar.** Entrar a `https://fichas.tu-dominio.com`, confirmar que
   redirige a `/auth/login` → Zitadel → vuelve autenticado, y crear un
   personaje de prueba (ver requisito "Arranque desde cero" — sección más
   abajo).

## Integración y despliegue continuo

Ver `openspec/changes/add-ci-cd-pipeline/` para el *why* y las decisiones
(`design.md`). Dos workflows en `.github/workflows/`:

- `ci.yml`: formato, análisis y pruebas de los tres paquetes en runners
  alojados por GitHub, en cada push y cada pull request. No necesita
  configuración en el host.
- `cd.yml`: reconstruye y levanta el stack (`docker compose up -d --build`)
  en el **runner autoalojado**, disparado solo por `push` a `main` o
  `webapp` que toque una ruta relevante. Necesita el runner de esta sección.

### Registrar el runner autoalojado

El runner corre en el mismo host que `docker compose`, nunca en una máquina
aparte (ver design.md, D1): así el despliegue es `docker compose up -d
--build` local, sin SSH ni socket Docker expuesto hacia afuera.

1. En GitHub: *Settings → Actions → Runners → New self-hosted runner*, a
   **nivel de repositorio** (no de organización, para que ningún otro
   repositorio pueda encolarle trabajo). Seguir las instrucciones que
   GitHub genera para el sistema operativo del host (descargar, configurar
   con el token de registro, instalar como servicio para que sobreviva a un
   reinicio).
2. **Colocar los secretos reales en el directorio de trabajo del runner**
   (el que `actions/checkout` usa, normalmente
   `_work/Proyecto-DnD/Proyecto-DnD` bajo la carpeta de instalación del
   runner): copiar ahí el `.env` completo y `cloudflared/config.yml` +
   `cloudflared/creds.json` ya configurados, igual que en un arranque manual
   (ver "Primer arranque" arriba). `cd.yml` usa `clean: false` en el
   checkout precisamente para no borrar estos archivos —no versionados—
   antes de cada despliegue; sin este paso manual único, el primer
   despliegue automático falla por falta de configuración.
3. Confirmar que el runner queda `Idle` en *Settings → Actions → Runners*.

### Protección de rama

Configurar en *Settings → Branches* para `main` y, mientras siga activa,
`webapp`:

- Requerir pull request antes de mergear.
- Requerir que los jobs de `ci.yml` pasen.
- Sin *force-push* ni borrado de la rama.
- Restringir quién puede pushear directo a quienes deben poder disparar un
  despliegue: es el único control de acceso sobre `cd.yml` (ver design.md,
  D5 — sin aprobación adicional por decisión del proyecto).

### Verificar el pipeline

- Un push a `main`/`webapp` que solo toque `docs/**` u otra ruta fuera de la
  lista de `cd.yml` no debe disparar ningún job de despliegue.
- Un push a `main`/`webapp` que toque `packages/dnd_server/**` (por ejemplo)
  debe reconstruir el stack y terminar en éxito una vez que `server` quede
  `healthy`.
- Un pull request abierto desde un fork no debe disparar ningún workflow en
  el runner autoalojado — solo los jobs de `ci.yml`, en runners de GitHub.

## Recuperar Zitadel de un arranque a medias

Síntoma, en `docker compose logs zitadel-setup`:

```
migration failed ... name=03_default_instance err.message=Errors.Instance.Domain.AlreadyExists
duplicate key value violates unique constraint "unique_constraints_pkey"
detail: Key (instance_id, unique_type, unique_field)=(, instance_domain, auth.tu-dominio.com) already exists.
```

Qué significa: `setup` ya había escrito los eventos de la primera instancia en
un intento anterior y después se cortó. Zitadel marca ese paso como `failed` y
lo **reintenta** en cada arranque, pero `03_default_instance` no es idempotente
contra el eventstore, así que el reintento siempre choca contra la fila que ya
está. No se arregla reintentando ni borrando el contenedor: hay que dejar la
base de Zitadel vacía y volver a correr `setup`.

Antes de resetear, buscar **la falla original**, que está más arriba en el log y
es la que hay que corregir; el `duplicate key` es solo su eco:

```sh
docker compose logs zitadel-setup zitadel | grep -iE 'level=(ERROR|FATAL)' | head -40
```

Dos causas frecuentes: el arranque interrumpido a mano o por reinicio del host,
y un `permission denied` al escribir `/zitadel/bootstrap/login-client.pat` — un
volumen con nombre se crea vacío y propiedad de `root`, y la imagen de Zitadel
no corre como `root`. La segunda se corrige durante el reset (paso 3).

Reset de la base de Zitadel **sin tocar la de la aplicación** (las dos comparten
instancia de PostgreSQL, ver design.md, decisión D11, y
`postgres-init/init-zitadel-db.sh` solo corre con el volumen vacío, así que
recrear el contenedor no alcanza):

```sh
# 1. Bajar todo lo de Zitadel y resolver el nombre real del volumen.
vol="$(docker compose config --format json | jq -r '.name')_zitadel-bootstrap"
docker compose rm -sf zitadel zitadel-login zitadel-setup zitadel-init

# 2. Vaciar la base de Zitadel y el volumen del PAT.
docker compose exec -T db psql -U "$APP_DB_USER" -d postgres <<'SQL'
DROP DATABASE IF EXISTS zitadel WITH (FORCE);
CREATE DATABASE zitadel OWNER zitadel;
REVOKE CONNECT ON DATABASE zitadel FROM PUBLIC;
SQL
docker volume rm "$vol"

# 3. Solo si la falla original fue `permission denied` sobre el PAT: recrear el
#    volumen ya con el dueño correcto, tomando el UID que declara la imagen en
#    vez de adivinarlo.
uid="$(docker image inspect "ghcr.io/zitadel/zitadel:${ZITADEL_VERSION}" \
  --format '{{.Config.User}}')"
docker volume create "$vol"
docker run --rm -v "$vol:/b" alpine chown -R "${uid:-1000}" /b

# 4. Volver a levantar: `zitadel-setup` corre de nuevo contra una base vacía.
docker compose up -d
```

`WITH (FORCE)` (PostgreSQL 13+) corta las conexiones abiertas; sin él,
`DROP DATABASE` falla si quedó algún cliente colgado. El rol `zitadel` no se
recrea: lo creó `postgres-init/init-zitadel-db.sh` la primera vez y sobrevive al
`DROP DATABASE`. El volumen `zitadel-bootstrap` se borra junto con la base
porque el PAT que guarda queda huérfano: pertenece a la instancia que se acaba
de eliminar. Si no está `jq` a mano, resolver `$vol` con
`docker volume ls | grep zitadel-bootstrap`.

Después del reset hay que **volver a hacer el paso 4 de "Primer arranque"**: el
`OIDC_CLIENT_ID` y el `OIDC_CLIENT_SECRET` de `.env` apuntaban a una aplicación
de la instancia vieja y ya no existen.

Este procedimiento borra las cuentas de los jugadores (viven en Zitadel), no sus
fichas (viven en la base de la aplicación). Con el mismo
`ZITADEL_ADMIN_USERNAME`, cada jugador vuelve a entrar registrándose de nuevo,
pero **con un `sub` distinto**: las fichas quedan asociadas a la cuenta anterior.
Si ya hay datos de jugadores en juego, respaldar antes (ver "Respaldo y
restauración") y planificar la reasignación; en una instalación que todavía no
se usó, no hay nada que reasignar.

## Aislamiento de red (requisito "Publicación sin puertos entrantes")

Ningún servicio de `docker-compose.yml` declara `ports:`. Verificar en cada
arranque real:

```sh
docker compose ps --format '{{.Name}}: {{.Ports}}'
```

Ninguna fila debe mostrar un mapeo `0.0.0.0:<puerto>->...`: `cloudflared` es
el único servicio con salida a internet, y es saliente (un túnel, no un
puerto escuchando). `db` (que sirve las dos bases, aplicación y Zitadel) y
`portraits-data` solo son alcanzables desde dentro de la red interna de
Docker que arma `docker compose` para este proyecto.

## Sin credenciales en la imagen (requisito "Secretos fuera de las imágenes")

`packages/dnd_server/Dockerfile` no recibe secretos como `ARG` ni los
`COPY`: la configuración se lee de variables de entorno recién al arrancar
el proceso (`lib/src/config.dart`), nunca en tiempo de build. Verificar
después de construir:

```sh
docker build -f packages/dnd_server/Dockerfile -t dnd-server:check .
docker history --no-trunc dnd-server:check | grep -i -E 'password|secret|key' || echo "sin coincidencias"
```

## Respaldo y restauración

Todo el estado persistente vive en dos volúmenes con nombre (más
`zitadel-bootstrap`, que es recreable y no hace falta respaldar: es solo el
token de servicio entre `zitadel` y `zitadel-login`). Las dos bases —
aplicación y Zitadel— comparten una sola instancia de PostgreSQL (ver
design.md, decisión D11), así que un solo `pg_dump` con `--create` alcanza
para las dos.

```sh
# Respaldo
docker compose exec -T db pg_dumpall -U "$APP_DB_USER" > respaldo-db.sql
docker run --rm -v proyecto-dnd_portraits-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/respaldo-retratos.tar.gz -C /data .
```

```sh
# Restauración en una instalación limpia (stack levantado, sin datos)
cat respaldo-db.sql | docker compose exec -T db psql -U "$APP_DB_USER" postgres
docker run --rm -v proyecto-dnd_portraits-data:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar xzf /backup/respaldo-retratos.tar.gz"
docker compose restart server
```

`pg_dumpall` requiere un rol con permiso para leer roles y todas las bases.
`$APP_DB_USER` alcanza: la imagen oficial de postgres crea a `POSTGRES_USER`
como **superusuario de la instancia**, no como un rol acotado a su propia
base (ver design.md, decisión D11, y el comentario en
`postgres-init/init-zitadel-db.sh`) — es lo mismo que le permite a la
aplicación llegar a la base de Zitadel pese al `REVOKE CONNECT` de esa base.

El nombre del volumen (`proyecto-dnd_portraits-data` arriba) depende del
nombre del proyecto de Compose (por defecto, el nombre de la carpeta):
confirmar con `docker volume ls` antes de restaurar.

## Arranque desde cero (checklist manual)

Como este entorno no tiene Docker, esta sección queda como procedimiento a
seguir la primera vez que haya una máquina real disponible, no como algo ya
ejecutado:

1. `docker compose up -d --build` en una máquina limpia, sin volúmenes
   previos.
2. Confirmar que los cuatro servicios con healthcheck (`db`, `zitadel`,
   `zitadel-login`, `server`) llegan a `healthy` sin intervención manual, y
   que `cloudflared` también. `zitadel-init` y `zitadel-setup` deben quedar
   en `exited (0)`; si alguno sale con código distinto de 0, el arranque se
   detiene ahí a propósito (ver "Recuperar Zitadel de un arranque a medias").
3. Completar el registro manual de Zitadel (paso 4 de "Primer arranque").
4. Iniciar sesión desde `https://fichas.tu-dominio.com` y crear un personaje.
5. `docker compose down && docker compose up -d` y confirmar que el
   personaje y la sesión de cuenta siguen ahí (los datos sobreviven al
   reinicio; la sesión de navegador expira a las 12 h, ver
   `session_cookie.dart`, así que puede pedir volver a iniciar sesión).
6. Verificar la unificación de bases (tarea 10.12, D11):
   - `docker compose exec -T db psql -U zitadel -d "$APP_DB_NAME" -c '\q'`
     MUST fallar (`FATAL: permission denied for database`).
   - `docker compose exec -T db psql -U "$APP_DB_USER" -d zitadel -c '\q'`
     SHALL funcionar: es el lado asimétrico documentado en design.md,
     decisión D11 — la aplicación llega a la base de Zitadel porque
     `$APP_DB_USER` es superusuario de la instancia, no una excepción a
     corregir acá.

Cualquier paso que no funcione como está descrito acá es una corrección para
este documento, no un bloqueo del despliegue: registrarlo y ajustar.
