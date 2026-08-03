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

#### Verificación determinista: `Player's Handbook (2024).md`

La misma carpeta tiene una extracción del PHB completo **en inglés y en
markdown**, con las tablas en formato parseable. Para todo lo que sea enumerable
conviene más que el PDF: no arrastra el ruido de OCR que se describe abajo, así
que el catálogo se puede comparar con un script en vez de por lectura, y el
resultado es reproducible. Así se cerró la tabla de armas y así se comprobó que
las dotes reconcilian contra el capítulo 5.

Lo que **sí** trae: la *Feat List* completa con categoría y repetibilidad
(cap. 5), las tablas de armas y armaduras con peso y precio (cap. 6), la tabla
de costes de la compra de puntos (cap. 2), los 48 nombres de subclase (cap. 3) y
el glosario de reglas.

Lo que **no** trae, y sigue exigiendo el PDF en español: las descripciones de
conjuros (el cap. 7 del markdown son solo las reglas de lanzamiento), los rasgos
de clase y de especie en detalle (los cap. 3 y 4 son resúmenes) y la entrada de
Agotamiento del glosario, que quedó como un embed HTML sin extraer.

Los **nombres en español** nunca salen de ahí: para eso manda el PDF, que es lo
que lee la mesa. Traducir a ojo desde el inglés es justamente cómo aparecen las
colisiones de nombre.

