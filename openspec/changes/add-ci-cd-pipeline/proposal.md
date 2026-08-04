## Why

El despliegue del stack autoalojado (`docker-compose.yml`, ver capacidad
`self-hosted-deployment` en `migrate-to-self-hosted-webapp`) hoy es
enteramente manual: alguien corre `docker compose up -d --build` a mano
siguiendo `docs/despliegue.md`. No hay verificación automática de formato,
análisis ni pruebas antes de que un cambio llegue a las ramas que importan, y
publicar una versión nueva depende de que una persona se acuerde de hacerlo.
Automatizar ambas partes reduce el riesgo de desplegar algo que no pasó sus
propias pruebas y el de que el runbook manual quede desactualizado por falta
de uso.

## What Changes

- Se agrega un pipeline de **integración continua** en GitHub Actions que
  corre formato, análisis y pruebas de `dnd_engine`, `dnd_app` y `dnd_server`
  en runners alojados por GitHub, ante cada push y cada pull request.
- Se agrega un pipeline de **despliegue continuo** que reconstruye y levanta
  el stack (`docker compose up -d --build`) cuando se pushea a `main` o
  `webapp` **y** el cambio toca una ruta relevante para el stack desplegado
  (`packages/dnd_server/**`, `packages/dnd_app/**`, `packages/dnd_engine/**`,
  `docker-compose.yml`, `postgres-init/**`). Cambios que solo tocan
  documentación, ejemplos de configuración o el propio workflow no disparan
  despliegue.
- El despliegue corre en un **runner autoalojado** registrado en el mismo
  host que ya ejecuta `docker compose`, para no tener que exponer ese host a
  conexiones entrantes (SSH, socket Docker remoto) ni sacar secretos de él: el
  `.env` real ya vive ahí.
- El runner autoalojado **solo** ejecuta el workflow de despliegue, disparado
  por `push`. Nunca corre un workflow disparado por `pull_request`: el
  repositorio es público, y un workflow de PR corriendo en un runner
  autoalojado es la vía clásica para que el código de un fork ajeno se
  ejecute sobre la máquina de producción.
- El único control de acceso al despliegue es la protección de rama que ya
  aplica GitHub sobre quién puede pushear o mergear a `main`/`webapp`; no se
  agrega una aprobación adicional por ahora.
- `docs/despliegue.md` se actualiza para documentar el runner y el pipeline;
  el procedimiento manual existente queda como respaldo para despliegue de
  emergencia, no se elimina.

### Non-goals

- Despliegue sin *downtime* (blue/green, canary): sigue siendo un host único.
- Rollback automático ante un despliegue que falla el chequeo de salud.
- Un entorno de *staging* separado de producción.
- Una aprobación manual adicional (GitHub Environment con revisores
  requeridos) sobre el paso de despliegue.
- Filtrado por ruta en el pipeline de CI: corre completo en cada push/PR: ver
  design.md para la justificación.

## Capabilities

### New Capabilities

- `ci-cd-pipeline`: verificación automática de los tres paquetes en cada
  push/PR y despliegue automático del stack autoalojado tras cambios
  relevantes en `main` o `webapp`, con el runner autoalojado acotado
  exclusivamente al despliegue disparado por push.

### Modified Capabilities

Ninguna: `openspec/specs/` sigue vacío (`self-hosted-deployment` todavía es
una capacidad declarada dentro del cambio `migrate-to-self-hosted-webapp`, no
archivada), así que no hay una capacidad existente cuyo requisito se esté
modificando.

## Impact

**Código nuevo**

- `.github/workflows/ci.yml`: formato, análisis y pruebas de los tres
  paquetes en runners de GitHub.
- `.github/workflows/cd.yml`: reconstrucción y despliegue del stack en el
  runner autoalojado, con el filtro de rutas y ramas descrito arriba.

**Infraestructura nueva**

- Un runner autoalojado de GitHub Actions instalado como servicio en el host
  que corre `docker compose`. Vive fuera de `docker-compose.yml`: necesita
  invocar `docker compose` él mismo, así que no puede ser un contenedor más
  del stack que administra.

**Documentación**

- `docs/despliegue.md`: sección nueva sobre el registro del runner y qué hace
  el pipeline; el runbook manual existente se conserva como vía de
  emergencia.

**Ajustes de configuración en GitHub (fuera del repositorio)**

- Reglas de protección de rama sobre `main` y `webapp`.
- Runner autoalojado registrado a nivel de repositorio (no de organización),
  para que ningún otro repositorio pueda apuntarle trabajo.
