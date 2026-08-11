# Instrucciones de corrección del catálogo D&D 5e 2024

## Propósito del documento

Este documento es una especificación de implementación para corregir los
hallazgos de la auditoría exhaustiva del catálogo. La IA que lo ejecute debe
realizar **todos y solo** los cambios enumerados aquí, mantener la compatibilidad
de los personajes existentes y verificar el resultado en la aplicación WEB.

No se debe interpretar `docs/Auditorias/auditoria-reglas-2024.md` como una lista
adicional de tareas: ese archivo contiene un historial acumulado y varias de sus
afirmaciones describen estados anteriores del proyecto. Para esta intervención,
la lista normativa es este documento.

## 1. Reglas absolutas

### 1.1. Fuentes válidas y precedencia

Usar exclusivamente estas fuentes:

1. **Player's Handbook 2024** (`XPHB` en 5e.tools) para las reglas y opciones
   del Manual del Jugador.
2. **SRD 5.2.1 oficial en español** para mecánicas y procedencia licenciada:
   `docs/Libros completos DnD/SP_SRD_CC_v5.2.1.pdf`.
3. **Eberron: Forge of the Artificer** (`EFA` en 5e.tools) para la versión
   actual de las mecánicas de Eberron.
4. [5e.tools](https://5e.tools/index.html), filtrando por `XPHB` y `EFA`, como
   referencia operativa determinista para inventarios y entradas vigentes.

La procedencia histórica de *Eberron: Rising from the Last War* puede servir
para identificar conceptos o nombres, pero **sus mecánicas de 2014 no se deben
copiar**. Si *Forge of the Artificer* actualiza, sustituye u omite una mecánica
de RftLW, prevalece EFA. No incorporar contenido que solo exista con reglas de
2014.

No usar PHB 2014, SRD 5.1, wikias, blogs, videos, resúmenes de terceros ni una
entrada de 5e.tools que no tenga el filtro de fuente correcto. Ante una
diferencia entre fuentes válidas:

- la regla 2024 vigente determina la mecánica;
- el SRD 5.2.1 determina si corresponde `srd_2024`;
- `XPHB` no incluido en SRD se etiqueta `phb_2024`;
- EFA se etiqueta con el valor interno ya existente `foa_2025`.

No renombrar `foa_2025` a `efa`, porque ese identificador ya forma parte del
modelo y de los datos persistidos. Sí actualizar el texto visible del manifiesto
para mencionar Forge of the Artificer.

### 1.2. Alcance técnico: el producto es full WEB

El proyecto es exclusivamente WEB. Toda mecánica que implique una elección,
un recurso, una competencia, un conjuro concedido o un dato derivado debe
funcionar de extremo a extremo:

| Capa | Responsabilidad mínima |
| --- | --- |
| Catálogo | JSON válido y dato canónico con la procedencia correcta. |
| Dominio | Parsear y serializar cualquier campo nuevo sin perder datos. |
| Personaje | Persistir las elecciones o usos que deban sobrevivir recargas. |
| Compilador | Reflejar el efecto en `ComputedSheet`, validación y cálculos. |
| Servidor | Conservar el dato en API, base de datos, importación y respaldo. |
| Flutter Web | Permitir elegir, revisar y consultar el resultado. |
| Pruebas | Cubrir JSON, round-trip, migración, compilación y experiencia WEB. |

Una descripción textual es suficiente solo cuando la regla no altera estado ni
ningún valor que Milantus ya pueda representar. **No es suficiente** para una
elección, una competencia, una lista de conjuros, un uso por descanso, una
exclusión entre opciones o una característica que aparezca en la ficha.

No agregar soporte para escritorio o móvil. No introducir dependencias nuevas,
generadores, capas de abstracción ni sistemas paralelos. Reutilizar primero
`FeatureChoiceEffect`, `ProficiencyChoiceEffect`, `GrantSpellEffect`,
`AlwaysPreparedSpellEffect`, `ResourceEffect`, `CompanionEffect`,
`FeatPrerequisite`, `exclusiveGroup` y los demás mecanismos existentes. Si un
mecanismo no alcanza, ampliarlo con el campo opcional mínimo y hacerlo compatible
con los JSON anteriores.

### 1.3. Compatibilidad y límites

- No cambiar identificadores existentes de clases, subclases, dotes, conjuros,
  armas, especies o rasgos.
- Si una elección nueva debe persistirse, agregar un campo opcional con un valor
  por defecto seguro. Incrementar `Character.currentSchemaVersion` una sola vez
  para el conjunto de campos nuevos y agregar la migración correspondiente.
- Un personaje viejo debe abrir, compilar, guardarse, exportarse e importarse
  sin perder ninguna selección previa.
- Las fichas creadas por una versión futura deben continuar rechazándose sin
  modificación.
- No debilitar validaciones ni borrar aserciones para hacer pasar pruebas.
- Preservar todos los cambios ajenos que ya existan en el árbol de trabajo.
- No modificar contenido que este documento declara verificado.
- No hacer commit, push, rebase, pull, stash ni publicación salvo autorización
  explícita posterior.

## 2. Línea base que debe conservarse

Antes de editar, ejecutar las pruebas actuales y registrar cualquier falla
preexistente. El catálogo auditado contiene:

| Bloque | Cantidad actual válida |
| --- | ---: |
| Clases | 13 |
| Subclases | 53: 48 XPHB y 5 EFA |
| Especies | 15: 10 XPHB/SRD y 5 EFA |
| Linajes | 28 |
| Trasfondos | 33: 16 XPHB/SRD y 17 EFA |
| Filas de dotes | 187 antes de agregar las dos opciones de clase faltantes |
| Armas | 38 |
| Armaduras | 13 |
| Conjuros | 392 |
| Criaturas | 101 antes de las seis altas requeridas |

Al terminar, las cantidades anteriores deben permanecer iguales salvo **dotes,
que deben pasar de 187 a 189**, y **criaturas, que deben pasar de 101 a 107**.
Una variación distinta indica una alta, baja o duplicación accidental.

Ya están verificados y no deben reescribirse sin que otra tarea de este
documento lo exija:

- los 33 trasfondos y sus datos mecánicos;
- las 15 especies de inventario y los cuatro linajes EFA;
- los niveles y el inventario de las 53 subclases;
- las 13 armaduras;
- los identificadores, niveles y listas de clase de los 392 conjuros;
- las 108 incorporaciones de conjuros de las Marcas Dracónicas y sus
  prerrequisitos;
- las estadísticas centrales ya auditadas de las criaturas existentes;
- `Druídico` del Druida y `Erudito` del Mago, que ya están corregidos.

## 3. Orden obligatorio de implementación

Trabajar por fases y dejar las pruebas de cada fase en verde antes de avanzar.
No mezclar una corrección declarativa con un rediseño general del motor.

1. Crear pruebas que reproduzcan el dato erróneo o la ausencia.
2. Corregir procedencia, manifiesto y datos declarativos simples.
3. Completar los mecanismos mínimos de elección, elegibilidad y persistencia.
4. Corregir especie y armas.
5. Corregir clases base.
6. Corregir subclases.
7. Corregir dotes.
8. Corregir conjuros.
9. Agregar criaturas y vincularlas a los conjuros.
10. Verificar la cadena WEB completa.
11. Actualizar README y el estado actual de la auditoría.
12. Ejecutar todas las verificaciones finales del apartado 12.

## 4. Procedencia, manifiesto y documentación

### 4.1. Conjuros

Archivo: `packages/dnd_engine/lib/assets/srd_2024/spells.json`.

El catálogo actual informa 177 `srd_2024`, 214 `phb_2024` y 1 `foa_2025`.
Hay 162 conjuros que están etiquetados `phb_2024` pero también forman parte del
SRD 5.2.1.

Acción requerida:

- cruzar por `id` los 392 conjuros contra el SRD 5.2.1;
- cambiar únicamente `source` en esos 162 registros;
- no cambiar id, nombre, nivel, escuela, clases ni mecánica en esta operación.

Resultado obligatorio: **339 `srd_2024`, 52 `phb_2024` y 1 `foa_2025`**.

### 4.2. Linajes

Archivo: `packages/dnd_engine/lib/assets/srd_2024/lineages.json`.

Dato actual: 8 `srd_2024`, 16 `phb_2024` y 4 `foa_2025`.

Cambiar a `srd_2024` los 10 linajes dracónicos y los 6 linajes gigantes del
Goliat. No cambiar sus efectos ni sus identificadores.

Resultado obligatorio: **24 `srd_2024`, 0 `phb_2024` y 4 `foa_2025`**.

### 4.3. Armas

Archivo: `packages/dnd_engine/lib/assets/srd_2024/weapons.json`.

Cambiar `source` de `phb_2024` a `srd_2024` en:

- `blowgun`;
- `musket`;
- `pistol`.

Resultado obligatorio: las **38 armas** quedan etiquetadas `srd_2024`.

### 4.4. Dotes

Archivo: `packages/dnd_engine/lib/assets/srd_2024/feats.json`.

Cambiar `source` de `phb_2024` a `srd_2024` exactamente en estos diez ids:

| Id |
| --- |
| `magic-initiate-druid` |
| `ability-score-improvement` |
| `fs-two-weapon-fighting` |
| `boon-of-combat-prowess` |
| `boon-of-truesight` |
| `boon-of-irresistible-offense` |
| `boon-of-fate` |
| `boon-of-the-night-spirit` |
| `boon-of-spell-recall` |
| `boon-of-dimensional-travel` |

No cambiar su contenido mecánico dentro de esta operación. Resultado de
procedencia obligatorio: **24 SRD, 135 PHB y 28 EFA**, manteniendo 187 filas.

### 4.5. Manifiesto y README

Archivos:

- `packages/dnd_engine/lib/assets/srd_2024/manifest.json`;
- `README.md`.

Cambios:

- conservar `id: "srd_2024"` y `formatVersion: 1`;
- cambiar el texto de `ruleset` para que enumere claramente PHB 2024, SRD 5.2.1
  y *Eberron: Forge of the Artificer*;
- en README, cambiar `24 linajes` por `28 linajes`;
- en README, cambiar `183 dotes` por `189 filas de dotes y opciones equivalentes`
  para incluir las dos opciones de clase faltantes sin confundir variantes
  mecánicas con familias canónicas;
- no cambiar las demás cantidades salvo el total de criaturas si README llega
  a exponerlo después de esta implementación.

## 5. Especies y equipo

### 5.1. Agilidad Mediana del Mediano

Archivo principal: `packages/dnd_engine/lib/assets/srd_2024/races.json`.

Dato actual: `Agilidad Mediana` permite atravesar el espacio de una criatura de
tamaño superior, pero omite la restricción final.

Corrección: añadir que el Mediano **no puede detenerse voluntariamente en el
espacio de otra criatura**. Conservar el resto del rasgo y su id.

Prueba mínima: localizar la especie por id y exigir ambas partes de la regla en
su descripción.

### 5.2. Lanza de caballería

Archivo de datos: `packages/dnd_engine/lib/assets/srd_2024/weapons.json`.

Dato actual: `lance` incluye `two-handed` como propiedad incondicional.

Regla correcta: la lanza requiere dos manos **solo si quien la usa no está
montado**. Estando montado no debe tratarse como arma a dos manos.

Implementación requerida:

1. Inspeccionar todos los consumidores de `Weapon.properties`.
2. Representar la condición con la ampliación opcional más pequeña del modelo;
   no borrar simplemente `two-handed` ni codificar la excepción solo en un
   widget.
3. Hacer que compilador, validación y presentación WEB produzcan el mismo
   resultado.
4. Mantener compatibles las armas homebrew antiguas sin el campo condicional.

Pruebas mínimas:

- personaje no montado: `lance` exige dos manos;
- personaje montado: `lance` no exige dos manos;
- las demás armas `two-handed` siguen siendo incondicionales;
- round-trip JSON del arma con y sin la nueva condición.

Si el personaje todavía no posee un estado canónico de “montado”, no crear un
sistema general de monturas. Modelar la condición en la definición y mostrarla
correctamente en la ficha; solo aplicar cálculo condicionado donde ya exista
un contexto de montaje confiable.

### 5.3. Pico de guerra

Archivo: `packages/dnd_engine/lib/assets/srd_2024/weapons.json`.

Dato actual: `war-pick` no tiene propiedades.

Corrección: agregar `versatile` a `properties` y establecer
`versatileDice: "1d10"`. Debe mostrarse y resolverse como **1d8** con una mano y
**1d10** con dos manos, usando el mecanismo existente para armas versátiles. No
cambiar daño perforante ni maestría `sap`.

## 6. Clases base

Archivo principal: `packages/dnd_engine/lib/assets/srd_2024/classes.json`.
Cuando la corrección implique estado o efectos, revisar también:

- `packages/dnd_engine/lib/src/domain/effects.dart`;
- `packages/dnd_engine/lib/src/domain/character.dart`;
- `packages/dnd_engine/lib/src/engine/character_compiler.dart`;
- `packages/dnd_engine/lib/src/engine/sheet_builder.dart`;
- creación, subida de nivel y ficha en `packages/dnd_app/lib/`.

### 6.1. Guerrero — Mente Táctica

Dato actual: indica gastar Tomar Aliento y sumar 1d10 a una prueba fallida, pero
omite el reembolso.

Corrección: si el resultado total continúa fallando después de añadir el d10,
**el uso de Tomar Aliento no se gasta**. La descripción y cualquier flujo WEB
que descuente el recurso deben respetarlo. No otorgar el reembolso si la prueba
se convierte en éxito.

### 6.2. Druida — Orden Primordial

Dato actual: falta la elección de nivel 1.

Agregar una elección persistida y obligatoria entre:

- **Magician**: un truco adicional de la lista de Druida; además, sumar el
  modificador de Sabiduría, con un mínimo de +1, a pruebas de Inteligencia
  (Arcanos) o Inteligencia (Naturaleza).
- **Warden**: competencia con armas marciales y entrenamiento con armadura
  media.

Requisitos de implementación:

- la elección debe aparecer durante creación o en el primer punto válido de
  regularización de un personaje existente;
- debe sobrevivir guardado, API, exportación, importación y recarga;
- Magician debe aumentar el cupo/selección real de trucos y el desglose de las
  dos habilidades, no quedar como texto;
- Warden debe modificar las competencias compiladas;
- la ficha debe mostrar la opción elegida y sus efectos;
- no devolver armadura media a todos los Druidas.

### 6.3. Druida — Compañero Salvaje

Dato actual: solo permite gastar Forma Salvaje y omite parte de la regla.

Corrección completa:

- se ejecuta como una acción de Magia;
- se puede gastar **un espacio de conjuro o un uso de Forma Salvaje** para
  lanzar `find-familiar`;
- no requiere componente material;
- el familiar convocado es Feérico;
- desaparece al terminar el siguiente descanso largo.

Conservar la integración existente con `CompanionEffect`. Si la ficha permite
ejecutar el rasgo, ofrecer ambas fuentes de coste y descontar exactamente la
elegida.

### 6.4. Paladín — Castigo de Paladín

Dato actual: `divine-smite` está siempre preparado, pero falta el lanzamiento
gratuito.

Corrección:

- `divine-smite` permanece siempre preparado;
- se puede lanzar **una vez sin gastar espacio de conjuro**;
- el uso gratuito se recupera tras un descanso largo;
- después de gastarlo, el conjuro sigue disponible mediante espacios normales.

Representar el uso gratuito con un recurso real y visible, no solo dentro de la
descripción.

### 6.5. Clérigo — Orden Divina

Dato actual: las dos opciones están resumidas como texto y algunas subclases
siguen otorgando competencias que pertenecen a esta elección de clase.

Agregar una elección persistida y obligatoria entre:

- **Protector**: competencia con armas marciales y entrenamiento con armadura
  pesada.
- **Thaumaturge**: un truco adicional de Clérigo y bonificación igual al
  modificador de Sabiduría, con mínimo +1, a pruebas de Inteligencia (Arcanos) e
  Inteligencia (Religión).

Aplicar los efectos al compilador y a la ficha. Quitar de las subclases Vida y
Guerra las competencias incondicionales que ahora correspondan exclusivamente
a Protector. Elegir Thaumaturge no debe conceder esas competencias.

### 6.6. Explorador — Explorador Hábil

Dato actual: ya concede Pericia en una habilidad, pero omite los idiomas.

Corrección: además de la Pericia, permitir elegir **dos idiomas**. Usar el
mecanismo de elección de idiomas existente, persistir dos ids diferentes,
validar duplicados y reflejarlos en la ficha.

### 6.7. Bárbaro — Furia

Dato actual: limita el daño adicional a ataques cuerpo a cuerpo con Fuerza.

Corrección: el bono de daño de Furia se aplica a **un ataque que use Fuerza**,
sin imponer que sea cuerpo a cuerpo. Mantener los valores de progresión ya
existentes. Actualizar cualquier condición del compilador que todavía compruebe
`melee` en vez de la característica usada por el ataque.

## 7. Subclases

Archivo principal: `packages/dnd_engine/lib/assets/srd_2024/subclasses.json`.

Conservar las 53 entradas, sus ids, niveles y procedencias. En cada punto,
reemplazar la mecánica antigua o inventada; no anexar la regla nueva dejando la
anterior activa. Confirmar la redacción final contra `XPHB` o `EFA` antes de
escribir el texto español, especialmente cuando se indican dados, distancias,
duraciones o recargas.

### 7.1. Guerrero

| Subclase / rasgo | Dato actual que debe desaparecer | Resultado requerido |
| --- | --- | --- |
| Battle Master — Know Your Enemy | Comparación de puntuación de Fuerza. | Revela inmunidades, resistencias y vulnerabilidades del objetivo. Un uso por descanso largo; se puede recuperar gastando un dado de superioridad. |
| Eldritch Knight — War Magic | Ataque como acción adicional después de un truco. | Dentro de la acción Atacar, sustituir uno de los ataques por un truco de Mago con tiempo de lanzamiento de acción. |
| Eldritch Knight — Improved War Magic | Versión de acción adicional o reemplazo incorrecto. | Dentro de la acción Atacar, sustituir dos ataques por un conjuro de Mago de nivel 1 o 2 con tiempo de lanzamiento de acción. |
| Psi Warrior — Telekinetic Adept | Rasgo incompleto. | Incluir Psi-Powered Leap y Telekinetic Thrust como las dos partes del rasgo. |
| Psi Warrior — Guarded Mind | Versión que no reúne ambas defensas. | Resistencia a daño psíquico; al comienzo del turno puede gastar un dado de Energía Psiónica para terminar Charmed o Frightened sobre sí mismo. |
| Psi Warrior — Telekinetic Master | `Bigby's Hand` u otra regla anterior. | `Telekinesis` siempre preparado; un lanzamiento gratuito y sin componentes por descanso largo; mientras mantiene la concentración puede hacer un ataque con arma como acción adicional. |

### 7.2. Bárbaro

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Berserker — Frenzy | Tras usar Reckless Attack, el primer impacto del turno con un ataque basado en Fuerza inflige dados d6 adicionales iguales al bono de daño de Furia. Eliminar cualquier ataque adicional como acción adicional. |
| Berserker — Intimidating Presence | Acción adicional; emanación de 30 pies que afecta a todas las criaturas elegidas. Un uso por descanso largo, recuperable gastando un uso de Furia. |
| Wild Heart — Aspect of the Wilds | La opción de percepción correcta es **Owl** y concede visión en la oscuridad. Eliminar la opción Hawk de “ver a gran distancia” si está ocupando ese lugar. |
| Wild Heart — Nature Speaker | Concede `commune-with-nature` como ritual conforme a XPHB. |
| World Tree — Vitality of the Tree | Al entrar en Furia, el Bárbaro recibe PG temporales; al comienzo de cada uno de sus turnos puede conceder PG temporales a un aliado. Quitar cualquier inmunidad inventada al terreno difícil. |

### 7.3. Bardo

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Dance — Dazzling Footwork | Completar todas sus partes, incluida Dance Virtuoso, con los efectos XPHB. |
| Dance — Inspiring Movement | Se dispara cuando un enemigo termina su turno a 5 pies del Bardo. Gasta una Inspiración Bárdica; el Bardo y un aliado se mueven hasta la mitad de su velocidad según la regla. |
| Dance — Tandem Footwork | Agregar el rasgo de iniciativa que falta y su uso de Inspiración según XPHB. |
| Glamour — Beguiling Magic | `charm-person` y `mirror-image` siempre preparados. Después de lanzar con espacio un conjuro de Encantamiento o Ilusionismo, una criatura visible a 60 pies hace la salvación correspondiente o queda Charmed o Frightened. Un uso por descanso largo, recuperable gastando Inspiración Bárdica. |
| Valor — Extra Attack | Uno de los ataques de la acción Atacar puede sustituirse por un truco con tiempo de lanzamiento de acción. |

### 7.4. Clérigo

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Life | Quitar la armadura pesada incondicional de la subclase; proviene de Orden Divina: Protector. |
| War | Quitar armas marciales y armadura pesada incondicionales de la subclase. |
| War — Avatar of Battle | Resistencia a todo daño contundente, perforante y cortante; no limitarla a armas no mágicas. |
| Light — Corona of Light | Los enemigos dentro de la Luz Brillante tienen desventaja en las salvaciones contra Radiance of the Dawn y contra conjuros del Clérigo que inflijan fuego o radiante. |
| Trickery — Improved Duplicity | Si el Clérigo y un aliado están a 5 pies de la ilusión, ambos comparten la ventaja que corresponda; cuando termina la ilusión, cura según XPHB. Eliminar la versión de múltiples duplicados. |

### 7.5. Druida

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Land — Nature's Sanctuary | Área espectral cúbica de 15 pies situada a hasta 120 pies. Concede cobertura y la resistencia definida por Nature's Ward; se mueve hasta 60 pies como acción adicional. |
| Moon — Circle Forms | CR máximo igual a nivel de Druida dividido por 3; CA 13 + Sabiduría si supera la CA de la forma; PG temporales iguales a 3 por nivel de Druida. |
| Moon — Improved Circle Forms | Elegir daño normal o radiante para los ataques de la forma y sumar Sabiduría a salvaciones de Constitución. Quitar “los ataques se vuelven mágicos” y cualquier curación de la versión anterior. |
| Moon — Lunar Form | Una vez por turno, +2d10 radiante; Moonlight Step puede teletransportar también a un aliado conforme a XPHB. |
| Sea — Aquatic Affinity | La emanación aumenta a 10 pies y concede velocidad de nado. |
| Sea — Stormborn | Velocidad de vuelo y resistencia a frío, relámpago y trueno. |
| Sea — Oceanic Gift | Permite mover o compartir la emanación según XPHB. Eliminar absorción, respiración acuática o resistencia al frío anticipada de versiones anteriores. |
| Stars — Full of Stars | Resistencia únicamente a contundente, perforante y cortante. No otorgar `hover` aquí; corresponde a la forma Dragon/Twinkling. |

### 7.6. Monje

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Open Hand — Fleet Step | Puede usar Step of the Wind después de realizar otra acción adicional, conforme a XPHB. |
| Open Hand — Quivering Palm | Cuesta 4 puntos de Concentración; salvación que produce 10d12 de daño de fuerza o la mitad. Eliminar la versión letal de daño necrótico. |
| Shadow — Improved Shadow Step | Puede gastar 1 punto de Concentración para ignorar el requisito de luz tenue/oscuridad en origen y destino, y luego realizar un ataque sin armas. No aturde. |

### 7.7. Paladín

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Devotion — Smite of Protection | Se dispara al lanzar `divine-smite`; el aura concede Cover hasta el inicio del siguiente turno según XPHB. |
| Devotion — Holy Nimbus | Activación como acción adicional, duración de 10 minutos y todos los efectos/dados de XPHB. Sustituir por completo cualquier versión 2014. |
| Ancients — Aura of Warding | Resistencia a daño necrótico, psíquico y radiante. |
| Vengeance — Soul of Vengeance | Reacción para hacer un ataque cuerpo a cuerpo cuando el objetivo de Vow of Enmity acierta **o falla** cualquier ataque. |

### 7.8. Explorador

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Hunter — Hunter's Lore | Agregar el rasgo faltante con la información que revela sobre la presa marcada. |
| Hunter — Hunter's Prey | Mantener las opciones XPHB y permitir cambiar la elección tras descanso corto o largo. |
| Hunter — Defensive Tactics | Conservar solo Escape the Horde y Multiattack Defense, con sus reglas XPHB. |
| Hunter — Superior Hunter's Prey | Propagar el daño de `hunter's-mark` según XPHB; la opción defensiva concede resistencia mediante reacción. |
| Beast Master — Exceptional Training | La orden como acción adicional también permite que la bestia use Dash, Disengage, Dodge o Help con su acción adicional. El daño de sus ataques puede ser de fuerza o el tipo normal. |
| Fey Wanderer — Beguiling Twist | El disparador puede afectar al Explorador o a una criatura visible a hasta 120 pies. |
| Gloom Stalker — Dread Ambusher | Bonificación de velocidad, Sabiduría a iniciativa y +2d6 psíquico una vez por turno; usos iguales a modificador de Sabiduría por descanso largo. Eliminar el ataque adicional de la versión antigua. |
| Gloom Stalker — Shadowy Dodge | Impone desventaja al ataque y permite teletransportarse 30 pies después, tanto si el ataque acierta como si falla. |

### 7.9. Pícaro

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Thief — Second-Story Work | Velocidad de trepar y saltos calculados con Destreza según XPHB. |
| Thief — Supreme Sneak | Agregar la opción de Cunning Strike que permite esconderse según XPHB. |
| Thief — Use Magic Device | Cuatro sintonizaciones; al gastar una carga, tirar d6 y con 6 no gastarla; reglas XPHB para pergaminos. |
| Assassin — Assassinate | Ventaja en iniciativa; durante la primera ronda, ventaja contra quien todavía no actuó; daño de arma adicional igual al nivel de Pícaro según XPHB. |
| Assassin — Infiltration Expertise | Sustituir la regla antigua por Masterful Mimicry y Roving Aim. |
| Assassin — Death Strike | Sobre el Sneak Attack de la primera ronda, salvación de Constitución para duplicar el daño. |
| Arcane Trickster — Versatile Trickster | Aplicar la opción Trip de Cunning Strike a una segunda criatura a 5 pies de Mage Hand. |
| Arcane Trickster — Magical Ambush | La condición es que el Pícaro esté Invisible, no una regla antigua de estar escondido. |

`Thief's Reflexes` ya coincide y no debe tocarse.

### 7.10. Hechicero

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Draconic — Draconic Resilience | CA base 10 + Destreza + Carisma. |
| Draconic — nivel 3 | Quitar Draconic Affinity si está como rasgo independiente; no pertenece a la versión XPHB auditada. |
| Draconic — Elemental Affinity | Resistencia permanente al tipo elegido y Carisma a una tirada de daño aplicable según XPHB. |
| Draconic — Dragon Wings | Velocidad de vuelo de 60 pies durante 1 hora; un uso por descanso largo, recuperable gastando 3 puntos de hechicería. |
| Draconic — Dragon Companion | `summon-dragon` sin componente material; un lanzamiento gratuito por descanso largo; opción de no requerir concentración y durar 1 minuto. Eliminar Presencia Dracónica. |
| Aberrant — Telepathic Speech | Alcance igual a modificador de Carisma en millas, mínimo 1; duración igual al nivel de Hechicero en minutos; aplicar el requisito de idioma XPHB. |
| Clockwork — Trance of Order | Los ataques contra el Hechicero no pueden tener ventaja; un resultado d20 de 9 o menos en sus pruebas, ataques o salvaciones cuenta como 10. No describirlo como “sin desventaja”. |

### 7.11. Brujo

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Fiend — Dark One's Own Luck | Usos iguales al modificador de Carisma, mínimo 1, por descanso largo. |
| Archfey — Steps of the Fey | Modelar los usos de `misty-step` y cada efecto adicional exactamente como XPHB. No conservar efectos de la subclase 2014. |
| Archfey — Beguiling Defenses | Inmunidad a Charmed; reacción para reducir a la mitad el daño recibido y reflejar daño psíquico según XPHB. |
| Archfey — Bewitching Magic | Después de lanzar como acción y con espacio un conjuro de Encantamiento o Ilusionismo, lanzar `misty-step` sin gastar espacio. |
| Great Old One — Clairvoyant Combatant | Aplicar el efecto XPHB y quitar cualquier aturdimiento. |
| Great Old One — Eldritch Hex | Agregar `hex` siempre preparado y la desventaja en salvaciones de la característica elegida. |
| Great Old One — Thought Shield | Impedir la lectura de pensamientos, resistencia psíquica y reflejo de daño psíquico según XPHB. |
| Great Old One — Create Thrall | Modificar `summon-aberration` según XPHB. Eliminar el encantamiento permanente de una criatura humanoide. |

### 7.12. Mago

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Abjurer, Diviner, Illusionist — Savant | Agregar los tres rasgos Savant faltantes con la misma estructura que las otras escuelas, pero aplicados a su escuela. |
| Evoker — Potent Cantrip | Los trucos que requieren ataque hacen la mitad del daño al fallar y los que permiten salvación hacen la mitad al superarla, conforme a XPHB. No sumar el modificador de característica. |
| Diviner — The Third Eye | Acción adicional; opciones XPHB, incluidas visión en la oscuridad de 120 pies, leer idiomas y `see-invisibility` gratuito. Quitar visión etérea. |
| Illusionist — Improved Illusions | Reemplazar la versión antigua por la entrada XPHB completa. |
| Illusionist — Phantasmal Creatures | Reemplazar la versión antigua por la entrada XPHB completa y sus límites reales. |

### 7.13. Artífice EFA

| Subclase / rasgo | Resultado requerido |
| --- | --- |
| Cartographer — Adventurer's Atlas | Agregar +1d4 a iniciativa además de los efectos ya correctos. |
| Battle Smith — Arcane Jolt | El límite de usos compartido se aplica tanto a la opción destructiva como a la restaurativa. No dejar el daño ilimitado. |

Conservar sin rediseño las demás mecánicas EFA que ya coinciden con la fuente.

## 8. Dotes

Archivo principal: `packages/dnd_engine/lib/assets/srd_2024/feats.json`.

### 8.1. Estilos de combate faltantes

Agregar dos opciones especiales de nivel 2 como filas de categoría
`fighting-style`, porque ese es el mecanismo que ya consume
`FeatureChoiceEffect`:

- id `fs-blessed-warrior`, nombre **Blessed Warrior**, `source: srd_2024`,
  elegible únicamente por Paladín: aprender dos trucos de
  Clérigo, usando Carisma; al subir un nivel de Paladín puede sustituir uno por
  otro truco de Clérigo.
- id `fs-druidic-warrior`, nombre **Druidic Warrior**, `source: srd_2024`,
  elegible únicamente por Explorador: aprender dos trucos
  de Druida, usando Sabiduría; al subir un nivel de Explorador puede sustituir
  uno por otro truco de Druida.

No exponer estas opciones al Guerrero. Agregar a `FeatPrerequisite` un campo
opcional y singular `requiredClassId`, incluirlo en `isEmpty`, `toJson`,
`fromJson` y `CharacterValidator`, y asignar `paladin` o `ranger` a cada fila.
No hace falta migración de personaje porque el nuevo campo pertenece al
contenido, no al JSON de la ficha. La restricción debe aplicarse tanto en
validación como en los selectores WEB; ocultar la opción sin validarla no
alcanza.

Resultado obligatorio: el catálogo pasa de 187 a **189 filas**. La distribución
final, después de las correcciones de procedencia del apartado 4.4, es **26
SRD, 135 PHB y 28 EFA**. Estas dos entradas son alternativas de clase “en lugar
de una dote de Estilo de Combate”; documentarlas como opciones equivalentes y
no como integrantes de la lista general de dotes.

### 8.2. Correcciones de reglas

| Dote | Sustitución obligatoria |
| --- | --- |
| Healer | Battle Medic permite que el objetivo gaste un Dado de Golpe y recupera la tirada + bonificador por competencia. Healing Rerolls permite volver a tirar los 1 obtenidos al curar con un conjuro o con Battle Medic. |
| Observant | Elegir competencia o Pericia en Insight, Investigation o Perception; además permite Search como acción adicional. Persistir habilidad y grado elegidos. |
| Heavy Armor Master | Reducir en el bonificador por competencia todo daño contundente, perforante o cortante procedente de un ataque. Quitar “no mágico”. |
| Ritual Caster | Elegir una cantidad de conjuros rituales de nivel 1 igual al bonificador por competencia; quedan siempre preparados. Al aumentar el bonificador, agregar uno. Quick Ritual una vez por descanso largo. |
| Shield Master | Tras impactar con ataque cuerpo a cuerpo durante la acción Atacar, Shield Bash una vez por turno: salvación de Fuerza CD 8 + Fuerza + competencia, empujar 5 pies o derribar. Reacción: en una salvación de Destreza que daría mitad, no recibir daño al superarla. |
| Speedy | +10 pies de velocidad; después de Dash se ignora terreno difícil durante ese turno; los ataques de oportunidad contra el personaje tienen desventaja. |
| Spell Sniper | Ignora cobertura media y tres cuartos, no tiene desventaja por hacer ataque de conjuro a 5 pies y suma 60 pies al alcance de los conjuros aplicables. No duplica el alcance. |
| Great Weapon Master | Heavy Weapon Mastery agrega competencia al daño solo con arma Heavy y como parte de la acción Atacar. Hew se dispara con cualquier arma cuerpo a cuerpo al hacer crítico o reducir a 0, y concede el ataque con la misma arma como acción adicional. |
| Crossbow Expert | Ignora Loading de las ballestas nombradas por XPHB; permite cargarlas sin mano libre; no tiene desventaja a 5 pies; el ataque adicional de la propiedad Light añade el modificador. |
| Magic Initiate | Al obtener un nuevo nivel se puede reemplazar uno de los conjuros elegidos por otro de la misma lista. Puede elegirse repetidamente solo con listas distintas. Persistir lista, característica y conjuros. |
| Charger | Improved Dash añade 10 pies a la velocidad de Dash. Tras moverse al menos 10 pies en línea recta y acertar un ataque cuerpo a cuerpo, una vez por turno elegir +1d8 de daño o empujar 10 pies. |
| Chef | Competencia con Cook's Utensils. La comida beneficia a 4 + competencia criaturas y añade 1d8 a su curación con Dados de Golpe. Crear una cantidad de treats igual a competencia; duran 8 horas, se consumen como acción adicional y conceden PG temporales iguales a competencia. |
| Poisoner | Competencia con Poisoner's Kit; ignora resistencia al veneno. Crear en 1 hora, gastando 50 po, dosis iguales a competencia. Aplicar como acción adicional. CD 8 + competencia + modificador de la característica aumentada; 2d8 de veneno y Poisoned hasta el final del siguiente turno. |

Usar los nombres españoles ya adoptados por el proyecto, pero resolver cada
entrada por `id`; no crear un duplicado por diferencia de traducción.

### 8.3. Exclusión de Marcas Dracónicas

Un personaje solo puede poseer **una categoría base de Marca Dracónica**, y
`Aberrant Dragonmark` cuenta dentro de esa exclusión. Las versiones mayores y
Potent Dragonmark siguen dependiendo de su marca base y no son una segunda
marca base.

Reutilizar `exclusiveGroup` o añadir la mínima regla de categoría necesaria.
Validar:

- dos marcas base distintas: rechazo;
- una marca base + Aberrant: rechazo;
- marca base + su Greater Dragonmark válida: aceptación;
- cualquier marca + Potent Dragonmark con el prerrequisito correcto: aceptación;
- ningún cambio en las 108 ampliaciones de listas de conjuros.

### 8.4. Promesas mecánicas que deben dejar de ser solo texto

Comprobar y completar el comportamiento real de:

- `Magic Initiate`;
- `Aberrant Dragonmark`;
- conjuros intrínsecos de las Marcas Dracónicas;
- `Potent Dragonmark`;
- `Boon of Skill`.

Para cada uno, la elección debe estar disponible en creación/subida de nivel,
persistirse, compilarse y aparecer en la ficha. Los conjuros concedidos deben
tener la característica, usos, preparación y posibilidad de reemplazo que
indique la fuente; no tratarlos todos como si fueran el mismo tipo de conjuro.

## 9. Conjuros

Archivo: `packages/dnd_engine/lib/assets/srd_2024/spells.json`.

No cambiar ids, nombres, niveles ni listas de clase. Aplicar exactamente las
correcciones siguientes y agregar pruebas por id.

### 9.1. Componentes

| Id | Componentes correctos |
| --- | --- |
| `true-strike` | `S, M` |
| `dancing-lights` | `V, S, M` |
| `message` | `S, M` |
| `shield-of-faith` | `V, S, M` |
| `phantasmal-killer` | `V, S` |
| `banishment` | `V, S, M` |
| `power-word-heal` | `V, S` |
| `storm-of-vengeance` | `V, S` |

Conservar el detalle del material cuando el esquema lo represente; la tabla
solo fija qué letras deben estar presentes.

### 9.2. Tiempo, alcance y duración

| Id | Campo correcto |
| --- | --- |
| `lesser-restoration` | Tiempo: acción adicional. |
| `produce-flame` | Tiempo: acción adicional; alcance: Self; el ataque puede lanzarse a 60 pies. |
| `banishment` | Alcance: 30 pies. |
| `inflict-wounds` | Alcance: Touch. |
| `shillelagh` | Alcance: Self. |
| `dream` | Alcance: Self. |
| `goodberry` | Duración: 24 horas. |
| `command` | Duración: Instantaneous. |
| `mind-sliver` | Duración: Instantaneous. |
| `blink` | Duración: 1 minuto. |
| `false-life` | Duración: Instantaneous; quitar una duración artificial de 1 hora para los PG temporales. |
| `nystuls-magic-aura` | Duración normal: 24 horas; pasa a “hasta ser disipado” solo después de lanzarlo diariamente 30 días sobre el mismo objetivo. |
| `mordenkainens-faithful-hound` | Duración: 8 horas. |
| `commune-with-nature` | Tiempo de lanzamiento: 1 minuto; bajo tierra el alcance de información es 300 pies. |
| `transport-via-plants` | Duración: 10 minutos. |
| `astral-projection` | Duración: hasta ser disipado. |

Antes de editar ids largos como los de Nystul o Mordenkainen, localizar la
entrada real en el JSON; no crear un id alternativo si el proyecto usa otra
normalización ortográfica.

### 9.3. Daño y mecánicas

| Id | Regla correcta |
| --- | --- |
| `flame-strike` | 5d6 fuego + 5d6 radiante. |
| `mass-cure-wounds` | 5d8 + modificador de la característica de lanzamiento. |
| `circle-of-death` | 8d8. |
| `weird` | 10d10 inicial; 5d10 en las repeticiones. |
| `cordon-of-arrows` | 2d4; cada disparador consume una sola pieza de munición según XPHB. |
| `conjure-celestial` | Healing Light: 4d12 + característica de lanzamiento. Searing Radiance: 6d12. |
| `blade-barrier` | Tipo de daño: fuerza. |
| `mordenkainens-faithful-hound` | 4d8 de fuerza. |
| `phantasmal-killer` | 4d10 inicial y mitad con salvación exitosa; con fallo, desventaja en pruebas de característica y ataques, con nueva salvación al final de cada turno. No aplica Frightened. |
| `wall-of-thorns` | Al aparecer: salvación y 7d8 perforante. Moverse cuesta 4 pies por cada pie. Al entrar por primera vez o terminar turno: salvación y 7d8 cortante. No aplica Restrained. |

Conservar el escalado por nivel superior y el escalado de trucos ya correcto.
Cuando un conjuro tenga dos momentos de daño, modelarlos de manera distinguible;
no reducirlos a una única cadena ambigua si el esquema actual ya permite
expresiones estructuradas.

## 10. Criaturas y compañeros de conjuro

Archivo principal: `packages/dnd_engine/lib/assets/srd_2024/creatures.json`.

Agregar seis bloques de estadísticas 2024:

1. Animated Object — Medium or Smaller;
2. Animated Object — Large;
3. Animated Object — Huge;
4. Giant Insect — Centipede;
5. Giant Insect — Spider;
6. Giant Insect — Wasp.

Usar ids estables en inglés y nombres visibles en español coherentes con el
catálogo. Copiar de XPHB/SRD 5.2.1 tamaño, tipo, CA, PG, velocidades,
características, salvaciones, sentidos, inmunidades/resistencias,
acciones y todas las fórmulas dependientes del nivel del conjuro. Etiquetar
`srd_2024` las entradas que estén en el SRD 5.2.1.

Después de las altas:

- el catálogo debe contener **107 criaturas**;
- los tres objetos deben vincularse a `animate-objects`;
- los tres insectos deben vincularse a `giant-insect`;
- reutilizar `CompanionEffect` y `requiresSpell`;
- exponer las opciones a toda clase que tenga el conjuro en `Spell.classes`, sin
  duplicar una lista manual divergente;
- la ficha WEB debe permitir consultar la estadística resultante;
- las fórmulas deben evaluarse con al menos dos niveles de espacio de conjuro
  válidos en pruebas;
- no modificar las estadísticas de las 101 criaturas existentes salvo que sea
  estrictamente necesario para reutilizar el mismo mecanismo.

No convertir estos conjuros a las invocaciones de monstruos de 2014. Los bloques
son los específicos de las versiones 2024 de `Animate Objects` y `Giant Insect`.

## 11. Requisitos de implementación transversal WEB

### 11.1. Elecciones

Para Orden Primordial, Orden Divina, idiomas de Explorador Hábil, opciones de
dotes, estilos de combate y cualquier elección nueva:

- mostrar el control solo cuando la clase, nivel y prerrequisitos correspondan;
- impedir confirmar mientras falte una elección obligatoria;
- no borrar elecciones que sigan siendo válidas al volver atrás en el wizard;
- limpiar únicamente las elecciones que dejan de ser válidas al cambiar su
  origen;
- mostrar la elección en el resumen antes de guardar;
- permitir completarla durante la subida de nivel si se obtiene después de la
  creación;
- ofrecer una regularización segura para personajes antiguos que no posean el
  nuevo campo, sin asignar silenciosamente una opción arbitraria.

### 11.2. Persistencia y servidor

Si se agregan campos al personaje:

1. actualizar constructor, `copyWith`, igualdad si aplica, `toJson` y
   `fromJson`;
2. agregar una migración explícita desde la versión inmediatamente anterior;
3. verificar fixture antiguo y round-trip de la versión actual;
4. revisar cliente API, repositorio del servidor, importación y respaldos;
5. comprobar que un JSON futuro siga rechazándose;
6. comprobar que ausencias heredadas produzcan “pendiente de elegir”, no una
   elección inventada.

No hace falta una migración de base de datos si los personajes continúan como
documentos JSON y el esquema relacional no cambia. No crearla por rutina.

### 11.3. Compilación y ficha

- Una competencia nueva debe aparecer en `ComputedSheet` y en la ficha.
- Un truco o conjuro concedido debe aparecer con su origen y característica.
- Un recurso por descanso debe poder gastarse y recuperarse correctamente.
- Una bonificación de habilidad debe figurar en el desglose, no solo en el
  total.
- Una incompatibilidad de dotes debe producir un mensaje de validación claro.
- La fuente debe mostrarse con la insignia ya existente: SRD, PHB o Forge.
- La vista WEB no debe depender de strings ingleses internos para decidir una
  regla; usar ids o tipos del dominio.

## 12. Pruebas y verificaciones obligatorias

### 12.1. Pruebas de contenido

Extender las pruebas existentes en lugar de crear suites duplicadas:

- `content_integrity_test.dart`: cantidades, ids únicos, referencias existentes
  y procedencias;
- `classes_2024_test.dart`, `martial_classes_test.dart` y
  `spellcaster_classes_test.dart`: clases base;
- `subclasses_test.dart`: todos los rasgos corregidos;
- `spells_2024_test.dart` y `spell_action_type_test.dart`: tabla exacta del
  apartado 9;
- `feature_choice_test.dart`, `proficiency_choice_test.dart`,
  `language_test.dart` y `feature_promises_test.dart`: elecciones y promesas;
- `companion_test.dart` y `creature_formula_test.dart`: seis criaturas y
  escalado;
- `character_migration_test.dart` y `content_serialization_test.dart`:
  compatibilidad;
- pruebas del wizard, subida de nivel y ficha en `packages/dnd_app/test`;
- pruebas de importación/API en `packages/dnd_server/test` si cambió el JSON del
  personaje.

Las pruebas de regresión deben comprobar valores, no solo que el texto contenga
el nombre del rasgo. Para datos tabulares, usar casos parametrizados por id.

### 12.2. Invariantes finales

Agregar o conservar aserciones para estas condiciones:

| Invariante | Resultado esperado |
| --- | --- |
| Clases | 13 |
| Subclases | 53 |
| Especies | 15 |
| Linajes | 28; fuentes 24 SRD y 4 EFA |
| Trasfondos | 33 |
| Dotes y opciones equivalentes | 189 filas: 26 SRD, 135 PHB y 28 EFA |
| Armas | 38, todas SRD |
| Armaduras | 13 |
| Conjuros | 392; fuentes 339 SRD, 52 PHB y 1 EFA |
| Criaturas | 107 |
| Listas de clases de conjuros | Sin cambios respecto de la línea base, salvo que una fuente 2024 demuestre un defecto independiente. |
| Conjuros de Marca | 108 incorporaciones exactas. |
| Ids | Únicos y sin renombres no migrados. |

### 12.3. Comandos finales

Desde cada paquete, ejecutar:

```powershell
cd packages/dnd_engine
dart format --output=none --set-exit-if-changed lib test
dart analyze
dart test

cd ../dnd_server
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test

cd ../dnd_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Además:

- construir la variante WEB con el comando que use actualmente el proyecto;
- abrir la aplicación en navegador y hacer una prueba manual de creación,
  subida de nivel, guardado, recarga y ficha;
- probar al menos un personaje antiguo migrado;
- probar exportación e importación del personaje con elecciones nuevas;
- confirmar que ninguna solicitud del navegador falla y que el servidor conserva
  los campos nuevos.

Un `dart test`, `flutter test` o build exitoso no sustituye la prueba en
navegador. Si el entorno no permite ejecutar el navegador o una base real,
registrar esa limitación de forma explícita; no declarar validada esa capa.

## 13. Actualización documental al finalizar

Una vez que código y pruebas estén en verde:

1. actualizar las cantidades de README según el apartado 4.5;
2. actualizar la fila de estado actual de
   `docs/Auditorias/auditoria-reglas-2024.md`;
3. añadir allí una sección de cierre fechada con los cambios realmente
   implementados y las pruebas realmente ejecutadas;
4. no reescribir secciones históricas como si nunca hubieran ocurrido;
5. no marcar como “verificado” un bloque cuya validación WEB no se ejecutó.

## 14. Criterio de aceptación final

La tarea solo está completa cuando se cumplen todos estos puntos:

- [ ] Ninguna mecánica de 2014 permanece en los hallazgos enumerados.
- [ ] Las procedencias y sus conteos coinciden con el apartado 4.
- [ ] Las cantidades de catálogo coinciden con el apartado 12.2.
- [ ] Las seis criaturas nuevas existen y se vinculan a sus conjuros.
- [ ] Todas las elecciones nuevas se guardan, recargan y compilan.
- [ ] Las competencias, conjuros, recursos y bonificaciones aparecen en la ficha
      WEB.
- [ ] La validación impide estilos de clase y Marcas Dracónicas incompatibles.
- [ ] Un personaje de esquema anterior migra sin pérdida.
- [ ] Exportar e importar conserva las selecciones nuevas.
- [ ] Las pruebas de motor, servidor y app pasan sin relajar aserciones.
- [ ] El análisis estático y el formato pasan.
- [ ] La aplicación WEB fue construida y probada en navegador, o la limitación
      quedó declarada con precisión.
- [ ] README, manifiesto y auditoría reflejan el estado final real.
- [ ] No se alteró ningún archivo o comportamiento ajeno al alcance.

Si un dato de este documento parece contradecir `XPHB`, SRD 5.2.1 o `EFA`, no
adivinar ni aplicar una mezcla. Detener solo ese ítem, citar la entrada exacta y
resolver la contradicción con la fuente 2024 antes de continuar; el resto de las
fases independientes puede seguir.
