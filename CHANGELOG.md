# Changelog

Cambios visibles del producto, agrupados por versión. El formato y el flujo de
actualización están definidos en [Versionado y changelog](docs/desarrollo/versionado-y-changelog.md).

## [Unreleased]

### Nuevo

- Multiclase de personajes: historia ordenada de clases, subclases por clase,
  competencias parciales, fórmulas alternativas de CA y bloques de magia por
  fuente.
- Subida de nivel con elección de clase secundaria, advertencias de requisitos
  y persistencia de elecciones por clase.

### Modificado

- El motor combina espacios normales según el nivel de lanzador y separa los
  espacios de Magia de Pacto.
- Dashboard, ficha, Modo DM, ficha de miembro y retratos muestran la
  combinación de clases y niveles.
- Los personajes de esquema 23 se leen mediante migración automática a esquema
  24; los respaldos y la API conservan el mismo contrato JSON.

### Eliminado

- El supuesto de que una ficha solo puede tener una clase en los cálculos de
  nivel, rasgos, recursos, conjuros y dados de golpe.
