# Auditoría de contenido SRD/EFA posterior a 0.7.0

Fecha de corte: 13 de agosto de 2026.

## Alcance y criterio

Esta auditoría cierra los puntos 1–3 del plan con un criterio híbrido: el
catálogo y los datos de creación son completos; se automatizan modificadores
pasivos y estables que el motor puede representar sin ambigüedad. Cargas,
activaciones, tablas aleatorias, conjuros contenidos y decisiones del GM quedan
descritos en el objeto. No se agregó un segundo motor de combate.

Los puntos 4–6 se registran como **pendiente opcional** y no se cuentan como
contenido completo.

## Línea base anterior a este trabajo

| Área | Situación inicial |
|---|---:|
| Objetos mundanos | 131 |
| Objetos mágicos | 0 |
| Clases | 13: 12 SRD y 1 EFA |
| Trasfondos | 33: 4 SRD, 12 PHB y 17 EFA |
| Criaturas | 107: 78 SRD, 25 PHB y 4 EFA |

## Fuentes fijadas

- Fuente normativa de objetos mágicos: `docs/Libros completos
  DnD/SP_SRD_CC_v5.2.1.pdf`, páginas impresas 223–277. Las reglas generales
  ocupan 223–227 y los bloques extraídos abarcan 228–277.
- Datos estructurados compatibles con los Markdown locales de PHB/EFA:
  repositorio `5etools-mirror-3/5etools-src`, revisión inmutable
  `e5f3e77b303a92df10487207857200245e71957c`.
- Archivos estructurados usados: `data/backgrounds.json`,
  `data/class/class-artificer.json`, `data/items.json` y
  `data/magicvariants.json`. Las opciones de clase PHB se contrastaron además
  con `docs/Libros completos DnD/Player's Handbook (2024).md`.
- La generación reproducible vive en
  `packages/dnd_engine/tool/generate_magic_items.py` y
  `packages/dnd_engine/tool/apply_structured_content.py`.

## Listas cerradas de control

- `expected_magic_item_ids.json`: 261 IDs SRD únicos, resultantes de los
  bloques normativos y la expansión de las variantes +1/+2/+3.
- `expected_class_ids.json`: 13 IDs.
- `expected_background_ids.json`: 33 IDs.

Las pruebas comprueban unicidad, presencia y resolución de cada referencia a
arma, armadura, escudo u objeto base.

## Resultado de los puntos obligatorios

### 1. Objetos mágicos SRD 5.2.1 — completo

- 261 registros SRD únicos en un activo separado, con nombre e ID estables en
  español, fuente, rareza, sintonización, precio de referencia, descripción y
  página de procedencia.
- 54 plantillas de arma, armadura o escudo resuelven su base mundana. Los bonos
  mágicos modifican solamente la entrada equipada que los posee.
- Se automatizan los bonos de ataque/daño y CA de las plantillas, el requisito
  de sintonización y los efectos pasivos inequívocos representables por el
  motor: puntuaciones establecidas, salvaciones, resistencias, inmunidades y
  visión en la oscuridad. El resto queda en la descripción normativa.
- Resultado de la matriz: **0 faltantes, 0 duplicados y 0 referencias de base
  inexistentes**.

### 2. EFA y Réplica de Objeto Mágico — completo dentro del criterio híbrido

- Se incorporaron los nueve objetos EFA: Boots of the Winding Path, Dazzling
  Weapon, Helm of Awareness, Manifold Tool, Mind Sharpener, Repeating Shot,
  Repulsion Shield, Returning Weapon y Spell-Refueling Ring.
- Los planos conocidos se guardan en `Character.magicItemChoices`; conocer un
  plano no aplica el objeto.
- La progresión de planos es 4/5/6/7/8 en niveles 2/6/10/14/18 y la de réplicas
  simultáneas es 2/3/4/5/6. Se respetan niveles mínimos, planes explícitos y
  planes abiertos por rareza/tipo de EFA.
- Las réplicas tienen identidad y procedencia propias, resuelven su base,
  pueden equiparse y sintonizarse, y no exceden el máximo simultáneo.
- Reemplazar un plano elimina únicamente sus réplicas. Transmutar está
  automatizado. Cargar y Drenar permanecen descritos: automatizarlos exigiría
  estado genérico de cargas de objeto y espacios temporales que hoy no existe.

