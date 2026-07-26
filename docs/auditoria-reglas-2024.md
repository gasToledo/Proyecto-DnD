# Auditoría de reglas 2024

## Fuente de verdad

Hay **dos referencias y no compiten**: resuelven preguntas distintas.

### Reglas y contenido: Manual del Jugador 2024

La mesa juega con el **Manual del Jugador 2024** y lo usa para crear personajes
y resolver reglas. Es la referencia mecánica del proyecto: si el PHB y el SRD
difieren en la redacción de un rasgo o en qué opciones existen, **gana el PHB**.

### Licencia: SRD 5.2.1

El **SRD 5.2.1 en español**, publicado por Wizards of the Coast bajo CC BY 4.0,
define qué contenido es libremente distribuible:

- <https://media.dndbeyond.com/compendium-images/srd/5.2/SP_SRD_CC_v5.2.1.pdf>
- <https://www.dndbeyond.com/srd>

El SRD **no** limita qué puede tener el catálogo, solo cómo hay que etiquetarlo.
El contenido oficial que no está en el SRD se marca `phb_2024` y no queda
cubierto por la atribución CC.

Que algo falte en el SRD no es motivo para excluirlo ni para dejarlo sin
corregir: es motivo para etiquetarlo bien.

### Dónde consultarlas

La biblioteca del proyecto es el notebook **`D&D Project`** de NotebookLM
(`615f7888-577f-4f7c-a3c0-ee6c4a5924d4`), que tiene el PDF del *Manual del
Jugador 2024* y el de *Forge of the Artificer*, para el día que se sume el
Artífice.

Sus otras 53 fuentes son material secundario (blogs, Reddit, Roll20, tiendas):
sirven para detectar restos de 2014, no para fijar valores numéricos.

**Verificar siempre `sources_used` antes de tocar un dato.** El notebook tiene
una instrucción persistente que le pide responder solo desde el PDF del PHB,
pero no la cumple de forma confiable: en las pruebas contestó tablas enteras
citando páginas del manual cuando en realidad había leído un blog. Una respuesta
sirve como evidencia únicamente si `sources_used` incluye el id del PDF
(`09011168-f63f-47cb-b3fb-e009ae22db50`) y el `cited_text` es texto de la
sección consultada, no el índice general.

Las reglas gratuitas 2024 de D&D Beyond quedan como apoyo de consulta:

- <https://www.dndbeyond.com/sources/dnd/br-2024/character-origins>

## Método

Cada bloque se revisa en cuatro dimensiones:

1. presencia y procedencia del contenido;
2. valores y texto mecánico;
3. elecciones que deben persistirse en el personaje;
4. comportamiento derivado, recursos y presentación en la ficha.

Estados: `pendiente`, `en revisión`, `corregido` y `verificado`.

## Matriz

| Bloque | Estado | Hallazgos y alcance |
| --- | --- | --- |
| Especies y linajes | en revisión | Verificados contra el SRD el Enano (Afinidad con la Piedra), el Orco (sin Complexión Poderosa) y el Humano. Los tres legados del Tiflin y los linajes de Elfo y Gnomo coinciden exactamente. Falta la elección de tamaño de Humano y Tiflin, las elecciones internas de Dracónido y Goliat, y el cambio de truco del Alto Elfo. |
| Magia de linaje | corregido | INT/SAB/CAR ahora es una elección persistida. Se agregó Artificio Druídico al Elfo de los Bosques y se corrigieron los usos de Hablar con los Animales del Gnomo de los Bosques. |
| Procedencia del catálogo | en revisión | `ContentSource` ya conoce `phb_2024` (antes degradaba a `homebrew` en silencio). Cerradas subclases (12 SRD / 36 PHB) y dotes (9 SRD / 48 PHB), con la procedencia visible en la app. **Falta trasfondos: el SRD solo incluye Acólito, Criminal, Erudito y Soldado, así que 10 de los 12 del catálogo son PHB.** Faltan también conjuros y equipo. |
| Trasfondos | pendiente | Verificar competencias, herramientas, dotes de origen, equipo y tres características disponibles. |
| Clases | en revisión | **Las 12 tablas verificadas contra el PHB.** Marciales: corregidas las progresiones de maestría con armas, Tomar Aliento, Furias, Movimiento sin Armadura y Canalizar Divinidad, congeladas en el valor de nivel 1; sumada la ballesta de mano a Pícaro y Monje; quitada Interpretación de la lista del Pícaro. Lanzadoras: Canalizar Divinidad del Clérigo (3 a nivel 6, 4 a nivel 18) y Forma Salvaje del Druida (3 a nivel 6, 4 a nivel 17) tenían el mismo defecto; el Druida perdió la armadura media, que en 2024 ya no tiene. Las 12 salvaciones y los 6 valores de trucos iniciales coinciden. Faltan los rasgos de nivel 8 a 20, el equipo inicial y las competencias con herramientas, que son contenido nuevo. |
| Subclases | en revisión | Corregida la progresión del Evocador (Experto en Evocación a 3, Esculpir Conjuros a 6) y separada la procedencia: 12 SRD y 36 PHB. Falta verificar los rasgos de las 47 restantes. |
| Dotes | en revisión | Iniciado en la Magia pasó a origen, Habilidoso a repetible, y se corrigieron Acechador, Tirador de Élite y el estilo Arma Grande. Prerrequisito real en Apresador, Maestro de Armas Grandes y Tirador de Élite. Falta el prerrequisito de las 40 generales restantes, la elección de característica (+1 a X o Y), Observador, y las dotes que el SRD no incluye. |
| Conjuros | en revisión | Normalizados escuela (`Necromancia` vs `Nigromancia`), el único alcance en métrico y los 164 tiempos de lanzamiento a la convención 2024. Faltan las reescrituras de Toque Gélido, Convocar Animales y Marca del Cazador, la procedencia, y los 161 conjuros del SRD que no están en el catálogo (338 contra 177). |
| Equipo | en revisión | Armas y armaduras verificadas contra el SRD en daño, propiedades y maestrías. La maestría ahora exige competencia con el arma. Falta precio, peso y alcance, y las armas que el SRD lista y el catálogo no tiene. |

