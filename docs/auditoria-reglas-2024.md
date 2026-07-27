# Auditoría de reglas 2024

## Fuente de verdad

Hay **tres referencias y no compiten**: resuelven preguntas distintas.

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

### Expansión: Forge of the Artificer

*Forge of the Artificer* (2025) suma la clase Artífice y contenido de Eberron.
No está en el SRD y no es el PHB, así que tiene su propia etiqueta `foa_2025` y
se muestra como **Forge 2025**.

El motivo es distinto al de la licencia: el jugador tiene que poder reconocer
que una opción viene de otro libro **antes** de comprometer un personaje con
ella, porque no todas las mesas lo usan.

### El objetivo es el catálogo completo

El criterio del proyecto es que el jugador pueda ver todas las opciones al
elegir. Un personaje dura mucho tiempo y decidir sin ver el panorama lleva a
elecciones que después no se quieren. Por eso el contenido faltante deja de
tratarse como relleno: es lo que más tapa la decisión.

Medida de referencia: al empezar, Mago, Bardo, Hechicero y Brujo **no tenían
ningún rasgo por encima del nivel 2**. Hoy las 12 clases llegan a 20 (el Paladín
a 19, porque su nivel 20 es rasgo de subclase).

### Dónde consultarlas

La fuente primaria son los **PDFs locales** de `d&d-data/`: el *Manual del
Jugador 2024* y *Forge of the Artificer*. La carpeta está en `.gitignore` — son
manuales con copyright y no se versionan.

El texto se extrae con `pdftotext`, que **no** son escaneos:

```sh
pdftotext -enc UTF-8 -layout "d&d-data/Manual del Jugador 2024.pdf" phb.txt
```

`-enc UTF-8` es obligatorio: sin eso sale en Latin-1 y los acentos quedan rotos.
`-layout` importa cuando el texto convive con una tabla a dos columnas —el
capítulo 3 intercala las listas de conjuros con los rasgos de clase, y sin
`-layout` las dos columnas se entrelazan hasta volverse ilegibles—. Para el resto
conviene la extracción sin `-layout`, que da párrafos más limpios. Vale tener las
dos versiones.

La extracción arrastra **ruido de OCR en los números**: se vieron `1410` por
`1d10`, `1-16` por `11-16`, `D£D` por `D&D`, y columnas enteras de tablas
desalineadas respecto de su fila. Los **nombres de rasgo y el texto de reglas
salen limpios**; las cifras hay que leerlas con desconfianza y, si el número es
el dato que se está por cargar, contrastarlo con el texto del rasgo, que suele
repetirlo en palabras.

El manual está en **métrico** (3 m, 4,5 m, 18 m). El catálogo usa pies por
convención de la casa, así que hay que convertir: 1,5 m = 5 pies, 3 m = 10, 4,5 m
= 15, 9 m = 30, 18 m = 60, 90 m = 300.