#### Extracción del PDF

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
| Especies y linajes | en revisión | **Las 10 especies del catálogo son exactamente las 10 del PHB**, y coinciden los linajes de Elfo (3) y Gnomo (2), la ausencia de linaje en Orco y Aasimar, y la velocidad de 35 pies del Goliat. **El Linaje gigante del Goliat (6) y el Linaje dracónico del Dracónido (10) ya son elecciones persistidas y con efecto mecánico**, modeladas como linajes porque así los llama el PHB; el catálogo llega a 24 linajes. La resistencia del Dracónido dejó de ser texto y el Ataque de Aliento es un recurso con usos iguales al bonificador por competencia. Falta la elección de tamaño (Humano, Tiefling **y Aasimar**, que en el PHB son Mediano o Pequeño) y el cambio de truco del Alto Elfo. |
| Magia de linaje | corregido | INT/SAB/CAR ahora es una elección persistida. Se agregó Artificio Druídico al Elfo de los Bosques y se corrigieron los usos de Hablar con los Animales del Gnomo de los Bosques. |
| Procedencia del catálogo | en revisión | `ContentSource` ya conoce `phb_2024` y `foa_2025` (antes degradaba a `homebrew` en silencio), con la procedencia visible en la app. Estado actual del etiquetado: subclases 12 SRD / 36 PHB / 5 FoA, dotes 9 / 73 / 28, trasfondos 4 / 12 / 17, conjuros 177 / 214 / 1, especies 9 / 1 / 5. Cerrado en todos los bloques salvo equipo, que sigue sin desglose por procedencia. |
| Trasfondos | corregido | **Cierra Q3**: los 4 trasfondos que faltaban, cargados con los datos del bloque de características de cada uno en el capítulo 4 (más confiable que la tabla resumen de creación de personaje, que quedó cortada por columnas en la extracción). Acólito y Erudito son `srd_2024`; Guía y Marinero, `phb_2024`. Trajeron dos dotes de origen que no estaban: **Iniciado en la Magia (Druida)** y **Matón de Taberna**, con el mismo texto que las variantes de Mago y Clérigo ya cargadas. El catálogo llega a **16 trasfondos y 59 dotes**. Falta verificar las tres características ofrecidas y el equipo inicial de los 16. |
| Puntuaciones | en revisión | Verificados contra el capítulo 2: el array estándar (15, 14, 13, 12, 10, 8), la tirada de 4d6 quedándose con los tres más altos, el aumento de 3 puntos del trasfondo en sus dos repartos (+2/+1 y +1/+1/+1) y el tope de 20. **Falta la compra de puntos**, el tercer método oficial: 27 puntos, puntuaciones de 8 a 15, con costes 0/1/2/3/4/5/7/9. |
| Clases | en revisión | **Las 12 tablas verificadas contra el PHB.** Marciales: corregidas las progresiones de maestría con armas, Tomar Aliento, Furias, Movimiento sin Armadura y Canalizar Divinidad, congeladas en el valor de nivel 1; sumada la ballesta de mano a Pícaro y Monje; quitada Interpretación de la lista del Pícaro. Lanzadoras: Canalizar Divinidad del Clérigo (3 a nivel 6, 4 a nivel 18) y Forma Salvaje del Druida (3 a nivel 6, 4 a nivel 17) tenían el mismo defecto; el Druida perdió la armadura media, que en 2024 ya no tiene. Las 12 salvaciones y los 6 valores de trucos iniciales coinciden. **Rasgos de nivel 3 a 20 completados en las 12 clases**: las once que cierran en 20 más el Paladín, cuyo nivel 20 es rasgo de subclase. Al cargarlos aparecieron tres restos de 2014 que ninguna tabla delataba, porque el nombre del rasgo era correcto y lo que estaba mal era el texto: **Furia Implacable** dejaba al Bárbaro en 1 PG en vez de en el doble de su nivel, **Golpes Potenciados** volvía mágicos los golpes del Monje en vez de dejarle elegir daño de fuerza, y el Monje llamaba *Puntos de Enfoque* a la Concentración (se cambió el nombre visible; el id `focus_points` se conserva para no perder los puntos gastados de las partidas guardadas). Los únicos rasgos de la tanda con efecto mecánico y no solo descriptivo son Superviviente Disciplinado del Monje (competencia en las seis salvaciones) y los capstones de Bárbaro, Monje y Druida. Faltan el equipo inicial y las competencias con herramientas, que son contenido nuevo. |
| Subclases | en revisión | Corregida la progresión del Evocador (Experto en Evocación a 3, Esculpir Conjuros a 6) y separada la procedencia: 12 SRD y 36 PHB. **Los 48 nombres de subclase están verificados contra el índice del manual.** Rasgos verificados: Bárbaro (4/4), Monje (4/4), Paladín (4/4), Hechicero (4/4), Druida (3/4), Brujo (3/4 parcial), Clérigo (2/4 parcial) y Bardo (2/4). Los niveles coinciden en todos los casos; lo que fallaba era la nomenclatura, y de forma sistemática. **Único rasgo mal, no solo mal traducido: el nivel 18 de Hechicería Dracónica sigue siendo la Presencia Dracónica de 2014 en vez de Compañero Dragón**; hace falta el texto del manual para reescribirlo y hay un test que lo deja anotado. **Quedan sin verificar los rasgos de Guerrero, Mago, Explorador y Pícaro**, no por falta de intento sino porque esas consultas no pudieron citar el manual: ver la nota de fuentes. |
| Dotes | en revisión | Iniciado en la Magia pasó a origen, Habilidoso a repetible, y se corrigieron Acechador, Tirador de Élite y el estilo Arma Grande. **Las 43 generales tienen ahora su prerrequisito real del PHB**: 12 con una característica, 10 con dos o tres alternativas, 4 con entrenamiento de armadura, 3 con lanzamiento de conjuros y 14 solo con el nivel 4. Para eso se agregó `anyAbilityScores`, porque el mapa anterior combinaba con Y lógico y no podía expresar "Fuerza o Destreza 13". Falta la elección de característica (+1 a X o Y) y revisar `mobile`, que no figura entre las 43 del capítulo. **Sumadas 24 dotes que faltaban del capítulo 5**: Mejora de Característica, Entrenamiento con Armas Marciales, Maestro de Armas, los 6 Estilos de Combate (Lucha a Ciegas, Intercepción, Protección, Combate con Armas Arrojadizas, Combate con Dos Armas, Combate sin Armas), las 3 Resiliente (Fuerza, Inteligencia, Carisma) y los 12 Dones Épicos (de la Fortaleza, de la Habilidad, de la Pericia en Combate, de la Recuperación, de la Resistencia a Energías, de la Velocidad, de la Visión Verdadera, del Ataque Imparable, del Destino, del Espíritu de la Noche, del Recuerdo de Conjuros, del Viaje Dimensional). Se quitó una dote duplicada. El catálogo llega a **110 dotes** (9 SRD, 73 PHB, 28 FoA); falta verificar el prerrequisito y el texto de los Dones Épicos contra el capítulo 5. **Comprobado que las 110 reconcilian exacto contra las 75 del capítulo 5**, con dos familias expandidas a propósito: Iniciado en la Magia en 3 listas y Resiliente en 6 características (75 − 2 + 3 + 6 = 82, más las 28 de FoA). **Resuelta una colisión de nombre**: tres variantes de Resiliente (Sabiduría, Constitución y Destreza) estaban cargadas como *Resistente*, que es el nombre en español de otra dote general —la que da +1 a Constitución, ventaja en salvaciones contra muerte y Recuperación rápida, `durable` en el catálogo—. Por esa colisión `durable` había quedado con un sufijo inventado, *Resistente Físico*, que ya no necesita. Es el mismo defecto que tuvieron los conjuros con `feeblemind`: el id apunta bien y lo que engaña es la etiqueta visible. Hay un test que prohíbe nombres de dote repetidos, que antes solo existía para conjuros. |
| Conjuros | corregido | Normalizados escuela (`Necromancia` vs `Nigromancia`), el único alcance en métrico y los 164 tiempos de lanzamiento a la convención 2024; las 8 escuelas, los tiempos, los alcances y la coherencia de concentración se comprueban ahora sobre los 177. **Hechas las tres reescrituras**: Toque Helado (pasa a Toque y ataque cuerpo a cuerpo), Conjurar Animales (deja de invocar criaturas, pasa a daño de área y baja a 10 minutos) y Marca del Cazador (daño de fuerza). **El capítulo 7 del PDF se parsea completo**: 384 conjuros con nivel, escuela, clases, tiempo, alcance, componentes y duración. El encabezado es regular (`NOMBRE` + `Escuela de nivel N (clases)`), con tres trampas que hay que tolerar: el nombre a veces cae en la misma línea que la escuela, la lista de clases se parte en dos, y una docena de encabezados salen en caja mixta (`Luz DEL DÍA`, `Trepar cual arácnido`) en vez de mayúsculas. La escuela se llama **Ilusionismo**, no Ilusión: eso se corrigió en los 12 conjuros afectados y en la lista blanca del test. **31 conjuros llevaban un nombre que no es el del manual y se renombraron**, verificando cada uno por dos vías independientes —la firma de metadatos contra el capítulo 7 y el id, que es el nombre en inglés—; emparejar solo por metadatos no alcanza, porque mandaba Deseo y Detener el Tiempo al mismo destino. El peor era `geas`, catalogado como *Mandato*, que es el nombre de otro conjuro. **Cerrada la nomenclatura**: una segunda tanda resolvió los 43 restantes verificando cada destino contra su encabezado y su nivel en el capítulo 7 (0 rechazos); 36 eran renombres reales y 7 ya coincidían. Renombrar destapó dos cosas más: una **colisión de nombres** —`feeblemind` estaba catalogado como *Mente en Blanco*, que es el nombre de `mind-blank`— y, al mirarlo, que su texto seguía siendo el de 2014 (reducía Inteligencia y Carisma a 1, cuando en 2024 son 10d12 psíquicos y bloqueo de conjuros). Con los nombres alineados se pudo cruzar por fin escuela y nivel de los 172 emparejados: una sola diferencia, **Salpicadura Ácida**, que en 2024 es de Evocación y no de Conjuración. Hay un test que prohíbe nombres repetidos. **Altas en curso**: cargados los **8 trucos y 32 conjuros de nivel 1** que faltaban (catálogo de 177 a 217). Los campos mecánicos no se transcriben a mano: salen del parseo y un generador los convierte a la convención de la casa —métrico a pies, el ritual separado del tiempo de lanzamiento, la concentración separada de la duración—; solo la descripción corta es de autor. Se etiquetan `phb_2024`: sin el SRD a mano no se puede afirmar que estén cubiertas por CC BY 4.0, y quedarse corto es seguro mientras que al revés sería un problema de licencia. De paso quedó claro que **Castigo Divino es un conjuro en 2024**, no un rasgo del Paladín. **Nivel 2 cargado**: los 39 conjuros que faltaban (catálogo de 217 a 256). Dos defectos del generador aparecieron y quedaron corregidos con test: una comilla tipográfica del OCR pegada al nombre de Truco de la Cuerda, y el Title Case de la casa no capitalizaba la segunda mitad de un nombre compuesto (Agrandar/Reducir, Sordera/Ceguera). **Nivel 3 cargado**: los 26 conjuros que faltaban (catálogo de 256 a 282; el hueco real fue menor que la estimación de 33). Dos defectos del generador aparecieron y quedaron corregidos con test: el alcance en kilómetros de Clarividencia (1,5 km, la misma distancia que ya usa Enjambre de Meteoros como "1 milla") no tenía conversión, y el tiempo de lanzamiento en minutos u horas pluralizaba mal porque la alternancia de la regex probaba la forma singular antes que la plural y recortaba la "s". **Nivel 4 cargado**: los 28 conjuros que faltaban (catálogo de 282 a 310; otra vez el hueco real fue menor que la estimación de 31). Aparecieron dos colisiones de id reales, no de nombre: `moonbeam` ya estaba tomado por Rayo de Luna (nivel 2) y el nuevo conjuro era en realidad Fuente de Luz Lunar (*Fount of Moonlight*, nivel 4, sin relación); y `dominate-monster` ya era Dominar Monstruo (nivel 8) cuando el nuevo era Hechizar Monstruo (*Charm Monster*, nivel 4) — dos conjuros distintos del manual, no una progresión del mismo. El chequeo de id duplicado que atajó `friends`/`feeblemind` en tandas anteriores volvió a servir. **Nivel 5 cargado**: los 32 conjuros que faltaban (catálogo de 310 a 342; el hueco real igualó la estimación esta vez). Dos casos nuevos en el parseo, ambos con campos vacíos que se completaron a mano leyendo el PDF directamente: Círculo de Teletransportación (tiempo de lanzamiento partido entre columnas) y Creación (duración "Especial" y alcance "9 m" sepultados bajo el cuerpo del conjuro). De paso apareció la tercera colisión de nombre-no-id de la tanda: Invocar Elemental (nivel 4, el conjuro de invocación nuevo de 2024) y Conjurar Elemental (nivel 5, el conjuro de 2014 con un elemental Grande de estadísticas propias) comparten la raíz en español pero son conjuros distintos del manual. **Q2 completo**: cargados los conjuros de nivel 6 a 9 (23, 10, 9 y 4 respectivamente). El catálogo cierra en **388 conjuros**, la cifra exacta que trae el capítulo 7. Cinco parejas de conjuros que comparten raíz en español pero son entradas distintas del manual (el nuevo verbo "invocar" de 2024 contra el "conjurar" que sigue de 2014, sobre la misma criatura): elemental (nivel 4/5), feérico (3/6) y celestial (5/7), más las dos colisiones de nombre-no-id de tandas anteriores (Fuente de Luz Lunar/Rayo de Luna, Hechizar/Dominar Monstruo). El chequeo de id contra el catálogo, hecho rutina desde la tercera tanda, las atajó todas antes de escribir nada. Dos artefactos de OCR nuevos: Telepatía perdía la mayúscula de "Ilimitado" ("Alcance: limitado"), corregido contrastando con la descripción del conjuro; y el alcance en kilómetros —antes solo el caso de Enjambre de Meteoros— se generalizó a una conversión (750 km de Proyectar Imagen dan 500 millas). |
| Equipo | en revisión | Armas y armaduras verificadas contra el SRD en daño, propiedades y maestrías. La maestría ahora exige competencia con el arma. **Las ocho propiedades de maestría tienen glosario** con el nombre oficial del PHB y el texto de la regla, así que la ficha dejó de mostrar el identificador en inglés. **Cerrada la tabla de armas**: cargadas las tres que faltaban de Armas Marciales a Distancia —Cerbatana, Mosquete y Pistola—, así que el catálogo llega a las **38 armas** del capítulo 6, con las 13 armaduras ya completas. La verificación se hizo por primera vez de forma determinista contra las tablas del cap. 6 (ver la nota de fuentes): las 35 armas previas coincidían con el PHB en dado, tipo de daño y maestría sin una sola diferencia, y las armaduras en CA, tope de Destreza, sigilo y requisito de Fuerza. La Cerbatana hace 1 de daño fijo y no un dado; `damageDice` es una cadena de presentación que nunca se parsea, así que `"1"` es un valor legítimo. Las tres van como `phb_2024`: sin el SRD a mano no se puede afirmar que estén cubiertas por CC BY 4.0, el mismo criterio conservador que se usó con los conjuros. Falta precio, peso y alcance, que no existen como campo en el modelo. |
| Forge of the Artificer | corregido | **Cierra Q4**: cargado el capítulo 2 completo salvo la clase Artífice — **5 especies** (Cambiaformas, Kalashtar, Khoravar, Cambiante y Forjado), **17 trasfondos** (trece herederos de casa dracomarcada, Heredero Aberrante, Agente de Casa, Arqueólogo e Inquisidor) y **28 dotes** (13 de Marca Dracónica, 14 generales y Bendición de Siberys). Todo etiquetado `foa_2025`. Hicieron falta dos categorías de dote nuevas, `dragonmark` y `epic-boon`, y que un trasfondo pueda conceder una dote de marca a nivel 1: el libro dice que tomar el trasfondo de la casa es la única forma de tener una marca en la creación. También `requiredFeatIds` y `requiredFeatCategory` en el prerrequisito, porque las doce marcas mayores exigen su marca base y Marca Dracónica Potente exige "alguna dote de marca"; sin eso la validación aceptaba cualquier combinación. Las tablas de Conjuros de la Marca no se transcribieron: se resolvieron por id contra `spells.json`, y ese cruce destapó **cuatro conjuros con un id inglés que no era el suyo** —Consagrar, Caparazón Antivida, Creación y el par Conjurar Descarga de Proyectiles / Conjurar Lluvia de Flechas, que tenían los ids intercambiados—. El nombre y las reglas estaban bien; solo el id apuntaba a otro conjuro, que es la clase de defecto que ninguna verificación por tabla puede ver. Corregirlo obligó a la migración de ficha **v3 → v4**, que reescribe `cantripIds` y `spellIds` para que nadie pierda un conjuro elegido. Falta el equipo inicial de los 17 trasfondos, la elección de tamaño y el tipo de criatura de las 5 especies (misma deuda que Humano, Tiefling y Aasimar), y la clase Artífice, que va aparte. **Cierra Q5**: cargada la clase Artífice completa (niveles 1 a 20) y sus **5 subclases** (Alquimista, Armero, Artillero, Herrero de Batalla y Cartógrafo), la 13ª clase del catálogo y las últimas piezas del capítulo 2. Es un semi-lanzador cuya tabla de espacios y de conjuros preparados coincide exactamente con la que ya usan Paladín y Explorador (`progression: "half"`, sin tocar el motor); lo que sí obligó a tocar el motor fueron sus trucos, que crecen a niveles 1/10/14 en vez de 1/4/10, y media docena de recursos (Magia de Manitas, Chispa de Genialidad y uno por subclase) cuyo máximo es un modificador de característica y no el nivel de personaje. Se sumaron `SpellcastingEffect.cantripIncreases` y `ResourceEffect.maxFromAbility`, ambos opcionales y sin efecto sobre ninguna de las 8 clases y 2 subclases lanzadoras existentes. Réplica de Objeto Mágico, Defensor de Acero, Cañón Arcano, Elixir Experimental, Armadura Arcana y Atlas del Aventurero no tienen modelo mecánico propio en el motor —objetos mágicos temporales y compañeros con estadísticas propias son mecánicas que no existen todavía— así que van como texto descriptivo, la misma convención que ya usan los conjuros siempre preparados de las 48 subclases del PHB. La lista de conjuros del Artífice tiene 80 conjuros; 79 ya estaban en el catálogo y solo hizo falta agregarles la clase, y el conjuro nuevo del capítulo (**Sirviente Homúnculo**) se cargó como `foa_2025`, el primer conjuro con esa procedencia. El catálogo llegó a **389 conjuros**. **Corrección posterior de contenido PHB 2024**: cinco ids apuntaban a un conjuro distinto del que llevaban de nombre (`feeblemind`, `branding-smite`, `snare`, `dispel-good-and-evil`, `holy-word`) y se realinearon; sumados los 8 conjuros que quedaban sin cargar (Ofuscación, Castigo Brillante, Cordón de Flechas, Disipar el Bien y el Mal, Palabra Divina, Alterar los Recuerdos, Hablar con los Muertos, Tañido por los Muertos). El catálogo llega a **392 conjuros** (177 SRD, 214 PHB, 1 FoA). **Revisión completa de la clase contra el PDF del capítulo 1**: la tabla de rasgos coincide celda por celda (dado de golpe, salvaciones, entrenamiento de armadura, las 7 habilidades a elegir 2, espacios, preparados y el escalado de trucos 2/10/14) y la lista de conjuros es un **80 de 80 exacto**, nivel por nivel. Los cinco defectos que sí aparecieron: el **Artillero recibía todas las armas marciales** cuando el manual le da solo las marciales a distancia —resuelto con la media categoría `martial-ranged` en `Weapon.proficiencyKeys`, que además unificó la regla de competencia que el compilador, el validador y el wizard duplicaban—; **tres herramientas con nombre inventado** (Herramientas de Alquimista, de Tallista y Kit de Herbolario, que en el capítulo 6 son Suministros de alquimista, Herramientas de ebanista y Útiles de herborista); las competencias se **mostraban en inglés** en la ficha, capitalizando el id; la **elección de Herramientas de Artesano** no existía; y los **51 conjuros siempre preparados** de las 5 subclases vivían solo como texto. Los tres últimos se cerraron en esta tanda con `proficiency_labels.dart`, la entrada genérica `artisans-tools` y el efecto `AlwaysPreparedSpellEffect`. Ese efecto es distinto de `GrantSpellEffect` a propósito: el conjuro innato se lanza sin gastar espacio y con CD propia, mientras que el siempre preparado usa los espacios normales de la clase y lo único que lo separa de un preparado común es que no ocupa cupo. Las tablas quedaron como un rasgo por nivel (3, 5, 9, 13 y 17), así que heredan el nivel de `featuresUpTo` y de paso las subclases dejaron de estar vacías a 13 y 17. Cruce que confirma la transcripción: los 45 ids existían todos y su nivel de conjuro cae exacto en el tramo que les toca (3→nivel 1, 5→2, 9→3, 13→4, 17→5). |

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
- ~~Elecciones de ascendencia del Dracónido y del Goliat.~~ **Resuelto**: el
  PHB las llama *Linaje gigante* y *Linaje dracónico*, así que se modelaron con
  el mismo mecanismo que ya usaban Elfo, Gnomo y Tiefling. Son 6 linajes de
  gigante y 10 de dragón, etiquetados `phb_2024` porque no se pudo verificar
  que estén en el SRD 5.2.1. La resistencia del Dracónido, que antes era solo
  texto descriptivo, ahora se aplica de verdad, y el Ataque de Aliento pasó a
  ser un recurso con usos reales. Para eso `ResourceEffect` ganó
  `maxFromProficiency`: sabía escalar por nivel y por característica, pero no
  por bonificador por competencia.

