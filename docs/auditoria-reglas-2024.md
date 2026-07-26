# Auditoría de reglas 2024

## Fuente de verdad

La referencia normativa y licenciable del proyecto es el **SRD 5.2.1 en
español**, publicado por Wizards of the Coast bajo CC BY 4.0:

- <https://media.dndbeyond.com/compendium-images/srd/5.2/SP_SRD_CC_v5.2.1.pdf>
- <https://www.dndbeyond.com/srd>

Las reglas gratuitas 2024 de D&D Beyond se usan como apoyo de consulta:

- <https://www.dndbeyond.com/sources/dnd/br-2024/character-origins>

El catálogo puede incluir contenido oficial del PHB 2024 que no pertenece al
SRD. Ese contenido debe identificarse como `phb_2024`; no queda cubierto por la
atribución CC del SRD.

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
| Clases | en revisión | Corregidos contra el SRD: Abrasar Muertos Vivientes del Clérigo, Adepto en Rituales del Mago a nivel 1, Pericia del Bardo a nivel 2, Talentos Fiables del Pícaro a nivel 7, Conocimiento Primigenio del Bárbaro, Castigo Divino del Paladín y la Dádiva de Pacto del Brujo. Falta completar las tablas hasta nivel 20, el equipo inicial, las competencias con herramientas, la ballesta de mano de Pícaro y Monje, y el Estilo de Combate de Paladín y Explorador. |
| Subclases | en revisión | Corregida la progresión del Evocador (Experto en Evocación a 3, Esculpir Conjuros a 6) y separada la procedencia: 12 SRD y 36 PHB. Falta verificar los rasgos de las 47 restantes. |
| Dotes | en revisión | Iniciado en la Magia pasó a origen, Habilidoso a repetible, y se corrigieron Acechador, Tirador de Élite y el estilo Arma Grande. Prerrequisito real en Apresador, Maestro de Armas Grandes y Tirador de Élite. Falta el prerrequisito de las 40 generales restantes, la elección de característica (+1 a X o Y), Observador, y las dotes que el SRD no incluye. |
| Conjuros | pendiente | Verificar nombres SRD, nivel, escuela, listas, componentes, duración, ritual y concentración. |
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

- Elección Pequeño/Mediano para Humano y Tiefling.
- Cambio de truco del Alto Elfo después de un descanso largo.
- Lanzamiento explícito de conjuros innatos usando espacios desde la ficha.
- Elecciones de ascendencia del Dracónido y del Goliat.

## Criterio de cierre

Un bloque pasa a `verificado` cuando sus datos tienen prueba de contenido, las
elecciones necesarias sobreviven serialización y migración, el motor produce la
ficha esperada y la aplicación expone el resultado sin depender de una clase
lanzadora.