Esto reemplaza al notebook **`D&D Project`** de NotebookLM
(`ca6c9871-c8fd-4037-a7ae-bcf8397084b5`), que queda como apoyo para búsquedas
exploratorias, no como evidencia. El PDF que se le subió tenía nueve páginas
faltantes del capítulo 3 y cuatro clases que fallaban de forma determinista
—Guerrero y Pícaro devolvían `sources_used` vacío; Explorador y Mago citaban el
PDF de *Forge of the Artificer* con texto de Eberron—. Ninguno de esos dos
problemas existe leyendo el PDF local. Si aun así se usa el notebook,
**verificar `sources_used` antes de tocar un dato**: hubo respuestas que citaban
páginas del manual habiendo leído un blog. El campo `cited_text` no sirve para
juzgar, porque casi siempre devuelve el índice general.

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
| Especies y linajes | en revisión | **Las 10 especies del catálogo son exactamente las 10 del PHB**, y coinciden los linajes de Elfo (3) y Gnomo (2), la ausencia de linaje en Orco y Aasimar, y la velocidad de 35 pies del Goliat. La Ascendencia Dracónica ahora nombra los diez dragones y su tipo de daño, como ya hacía el Goliat con los seis gigantes. Falta la elección de tamaño (Humano, Tiflin **y Aasimar**, que en el PHB son Mediano o Pequeño), las ascendencias de Dracónido y Goliat como elección persistida, y el cambio de truco del Alto Elfo. |
| Magia de linaje | corregido | INT/SAB/CAR ahora es una elección persistida. Se agregó Artificio Druídico al Elfo de los Bosques y se corrigieron los usos de Hablar con los Animales del Gnomo de los Bosques. |
| Procedencia del catálogo | en revisión | `ContentSource` ya conoce `phb_2024` (antes degradaba a `homebrew` en silencio). Cerradas subclases (12 SRD / 36 PHB), dotes (9 SRD / 48 PHB) y trasfondos (2 SRD / 10 PHB), con la procedencia visible en la app. Faltan conjuros y equipo. |
| Trasfondos | en revisión | **Los 12 verificados contra el PHB sin una sola diferencia** en dote de origen, las dos habilidades y la herramienta. Cerrada la procedencia: el SRD trae 4 trasfondos y el catálogo tiene 2 de ellos, así que 10 pasaron a `phb_2024`. Falta verificar las tres características ofrecidas y el equipo inicial, y faltan 4 trasfondos del manual: Acólito, Erudito, Guía y Marinero. |
| Puntuaciones | en revisión | Verificados contra el capítulo 2: el array estándar (15, 14, 13, 12, 10, 8), la tirada de 4d6 quedándose con los tres más altos, el aumento de 3 puntos del trasfondo en sus dos repartos (+2/+1 y +1/+1/+1) y el tope de 20. **Falta la compra de puntos**, el tercer método oficial: 27 puntos, puntuaciones de 8 a 15, con costes 0/1/2/3/4/5/7/9. |
| Clases | en revisión | **Las 12 tablas verificadas contra el PHB.** Marciales: corregidas las progresiones de maestría con armas, Tomar Aliento, Furias, Movimiento sin Armadura y Canalizar Divinidad, congeladas en el valor de nivel 1; sumada la ballesta de mano a Pícaro y Monje; quitada Interpretación de la lista del Pícaro. Lanzadoras: Canalizar Divinidad del Clérigo (3 a nivel 6, 4 a nivel 18) y Forma Salvaje del Druida (3 a nivel 6, 4 a nivel 17) tenían el mismo defecto; el Druida perdió la armadura media, que en 2024 ya no tiene. Las 12 salvaciones y los 6 valores de trucos iniciales coinciden. **Rasgos de nivel 3 a 20 completados en las 12 clases**: las once que cierran en 20 más el Paladín, cuyo nivel 20 es rasgo de subclase. Al cargarlos aparecieron tres restos de 2014 que ninguna tabla delataba, porque el nombre del rasgo era correcto y lo que estaba mal era el texto: **Furia Implacable** dejaba al Bárbaro en 1 PG en vez de en el doble de su nivel, **Golpes Potenciados** volvía mágicos los golpes del Monje en vez de dejarle elegir daño de fuerza, y el Monje llamaba *Puntos de Enfoque* a la Concentración (se cambió el nombre visible; el id `focus_points` se conserva para no perder los puntos gastados de las partidas guardadas). Los únicos rasgos de la tanda con efecto mecánico y no solo descriptivo son Superviviente Disciplinado del Monje (competencia en las seis salvaciones) y los capstones de Bárbaro, Monje y Druida. Faltan el equipo inicial y las competencias con herramientas, que son contenido nuevo. |
| Subclases | en revisión | Corregida la progresión del Evocador (Experto en Evocación a 3, Esculpir Conjuros a 6) y separada la procedencia: 12 SRD y 36 PHB. **Los 48 nombres de subclase están verificados contra el índice del manual.** Rasgos verificados: Bárbaro (4/4), Monje (4/4), Paladín (4/4), Hechicero (4/4), Druida (3/4), Brujo (3/4 parcial), Clérigo (2/4 parcial) y Bardo (2/4). Los niveles coinciden en todos los casos; lo que fallaba era la nomenclatura, y de forma sistemática. **Único rasgo mal, no solo mal traducido: el nivel 18 de Hechicería Dracónica sigue siendo la Presencia Dracónica de 2014 en vez de Compañero Dragón**; hace falta el texto del manual para reescribirlo y hay un test que lo deja anotado. **Quedan sin verificar los rasgos de Guerrero, Mago, Explorador y Pícaro**, no por falta de intento sino porque esas consultas no pudieron citar el manual: ver la nota de fuentes. |
| Dotes | en revisión | Iniciado en la Magia pasó a origen, Habilidoso a repetible, y se corrigieron Acechador, Tirador de Élite y el estilo Arma Grande. **Las 43 generales tienen ahora su prerrequisito real del PHB**: 12 con una característica, 10 con dos o tres alternativas, 4 con entrenamiento de armadura, 3 con lanzamiento de conjuros y 14 solo con el nivel 4. Para eso se agregó `anyAbilityScores`, porque el mapa anterior combinaba con Y lógico y no podía expresar "Fuerza o Destreza 13". Falta la elección de característica (+1 a X o Y) y revisar `mobile`, que no figura entre las 43 del capítulo. |
| Conjuros | en revisión | Normalizados escuela (`Necromancia` vs `Nigromancia`), el único alcance en métrico y los 164 tiempos de lanzamiento a la convención 2024; las 8 escuelas, los tiempos, los alcances y la coherencia de concentración se comprueban ahora sobre los 177. **Hechas las tres reescrituras**: Toque Helado (pasa a Toque y ataque cuerpo a cuerpo), Conjurar Animales (deja de invocar criaturas, pasa a daño de área y baja a 10 minutos) y Marca del Cazador (daño de fuerza). **El capítulo 7 del PDF se parsea completo**: 384 conjuros con nivel, escuela, clases, tiempo, alcance, componentes y duración. El encabezado es regular (`NOMBRE` + `Escuela de nivel N (clases)`), con tres trampas que hay que tolerar: el nombre a veces cae en la misma línea que la escuela, la lista de clases se parte en dos, y una docena de encabezados salen en caja mixta (`Luz DEL DÍA`, `Trepar cual arácnido`) en vez de mayúsculas. La escuela se llama **Ilusionismo**, no Ilusión: eso se corrigió en los 12 conjuros afectados y en la lista blanca del test. **31 conjuros llevaban un nombre que no es el del manual y se renombraron**, verificando cada uno por dos vías independientes —la firma de metadatos contra el capítulo 7 y el id, que es el nombre en inglés—; emparejar solo por metadatos no alcanza, porque mandaba Deseo y Detener el Tiempo al mismo destino. El peor era `geas`, catalogado como *Mandato*, que es el nombre de otro conjuro. **Cerrada la nomenclatura**: una segunda tanda resolvió los 43 restantes verificando cada destino contra su encabezado y su nivel en el capítulo 7 (0 rechazos); 36 eran renombres reales y 7 ya coincidían. Renombrar destapó dos cosas más: una **colisión de nombres** —`feeblemind` estaba catalogado como *Mente en Blanco*, que es el nombre de `mind-blank`— y, al mirarlo, que su texto seguía siendo el de 2014 (reducía Inteligencia y Carisma a 1, cuando en 2024 son 10d12 psíquicos y bloqueo de conjuros). Con los nombres alineados se pudo cruzar por fin escuela y nivel de los 172 emparejados: una sola diferencia, **Salpicadura Ácida**, que en 2024 es de Evocación y no de Conjuración. Hay un test que prohíbe nombres repetidos. **Altas en curso**: cargados los **8 trucos y 32 conjuros de nivel 1** que faltaban (catálogo de 177 a 217). Los campos mecánicos no se transcriben a mano: salen del parseo y un generador los convierte a la convención de la casa —métrico a pies, el ritual separado del tiempo de lanzamiento, la concentración separada de la duración—; solo la descripción corta es de autor. Se etiquetan `phb_2024`: sin el SRD a mano no se puede afirmar que estén cubiertas por CC BY 4.0, y quedarse corto es seguro mientras que al revés sería un problema de licencia. De paso quedó claro que **Castigo Divino es un conjuro en 2024**, no un rasgo del Paladín. **Nivel 2 cargado**: los 39 conjuros que faltaban (catálogo de 217 a 256). Dos defectos del generador aparecieron y quedaron corregidos con test: una comilla tipográfica del OCR pegada al nombre de Truco de la Cuerda, y el Title Case de la casa no capitalizaba la segunda mitad de un nombre compuesto (Agrandar/Reducir, Sordera/Ceguera). **Nivel 3 cargado**: los 26 conjuros que faltaban (catálogo de 256 a 282; el hueco real fue menor que la estimación de 33). Dos defectos del generador aparecieron y quedaron corregidos con test: el alcance en kilómetros de Clarividencia (1,5 km, la misma distancia que ya usa Enjambre de Meteoros como "1 milla") no tenía conversión, y el tiempo de lanzamiento en minutos u horas pluralizaba mal porque la alternancia de la regex probaba la forma singular antes que la plural y recortaba la "s". **Nivel 4 cargado**: los 28 conjuros que faltaban (catálogo de 282 a 310; otra vez el hueco real fue menor que la estimación de 31). Aparecieron dos colisiones de id reales, no de nombre: `moonbeam` ya estaba tomado por Rayo de Luna (nivel 2) y el nuevo conjuro era en realidad Fuente de Luz Lunar (*Fount of Moonlight*, nivel 4, sin relación); y `dominate-monster` ya era Dominar Monstruo (nivel 8) cuando el nuevo era Hechizar Monstruo (*Charm Monster*, nivel 4) — dos conjuros distintos del manual, no una progresión del mismo. El chequeo de id duplicado que atajó `friends`/`feeblemind` en tandas anteriores volvió a servir. **Pendiente**: las **112 altas** de nivel 5 en adelante. El hueco real es mayor que la estimación anterior: no son 161 sobre el SRD sino 245 sobre el PHB. |
| Equipo | en revisión | Armas y armaduras verificadas contra el SRD en daño, propiedades y maestrías. La maestría ahora exige competencia con el arma. **Las ocho propiedades de maestría tienen glosario** con el nombre oficial del PHB y el texto de la regla, así que la ficha dejó de mostrar el identificador en inglés. Falta precio, peso y alcance, que no existen como campo en el modelo, y las armas que el manual lista y el catálogo no tiene. |

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

