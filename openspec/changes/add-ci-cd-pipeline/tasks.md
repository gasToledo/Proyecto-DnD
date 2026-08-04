## 1. Pipeline de integración continua

- [x] 1.1 Crear `.github/workflows/ci.yml` disparado por `push` y
      `pull_request`, corriendo en runners alojados por GitHub
      (`ubuntu-latest`), nunca en el runner autoalojado
- [x] 1.2 Job para `dnd_engine`: `dart pub get`, `dart format
      --output=none --set-exit-if-changed .`, `dart analyze`, `dart test`
- [x] 1.3 Job para `dnd_app`: `flutter pub get`, `dart format --output=none
      --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`,
      `flutter build web --release`
- [x] 1.4 Job para `dnd_server`: `dart pub get`, `dart format --output=none
      --set-exit-if-changed lib bin test`, `dart analyze`, `dart test`
- [x] 1.5 Confirmar que los tres jobs corren en paralelo y sin filtro de
      ruta (ver design.md, Non-Goals y D4): cada push/PR los ejecuta
      completos (sin `needs:` entre jobs, sin `paths:` en el trigger)
- [ ] 1.6 Verificar en un pull request de prueba que el resultado de los
      tres jobs queda visible antes de poder mergear (necesita un push real
      contra GitHub; no ejecutable desde esta sesión)

## 2. Protección de rama

- [ ] 2.1 Configurar protección de rama sobre `main`: requerir pull request,
      requerir que los jobs de CI pasen, sin *force-push* (ajuste en GitHub
      *Settings → Branches*, ver `docs/despliegue.md`; no ejecutable desde
      esta sesión, requiere acceso de administrador al repositorio)
- [ ] 2.2 Configurar la misma protección sobre `webapp` mientras siga activa
- [ ] 2.3 Confirmar quién tiene permiso de push directo/merge sobre ambas
      ramas y ajustarlo si hace falta (ver design.md, D5: es el único
      control de acceso al despliegue)

## 3. Runner autoalojado

- [ ] 3.1 Instalar el runner de GitHub Actions como servicio en el host que
      corre `docker compose`, registrado a nivel de repositorio (no de
      organización), para que ningún otro repositorio pueda encolarle
      trabajo (procedimiento documentado en `docs/despliegue.md`; requiere
      acceso físico/remoto al host de producción, no ejecutable desde esta
      sesión)
- [ ] 3.2 Confirmar que el usuario del sistema bajo el que corre el runner
      tiene permiso para invocar `docker compose` en ese host
- [ ] 3.3 Colocar `.env`, `cloudflared/config.yml` y `cloudflared/creds.json`
      reales en el directorio de trabajo del runner (`cd.yml` usa
      `clean: false` para no borrarlos entre despliegues — ver
      `docs/despliegue.md`, sección "Registrar el runner autoalojado")
- [ ] 3.4 Verificar con un workflow mínimo de prueba que el runner queda
      `Idle` y visible en la configuración de Actions del repositorio

## 4. Pipeline de despliegue continuo

- [x] 4.1 Crear `.github/workflows/cd.yml` disparado por `push` a `main` o
      `webapp`, con filtro de rutas: `packages/dnd_server/**`,
      `packages/dnd_app/**`, `packages/dnd_engine/**`, `docker-compose.yml`,
      `postgres-init/**` (ver design.md, D4)
- [x] 4.2 Configurar el job para correr en el runner autoalojado
      (`runs-on: [self-hosted]`)
- [x] 4.3 Paso de checkout (con `clean: false`, ver 3.3) y `docker compose
      up -d --build`
- [x] 4.4 Paso de chequeo de salud: como no hay puertos publicados al host,
      lee el `healthcheck` que `docker-compose.yml` ya define sobre
      `/health` vía `docker inspect` en vez de pedirlo por HTTP desde el
      runner; el workflow falla si no queda `healthy` a tiempo (ver
      design.md, D7 — sin rollback automático)
- [x] 4.5 Confirmar que el job no ejecuta ningún paso con contenido
      controlado por un pull request: el trigger es solo `push`, sin
      `pull_request_target` ni pasos que evalúen contenido de un PR (ver
      design.md, Risks/Trade-offs)
- [ ] 4.6 Probar el filtro de rutas: un push que solo toca `docs/**` no
      dispara el job; un push a `packages/dnd_server/**` sí (necesita el
      runner de la sección 3 registrado y un push real; no ejecutable desde
      esta sesión)
- [ ] 4.7 Probar el filtro de rama: un push a una rama distinta de
      `main`/`webapp` no dispara el job (idem 4.6)

## 5. Documentación

- [x] 5.1 Agregar a `docs/despliegue.md` una sección sobre el runner
      autoalojado y qué hace `cd.yml`, dejando el runbook manual existente
      como vía de emergencia
- [x] 5.2 Actualizar `CLAUDE.md`: los comandos de cierre no cambian (siguen
      siendo el criterio para pushear), se agrega una nota de que
      `ci.yml`/`cd.yml` los corren automáticamente después

## 6. Cierre

- [ ] 6.1 Primer despliegue real disparado por `cd.yml` contra el host de
      producción
- [ ] 6.2 Con ese despliegue real, retomar las tareas bloqueadas de
      `migrate-to-self-hosted-webapp` que necesitaban un host real: 10.7,
      10.8, 10.9, 10.10, 10.12 y 11.1
- [ ] 6.3 Confirmar que un push que dispara CD también pasó CI antes (por la
      protección de rama de la sección 2), de modo que nunca se despliega
      código que no pasó sus propias pruebas