### 3. Equipo inicial — completo

- Las 13 clases y los 33 trasfondos tienen opciones iniciales válidas.
- El modelo representa opciones A/B/C, cantidades, monedas y elecciones
  internas de objetos.
- El asistente elige por separado clase y trasfondo, conserva el borrador,
  muestra resultado y monedas, y solo deja equipar lo recibido.
- La alternativa monetaria acredita únicamente monedas. No se agregó una
  tienda.
- Se añadió el libro de conjuros que faltaba al catálogo mundano. El total
  mundano posterior es 132.
- Resultado de la matriz: **13/13 clases y 33/33 trasfondos con referencias
  resolubles**.

## Base técnica y compatibilidad

- Esquema de ficha 20: `InventoryEntry.equipped` es la fuente de verdad;
  `entryId`, `baseItemId` y `origin` distinguen ejemplares y variantes.
- La migración 19→20 conserva armadura, escudo, armas, notas, cantidades y
  sintonización, y asigna IDs estables a las entradas antiguas.
- La resolución central combina plantilla y base para ataque, daño, CA, peso,
  valor, sintonización y efectos.
- Homebrew, carga de activos y JSON de personaje aceptan los campos nuevos sin
  cambiar endpoints. La suite del servidor cubre el round-trip de personajes.

## Validación ejecutada

| Capa | Resultado |
|---|---|
| Formato Dart | limpio |
| Análisis estático `dnd_engine` | sin problemas |
| Pruebas `dnd_engine` | 1.025 aprobadas |
| Análisis estático `dnd_server` | sin problemas |
| Pruebas `dnd_server` | 163 aprobadas |
| Análisis estático `dnd_app` | sin problemas |
| Pruebas `dnd_app` | suite completa aprobada |
| Build web release | aprobado; `build/web` generado |
| Smoke manual web | aprobado con servidor API efímero local |

Las pruebas automatizadas incluyen la migración 19→20, identidades duplicadas,
sintonización, arma +1 aislada, escudo mágico, planes sin concesión automática,
reemplazo de réplicas, progresiones de Artífice, matrices 13/33 y alternativas
monetarias.

Esta validación no implica una conexión real a PostgreSQL ni un inicio de
sesión real contra OIDC. Las pruebas de servidor usan sus dobles controlados.
El smoke abrió el build release, inició el asistente, cargó una ficha de
Artífice de nivel 2, eligió cuatro planos, restringió Returning Weapon a las
siete armas arrojadizas, creó una réplica sobre una daga, la equipó, recargó la
página y confirmó por API local la persistencia de planos, base, procedencia y
estado equipado. El servidor efímero se eliminó al finalizar.

Los paquetes A/B/C, alternativas monetarias, elecciones de herramienta, la
matriz completa de clases/trasfondos y las familias arma/armadura/escudo/objeto
mágico quedan cubiertos por pruebas automatizadas; no se repitieron manualmente
las 46 combinaciones en navegador.

## Pendientes opcionales auditados

### 4. Capacidades adicionales de Artífice — pendiente opcional

- Elixir Experimental.
- Armadura Arcana.
- Atlas del Aventurero.

### 5. Bestiario completo — resuelto

El catálogo pasó de 117 a **367 criaturas**: entraron los 250 perfiles del
capítulo «Monstruos» y del apéndice «Animales» del SRD 5.2.1 que faltaban, y
con ellos el rango completo de valor de desafío (antes el techo era VD 2, hoy
llega a 30).

Las capacidades que antes no se representaban ya están modeladas: salvaciones,
competencias en habilidades, acciones adicionales, acciones legendarias con su
presupuesto por ronda, bonificador de iniciativa impreso, y tipo y tamaño
consultables aparte de la línea de perfil.

Lo genera `packages/dnd_engine/tool/generate_bestiary.dart` desde el PDF en
español; los ids ingleses salen del mapa commiteado en
`tool/data/bestiario_ids.json`. Correrlo con `--check` avisa si
`creatures.json` dejó de ser reproducible desde el PDF.

Quedan afuera a propósito los conjuros de monstruo (`spellcasting`), que se
muestran como texto del rasgo y no como lista estructurada.

### 6. Sistemas de campaña — pendiente opcional

Faltan bastiones y aeronaves, tanto catálogo como reglas y flujos de uso.
