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

   Esperar a que `zitadel`, `zitadel-login`, `db`, `zitadel-db` y `server`
   queden `healthy` (ver sección "Comprobación de salud" en cada servicio
   del `docker-compose.yml`). `server` no queda sano hasta que `zitadel` y
   `zitadel-login` lo estén: si se cuelga ahí, revisar `docker compose logs
   zitadel` primero.

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

## Aislamiento de red (requisito "Publicación sin puertos entrantes")

Ningún servicio de `docker-compose.yml` declara `ports:`. Verificar en cada
arranque real:

```sh
docker compose ps --format '{{.Name}}: {{.Ports}}'
```

Ninguna fila debe mostrar un mapeo `0.0.0.0:<puerto>->...`: `cloudflared` es
el único servicio con salida a internet, y es saliente (un túnel, no un
puerto escuchando). `db`, `zitadel-db` y `portraits-data` solo son
alcanzables desde dentro de la red interna de Docker que arma `docker
compose` para este proyecto.

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

Todo el estado persistente vive en tres volúmenes con nombre (más
`zitadel-bootstrap`, que es recreable y no hace falta respaldar: es solo el
token de servicio entre `zitadel` y `zitadel-login`).

```sh
# Respaldo
docker compose exec -T db pg_dump -U "$APP_DB_USER" "$APP_DB_NAME" > respaldo-app-db.sql
docker compose exec -T zitadel-db pg_dump -U zitadel zitadel > respaldo-zitadel-db.sql
docker run --rm -v proyecto-dnd_portraits-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/respaldo-retratos.tar.gz -C /data .
```

```sh
# Restauración en una instalación limpia (stack levantado, sin datos)
cat respaldo-app-db.sql | docker compose exec -T db psql -U "$APP_DB_USER" "$APP_DB_NAME"
cat respaldo-zitadel-db.sql | docker compose exec -T zitadel-db psql -U zitadel zitadel
docker run --rm -v proyecto-dnd_portraits-data:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar xzf /backup/respaldo-retratos.tar.gz"
docker compose restart server
```

El nombre del volumen (`proyecto-dnd_portraits-data` arriba) depende del
nombre del proyecto de Compose (por defecto, el nombre de la carpeta):
confirmar con `docker volume ls` antes de restaurar.

## Arranque desde cero (checklist manual)

Como este entorno no tiene Docker, esta sección queda como procedimiento a
seguir la primera vez que haya una máquina real disponible, no como algo ya
ejecutado:

1. `docker compose up -d --build` en una máquina limpia, sin volúmenes
   previos.
2. Confirmar que los cinco servicios con healthcheck (`db`, `zitadel-db`,
   `zitadel`, `zitadel-login`, `server`) llegan a `healthy` sin intervención
   manual, y que `cloudflared` también.
3. Completar el registro manual de Zitadel (paso 4 de "Primer arranque").
4. Iniciar sesión desde `https://fichas.tu-dominio.com` y crear un personaje.
5. `docker compose down && docker compose up -d` y confirmar que el
   personaje y la sesión de cuenta siguen ahí (los datos sobreviven al
   reinicio; la sesión de navegador expira a las 12 h, ver
   `session_cookie.dart`, así que puede pedir volver a iniciar sesión).

Cualquier paso que no funcione como está descrito acá es una corrección para
este documento, no un bloqueo del despliegue: registrarlo y ajustar.
