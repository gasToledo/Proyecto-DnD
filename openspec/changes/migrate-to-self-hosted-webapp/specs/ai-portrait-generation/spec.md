## Purpose

Mueve la generación de retratos con IA al servidor, de modo que las credenciales
de los proveedores dejen de estar en la máquina de la persona usuaria y el
navegador nunca hable directamente con un proveedor externo.

## ADDED Requirements

### Requirement: Las credenciales de proveedor viven solo en el servidor

Las credenciales de los proveedores de generación de imágenes SHALL estar bajo
control exclusivo del servidor. MUST NOT enviarse al cliente web, aparecer en
respuestas de la API, ni ser deducibles a partir del tráfico que el navegador
observa.

#### Scenario: Inspección del tráfico del navegador

- **WHEN** se inspecciona cualquier respuesta que recibe el cliente web
- **THEN** ninguna contiene una clave de proveedor

#### Scenario: Configuración de credenciales

- **WHEN** se configuran las credenciales de un proveedor
- **THEN** se configuran en el servidor y no en la interfaz del cliente web

### Requirement: El navegador no contacta al proveedor externo

Toda petición a un proveedor de generación de imágenes SHALL originarse en el
servidor. El cliente web MUST solicitar la generación a la API propia y recibir
el resultado desde ella.

#### Scenario: Generación de un retrato

- **WHEN** una cuenta pide generar un retrato
- **THEN** el navegador solo se comunica con la API propia y el servidor realiza
  la llamada al proveedor

#### Scenario: Proveedor que exige imagen de referencia

- **WHEN** se pide una generación basada en una imagen de referencia
- **THEN** la referencia se envía a la API propia y es el servidor quien la
  reenvía al proveedor

### Requirement: Selección de proveedor y degradación

El sistema SHALL permitir elegir entre los proveedores configurados. Un
proveedor sin credenciales configuradas MUST NOT ofrecerse como opción
seleccionable, y una configuración que referencie un proveedor desconocido o
retirado SHALL degradar al proveedor predeterminado sin perder el resto de los
ajustes.

#### Scenario: Proveedor sin credenciales

- **WHEN** un proveedor no tiene credenciales configuradas en el servidor
- **THEN** no aparece como opción disponible para generar

#### Scenario: Ajuste que referencia un proveedor retirado

- **WHEN** se cargan ajustes que nombran un proveedor retirado
- **THEN** el sistema usa el proveedor predeterminado y conserva los demás
  ajustes

### Requirement: Manejo de fallos del proveedor

Cuando un proveedor falle, se demore en exceso o devuelva una respuesta no
utilizable, el sistema SHALL informarlo de forma comprensible y MUST NOT dejar
un retrato parcial asociado al personaje.

#### Scenario: Error del proveedor

- **WHEN** el proveedor responde con un error
- **THEN** la cuenta recibe un mensaje que explica el fallo y el personaje queda
  sin retrato nuevo

#### Scenario: Respuesta ilegible

- **WHEN** el proveedor devuelve datos que no son una imagen válida
- **THEN** el sistema descarta el resultado y no lo guarda

### Requirement: Importación de un retrato desde archivo

El sistema SHALL permitir subir un retrato desde un archivo propio como
alternativa a la generación, disponible con independencia de que haya algún
proveedor de IA configurado.

#### Scenario: Subida de un retrato propio

- **WHEN** una cuenta sube una imagen desde su dispositivo
- **THEN** queda asociada al personaje igual que un retrato generado

#### Scenario: Sin proveedores configurados

- **WHEN** el servidor no tiene ningún proveedor de IA configurado
- **THEN** la subida de un retrato desde archivo sigue disponible