## Qué contiene el SRD 5.2.1

Medido contra el PDF en español, para dimensionar cuánto del catálogo es PHB:

| Bloque | SRD 5.2.1 | Catálogo actual |
| --- | --- | --- |
| Especies | 9 (sin Aasimar) | 15 |
| Trasfondos | 4 (Acólito, Criminal, Erudito, Soldado) | 33 |
| Subclases | 12 (una por clase del PHB) | 53 |
| Dotes | 17 | 110 |
| Conjuros | 388 (PHB, cap. 7) | 392 |

El catálogo es más grande que el SRD en todos los bloques, con contenido del
PHB 2024 y, desde Q4/Q5, de *Forge of the Artificer* (2025). De los 392
conjuros, 391 vienen del capítulo 7 del PHB (177 dentro del SRD, 214 fuera) y
el único que lo excede es Sirviente Homúnculo, de *Forge of the Artificer*.
Sin la etiqueta correcta, todo esto se confundiría bajo la misma atribución.

## Pendientes abiertos al cierre de esta tanda

Ordenados por costo, del más barato al más caro:

1. ~~**Texto de 2014 en Resistente**~~ — **resuelto**, y no era una sola dote.
   Comparar las 75 dotes del capítulo 5 contra el catálogo, término a término,
   encontró **diez descripciones que hablaban de otra edición**: Resistente
   (`durable`), Mente Aguda, Azote de Magos, Acechador, Centinela, Atleta,
   Combatiente con Dos Armas y las tres de entrenamiento con armadura. Todas
   reescritas contra el manual.

   Dos eran defectos mecánicos, no de texto: **los escudos estaban en la dote
   equivocada** —el manual los concede con la armadura ligera, no con la
   media— y **Experto en Ballestas y Maestro en Escudos no daban su Mejora de
   Característica**. Hay un test que fija el reparto de armaduras.
