## Purpose

Traslada los retratos desde rutas del disco del usuario a blobs guardados por el
servidor, referenciados por claves opacas y servidos solo a su dueño, de modo
que un personaje exportado deje de arrastrar rutas de una máquina concreta.

## ADDED Requirements

### Requirement: Los retratos se referencian por claves opacas

Un personaje SHALL referenciar sus retratos mediante claves opacas resueltas por
la plataforma que los muestra. El documento del personaje MUST NOT contener
rutas absolutas del sistema de archivos de la máquina que lo creó.

#### Scenario: Personaje exportado

- **WHEN** se exporta un personaje que tiene retratos
- **THEN** el documento exportado no contiene ninguna ruta del sistema de
  archivos

#### Scenario: Migración de un personaje histórico

- **WHEN** se lee un personaje guardado con rutas absolutas de retrato
- **THEN** la migración de esquema las convierte en claves y el personaje queda
  legible sin intervención manual

#### Scenario: Retrato activo

- **WHEN** un personaje tiene varias claves de retrato
- **THEN** la primera sigue siendo la que se muestra como retrato activo

### Requirement: Autorización en el servido de retratos

El servidor SHALL entregar un retrato únicamente a la cuenta propietaria del
personaje al que pertenece. Una petición no autenticada, o autenticada como otra
cuenta, MUST NOT obtener la imagen ni confirmación de que existe.

#### Scenario: Petición de un retrato ajeno

- **WHEN** una cuenta pide un retrato cuya clave pertenece a otra cuenta
- **THEN** el servidor responde como si no existiera

#### Scenario: Petición sin sesión

- **WHEN** se pide un retrato sin sesión válida
- **THEN** el servidor no entrega la imagen

#### Scenario: Clave manipulada

- **WHEN** una clave de retrato entrante contiene segmentos que intentan salir
  del espacio de la cuenta
- **THEN** el servidor rechaza la petición

### Requirement: Durabilidad e independencia del backend de blobs

El almacenamiento de retratos SHALL estar detrás de una interfaz que permita
cambiar el medio de almacenamiento sin modificar la API ni el cliente. Un
retrato guardado con éxito MUST seguir disponible tras reiniciar los
contenedores.

#### Scenario: Reinicio del stack

- **WHEN** se reinician los contenedores del servidor
- **THEN** los retratos guardados previamente siguen siendo accesibles

#### Scenario: Cambio de medio de almacenamiento

- **WHEN** se sustituye el medio de almacenamiento de blobs
- **THEN** no cambia ningún contrato observable de la API de retratos

### Requirement: Validación de las imágenes aceptadas

El servidor SHALL validar tipo y tamaño de toda imagen entrante antes de
almacenarla, y rechazar las que excedan el límite configurado.

#### Scenario: Archivo demasiado grande

- **WHEN** se sube una imagen que supera el tamaño máximo admitido
- **THEN** el servidor la rechaza con un error descriptivo y no almacena nada

#### Scenario: Archivo que no es una imagen admitida

- **WHEN** se sube un archivo cuyo tipo no está entre los admitidos
- **THEN** el servidor lo rechaza
