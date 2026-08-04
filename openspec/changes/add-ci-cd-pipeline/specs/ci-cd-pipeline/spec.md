## Purpose

Define el contrato de verificación y despliegue automático del proyecto:
qué corre en cada push y pull request, qué dispara un despliegue del stack
autoalojado, y cómo se mantiene el runner de despliegue fuera del alcance de
código no confiable.

## ADDED Requirements

### Requirement: Verificación continua de los tres paquetes

El sistema SHALL ejecutar formato, análisis y pruebas de `dnd_engine`,
`dnd_app` y `dnd_server` en runners alojados por GitHub ante cada push y cada
pull request, sin depender del runner autoalojado de despliegue.

#### Scenario: Pull request abierto o actualizado

- **WHEN** se abre o se actualiza un pull request
- **THEN** corren formato, análisis y pruebas de los tres paquetes y el
  resultado queda visible antes de poder mergear

#### Scenario: Verificación nunca en el runner de despliegue

- **WHEN** corre el pipeline de verificación, sin importar el origen del
  push o pull request
- **THEN** se ejecuta en un runner alojado por GitHub, nunca en el runner
  autoalojado del despliegue

### Requirement: Despliegue automático tras cambios relevantes en main o webapp

El sistema SHALL desplegar automáticamente el stack autoalojado cuando se
pushea a `main` o a `webapp` y el cambio toca al menos una ruta relevante
para lo que corre en el host desplegado.

#### Scenario: Push relevante a una rama de despliegue

- **WHEN** se pushea a `main` o `webapp` tocando `packages/dnd_server/**`,
  `packages/dnd_app/**`, `packages/dnd_engine/**`, `docker-compose.yml` o
  `postgres-init/**`
- **THEN** el pipeline reconstruye la imagen y levanta el stack en el host de
  despliegue

#### Scenario: Push sin cambios relevantes

- **WHEN** se pushea a `main` o `webapp` sin tocar ninguna ruta relevante
  para el stack desplegado
- **THEN** no se dispara ningún despliegue

#### Scenario: Push a una rama distinta

- **WHEN** se pushea a una rama que no es `main` ni `webapp`
- **THEN** no se dispara ningún despliegue

### Requirement: El runner autoalojado no ejecuta código no confiable

El runner autoalojado SHALL ejecutar exclusivamente el pipeline de
despliegue, disparado por eventos `push`. MUST NOT ejecutar ningún workflow
disparado por un evento `pull_request`, sin importar si el pull request se
originó dentro del repositorio o desde un fork.

#### Scenario: Pull request desde un fork externo

- **WHEN** se abre o actualiza un pull request desde un fork
- **THEN** ningún workflow disparado por ese pull request corre en el runner
  autoalojado

#### Scenario: Pull request desde una rama del propio repositorio

- **WHEN** se abre o actualiza un pull request desde una rama del propio
  repositorio
- **THEN** tampoco corre en el runner autoalojado: la verificación de ese PR
  corre en runners alojados por GitHub como cualquier otro pull request

### Requirement: Control de acceso al despliegue mediante protección de rama

El disparo de un despliegue SHALL quedar acotado a quien tiene permiso de
push sobre `main` o `webapp`, aplicado mediante las reglas de protección de
rama del repositorio, sin un mecanismo de aprobación adicional dentro del
pipeline.

#### Scenario: Push sin permiso de escritura

- **WHEN** alguien sin permiso de push directo intenta modificar `main` o
  `webapp`
- **THEN** GitHub rechaza el push y ningún despliegue se dispara

#### Scenario: Merge de un pull request aprobado

- **WHEN** un pull request hacia `main` o `webapp` se mergea por alguien con
  permiso para hacerlo
- **THEN** el merge cuenta como push a esa rama a los efectos de disparar el
  despliegue si toca una ruta relevante

### Requirement: Verificación de salud tras el despliegue

Tras reconstruir y levantar el stack, el pipeline SHALL comprobar que el
servicio queda saludable antes de reportar el despliegue como exitoso.

#### Scenario: Servicio saludable dentro del tiempo de espera

- **WHEN** el servicio alcanza estado saludable dentro del tiempo de espera
  configurado
- **THEN** el pipeline reporta el despliegue como exitoso

#### Scenario: Servicio no queda saludable

- **WHEN** el servicio no alcanza estado saludable dentro del tiempo de
  espera configurado
- **THEN** el pipeline reporta el despliegue como fallido, sin revertir
  automáticamente el stack a la versión anterior