2. ~~**Nomenclatura de dotes**~~ — **resuelto**. Eran **33 dotes con nombre
   inventado**, no las tres que estimaba este punto: Robustez era *Duro*,
   Artesano era *Fabricante*, Cazamagos era *Azote de Magos*, Ambidiestro era
   *Combatiente con Dos Armas*, Tirador de Élite era *Tirador de Primera*, y
   así. Los cuatro estilos de combate llevaban un prefijo "Estilo de Combate:"
   que el manual no usa, y solo cuatro de los diez.

   El id no se toca —es el nombre en inglés y la clave que viaja en los
   personajes guardados—, así que renombrar es seguro. Después del cambio las
   75 entradas del capítulo emparejan con el catálogo **sin una sola
   excepción**, que es lo que confirma que el mapeo está completo.

   Dos pares se parecen lo bastante como para intercambiarse y se verificaron
   por su texto y prerrequisito: *Maestro en Armaduras Pesadas* (reducción de
   daño) contra *Maestro en Armas Pesadas* (propiedad Pesada), y *Combate con
   Dos Armas* (estilo) contra *Combatiente con Dos Armas* (dote general).
   Renombrar `crafter` deshizo además una colisión: el trasfondo Artesano y la
   dote Artesano compartían nombre.

   Queda pendiente la nomenclatura fuera de las dotes (Aprendiz de Mucho,
   Sentir el Peligro, Truco Potente).