## Primera pasada: orígenes y magia innata

### Verificado contra SRD 5.2.1

- Elfo: tres linajes; los conjuros de nivel 3 y 5 tienen un uso gratuito por
  descanso largo y admiten espacios apropiados.
- Alto Elfo: Prestidigitación, Detectar Magia y Paso Brumoso. Queda pendiente
  modelar el reemplazo del truco tras cada descanso largo.
- Drow: visión en la oscuridad de 120 pies, Luces Danzantes, Fuego Feérico y
  Oscuridad.
- Elfo de los Bosques: velocidad de 35 pies, Artificio Druídico, Zancada
  Prodigiosa y Pasar sin Rastro.
- Gnomo de los Bosques: Ilusión Menor y Hablar con los Animales con usos
  gratuitos iguales al bono de competencia por descanso largo.
- Gnomo de las Rocas: Reparar, Prestidigitación y dispositivo mecánico.
- Tiefling: tres legados, Taumaturgia compartiendo aptitud mágica, resistencias
  y progresión de conjuros correctas.
- Elfo, Gnomo y Tiefling eligen Inteligencia, Sabiduría o Carisma como aptitud
  mágica de sus conjuros de especie o linaje.

### Pendientes derivados

- Elección Pequeño/Mediano para Humano y Tiefling. El SRD la declara explícita
  ("elegido al seleccionar la especie"), así que es una elección a persistir.
- Cambio de truco del Alto Elfo después de un descanso largo.
- Lanzamiento explícito de conjuros innatos usando espacios desde la ficha.
- Elecciones de ascendencia del Dracónido y del Goliat.

## Qué contiene el SRD 5.2.1

Medido contra el PDF en español, para dimensionar cuánto del catálogo es PHB:

| Bloque | SRD 5.2.1 | Catálogo actual |
| --- | --- | --- |
| Especies | 9 (sin Aasimar) | 10 |
| Trasfondos | 4 (Acólito, Criminal, Erudito, Soldado) | 12 |
| Subclases | 12 (una por clase) | 48 |
| Dotes | 17 | 57 |
| Conjuros | 338 | 177 |

El catálogo es a la vez más chico que el SRD en conjuros y más grande en el
resto, con contenido del PHB 2024. Sin la etiqueta correcta, ambas cosas se
confunden bajo la misma atribución.

## Pendientes abiertos al cierre de esta tanda

Ordenados por costo, del más barato al más caro:

1. **Procedencia de trasfondos.** Hay evidencia dura: 10 de los 12 son PHB.
   Mismo cambio mecánico que ya se hizo con subclases y dotes.
2. **Reescritura de tres conjuros**: Toque Gélido (pasa a Toque y ataque cuerpo
   a cuerpo), Convocar Animales (deja de invocar criaturas y pasa a daño de
   área) y Marca del Cazador (daño de fuerza, sin ventaja para rastrear).
3. **Ballesta de mano** en Pícaro y Monje: en 2024 la competencia es "marciales
   con Sutileza o Ligera" y la ballesta de mano califica.
4. **Nomenclatura**: el catálogo usa traducciones propias donde el SRD tiene
   nombre oficial (Aprendiz de Mucho, Sentir el Peligro, Truco Potente). Esta
   tanda solo alineó los rasgos que tocó.
5. **Prerrequisitos de dote**: 40 de las 43 generales siguen con
   `minAbilityScores` vacío, así que la validación no puede detectar nada.
6. **Elección de característica en dotes** (+1 a X o Y): hoy está fija en el
   dato y anotada en el texto. Requiere efecto nuevo, campo persistido,
   migración y dos superficies de UI.
7. **Estilo de Combate de Paladín y Explorador**: confirmado contra el PHB que
   ambos lo obtienen en el **nivel 2**. Falta implementarlo: `grantsFightingStyle`
   es un booleano sin noción de nivel y la pantalla de subida de nivel no tiene
   dónde elegirlo, así que activarlo tal cual lo regalaría a nivel 1. Hace falta
   un campo `fightingStyleLevel`, el gating del asistente y una sección nueva.
8. **Agotamiento e Inspiración Heroica**: ambos existen como dato pero no
   afectan ningún cálculo. En 2024 el agotamiento da −2 por nivel a las pruebas
   de d20 y −5 pies de velocidad.
9. **Glosario de maestrías**: `mastery` es un id suelto (`nick`, `vex`) sin
   descripción en ningún lado; la ficha muestra el identificador en inglés.
10. **Invocaciones Sobrenaturales**: el sistema no existe en el motor, así que
    los cuatro pactos del Brujo solo figuran como texto.

## Criterio de cierre

Un bloque pasa a `verificado` cuando sus datos tienen prueba de contenido, las
elecciones necesarias sobreviven serialización y migración, el motor produce la
ficha esperada y la aplicación expone el resultado sin depender de una clase
lanzadora.
