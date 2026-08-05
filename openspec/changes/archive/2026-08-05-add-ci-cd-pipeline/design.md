## Context

Ver `proposal.md` para el *why*. Lo relevante para el diseño, medido sobre el
estado actual del repositorio:

- El despliegue es hoy un procedimiento manual documentado en
  `docs/despliegue.md`: alguien corre `docker compose up -d --build` a mano.
  Ese runbook sigue siendo válido como vía de emergencia después de este
  cambio, no se reemplaza.
- El stack (`docker-compose.yml`) no publica ningún puerto al host; el único
  servicio con salida a internet es `cloudflared`, como túnel saliente. No hay
  forma de llegar al host desde afuera salvo por ese túnel.
- El repositorio (`gasToledo/Proyecto-DnD`) es **público**, con `main` como
  rama por defecto. `webapp` es la rama donde vive el trabajo de la migración
  en curso (`migrate-to-self-hosted-webapp`, 77/86 tareas), todavía no
  mergeada.
- Cada uno de los tres paquetes ya define sus propios comandos de cierre en
  `CLAUDE.md`: `dart format`, `dart analyze`/`flutter analyze` y
  `dart test`/`flutter test`, y para `dnd_app` además `flutter build web
  --release` cuando el cambio toca UI, persistencia, dependencias o
  integración del cliente web.
- `packages/dnd_server/Dockerfile` construye con `context: .` (raíz del
  repo), así que la imagen que sirve API + cliente web depende del contenido
  de los tres paquetes, no solo de `dnd_server`.
- El servidor ya expone `/health` y ya reintenta las migraciones de base de
  datos al arrancar en lugar de terminar en fallo permanente
  (`_runMigrationsWithRetry`), así que un chequeo de salud post-despliegue
  puede apoyarse en un endpoint que ya existe.

## Goals / Non-Goals

**Goals:**

- Verificación automática (formato, análisis, pruebas) de los tres paquetes
  en runners alojados por GitHub, en cada push y cada pull request.
- Despliegue automático del stack cuando se pushea a `main` o `webapp` con
  cambios en una ruta relevante para lo que corre en el host.
- El runner autoalojado nunca ejecuta código disparado por `pull_request`: es
  la única forma de tener un runner autoalojado en un repositorio público sin
  abrirle la puerta a un fork malicioso.
- El único control de acceso al despliegue es la protección de rama que ya
  gobierna quién puede pushear/mergear a `main`/`webapp` (decisión explícita:
  sin un gate de aprobación adicional).

**Non-Goals:**

- *Blue/green*, *canary* o cualquier despliegue sin *downtime*: sigue siendo
  un host único con un solo `docker compose up -d --build`.
- Rollback automático ante un despliegue que no queda saludable.
- Filtrado por ruta dentro del pipeline de CI (sí lo hay en CD): con tres
  paquetes y suites de pruebas que hoy corren en segundos, la complejidad de
  un *matrix* condicional no se justifica todavía, y evita el problema
  conocido de GitHub donde un *required check* que un filtro de ruta salteó
  queda pendiente para siempre y bloquea el merge.
- Respaldo automático de la base de datos como parte del despliegue (ver
  decisión más abajo).

## Decisions

### D1. El runner autoalojado vive en el mismo host que corre `docker compose`

**Por qué:** el stack no publica puertos y no acepta conexiones entrantes por
diseño (ver capacidad `self-hosted-deployment`). Un runner en otra máquina
necesitaría SSH o un socket Docker remoto hacia el host de producción, es
decir, abrir exactamente la superficie que ese diseño evita. Un runner local
ya tiene `docker compose`, el `.env` real y el repositorio clonado ahí mismo;
desplegar es `git pull` + `docker compose up -d --build` sin que ningún
secreto viaje por la red.

**Alternativas consideradas:** runner en una máquina intermedia con acceso
SSH al host de producción. Se descarta: agrega una máquina más que mantener y
una clave SSH con permiso de desplegar que administrar, a cambio de nada — el
runner local ya cumple el mismo rol sin esa superficie extra.