2b. **Elección de característica en 16 dotes más**: el manual ofrece elegir
   entre dos o tres características y el catálogo asigna una sola. Alcanza a
   Atleta, Atacante a la Carga, Combatiente con Dos Armas, Apresador, Muy
   Acorazado, Maestro en Armaduras Pesadas y Medias, Líder Inspirador,
   Ligeramente y Moderadamente Acorazado, Combatiente Montado, Observador,
   Veloz, Telequinético, Telepático y Experto en Habilidades. Diez dotes más
   directamente **no dan su Mejora de Característica** porque su elección no
   se podía expresar. Es el mismo defecto que ya se resolvió para Influencia
   Feérica y compañía, y se arregla igual: variantes con `exclusiveGroup`.
3. ~~**Elección de característica en dotes**~~ — **resuelto**. No hizo falta el
   efecto nuevo que se preveía acá: se dividieron en variantes por
   característica con `exclusiveGroup`, el patrón que ya usaban Resiliente e
   Iniciado en la Magia. Alcanzó a Tocado por la Sombra, Tocado por lo Feérico,
   Cocinero, Triturador, Perforador y Tajador.
4. ~~**Estilo de Combate de Paladín y Explorador**~~ — **resuelto**. Ambos lo
   declaran a nivel 2 y el asistente de subida de nivel tiene un paso de
   elecciones que lo pide. La solución que proponía este punto
   (`fightingStyleLevel: int`) quedó superada: se hizo con
   `FeatureChoiceEffect`, un efecto que vive dentro del rasgo de clase y hereda
   el nivel de `featuresUpTo`, así que también resuelve cantidad y reemplazo.
   `grantsFightingStyle` se eliminó y `Character.fightingStyleId` pasó a ser
   `featureChoices`, con migración v6 → v7.

   Consecuencia visible: un Paladín o Explorador guardado de nivel 2 o más
   muestra `feature_choice_pending` hasta que elija, porque nunca lo hizo.
