# account-data-import Specification

## Purpose

Permite que quien ya tiene personajes en la aplicación de escritorio congelada
los traiga a su cuenta del servidor subiendo el respaldo ZIP que esa aplicación
genera, sin pérdida de datos ni de retratos.

## Requirements

### Requirement: Importación de un respaldo de la aplicación de escritorio

El sistema SHALL aceptar el respaldo ZIP producido por la aplicación de
escritorio congelada e incorporar a la cuenta autenticada los personajes, el
contenido homebrew y los retratos que contiene.

#### Scenario: Importación completa

- **WHEN** una cuenta sube un respaldo válido con personajes, homebrew y
  retratos
- **THEN** los tres quedan disponibles en la cuenta tras finalizar la
  importación

#### Scenario: Personajes de versiones anteriores

- **WHEN** el respaldo contiene personajes con una versión de esquema anterior a
  la vigente
- **THEN** se migran al importarlos y quedan legibles

#### Scenario: Respaldo de versión futura

- **WHEN** el respaldo declara una versión de formato posterior a la conocida
- **THEN** el sistema rechaza la importación completa sin alterar los datos
  existentes de la cuenta

### Requirement: Reescritura de las referencias de retrato

Al importar, el sistema SHALL extraer los retratos del respaldo, almacenarlos
como blobs de la cuenta y reescribir las referencias del personaje a las nuevas
claves. MUST NOT conservar en el documento importado ninguna ruta del sistema de
archivos de origen.

#### Scenario: Personaje con retratos

- **WHEN** se importa un personaje que traía rutas absolutas de retrato
- **THEN** el personaje importado muestra sus retratos y sus referencias son
  claves de la cuenta

#### Scenario: Retrato ausente en el respaldo

- **WHEN** un personaje referencia un retrato que el respaldo no incluye
- **THEN** el personaje se importa igualmente, sin esa referencia rota

### Requirement: El respaldo se trata como dato no confiable

El sistema SHALL validar el contenido del respaldo antes de aplicarlo. Ninguna
entrada del archivo MUST poder escribir fuera del espacio de la cuenta que
importa, cualquiera sea la ruta que declare.

#### Scenario: Entrada con ruta de escape

- **WHEN** el respaldo contiene una entrada cuya ruta intenta salir del espacio
  de destino
- **THEN** el sistema rechaza la importación y no escribe nada

#### Scenario: Contenido corrupto

- **WHEN** el respaldo contiene un documento ilegible
- **THEN** el sistema informa qué entrada falló y la cuenta no queda a medias

### Requirement: La importación no destruye datos existentes

Una importación SHALL agregarse a lo que la cuenta ya tiene. MUST NOT eliminar
ni sobrescribir personajes existentes; ante un identificador ya usado en la
cuenta, el personaje importado recibe uno libre.

#### Scenario: Importación sobre una cuenta con datos

- **WHEN** una cuenta que ya tiene personajes importa un respaldo
- **THEN** conserva los anteriores y suma los importados

#### Scenario: Identificador repetido

- **WHEN** el respaldo trae un personaje con un identificador que la cuenta ya
  usa
- **THEN** el importado se guarda con un identificador nuevo y el existente
  queda intacto

#### Scenario: Importación repetida del mismo respaldo

- **WHEN** se importa dos veces el mismo respaldo
- **THEN** la segunda importación no corrompe ni elimina lo que dejó la primera