- Elección Pequeño/Mediano para Humano, Tiefling y Aasimar. El SRD la declara
  explícita ("elegido al seleccionar la especie"), y el PHB confirma que el
  Aasimar también la tiene, así que es una elección a persistir.
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
| Conjuros | 384 (PHB, cap. 7) | 310 |

El catálogo es a la vez más chico que el SRD en conjuros y más grande en el
resto, con contenido del PHB 2024. Sin la etiqueta correcta, ambas cosas se
confunden bajo la misma atribución.

## Pendientes abiertos al cierre de esta tanda

Ordenados por costo, del más barato al más caro:

1. **Compra de puntos**: es el tercer método oficial de asignar puntuaciones y
   la app solo tiene dos. El dato es chico (27 puntos, rango 8–15, costes
   0/1/2/3/4/5/7/9), pero la interacción no encaja en el paso actual, que
   reparte un pool fijo de seis valores con desplegables: la compra necesita
   selectores con presupuesto. Es un modo nuevo en `scores_step.dart` más un
   valor nuevo en `ScoreMethod`, que el borrador ya tolera porque resuelve el
   enum por nombre con respaldo.
2. **Nomenclatura**: el catálogo usa traducciones propias donde el SRD tiene
   nombre oficial (Aprendiz de Mucho, Sentir el Peligro, Truco Potente). Esta
   tanda solo alineó los rasgos que tocó.