5. **Compra de puntos**: es el tercer método oficial de puntuaciones y no existe.
   `ScoreMethod` solo tiene array estándar y 4d6. La tabla del capítulo 2 ya está
   verificada: 27 puntos, puntuaciones de 8 a 15, costes 0/1/2/3/4/5/7/9.
6. **Agotamiento e Inspiración Heroica**: ambos existen como dato pero no
   afectan ningún cálculo. En 2024 el agotamiento da −2 por nivel a las pruebas
   de d20 y −5 pies de velocidad. La Inspiración Heroica no está modelada en
   absoluto, lo que deja incompleto al **Humano**: su rasgo Ingenioso la concede
   en cada descanso largo y hoy es solo texto. Hay un choque de diseño que
   resolver: `CombatState` no alimenta `ComputedSheet` por decisión explícita,
   así que conviene aplicarlo como una capa de modificadores situacionales sobre
   la ficha ya calculada, que además sirve para el resto de las condiciones.
7. **Precio y peso del equipo**: no existen como campo en `Weapon` ni en
   `Armor`, así que no hay dónde guardarlos. Sumarlos implica campo nuevo,
   los valores de las 38 armas y 13 armaduras, y decidir si la ficha lleva
   carga. Los datos ya están en las tablas del capítulo 6. Se conecta con el
   equipo inicial: cada trasfondo ofrece un paquete de equipo **o 50 po**.
