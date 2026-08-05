# character-api Specification

## Purpose

Reemplaza el almacenamiento en archivos locales por una API de servidor que
guarda personajes, homebrew y ajustes como documentos versionados propiedad de
una cuenta, conservando las garantías de integridad y compatibilidad de datos
que ya ofrecía la aplicación de escritorio.

## Requirements

### Requirement: Persistencia de personajes como documentos versionados

El sistema SHALL almacenar cada personaje como el documento JSON que produce la
serialización del dominio, sin descomponerlo en un modelo relacional. El
documento almacenado MUST conservar su versión de esquema declarada.

#### Scenario: Guardado y relectura

- **WHEN** una cuenta guarda un personaje y luego lo vuelve a leer
- **THEN** el documento recuperado es equivalente al enviado, incluida su
  versión de esquema

#### Scenario: Documento de versión histórica

- **WHEN** se lee un personaje almacenado con una versión de esquema anterior a
  la vigente
- **THEN** el sistema lo migra secuencialmente hasta la versión vigente antes de
  entregarlo

#### Scenario: Documento de versión futura

- **WHEN** se lee un personaje cuya versión de esquema es posterior a la que el
  sistema conoce
- **THEN** el sistema rechaza la lectura y MUST NOT modificar ni sobrescribir el
  documento almacenado

### Requirement: Atomicidad de escrituras multi-documento

Cuando una operación afecte a más de un documento, el sistema SHALL aplicarla
por completo o no aplicarla en absoluto. MUST NOT quedar un estado en el que
parte de los documentos de la operación se hayan actualizado y el resto no.

#### Scenario: Fallo a mitad de una escritura por lotes

- **WHEN** una operación que actualiza varios personajes falla al procesar uno
  de ellos
- **THEN** ninguno de los documentos de esa operación queda modificado

#### Scenario: Importación de un conjunto de datos

- **WHEN** se importan simultáneamente personajes y contenido homebrew
- **THEN** o bien todo el conjunto queda disponible, o bien la cuenta queda
  exactamente como estaba antes de la importación

### Requirement: Identificadores de personaje únicos por cuenta

El sistema SHALL garantizar que un identificador de personaje sea único dentro
de una cuenta. Identificadores iguales en cuentas distintas MUST poder coexistir
sin interferir entre sí.

#### Scenario: Dos cuentas con el mismo identificador

- **WHEN** dos cuentas distintas poseen personajes con el mismo identificador
- **THEN** cada cuenta lee su propio personaje sin conflicto ni mezcla de datos

#### Scenario: Alta de un identificador ya usado en la cuenta

- **WHEN** una cuenta intenta crear un personaje con un identificador que ya
  posee
- **THEN** el sistema asigna un identificador libre en lugar de sobrescribir el
  personaje existente

### Requirement: Persistencia de homebrew y ajustes por cuenta

El sistema SHALL almacenar el contenido homebrew y los ajustes de cada cuenta de
forma independiente, con las mismas garantías de versionado que los personajes.
El contenido homebrew de una cuenta MUST NOT aparecer en el catálogo de otra.

#### Scenario: Homebrew visible solo para su autor

- **WHEN** una cuenta crea contenido homebrew
- **THEN** ese contenido aparece en su catálogo y no en el de ninguna otra cuenta

#### Scenario: Ajustes independientes

- **WHEN** dos cuentas configuran preferencias distintas
- **THEN** cada una recibe sus propias preferencias al iniciar sesión

### Requirement: Tratamiento de datos entrantes como no confiables

El sistema SHALL validar todo documento recibido de un cliente antes de
almacenarlo, comprobando versión, tipos e identificadores. Un documento que no
supere la validación MUST ser rechazado sin alterar datos ya almacenados.

#### Scenario: Documento malformado

- **WHEN** un cliente envía un documento cuyo contenido no corresponde al
  esquema declarado
- **THEN** el sistema lo rechaza con un error descriptivo y no modifica nada

#### Scenario: Identificador con caracteres no permitidos

- **WHEN** un documento entrante trae un identificador que no cumple el formato
  admitido
- **THEN** el sistema rechaza la operación

### Requirement: Preservación del estado de combate

El estado mutable de partida SHALL persistirse junto al personaje al que
pertenece. Una operación que modifique equipo, conjuros o nivel MUST NOT
descartar el estado de combate vigente salvo que la operación lo reemplace de
forma explícita.

#### Scenario: Edición de equipo durante una partida

- **WHEN** una cuenta modifica el equipo de un personaje que tiene daño
  acumulado y recursos consumidos
- **THEN** al releer el personaje el daño y los recursos consumidos siguen
  siendo los mismos