### D2. La verificación (CI) corre siempre en runners de GitHub, nunca en el autoalojado

**Por qué:** el repositorio es público. Un `pull_request` desde un fork
ejecuta el workflow que ese PR declara; si ese workflow corriera en el runner
autoalojado, el código de un desconocido correría sobre la máquina de
producción. GitHub documenta esto explícitamente como el motivo para no usar
runners autoalojados en repositorios públicos salvo que se acoten con
cuidado. La forma más simple de acotarlo es no darle nunca ese trabajo: CI
(que sí debe correr sobre PRs de forks) vive enteramente en runners alojados
por GitHub, efímeros y sin acceso al host.

**Alternativas consideradas:** runner autoalojado único para CI y CD, con
`pull_request_target` o aprobación manual de ejecución para colaboradores
externos. Se descarta: sigue dejando una vía —un mantenedor aprobando sin
mirar el diff con suficiente detalle— para que código no confiable llegue al
runner de producción. Separar los dos pipelines por tipo de runner elimina la
pregunta en vez de mitigarla.

### D3. El despliegue dispara solo con `push`, nunca con `pull_request`, a `main` o `webapp`

**Por qué:** ver D2 — es la mitad complementaria de esa decisión. `push` a
una rama protegida ya implica que alguien con permiso de escritura aterrizó
ese commit; no hay forma de que un PR externo dispare este workflow, tenga o
no aprobación.

**Nota:** mientras `webapp` no esté mergeada a `main`, ambas ramas despliegan
al mismo host de producción — el último push gana. Es la situación actual,
deliberada mientras dura la migración (permite ensayar el despliegue real
antes de cerrar `migrate-to-self-hosted-webapp`, tareas 10.7–10.12). Cuando
`webapp` se mergee y quede en la línea principal, este solapamiento
desaparece solo. Ver Risks/Trade-offs.

### D4. Filtro de rutas para CD, no para CI

**Por qué:** el objetivo de CD es no reconstruir la imagen ni reiniciar
contenedores cuando el cambio no afecta lo que corre en el host. La imagen de
`dnd_server` se construye con `context: .`, así que un cambio relevante puede
venir de cualquiera de los tres paquetes, no solo del propio servidor:

- Dispara CD: `packages/dnd_server/**`, `packages/dnd_app/**`,
  `packages/dnd_engine/**`, `docker-compose.yml`, `postgres-init/**`.
- No dispara CD: `docs/**`, `openspec/**`, `CLAUDE.md`, `README.md`,
  `brief-app-dnd5e.md`, `.env.example`, `cloudflared/config.example.yml`,
  `.github/workflows/**`.

CI no usa este ni ningún otro filtro (ver Non-Goals): corre completo siempre.
Son preguntas distintas — "¿rompí algo?" vs. "¿necesita esto llegar a
producción?" — y reusar la misma lista para ambas dejaría a CI sin correr
sobre cambios que sí quiere cubrir (por ejemplo, un test nuevo que no toca
ningún paquete de producto).

### D5. Protección de rama es el único control de acceso al despliegue

**Por qué:** decisión explícita del proyecto — con un mantenedor
único/equipo pequeño, un gate de aprobación adicional (GitHub Environment con
revisores requeridos) agrega fricción sin agregar seguridad real, porque la
misma persona que pushea sería quien aprueba. La protección de rama sobre
`main`/`webapp` (PRs requeridos, sin *force-push*, restricción de quién puede
pushear directo) ya es la barrera efectiva.

**Alternativa considerada:** GitHub Environment `production` con revisores
requeridos sobre el job de CD. Queda descartada por ahora; es agregable más
adelante sin cambiar el resto del diseño si el equipo crece.

### D6. CD no incluye respaldo automático de la base antes de desplegar

**Por qué:** el respaldo (`pg_dumpall` + `tar` del volumen de retratos) ya es
un procedimiento documentado y manual en `docs/despliegue.md`, pensado para
ejecutarse bajo control humano, no como paso ciego de cada despliegue.
Meterlo dentro de CD suma tiempo y superficie (¿dónde se guarda el dump?
¿cuánto se retiene? ¿qué pasa si el respaldo falla — bloquea el deploy?) a un
pipeline que este cambio busca mantener simple: reconstruir, levantar,
comprobar salud. El servidor además ya reintenta migraciones al arrancar en
vez de fallar duro, que es la protección que más importa en el camino común.

