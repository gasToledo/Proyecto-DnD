## Purpose

Define el contrato operativo del stack autoalojado: cómo se levanta, cómo se
publica en internet sin abrir puertos, cómo se configuran los secretos y qué
garantías de recuperación debe ofrecer quien lo opera.

## ADDED Requirements

### Requirement: Arranque reproducible del stack completo

El stack SHALL levantarse completo con una única orden de composición de
contenedores, a partir de un archivo de configuración de ejemplo versionado en
el repositorio. Un arranque en limpio MUST dejar el sistema utilizable sin pasos
manuales no documentados.

#### Scenario: Arranque desde cero

- **WHEN** se levanta el stack en una máquina limpia con la configuración de
  ejemplo completada
- **THEN** la aplicación queda accesible y permite iniciar sesión y crear un
  personaje

#### Scenario: Reinicio del stack

- **WHEN** se detienen y vuelven a levantar los contenedores
- **THEN** los datos de las cuentas y los retratos siguen presentes

#### Scenario: Dependencias no listas

- **WHEN** la API arranca antes que la base de datos
- **THEN** espera a que esté disponible en lugar de terminar en un estado fallido
  permanente

### Requirement: Publicación sin puertos entrantes

El stack SHALL publicarse mediante un túnel saliente. MUST NOT requerir abrir
puertos entrantes en el router ni exponer directamente los servicios internos.

#### Scenario: Servicios internos no expuestos

- **WHEN** se inspeccionan los puertos accesibles desde internet
- **THEN** la base de datos y el almacenamiento de blobs no son alcanzables

#### Scenario: Nombres públicos requeridos

- **WHEN** se configura la publicación
- **THEN** existe un nombre público para la aplicación y otro para el emisor
  OIDC, y el emisor coincide exactamente con el nombre configurado en el
  proveedor de identidad

### Requirement: Secretos fuera de las imágenes y del repositorio

Las credenciales de base de datos, del proveedor de identidad, del túnel y de
los proveedores de IA SHALL suministrarse como configuración de entorno o
secretos montados. MUST NOT incluirse en las imágenes construidas ni versionarse
en el repositorio.

#### Scenario: Inspección de la imagen

- **WHEN** se inspecciona una imagen construida del stack
- **THEN** no contiene ninguna credencial

#### Scenario: Contenido versionado

- **WHEN** se revisa el repositorio
- **THEN** solo hay un archivo de configuración de ejemplo con valores de
  marcador, sin secretos reales

### Requirement: Entrega correcta de nuevas versiones del cliente web

La publicación SHALL evitar que el navegador quede fijado a una versión anterior
del cliente web tras un despliegue. Los recursos que determinan la versión
cargada MUST NOT servirse con una caché que sobreviva al despliegue.

#### Scenario: Despliegue de una versión nueva

- **WHEN** se despliega una versión nueva del cliente web
- **THEN** una recarga normal del navegador carga la versión nueva

#### Scenario: Recursos sin huella de contenido

- **WHEN** se sirven los archivos del build web, cuyos nombres `flutter build
  web` repite entre versiones (`main.dart.js`, `flutter_bootstrap.js`,
  `assets/…`, `canvaskit/…`: ninguno lleva huella de contenido)
- **THEN** ninguno se declara inmutable ni se cachea sin revalidar

#### Scenario: Caché compartida en el camino

- **WHEN** un intermediario (Cloudflare) almacena la respuesta y reescribe su
  tiempo de vida hacia el navegador
- **THEN** los archivos del build se marcan de modo que ese intermediario no
  pueda conservarlos, para que sea el servidor quien decida qué versión
  corresponde

### Requirement: Respaldo y restauración del estado persistente

El sistema SHALL documentar y permitir respaldar todo el estado persistente
—datos de la aplicación, datos del proveedor de identidad y blobs de retratos— y
restaurarlo en una instalación nueva.

#### Scenario: Restauración en una máquina nueva

- **WHEN** se restaura un respaldo completo sobre una instalación limpia
- **THEN** las cuentas, sus personajes y sus retratos quedan disponibles como
  estaban

#### Scenario: Estado fuera de los volúmenes

- **WHEN** se revisa qué debe respaldarse
- **THEN** todo el estado persistente reside en volúmenes declarados y ninguno
  queda dentro de la capa efímera de un contenedor

### Requirement: Comprobación de salud de los servicios

Cada servicio del stack SHALL exponer una forma de comprobar que está operativo,
de modo que un fallo sea observable sin inspeccionar registros a mano.

#### Scenario: Servicio caído

- **WHEN** un servicio del stack deja de estar operativo
- **THEN** su comprobación de salud lo refleja como no saludable
