# user-accounts Specification

## Purpose

Da a cada jugador una identidad propia en el servidor autoalojado, de modo que
sus fichas, su homebrew y sus ajustes solo sean accesibles para él, y que el
navegador nunca custodie credenciales de larga duración.

## Requirements

### Requirement: Autenticación mediante proveedor OIDC autoalojado

El sistema SHALL autenticar a las personas usuarias contra un proveedor OIDC
autoalojado usando el flujo Authorization Code con PKCE. El sistema MUST NOT
aceptar ninguna otra forma de identificación para acceder a datos de una cuenta.

#### Scenario: Acceso sin sesión

- **WHEN** alguien abre la aplicación web sin una sesión válida
- **THEN** el sistema lo redirige al proveedor OIDC y no muestra ninguna ficha

#### Scenario: Autenticación exitosa

- **WHEN** la persona completa la autenticación en el proveedor OIDC
- **THEN** el sistema establece una sesión de navegador y muestra únicamente los
  personajes de esa cuenta

#### Scenario: Emisor no reconocido

- **WHEN** llega una aserción de identidad cuyo emisor o firma no corresponde al
  proveedor configurado
- **THEN** el sistema la rechaza y trata la petición como no autenticada

### Requirement: El navegador no custodia tokens

El servidor SHALL realizar el intercambio de código y conservar los tokens de
acceso y de refresco. El cliente web MUST recibir únicamente una cookie de
sesión marcada `httpOnly`, `Secure` y `SameSite`. Los tokens del proveedor OIDC
MUST NOT quedar disponibles para código JavaScript ni almacenarse en
`localStorage` o `sessionStorage`.

#### Scenario: Inspección del almacenamiento del navegador

- **WHEN** se inspecciona el almacenamiento del navegador tras iniciar sesión
- **THEN** no hay ningún token de acceso ni de refresco del proveedor OIDC

#### Scenario: Peticiones autenticadas

- **WHEN** el cliente web llama a cualquier endpoint de datos
- **THEN** la autorización viaja en la cookie de sesión y no en un encabezado
  gestionado por el cliente

### Requirement: Aislamiento de datos entre cuentas

Todo dato propiedad de una cuenta SHALL ser accesible únicamente por esa cuenta.
Una petición autenticada como una cuenta MUST NOT poder leer, modificar ni
eliminar datos de otra, aun cuando conozca el identificador exacto del recurso.

#### Scenario: Acceso cruzado por identificador conocido

- **WHEN** una cuenta solicita un personaje cuyo identificador pertenece a otra
  cuenta
- **THEN** el sistema responde como si el recurso no existiera y no revela su
  existencia

#### Scenario: Listado de personajes

- **WHEN** una cuenta lista sus personajes
- **THEN** el resultado contiene exclusivamente personajes de esa cuenta

### Requirement: Fin de sesión

El sistema SHALL permitir cerrar la sesión, invalidando la sesión de servidor.
Una sesión expirada o cerrada MUST NOT permitir acceso a datos de la cuenta.

#### Scenario: Cierre de sesión explícito

- **WHEN** la persona cierra sesión
- **THEN** la cookie de sesión deja de ser válida y una petición posterior con
  esa cookie se trata como no autenticada

#### Scenario: Sesión expirada durante el uso

- **WHEN** la sesión expira mientras la aplicación está abierta
- **THEN** el cliente web informa que la sesión terminó y ofrece volver a
  autenticarse sin perder los cambios que aún no pudo enviar
