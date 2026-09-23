# Changelog

Cambios visibles del producto, agrupados por versión. El formato y el flujo de
actualización están definidos en [Versionado y changelog](docs/desarrollo/versionado-y-changelog.md).

## [0.11.0+1] - 2026-09-22

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
- La subida de nivel y el editor de conjuros conservan las elecciones de cada
  clase al revisar o modificar una fuente distinta.
- Los personajes de esquema 23 se leen mediante migración automática a esquema
  24; los respaldos y la API conservan el mismo contrato JSON.

### Eliminado

- El supuesto de que una ficha solo puede tener una clase en los cálculos de
  nivel, rasgos, recursos, conjuros y dados de golpe.

## [Unreleased]

### Nuevo

- PNJ en el Modo DM: una biblioteca propia del DM con PNJ sin estadísticas,
  con bloque copiado de una criatura o con ficha de personaje completa, con
  «cómo habla», apariencia, trasfondo, notas fechadas, tags y retrato.
- Cada campaña tiene su sección de PNJ con el estado de cada uno en esa mesa
  (vivo, muerto o desconocido); quitar un PNJ de una campaña no lo borra de la
  biblioteca.
- «Mostrar a la mesa» proyecta el retrato del PNJ y, si el DM quiere, su
  nombre, sin ningún otro dato.
- Exportar un PNJ a un `.zip` e importarlo en otra cuenta como copia propia,
  con su ficha, su homebrew y sus retratos; las campañas nunca viajan.
- Bandos en el combate: aliado, enemigo o neutral para PNJ y monstruos, con
  cambio de bando a mitad de combate y conteos «en pie» por bando.
- «Convertir en PNJ» desde la fila de un monstruo, conservando su lugar, sus
  PG, su bando y sus efectos.
- Al terminar y guardar un combate se puede marcar qué PNJ caídos murieron.

### Modificado

- «Sumar monstruo» pasa a ser «Sumar al combate», con solapas de PNJ y
  Bestiario; un PNJ no entra sin que el DM le elija bando.
- La tirada automática de iniciativa sigue siendo solo del bestiario: la de un
  PNJ se carga a mano.
- El Cuaderno del DM muestra aliados y neutrales en líneas propias; «cayeron N
  de M» cuenta solo enemigos.
- Las batallas que ve el jugador muestran solo a los enemigos y nombran a los
  PNJ por su criatura de base, nunca por su nombre propio.
- `Encounter` y `EncounterLog` pasan al esquema 2; los combates y registros
  anteriores se leen con los jugadores como aliados y los monstruos como
  enemigos.

### Eliminado

- Sin cambios.