8. ~~**Invocaciones Sobrenaturales**~~ — **resuelto**. Las 28 del capítulo 3
   están cargadas como dotes de categoría `warlock-invocation` y el Brujo
   declara cuántas conoce a cada nivel (1, y sube en 2, 5, 7, 9, 12, 15 y 18
   hasta 10), revisables en cada nivel como manda la regla.

   Tres correcciones que salieron de verificar contra el manual:
   - **Son tres pactos, no cuatro.** El Pacto del Talismán es de 2014; el
     catálogo lo afirmaba y un test lo daba por bueno. El manual lo llama
     Pacto del Filo, no Pacto de la Hoja.
   - **Ninguna invocación exige un conjuro concreto**: los requisitos son nivel
     de Brujo, otra invocación, o "un truco que cause daño". El
     `requiredSpellId` que se preveía acá no hizo falta.
   - Dos celdas de la tabla no estaban en la capa de texto del PDF y las
     confirmó el usuario leyendo el manual.

   Doce conceden conjuros o visión en la oscuridad y se aplican solas; el resto
   —arma de pacto, familiar mejorado, trucos elegidos de cualquier lista— va
   como texto, que es la convención del catálogo. Se etiquetan `phb_2024`: no
   está verificado cuáles cubre el SRD 5.2.1.