3. **`mobile` no está en el capítulo 5**: las 43 dotes generales del PHB
   incluyen Veloz (`speedy`) pero no Móvil, que es de 2014 y quedó cubierta por
   aquella. El catálogo tiene las dos y por ahora `mobile` copia el
   prerrequisito de `speedy`. Falta decidir si se retira o se marca como
   contenido propio.
4. **Elección de característica en dotes** (+1 a X o Y): hoy está fija en el
   dato y anotada en el texto. Requiere efecto nuevo, campo persistido,
   migración y dos superficies de UI.
5. **Estilo de Combate de Paladín y Explorador**: confirmado contra el PHB que
   ambos lo obtienen en el **nivel 2**. Falta implementarlo: `grantsFightingStyle`
   es un booleano sin noción de nivel y la pantalla de subida de nivel no tiene
   dónde elegirlo, así que activarlo tal cual lo regalaría a nivel 1. Hace falta
   un campo `fightingStyleLevel`, el gating del asistente y una sección nueva.
6. **Agotamiento e Inspiración Heroica**: ambos existen como dato pero no
   afectan ningún cálculo. En 2024 el agotamiento da −2 por nivel a las pruebas
   de d20 y −5 pies de velocidad.
7. **Precio y peso del equipo**: no existen como campo en `Weapon` ni en
   `Armor`, así que no hay dónde guardarlos. Sumarlos implica campo nuevo,
   los valores de las 35 armas y 13 armaduras, y decidir si la ficha lleva
   carga.
8. **Invocaciones Sobrenaturales**: el sistema no existe en el motor, así que
    los cuatro pactos del Brujo solo figuran como texto.

## Criterio de cierre

Un bloque pasa a `verificado` cuando sus datos tienen prueba de contenido, las
elecciones necesarias sobreviven serialización y migración, el motor produce la
ficha esperada y la aplicación expone el resultado sin depender de una clase
lanzadora.