**Alternativa considerada:** respaldo automático antes de cada `docker
compose up --build`. Se difiere: es una mejora operativa independiente
(programarla, decidir retención) que no depende de que exista CI/CD y puede
agregarse después sin tocar este diseño.

### D7. Health check post-despliegue reutiliza `/health`, sin rollback automático

**Por qué:** el endpoint ya existe y ya es lo que usa el `healthcheck` del
propio `docker-compose.yml`. El paso de CD hace poll sobre ese mismo endpoint
tras el `up -d --build` y reporta el workflow como fallido si no queda
saludable dentro de un tiempo de espera acotado. No revierte el despliegue:
revertir implicaría reconstruir la imagen anterior o mantener un tag de
respaldo, mecanismo que no existe hoy y que este cambio no introduce (ver
Non-Goals). Un despliegue fallido queda visible en GitHub Actions y se
resuelve a mano, igual que cualquier fallo detectado hoy por lectura de
`docker compose logs`.

## Risks / Trade-offs

- **`main` y `webapp` despliegan al mismo host mientras dure la migración**
  (D3) → sin aislamiento entre lo que cada rama publica; el último push
  gana. Aceptado como transitorio: desaparece cuando `webapp` se mergee.
- **Sin rollback automático** (D7) → un despliegue que rompe algo queda
  corriendo hasta una intervención manual (`docker compose` a un commit
  anterior, o restaurar desde el respaldo documentado). Mitigación: el
  chequeo de salud hace visible el fallo de inmediato en vez de descubrirlo
  por un jugador reportando que la app no anda.
- **El runner autoalojado comparte host con producción** (D1) → un workflow
  de CD mal escrito tiene el mismo alcance que cualquier proceso corriendo en
  ese host. Mitigación: el job de CD se mantiene deliberadamente angosto
  (`git pull` + `docker compose up -d --build` + chequeo de salud), sin pasos
  que ejecuten contenido arbitrario controlado por un PR.
- **Sin respaldo automático pre-despliegue** (D6) → un despliegue que trae
  una migración de esquema rota se aplica sin red de seguridad automática.
  Mitigación: el procedimiento de respaldo manual ya documentado sigue
  disponible y queda como paso recomendado antes de un cambio de esquema
  conocido, no como parte del pipeline.

## Migration Plan

1. Crear `.github/workflows/ci.yml`: formato, análisis y pruebas de los tres
   paquetes en runners de GitHub, disparado por `push` y `pull_request`.
2. Configurar protección de rama sobre `main` y `webapp` en GitHub (requerir
   PR, requerir que CI pase, restringir quién puede pushear directo). Es un
   ajuste de configuración del repositorio, no código.
3. Aprovisionar el runner autoalojado en el host de despliegue: instalarlo
   como servicio, registrarlo a nivel de repositorio (no de organización).
4. Crear `.github/workflows/cd.yml`: disparado por `push` a `main`/`webapp`
   con el filtro de rutas de D4, corre en el runner autoalojado, hace
   `docker compose up -d --build` y comprueba `/health`.
5. Documentar el runner y el pipeline en `docs/despliegue.md`, conservando el
   procedimiento manual como vía de emergencia.
6. Primer despliegue real disparado por el pipeline: es también la primera
   oportunidad de cerrar las tareas bloqueadas de `migrate-to-self-hosted-webapp`
   que necesitan un host real (10.7–10.10, 10.12, 11.1), ya que hasta ahora
   ningún entorno de trabajo tuvo Docker disponible.

**Rollback:** deshabilitar o borrar el trigger de `cd.yml` (o detener el
servicio del runner) devuelve el proyecto al procedimiento 100% manual que ya
existe y sigue documentado; no hay estado de datos que revertir porque CD no
toca el esquema más allá de lo que el servidor ya hace al arrancar.
