# Versionado y changelog

## Objetivo

Cada versión publicada debe poder entenderse sin recorrer todos los commits.
Para eso, el proyecto mantiene un único registro en [CHANGELOG.md](../../CHANGELOG.md),
con el mismo formato en todas las versiones.

## Fuente de la versión

La versión visible del cliente web se define en:

```text
packages/dnd_app/pubspec.yaml → version
```

El formato es `major.minor.patch+build`, por ejemplo `0.10.0+1`. El número
completo se conserva en el encabezado del changelog, incluido `+build`.

`dnd_engine` y `dnd_server` tienen versiones propias porque son paquetes del
monorepo. Si se modifica alguna de ellas, el mismo release debe mencionarlo en
la entrada correspondiente, indicando el componente afectado. No se crea otro
changelog por paquete.

## Cuándo se actualiza

Una modificación de `version` en cualquier `pubspec.yaml` exige actualizar
`CHANGELOG.md` en el mismo cambio. El changelog no se completa después del
release: la entrada debe estar lista antes del commit que cambia la versión.

Los cambios que todavía no tienen versión se escriben en `[Unreleased]`. Al
preparar una versión:

1. Revisar los cambios desde la última versión y agruparlos por impacto para la
   persona que usa el producto.
2. Completar la sección `[Unreleased]` sin copiar mensajes de commit de forma
   mecánica.
3. Cambiar `[Unreleased]` por la versión exacta y la fecha ISO (`YYYY-MM-DD`).
4. Crear debajo una nueva sección `[Unreleased]` vacía, con las tres categorías.
5. Cambiar la versión en el `pubspec.yaml` correspondiente.
6. Ejecutar las validaciones afectadas y revisar que el changelog esté incluido
   en el mismo commit.

No se inventa historial para versiones anteriores que no tengan una fuente
confiable. En ese caso, se empieza desde la próxima versión.

## Categorías obligatorias

Las tres categorías aparecen siempre y en este orden:

### Nuevo

Capacidades, pantallas, endpoints o flujos que antes no existían para la
persona usuaria.

### Modificado

Cambios de comportamiento, interfaz, reglas, rendimiento o correcciones que
alteran algo existente. Las correcciones de errores van acá si no agregan una
capacidad nueva.

### Eliminado

Funciones, pantallas, endpoints o comportamientos retirados. Si algo fue
reemplazado, se explica brevemente por qué o por qué alternativa.

Si una categoría no tiene entradas, conserva el texto `- Sin cambios.`. No se
eliminan categorías para que todas las versiones puedan compararse con el mismo
formato.

## Cómo redactar una entrada

Cada viñeta debe explicar el resultado observable y, cuando ayude, el área
afectada. Preferir:

```markdown
- La ficha oculta el encabezado de datos en Inventario, Campaña y Diario para
  dejar más espacio al contenido.
```

Evitar:

```markdown
- Refactor de `_SheetNavigation`.
```

La implementación interna solo se menciona si cambia una decisión importante
para quien mantiene el proyecto, no como sustituto de la explicación del
resultado.

## Plantilla

```markdown
## [X.Y.Z+N] - YYYY-MM-DD

### Nuevo

- Describir la capacidad nueva y su efecto.

### Modificado

- Describir el cambio visible o la corrección.

### Eliminado

- Describir lo retirado y su reemplazo, si corresponde.

## [Unreleased]

### Nuevo

- Sin cambios.

### Modificado

- Sin cambios.

### Eliminado

- Sin cambios.
```

## Regla de revisión

Antes de commitear una versión, comprobar que:

- la versión del `pubspec.yaml` y el encabezado publicado coinciden;
- las tres categorías existen y están en el orden establecido;
- las entradas describen cambios para la persona usuaria;
- no se mezclaron cambios de otra versión;
- las pruebas, el análisis y el build requeridos por el área modificada fueron
  ejecutados o la limitación quedó declarada.
