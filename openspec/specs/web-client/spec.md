# web-client Specification

## Purpose

Define qué es la aplicación Flutter compilada para navegador: qué conserva de la
experiencia de escritorio, qué deja de ofrecer por no tener sistema de archivos
ni ser el producto instalado, y cómo se comporta cuando el servidor no responde.

## Requirements

### Requirement: Paridad de reglas y de interfaz con la aplicación de escritorio

El cliente web SHALL ofrecer la creación guiada, la ficha completa, la subida de
nivel, el combate, el inventario, las notas y el catálogo homebrew con el mismo
comportamiento de reglas que la aplicación de escritorio congelada. El cliente
web MUST NOT duplicar ni recalcular reglas por su cuenta: la ficha mostrada
proviene de la compilación del motor.

#### Scenario: Misma ficha compilada

- **WHEN** se abre en el navegador un personaje idéntico a uno de escritorio
- **THEN** los valores derivados de la ficha coinciden con los que produce la
  aplicación de escritorio para ese mismo personaje

#### Scenario: Elecciones abiertas pendientes

- **WHEN** un personaje tiene elecciones abiertas sin resolver
- **THEN** el cliente web las obtiene de la ficha compilada y no recorriendo el
  contenido de clase por su cuenta

### Requirement: Ausencia de persistencia local de fichas

El cliente web MUST NOT almacenar personajes, homebrew ni ajustes en el
almacenamiento del navegador como fuente de verdad. La fuente de verdad SHALL
ser el servidor.

#### Scenario: Apertura desde otro dispositivo

- **WHEN** la misma cuenta abre la aplicación desde un navegador distinto
- **THEN** ve los mismos personajes, sin necesidad de importar ni exportar nada

#### Scenario: Borrado de datos del navegador

- **WHEN** se borran los datos del sitio en el navegador
- **THEN** al volver a iniciar sesión los personajes siguen estando completos

### Requirement: Funciones de escritorio ausentes en el cliente web

El cliente web MUST NOT ofrecer las funciones que dependen del sistema de
archivos local o del ciclo de distribución de escritorio: comprobación y
descarga de actualizaciones, apertura de la carpeta de exportaciones en el
explorador y listado de archivos de respaldo del disco del usuario.

#### Scenario: Sin comprobación de actualizaciones

- **WHEN** se usa el cliente web
- **THEN** no se ofrece comprobar ni descargar actualizaciones de la aplicación

#### Scenario: Exportación de un personaje

- **WHEN** una cuenta exporta un personaje o un respaldo desde el cliente web
- **THEN** el archivo se entrega como descarga del navegador, sin exponer rutas
  del servidor

### Requirement: Comportamiento ante pérdida de conexión

Cuando el servidor no esté disponible, el cliente web SHALL informarlo de forma
visible y MUST NOT presentar como guardado un cambio que no fue confirmado por
el servidor.

#### Scenario: Guardado fallido

- **WHEN** un cambio no puede enviarse al servidor
- **THEN** el cliente lo indica claramente y conserva el cambio en pantalla para
  reintentarlo

#### Scenario: Lectura sin conexión

- **WHEN** la aplicación se abre sin conexión con el servidor
- **THEN** el cliente informa que no puede cargar los datos, en lugar de mostrar
  una lista vacía como si la cuenta no tuviera personajes

### Requirement: Compatibilidad de presentación en tabletas

El cliente web SHALL ser usable en la resolución de una tableta en orientación
horizontal, sin desbordes horizontales ni controles inaccesibles en las
pantallas de ficha, combate y creación.

#### Scenario: Ficha en tableta

- **WHEN** se abre la ficha de un personaje en una tableta horizontal
- **THEN** todas las pestañas y acciones son alcanzables y ningún contenido
  queda cortado fuera de la pantalla