9. **Objetos mágicos temporales y compañeros con estadísticas propias**: no
   tienen modelo mecánico. Réplica de Objeto Mágico, Defensor de Acero y Cañón
   Arcano del Artífice, cargados en Q5, van como texto descriptivo por esto
   mismo; sistematizarlo alcanzaría también a las invocaciones del Druida y del
   Explorador.
10. ~~**Conjuros siempre preparados fuera del Artífice**~~ — **resuelto**. Las
    19 subclases del PHB 2024 que tienen tabla la tienen cargada: 4 patrones de
    Brujo, 4 dominios de Clérigo, 2 círculos de Druida, 2 subclases de
    Explorador, 3 estirpes de Hechicero y los 4 juramentos de Paladín. Con las
    5 del Artífice son **24 subclases y 232 conjuros**.

    Se resolvió con un extractor sobre `pdftotext -raw` en vez de a mano. La
    columna de nivel no es de fiar —el OCR lee el 9 como `e)`, `ol` o `)`—
    pero el orden de las filas sí, y los tramos son fijos por progresión
    (completo 3/5/7/9, semi 3/5/9/13/17), así que los niveles se asignan por
    posición. Los nombres se resuelven contra `spells.json` y lo que no
    empareja se lee del PDF: la tabla del Errante Feérico quedó como
    excepción escrita a mano porque una ilustración le parte el orden de
    lectura.

    **La comprobación que valida la transcripción no es contar conjuros**, sino
    que cada uno entre en los espacios de su clase a ese nivel: un conjuro
    corrido de fila casi siempre rompe esa condición. Los 232 la pasan. Hay un
    test que la vigila, junto con los tramos y que ninguna subclase repita
    conjuro.

    Dos correcciones de contenido salieron de la carga: `aberrant-sorcery` y
    `clockwork-sorcery` traían la tabla pegada a otro rasgo en un solo nombre
    ("Conjuros Psiónicos / Habla Telepática"), y se separaron. Ojo con el
    Patrón Primigenio: su rasgo *Conjuros Psíquicos* es un rasgo de verdad
    —cambia el tipo de daño a psíquico—, no una tabla; la tabla es *Conjuros
    del Primigenio*.

    Queda fuera el **Círculo de la Tierra**, que tiene cuatro tablas según el
    terreno elegido; esa elección no existe en el motor y sigue como texto.
11. **Elección de herramientas**: ningún rasgo que diga "una a tu elección"
    deja elegir. El Artífice recibe `artisans-tools`, la misma entrada
    genérica que ya usan los trasfondos, y las cláusulas condicionales de sus
    subclases ("si ya tenías esta, elegí otra") quedan como texto. Resolverlo
    de verdad pide un mecanismo de elección propio, porque las herramientas no
    son dotes y no entran en `FeatureChoiceEffect`.

## Criterio de cierre

Un bloque pasa a `verificado` cuando sus datos tienen prueba de contenido, las
elecciones necesarias sobreviven serialización y migración, el motor produce la
ficha esperada y la aplicación expone el resultado sin depender de una clase
lanzadora.
