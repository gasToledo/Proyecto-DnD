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

### Regla de descarte: nada de 2014

Cualquier material de la edición **2014** —el PHB viejo, un SRD 5.1 o anterior,
*Eberron: Rising from the Last War* (2019), o una página que no aclare de qué
edición habla— **no es fuente válida**. Se ignora y se busca la versión 2024 del
mismo contenido; si no existe, el contenido no entra. No se porta a mano.

Esto sale de la evidencia de esta misma auditoría, no de una preferencia. Los
defectos más caros que aparecieron no eran datos faltantes sino **texto de 2014
bajo un nombre correcto de 2024**: Furia Implacable dejaba al Bárbaro en 1 PG,
Golpes Potenciados volvía mágicos los golpes del Monje, el nivel 18 de
Hechicería Dracónica seguía siendo Presencia Dracónica, `feeblemind` reducía
Inteligencia a 1, y diez descripciones de dote hablaban de otra edición.
Ninguno lo delataba una tabla: el id apuntaba bien y la progresión cuadraba.

Consecuencia práctica: ante un rasgo que se lee raro, **sospechar del texto
antes que del nombre**, y contrastarlo con el manual 2024 aunque la tabla diga
que está bien.

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
| Cierre exhaustivo 2026-08-11 | verificado con límite de infraestructura | Se completaron las correcciones de PHB 2024, SRD 5.2.1 y *Forge of the Artificer*: 13 clases, 53 subclases, 15 especies, 28 linajes, 33 trasfondos, 189 filas de dotes/opciones, 38 armas, 13 armaduras, 392 conjuros y 107 criaturas. La procedencia final de dotes es 26 SRD / 135 PHB / 28 FoA; la de conjuros es 339 / 52 / 1. Pasaron análisis, pruebas de motor/servidor/app, build WEB release y smoke test real del bundle en navegador. El smoke comprobó arranque, dashboard, apertura de creación y distintivos PHB 2024 / SRD 5.2.1 / Forge 2025 sin errores de consola. No se validaron contra una instancia real OIDC/PostgreSQL el guardado, la recarga, la importación/exportación ni la subida de nivel; esos recorridos quedaron cubiertos por pruebas automatizadas, no por infraestructura integrada. Las filas históricas inferiores conservan el estado que tenían cuando se escribió cada pasada y no sustituyen este cierre. |
| Especies y linajes | en revisión | **Las 10 especies del catálogo son exactamente las 10 del PHB**, y coinciden los linajes de Elfo (3) y Gnomo (2), la ausencia de linaje en Orco y Aasimar, y la velocidad de 35 pies del Goliat. **El Linaje gigante del Goliat (6) y el Linaje dracónico del Dracónido (10) ya son elecciones persistidas y con efecto mecánico**, modeladas como linajes porque así los llama el PHB; el catálogo llega a 24 linajes. La resistencia del Dracónido dejó de ser texto y el Ataque de Aliento es un recurso con usos iguales al bonificador por competencia. **La elección de tamaño ya es una elección persistida** en Humano, Tiefling y Aasimar (Mediano o Pequeño), con `Race.sizeOptions` en el catálogo, `Character.chosenSize` en la ficha y `ComputedSheet.size` resolviéndola; no necesitó migración porque ausente significa "sin elegir" y compila al tamaño de la especie. Falta la misma elección en las 5 especies de FoA —dato, no mecanismo: las fuentes locales no traen su rasgo Tamaño—. **El cambio de truco tras un descanso largo también está**, con `GrantSpellEffect.replaceableFrom` declarando de qué listas sale el reemplazo (Alto Elfo de Mago; Don Feérico del Khoravar de Clérigo, Druida o Mago) y `Character.innateCantripChoices` guardando la elección. |
| Magia de linaje | corregido | INT/SAB/CAR ahora es una elección persistida. Se agregó Artificio Druídico al Elfo de los Bosques y se corrigieron los usos de Hablar con los Animales del Gnomo de los Bosques. |
| Procedencia del catálogo | en revisión | `ContentSource` ya conoce `phb_2024` y `foa_2025` (antes degradaba a `homebrew` en silencio), con la procedencia visible en la app. Estado actual del etiquetado: subclases 12 SRD / 36 PHB / 5 FoA, dotes 9 / 73 / 28, trasfondos 4 / 12 / 17, conjuros 177 / 214 / 1, especies 9 / 1 / 5. Cerrado en todos los bloques salvo equipo, que sigue sin desglose por procedencia. |
| Trasfondos | corregido | **Cierra Q3**: los 4 trasfondos que faltaban, cargados con los datos del bloque de características de cada uno en el capítulo 4 (más confiable que la tabla resumen de creación de personaje, que quedó cortada por columnas en la extracción). Acólito y Erudito son `srd_2024`; Guía y Marinero, `phb_2024`. Trajeron dos dotes de origen que no estaban: **Iniciado en la Magia (Druida)** y **Matón de Taberna**, con el mismo texto que las variantes de Mago y Clérigo ya cargadas. El catálogo llega a **16 trasfondos y 59 dotes**. Falta verificar las tres características ofrecidas y el equipo inicial de los 16. |
| Puntuaciones | corregido | Verificados contra el capítulo 2: el array estándar (15, 14, 13, 12, 10, 8), la tirada de 4d6 quedándose con los tres más altos, el aumento de 3 puntos del trasfondo en sus dos repartos (+2/+1 y +1/+1/+1) y el tope de 20. **Cargada la compra de puntos**, el tercer método oficial: 27 puntos, puntuaciones de 8 a 15, con costes 0/1/2/3/4/5/7/9. La tabla vive en el motor y la pantalla muestra el coste del próximo escalón, que es lo único que el número por sí solo no dice (de 13 a 14 cuesta 2, no 1). |
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
- Alto Elfo: Prestidigitación, Detectar Magia y Paso Brumoso. El reemplazo del
  truco tras cada descanso largo ya está modelado; los conjuros de nivel 3 y 5
  siguen siendo fijos, que es lo que dice el manual, y hay un test que lo fija.
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

### Pendientes derivados (HISTÓRICO)

> Cerrados. Ver [Estado verificado — 2026-08-24](#estado-verificado--2026-08-24).

- ~~Elección Pequeño/Mediano para Humano, Tiefling y Aasimar.~~ **Resuelto**.
  `Race.sizeOptions` declara los tamaños entre los que se elige y vacío
  significa "sin elección", que es el caso de las otras 12 especies;
  `Character.chosenSize` persiste la elección y `ComputedSheet.size` la
  resuelve, así que la UI nunca lee `Race.size` —que para estas tres es solo el
  valor por defecto—.

  **No hizo falta migración**: ausente se lee como null y null significa "sin
  elegir", que compila al tamaño de la especie. Una ficha vieja da exactamente
  la misma ficha que antes.

  El compilador **revalida contra el catálogo en cada compilación** en vez de
  confiar en el dato guardado: un personaje puede traer un tamaño que su
  especie ya no ofrece —cambió de especie, o desapareció el homebrew que lo
  declaraba— y ahí vale más caer al de la especie que mostrar un tamaño que
  nada respalda. El validador avisa en los tres casos: falta elegir, el valor
  no es una opción, y la especie no elige tamaño.

  Queda fuera la elección de tamaño de las **5 especies de FoA**: ni el
  markdown del PHB ni el de FoA traen el rasgo Tamaño —los capítulos de especie
  son índices, como ya advertía la nota de fuentes— y los PDF no están. Es
  dato, no mecanismo: agregarlas es completar `sizeOptions`.
- ~~Cambio de truco del Alto Elfo después de un descanso largo.~~ **Resuelto**,
  y con él el Don Feérico del Khoravar, que es la misma regla.

  `GrantSpellEffect.replaceableFrom` declara **de qué listas** se puede tomar el
  reemplazo, y vacío —el caso normal— significa que el conjuro es fijo. Es una
  lista y no un id porque el Khoravar elige entre tres (Clérigo, Druida o Mago)
  y el Alto Elfo entre una (Mago). Se declara por id de clase y no enumerando
  conjuros, así que sumar contenido no toca el motor: las opciones salen de
  `spellsForList`, la misma consulta que usa la magia de clase.

  El reemplazo vive en `Character.innateCantripChoices`, indexado por el
  conjuro **del contenido** y no por el elegido: así volver al original es
  borrar la entrada, y cambiar de linaje deja el dato huérfano en vez de pisar
  otro rasgo. `InnateSpell` expone `grantedSpellId` y `replaceableFrom` para
  que la UI no recorra los efectos del linaje por su cuenta.

  Tampoco necesitó migración: ausente es "sin cambios".

  El compilador revalida en cada compilación, como con el tamaño. El reemplazo
  tiene que existir, **tener el mismo nivel** que el original —un truco se
  cambia por otro truco, no por un conjuro de nivel 1— y estar en alguna de las
  listas declaradas; si no, se ignora en silencio. El recurso de usos se indexa
  por el conjuro original, para que cambiar el truco no devuelva usos gastados.
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

## Invocaciones del Brujo — 2026-08-05

Revisadas las 28 contra `docs/Datos de Clases/Brujo.md` (texto del PHB 2024).
Las descripciones son todas 2024 legítimo; no apareció ningún resto de 2014.

- **Los pactos no son exclusivos entre sí y no hace falta ninguna regla que los
  limite.** En 2024 la Dádiva de Pacto dejó de ser un rasgo aparte: Cadena, Filo
  y Grimorio son invocaciones normales, sin prerrequisito, y tener más de una es
  legal —cada una gasta su invocación—. Lo que la regla prohíbe es repetir la
  *misma* invocación "salvo que su descripción lo diga", y ninguno de los tres
  lo dice. El catálogo ya lo modelaba bien (sin `exclusiveGroup`) y el validador
  ya cubría el duplicado con `feat_duplicate`. **Sin cambios.**
- **Corregido un nombre inventado**: `arcane-smite` / "Castigo Arcano" era
  *Eldritch Smite*, ahora `eldritch-smite` / "Castigo Sobrenatural". El texto de
  la regla siempre fue el correcto, así que es el defecto inverso al habitual:
  falla el nombre, no el contenido. Migración de personajes 10 → 11.
- **Corregido**: las 4 invocaciones repetibles (Descarga Agónica, Descarga
  Ahuyentadora, Lanza Sobrenatural, Lecciones de los Primeros) no se podían
  repetir desde la interfaz, así que el brujo perdía una invocación que las
  reglas le permiten. El dato, el modelo y el compilador ya lo soportaban; el
  chip de la subida de nivel ahora lleva contador.

Deuda que queda anotada, sin efecto en la ficha:

- **A qué truco se ata cada copia de una repetible** no se registra. Las cuatro
  son sólo descriptivas hoy (Descarga Agónica no suma el modificador por Carisma
  al daño, porque el motor no modela el daño de un truco elegido), así que
  repetirlas es contabilidad de invocaciones. Modelarlo pide un `Effect` nuevo.
- **Filo y Grimorio no tienen mecánica**: no hay arma de pacto, ni competencia
  con ella, ni ataque con Carisma, ni los trucos y rituales del Libro de las
  Sombras. Cadena es el único con efecto real (`find-familiar` a voluntad).
- **Vista del Diablo** se modela como visión en la oscuridad de 120 pies, que es
  una aproximación: la regla ve con normalidad en oscuridad **mágica**, y la
  visión en la oscuridad no.

## Advertencias que ahora se pueden resolver — 2026-08-05

La arquitectura ya asumía "migrar → dejar hueco → advertir", pero faltaba el
tramo final: no había edición post-creación, así que una ficha de nivel alto que
quedaba con una elección pendiente tras una actualización de contenido sólo se
arreglaba recreando el personaje.

Las advertencias de la ficha traen ahora un botón **Resolver** cuando hay editor.
El mapeo `code` → editor vive en la aplicación (`ui/sheet/general_section.dart`)
y no en el motor: `code` ya es el identificador estable que fijan los tests, y un
código sin editor simplemente no muestra botón. Cubre `size_pending`,
`size_invalid`, `lineage_pending`, `lineage_missing`, `lineage_wrong_race`,
`species_spellcasting_ability_pending`, `feature_choice_pending` y
`proficiency_choice_count`. Los editores encadenan solos: elegir un linaje que
lanza conjuros destapa la advertencia de la aptitud mágica, con su propio botón.

La tarjeta de advertencias además distingue `info` de `warning`, que el motor ya
diferenciaba y la interfaz ignoraba: lo pendiente salía en carmesí como si la
ficha estuviera rota.

Siguen sin editor `asi_pending` y `subclass_pending`, que son los caros: viven
pegados al asistente de subida de nivel, que siempre asume nivel+1. No los pide
una actualización de contenido —los niveles de mejora y de subclase son estables
por clase—, así que sólo aparecen en fichas ya inconsistentes.

## Pendientes abiertos al cierre de esta tanda — 2026-08-07 (HISTÓRICO, ya cerrado)

> **Esta sección no es una lista de trabajo pendiente.** Se conserva como
> registro de las decisiones, porque explica *por qué* se resolvió cada punto
> como se resolvió. Todo lo que abajo dice «falta», «bloqueado» o «no existe»
> se construyó después: ver
> [Estado verificado — 2026-08-24](#estado-verificado--2026-08-24) al final del
> documento. Ante la duda, la autoridad es el código, no este archivo.

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
2b. ~~**Elección de característica en el resto de las dotes**~~ — **resuelto**.
   Eran **26 familias**: dieciséis que asignaban una sola característica donde
   el manual ofrece dos o tres, y diez que directamente **no daban ninguna
   Mejora de Característica** porque su elección no se podía expresar y el
   campo se había quedado vacío. Divididas en variantes con `exclusiveGroup`,
   el catálogo pasa de 146 a **183 dotes** y las 75 del capítulo quedan
   representadas por 127 registros.

   Lo que faltaba y ahora está: **una migración de ids de dote** (v7 → v8).
   Dividir hace desaparecer el id viejo, y sin migración una ficha guardada
   pierde la dote en silencio. Cada id apunta a la variante con la
   característica que el catálogo asignaba, así que la ficha compila idéntica;
   las diez que no daban ASI sí cambian, porque ganan el +1 que les
   correspondía. La migración repara además las **seis dotes divididas en la
   tanda anterior**, cuyos ids llevaban tiempo huérfanos.
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
5. ~~**Compra de puntos**~~ — **resuelto**. `ScoreMethod` gana `pointBuy` como
   cuarto método (los otros tres eran array estándar, 4d6 y escribir a mano).
   La tabla del capítulo 2 vive en el motor junto a `standardArray`, no en la
   UI: 27 puntos, de 8 a 15, costes 0/1/2/3/4/5/7/9.

   Es el segundo método que **no reparte pool**, así que escribe
   `assignedScores` directamente, como `manual`. Se diferencia en que su estado
   de partida —las seis en 8— ya es un reparto legal, y por eso el paso nunca
   bloquea: no hay nada "sin asignar" que exigir. `clearScores` vuelve al
   mínimo en vez de vaciar, porque las seis vacías no son un estado alcanzable.

   Lo que la UI tenía que mostrar y no se deduce del número: **el coste del
   próximo escalón**. La tabla no es lineal —de 13 a 14 cuesta 2, no 1— y sin
   eso subir de 9 a 10 parece valer lo mismo que de 14 a 15. El presupuesto es
   quien frena la subida, así que un reparto inválido no se puede construir
   desde la pantalla.

   Un borrador guardado **no se confía**: se acepta solo si las seis están en
   rango y el total entra en los 27; si algo no cierra vuelve al mínimo, en vez
   de restaurar un reparto que la UI no habría podido producir.
6. ~~**Agotamiento e Inspiración Heroica**~~ — **resuelto**, y de paso quedó
   claro que el nombre estaba mal: el SRD 5.2.1 en español lo llama
   **Cansancio**, no Agotamiento. El id sigue siendo `exhaustion`, que es la
   clave estable que viaja en los personajes guardados.

   El choque de diseño se resolvió como se preveía —una capa sobre la ficha ya
   calculada, `applyExhaustion` en `engine/exhaustion.dart`, encadenada después
   de `applyWildShape`—, pero el punto fino no era ese sino **dónde entra el
   −2 por nivel**. Descontarlo de `abilityModifiers` habría sido más corto y
   habría bajado también el daño, la CD de conjuros, los PG máximos, la CA y la
   capacidad de carga, que no son tiradas. Se agregó `ComputedSheet.d20Modifier`
   —que solo leen los getters de tirada— y el getter `abilityCheck`, que faltaba:
   la ficha leía `abilityModifiers` directo para la prueba de característica.
   `savingThrow` y `skillModifier` se apoyan en él, así que la Percepción pasiva
   cae sola. La contraprueba de que nada más se movió está en
   `exhaustion_test.dart` y es la mitad del valor del archivo.

   Prerequisito que salió al paso: **`ComputedSheet`, `Attack` y `Spellcasting`
   no tenían `copyWith`**, y `applyWildShape` los reconstruía campo por campo.
   Se le habían perdido dos por el camino —`skillBonuses` y `carriedWeight`—,
   así que un druida transformado quedaba sin su bono de Orden Primordial y con
   la mochila en cero. Reescribirlo sobre `copyWith` lo arregló de arrastre.
   Hay un test con `dart:mirrors` que compara los campos de la clase contra los
   parámetros de `copyWith`: es lo único que puede atrapar el campo que todavía
   no existe.

   La **Inspiración Heroica no es un recurso de clase**, aunque como
   `ResourceEffect` se habría renderizado sola: la concede el DM a quien quiera,
   así que un elfo tiene que poder tenerla. El estado vive en
   `CombatState.heroicInspiration` (un `bool`, porque nunca hay más de una) y el
   rasgo Ingenioso del Humano solo declara *quién la gana solo*, con
   `HeroicInspirationOnLongRestEffect`. Sin migración: `false` es el valor
   correcto para un documento viejo y subir `currentSchemaVersion` por un bool
   haría que una pestaña vieja se niegue a abrir el personaje entero.

   El DM la concede desde el Modo DM **como aviso y no como escritura**
   (`POST /api/campaigns/<id>/members/<memberId>/heroic-inspiration`), con la
   prueba negativa que compara el documento del personaje antes y después.

   Nivel 6 se topea y se avisa, pero la app **no mata al personaje ni le toca
   los PG**: esa decisión es de la mesa.

   Quedan afuera a propósito, porque su disparador no es el descanso largo del
   propio personaje: la dote **Músico** (reparte Inspiración a los aliados) y
   **Guerrero Heroico** del Campeón (la gana al empezar su turno). También queda
   el Cansancio de los combatientes del Modo DM.
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
12. **Conjuros de Marca sin efecto real** — **resuelto a medias**, y la mitad
    que falta está bloqueada por dos mecanismos que no existen.

    El diagnóstico era que de las 28 dotes `foa_2025`, 27 tenían **todos** sus
    efectos como `passiveTrait` (solo texto), con Marca Aberrante Mayor como
    única excepción. El texto de cada marca declara **tres** cosas distintas y
    conviene no confundirlas, porque solo una necesitaba código nuevo.

    **Hecho: los Conjuros de la Marca.** *"Si tenés Lanzamiento de Conjuros o
    Magia de Pacto, estos conjuros se suman a la lista de esa aptitud"* era lo
    único sin equivalente en el motor: no es conceder el conjuro sino
    **habilitar a elegirlo**, gastando el cupo normal. `GrantSpellEffect` lo
    haría lanzable sin espacio y `AlwaysPreparedSpellEffect` lo dejaría
    preparado sin ocupar cupo; los dos conceden de más. Se agregó
    `SpellListAdditionEffect`, el tercero y más débil de la familia, y las 12
    marcas de casa llevan sus 9 conjuros cada una: **108 efectos**.

    La lista elegible se arma en un solo lugar, `spellsForList`, que ahora
    toma los ids extra. Eso importa más de lo que parece: la usan el wizard,
    el editor de conjuros **y el validador**, y si una sola de las tres la
    armara por su cuenta, un conjuro válido de la marca quedaría marcado como
    error. `ComputedSheet.spellListAdditionIds` es el contrato con la app,
    que pregunta a la ficha en vez de recorrer las dotes.

    Los conjuros no se transcribieron: se resolvieron por nombre contra
    `spells.json` y **los 108 emparejaron al primer intento**. La comprobación
    que valida la transcripción no es contarlos —si uno se corre de grupo el
    total no cambia— sino que **el nivel declarado en el texto coincida con el
    nivel real del conjuro**; los 108 la pasan y hay un test que la vigila
    cruzando texto y efecto nombre por nombre.

    **Falta: los conjuros propios de la marca** (*"Tenés siempre preparados
    Detectar Magia y Detectar Venenos y Enfermedades. Podés lanzar cada uno
    gratis una vez por descanso largo"*). El efecto existe —es
    `AlwaysPreparedSpellEffect` más `GrantSpellEffect`— pero el dato no se
    puede escribir todavía, por dos huecos:

    - **Aptitud mágica por dote**: el texto dice "Inteligencia, Sabiduría o
      Carisma (se elige al tomar la dote)", y `GrantSpellEffect` exige una
      `Ability` fija. `speciesSpellcastingAbility` resuelve lo mismo para
      especie y linaje, pero es un campo de `Character` para *la especie*, no
      por dote. El patrón de la casa para "dote que deja elegir" es dividirla
      en variantes con `exclusiveGroup`, y acá serían 12 × 3 = 36 dotes más su
      migración de ids.
    - **Nivel dentro de una dote**: varias marcas dicen "a nivel 3 sumás X".
      Los rasgos de clase heredan el nivel de `featuresUpTo`, pero una dote no
      tiene niveles, así que hoy el conjuro se aplicaría desde el nivel 1.

    Ninguno de los dos es difícil por separado; los dos juntos son un cambio
    más grande que este, y por eso quedan acá y no se resolvieron a medias.

13. **Barrido de rasgos que prometen una mecánica y no la aplican** — el mismo
    defecto del punto 12, buscado en todo el catálogo en vez de una familia por
    vez. Salió de una pregunta del usuario: por qué un Mago con trasfondo
    Acólito ve "Iniciado en la Magia (Clérigo)" sin haberla elegido. **Eso no
    era un defecto** —el trasfondo concede una dote de origen fija y la de
    Acólito es esa— pero al verificarlo apareció que la dote **no concede sus
    conjuros**: es solo texto.

    Método: cruzar el texto de los 645 rasgos pasivos del catálogo contra los
    efectos que declara cada uno, buscando el caso "el texto promete algo que
    el motor sabe expresar y el efecto no está". Dio **41 candidatos**, todos
    revisados a mano. Es una heurística sobre prosa: sirve para no depender de
    leer 645 rasgos de corrido, no para dictar veredictos.

    **Sin ningún bloqueo — falta solo el dato** → **corregidos en esta tanda**,
    los cuatro con test de regresión:

    - **Velocidad del Mensajero** (`mark-of-passage`): "tu velocidad aumenta 5
      pies", sin condición → `SpeedBonusEffect`.
    - **Don de la Tormenta** (`mark-of-storm`): "resistencia al daño de
      relámpago", sin condición → `ResistanceEffect`.
    - **Errante** (Explorador, nivel 6): "+10 pies si no llevás armadura
      pesada". El **Bárbaro ya tenía esa misma regla aplicada** en Movimiento
      Rápido (nivel 5) con `UnarmoredMovementEffect(10, heavyArmorOnly: true,
      allowShield: true)`: mismo efecto, mismos números, misma condición. Al
      Explorador le faltaba la línea, y el test lo comprueba igual que al
      Bárbaro —media armadura y escudo lo conservan, la pesada lo anula—.
    - **Don Feérico** del Khoravar → `GrantSpellEffect` de Amistad. Entró sin
      mecanismo nuevo porque el truco es **concreto**, no a elección. La
      aptitud del JSON es solo el valor por defecto: el compilador la
      reemplaza por `speciesSpellcastingAbility`, igual que con el Tiefling,
      así que la elección del jugador ya funciona. Lo único que sí era una
      elección —cambiar el truco tras un descanso largo, la misma deuda del
      Alto Elfo— **también se cerró**: ver el pendiente derivado de la primera
      pasada. El Khoravar es el caso que obligó a que `replaceableFrom` fuera
      una lista, porque toma el reemplazo de tres listas y no de una.

    Las dos primeras son de las marcas que acaba de tocar el punto 12: se
    cargaron las tablas de conjuros y quedaron sin aplicar los beneficios
    pasivos de la misma dote. Vale como advertencia de método: cargar la parte
    grande de un rasgo no garantiza haber mirado el resto.

    **Bloqueados por elegir un conjuro dentro de una dote:**

    - **Iniciado en la Magia** en sus tres listas (Mago, Druida, Clérigo).
      Pesa más que el resto porque **Acólito, Erudito y Guía la conceden a
      nivel 1**, así que afecta a cualquier personaje con esos trasfondos.
    - **Magia Aberrante** (`aberrant-dragonmark`), con una diferencia útil: su
      aptitud es **Constitución fija**, así que le falta solo la elección de
      conjuro y no la de característica.
    - **Preparación de la Marca** (`potent-dragonmark`) no se resuelve con
      dato: "siempre preparados los conjuros de tu lista de Conjuros de la
      Marca" depende de qué marca tenga el personaje, así que necesita leer
      otra dote en tiempo de compilación.

    **Elegir una competencia** no existía fuera del `skillChoiceCount` de
    especie y clase. **Resuelto para dotes** con `ProficiencyChoiceEffect`:
    Habilidoso (3, entre habilidades y herramientas) y Mente Aguda (1 de 5)
    ya se eligen en el paso de Aptitudes y llegan a la ficha.

    Es un mecanismo aparte del de especie y clase a propósito. Esa elección es
    fija —las mismas para un personaje— y esta aparece y desaparece con la
    dote; además puede caer sobre una **herramienta**, que `chosenSkills` no
    sabe representar, así que las elegidas viven en
    `Character.chosenProficiencies` con habilidades y herramientas mezcladas y
    el compilador las separa contra el catálogo. `ProficiencyChoiceSlot` es el
    contrato con la app, con las opciones ya expandidas.

    Detalles que sí importan: el selector **no ofrece las entradas genéricas**
    (`artisans-tools`, `gaming-set`, `musical-instrument`), porque son "una de
    esta familia a tu elección" y elegirlas dejaría al personaje sin
    competencia concreta; lo que ya se tiene por otra vía se muestra bloqueado,
    para no gastar la dote dos veces; y cambiar de dote o de trasfondo **poda**
    lo elegido, que si no quedaría concediendo algo que ninguna dote respalda.

    Pesa más de lo que parece porque **Charlatán, Noble y Escriba conceden
    Habilidoso**, así que alcanza a personajes de nivel 1 sin dote elegida.

    Sigue pendiente **Conocimiento Primigenio** del Bárbaro (nivel 3): es una
    habilidad extra por rasgo de clase, no por dote, y el efecto hoy solo lo
    declaran las dotes. En Forjado y Khoravar la habilidad **sí** estaba
    cubierta y lo que falta es la **herramienta**, que es el punto 11.

    Y quedó a la vista un hueco mayor: **Pericia (Expertise) no existe en el
    motor**. No es solo el "o pericia si ya eras competente" de Mente Aguda:
    Pícaro (niveles 1 y 6) y Bardo (2 y 9) la tienen **solo como texto**, y son
    rasgos de clase de nivel bajo. Ver el punto 14.
14. **Pericia (Expertise)** — *cerrado el 2026-08-07, a partir de una queja de
    usuario ("nunca me lo hizo elegir")*. `ComputedSheet` gana `expertiseSkills`
    y, sobre todo, `skillModifier`: la suma de modificador + competencia pasa a
    vivir en un solo lugar, y `passivePerception` es ahora un getter sobre ese
    método. Antes la cuenta estaba duplicada entre el compilador y la ficha, que
    es exactamente por lo que la Pericia no llegaba a ninguna de las dos.

    La elección reusa `ProficiencyChoiceEffect` con dos campos nuevos
    (`expertise`, `allowNewProficiency`) en vez de un efecto propio, así que
    **no hizo falta migración de ficha**: un groupId nuevo dentro de
    `proficiencyChoices` no es un cambio de esquema. Los cupos resueltos viajan
    en `expertiseChoiceSlots`, aparte de los de competencia, porque el chequeo
    de duplicados de la validación dispararía siempre para una Pericia legal (la
    habilidad ya está entre las competencias, que es el requisito). El
    compilador la resuelve en una segunda pasada, después de las competencias,
    porque las opciones son las habilidades que ya tenés.

    Cargados los **siete** rasgos, no los cuatro que este punto listaba:
    Pícaro 1 y 6, Bardo 2 y 9, Explorador 2 y 9, y Académico del Mago. Al
    verificarlos contra el manual aparecieron dos errores de contenido:
    Académico y Explorador Hábil decían "competencia (o Pericia)" cuando el PHB
    2024 dice Pericia sobre una habilidad en la que ya seas competente, sin
    alternativa; y la Pericia del Explorador a nivel 9 es sobre **dos**
    habilidades, no una.

    Mente Aguda se quedó en la primera pasada: sus opciones son una lista fija
    que no depende de lo que tengas, así que sigue siendo una elección de
    competencia que se convierte en Pericia cuando ya la tenías. Moverla le
    hacía perder la migración del campo viejo `chosenProficiencies`.

    Sigue pendiente el don épico **de la Habilidad**, que concede competencia en
    las 18 habilidades más Pericia en una: eso necesita un efecto de "todas las
    habilidades" que no existe. Queda anotado acá y **no** lo cubre el guardián:
    `feature_promises_test.dart` recorre rasgos de clase y de subclase, no
    dotes. Extenderlo a las dotes es la continuación natural de ese archivo.

    **Lo que el barrido descartó**, y conviene dejar anotado para no volver a
    levantarlo: los rasgos **condicionales o temporales** (Filo Sediento solo
    con el arma de pacto, Forma Grande del Goliat, los del Gloom Stalker en el
    primer turno), las **auras** que alcanzan a los aliados (Aura de Coraje,
    de Entrega, de Salvaguarda), los **compañeros** (Defensor de Acero, el
    familiar del Amo de las Cadenas), que son el punto 9, y los rasgos donde
    otro efecto del mismo bloque ya aplica la regla —el Legado Diabólico del
    Tiefling la aplica desde el linaje, y las seis especies que "eligen una
    habilidad" lo hacen con `skillChoiceCount`—.

    También descartó dos **falsos positivos de la búsqueda**: Maestro en Armas
    Pesadas y Maestro en Armas de Asta dicen "ataque adicional" pero se
    refieren a un ataque de acción adicional, no al rasgo Ataque Adicional.

## La prosa que promete y los efectos que no entregan — 2026-08-07

Origen: tres quejas de usuarios que resultaron ser **una sola falla con tres
caras**. El contenido declara un rasgo con una descripción en castellano y una
lista de efectos; cuando la mecánica no se modela, la costumbre fue dejar un
`passiveTrait` con el texto y seguir. El jugador lee que tiene Pericia, o que un
conjuro está siempre preparado, y la ficha no se lo da.

Las tres quejas eran ciertas, y ninguna estaba sola:

| Queja | Alcance real |
|---|---|
| El Bardo nunca le hizo elegir la Pericia | **7 rasgos** de Pericia, ninguno modelado. Ver el punto 14 |
| Los conjuros preparados de la subclase no figuran | **9 huecos** cargados (Abjurador, Círculo de las Estrellas, Druídico, Castigo de Paladín, Corcel Fiel, Contactar Patrón, Enemigo Predilecto, las dos Palabras de Creación) |
| Luz Sanadora muestra 2 curas en nivel 4 | **5 recursos** con el máximo fijo contradiciendo su propia descripción |

**Dos huecos del esquema de recursos**, no de los datos: `maxPerLevel`
reemplazaba en vez de sumar, así que no podía expresar "1 + nivel de Brujo" de
Luz Sanadora; y `maxFromProficiency` era un bool sin factor, así que no podía
expresar "dos veces tu bonificador" de Energía Psiónica. Ahora `max` es el
término constante de `maxPerLevel` (los dos usuarios previos declaran 0, así que
no cambiaron) y hay `proficiencyMultiplier`. Con eso se corrigieron Luz
Sanadora, los dos Energía Psiónica, Sacerdote Guerrero —que decía "usos = mod.
de Sabiduría" y tenía un 2 fijo— y los tramos 4/5/6 del Maestro del Combate.

**Un bug latente que nadie reportó**: `featuresUpTo` no ordenaba por nivel, y
los arrays del contenido no están ordenados (el Guerrero declara
1,1,1,4,4,10,10,16,2,2,5,…). La convención de que varios `ResourceEffect` con el
mismo id declaran tramos y **gana el de mayor nivel** cuelga de que
`SheetBuilder` los aplique en orden, porque hace `_resources[id] = e`. Se
cumplía **solo por casualidad**, cuando el autor los declaró ascendentes.
Agregar los tramos del Maestro del Combate pisaba la trampa.

**Lo que cierra el bug como clase** es `feature_promises_test.dart`: tres lints
que cruzan prosa contra efectos declarados, más un trinquete sobre la cantidad
de rasgos que solo son texto (304 de 537, y no puede subir). Tres decisiones que
hacen que no se degrade solo:

- **cada lint fija el conteo de coincidencias del patrón**. De las dos formas en
  que un regex sobre prosa escrita a mano puede fallar solo una importa: un
  falso positivo cuesta una línea de lista, pero un falso *negativo* —alguien
  reescribe una descripción y el patrón deja de verla— dejaría el test en verde
  mientras el defecto se publica. Que es la misma degradación silenciosa que se
  venía a matar, reintroducida un nivel más arriba;
- **el patrón se deriva del código cuando se puede**: los nombres de
  característica salen de `Ability.label`, así que no pueden desincronizarse;
- **las listas de exención tienen que estar agotadas**: si una entrada ya no
  coincide con su lint, el test falla. Es lo que las mantiene registro y no
  basurero. Separan falso positivo de deuda real, con el motivo escrito.

Se descartó partir los 345 `passiveTrait` en "sabor" contra "sin modelar,
razón: X": es migrar 345 entradas para guardar strings que nadie lee, cuando el
trinquete da la misma señal en una línea y el historial de git de ese número es
el registro con la explicación en el commit que lo movió.

También se descartó un lint de **groupId únicos** que parecía obvio: su premisa
era falsa. El compilador **suma** los `count` de los `ProficiencyChoiceEffect`
que comparten groupId (`character_compiler.dart`) y los `FeatureChoiceEffect`
los comparten a propósito para declarar tramos por nivel, igual que los
recursos. Compartir groupId es un merge deliberado, no una colisión silenciosa.

**Deuda que queda anotada en el allowlist**, con el motivo: los Conjuros
Característicos del Mago (dos conjuros de nivel 3 a elección), los
Descubrimientos Mágicos del Colegio del Saber (dos de cualquier lista) y los dos
rasgos del Círculo de la Tierra (la tabla depende del terreno elegido). Las
cuatro necesitan mecanismos de elección que el motor no tiene.

**Reportado aparte, todavía sin cargar**: **Magia Cautivadora** del Colegio del
Glamour (Bardo, nivel 3, `subclasses.json` id `college-glamour`) es el mismo
patrón — `passiveTrait` puro, sin ningún efecto. La descripción dice "podés
lanzar Encantar Persona y Amistad más eficazmente y sin gastar espacio
limitado", pero no hay ni la ventaja/CD mejorada ni el uso gratuito sin espacio.
Bloqueado en la falta de fuente: los docs locales del PHB 2024 solo traen el
índice de esta subclase (`Player's Handbook (2024).md:2065`, una sola línea de
tabla de contenidos), no el capítulo con el texto exacto. Falta el texto del
manual para transcribir la mecánica antes de modelarla — no entra en el
allowlist de `feature_promises_test.dart` porque ese guardián solo cubre
Pericia, conjuros siempre preparados y escalado de recursos; "lanzar sin gastar
espacio con ventaja/CD mejorada" es un patrón distinto que ese archivo no mira.

## Auditoría de contenido Eberron (RftLW + FoA) — 2026-08-03

Origen: se agregaron `docs/Eberron_ Rising from the Last War.md` (2019, reglas
2014, fuente original) y ya existía `docs/Eberron_ Forge of the Artificer.md`
(2025, reglas 2024, la actualización oficial). El criterio es el mismo que
rige todo el proyecto: **FoA manda sobre RftLW** para mecánica, porque es la
versión vigente; RftLW solo aporta lo que FoA no repite.

**Limitación de la fuente**: a diferencia del PHB, ninguno de los dos
markdown trae el texto detallado de cada especie o cada dote — son índices o
placeholders (`See the Changeling entry.`, `## Feats` con una lista de
nombres). Por eso esta auditoría verificó **inventario y arquitectura
declarada**, no el valor exacto de cada rasgo palabra por palabra.

**Inventario: coincide exacto.** El capítulo 2 de FoA dice explícitamente
"17 backgrounds", "veintiocho dotes nuevas" (13 Dragonmark + 14 General + 1
Epic Boon) y "los cuatro especies introducidas en RftLW, más Khoravar" (5).
Los tres números calzan letra por letra contra el catálogo: 17 trasfondos, 28
dotes (13/14/1 por categoría) y 5 especies, mismos nombres, mismo id de
categoría.

**Casas y marcas: coincide exacto contra RftLW.** La tabla "Dragonmarks and
Their Houses" de RftLW lista 12 marcas y 13 casas (Shadow la comparten
Phiarlan y Thuranni) — son las 13 dotes `dragonmark` y los 13 trasfondos
`house-*-heir` ya cargados, sin faltantes ni sobrantes.

**Diseño de marcas como dotes: correcto, no es un defecto.** RftLW modela
cada marca como **variante de raza/subraza** (2014); FoA lo reemplaza
explícitamente por dotes — *"The benefits of each dragonmark now derive from
feats rather than species options"*, sin prerrequisito de especie. El
catálogo ya sigue el diseño de FoA (2024), que es el correcto.

**Goblinoids: no es contenido faltante.** RftLW presenta bugbears, goblins y
hobgoblins como raza jugable adicional (cap. 1, "Goblinoids"). FoA no la
retoma porque su alcance está acotado por su propio texto a "las cuatro
especies que introdujo RftLW" (Changeling, Kalashtar, Shifter, Warforged) más
Khoravar — Goblinoids nunca fue una de esas cuatro, así que quedar afuera es
la decisión de WotC en la actualización 2024, no un hueco del catálogo.

**Hallazgo real, ver pendiente 12 arriba**: los "Conjuros de la Marca" de las
28 dotes existen solo como texto (`passiveTrait`), no como efecto que la
ficha compilada aplique.

## Cierre de correcciones exhaustivas — 2026-08-11

Se ejecutaron las instrucciones de corrección sobre el proyecto WEB completo,
manteniendo como únicas reglas admitidas PHB 2024, SRD 5.2.1 y *Eberron: Forge
of the Artificer*. Las secciones anteriores se conservan como historial de la
auditoría; este apartado describe el estado final de la implementación.

Cambios cerrados:

- procedencia explícita y visible para SRD 5.2.1, PHB 2024 y Forge 2025;
- correcciones de especies, linajes, clases, subclases, dotes, equipo y
  conjuros indicadas en el plan de corrección;
- elecciones en línea de clase, prerrequisitos por clase, aptitud mágica de
  dotes, bonificaciones de habilidad, listas rituales y conjuros de marca;
- seis perfiles invocables nuevos: tres tamaños de Objeto Animado y las formas
  Ciempiés, Araña y Avispa de Insecto Gigante, con escalado por espacio;
- persistencia/migración de los campos nuevos y presentación en la ficha WEB;
- inventario final: 13 clases, 53 subclases, 15 especies, 28 linajes, 33
  trasfondos, 189 filas de dotes/opciones, 38 armas, 13 armaduras, 392 conjuros
  y 107 criaturas.

Validación ejecutada:

- `dnd_engine`: análisis sin observaciones y 972 pruebas aprobadas;
- `dnd_server`: análisis sin observaciones y 162 pruebas aprobadas;
- `dnd_app`: análisis sin observaciones y 223 pruebas Flutter aprobadas;
- `flutter build web --release --no-pub`: build generado correctamente; el
  dry-run de WebAssembly también terminó bien;
- navegador: el build real abrió el dashboard, mostró una biblioteca vacía,
  abrió el asistente de creación y expuso las insignias `PHB 2024`, `SRD 5.2.1`
  y `Forge 2025`, sin errores ni advertencias en la consola.

Límite de la validación manual: el entorno local no se conectó a una instancia
real de PostgreSQL y Zitadel. Para el smoke se usaron respuestas efímeras y
vacías de las cuatro lecturas de arranque. Por lo tanto, guardado/recarga,
subida de nivel, migración e importación/exportación quedaron validados por las
pruebas automatizadas, pero no por una sesión OIDC con base real. No se los
declara verificados manualmente.

## Criterio de cierre

Un bloque pasa a `verificado` cuando sus datos tienen prueba de contenido, las
elecciones necesarias sobreviven serialización y migración, el motor produce la
ficha esperada y la aplicación expone el resultado sin depender de una clase
lanzadora.

## Estado verificado — 2026-08-24

**Esta es la única sección vigente del documento.** Todo lo de arriba es
historial.

Nace de un error real que conviene no repetir: alguien preguntó qué quedaba
pendiente, se leyó «Pendientes abiertos al cierre de esta tanda» como si fuera
un backlog vivo, y salió una lista de diez pendientes de los cuales **ninguno**
lo era. La sección estaba cerrada desde el 2026-08-11 y lo decía… quinientas
líneas más abajo.

De ahí la regla de redacción de acá en adelante: **un pendiente se escribe con
la ruta que lo desmiente**. «Falta X» sin `archivo:línea` es prosa que envejece
sin avisar; con la ruta, verificarlo es un grep y no una lectura de 800 líneas.

Lo que sigue se comprobó contra el código y los tests, no contra este archivo.

### Cerrado en esta pasada

- **Conocimiento Primigenio** (Bárbaro, nivel 3) era el último rasgo de la lista
  histórica que seguía siendo solo texto. Ahora declara su elección de habilidad
  con `proficiencyChoice` sobre las seis de `skillChoiceFrom`
  (`classes.json`, rasgo de nivel 3 del bárbaro), con pruebas en
  `test/classes_2024_test.dart`. No hizo falta mecanismo ni migración: el efecto
  ya lo usaban ocho rasgos de clase y `proficiencyChoices` existe como mapa
  desde el esquema 9.

  La segunda mitad del rasgo —hacer como prueba de Fuerza cualquier prueba de
  Acrobacias, Intimidación, Percepción, Sigilo o Supervivencia mientras estás
  enfurecido— **queda como texto a propósito**: es una sustitución de
  característica en tiempo de tirada, y el motor no la modela. No es deuda
  olvidada; es una decisión, y hay un test que la fija.

### Abierto

| Qué | Dónde se comprueba | Estado |
|---|---|---|
| **Don épico de la Habilidad**: el texto promete «Aumenta una característica en 1, hasta un máximo de 30» y la dote no declara ningún `abilityScoreBonus` | `feats.json`, dote `boon-of-skill` | Defecto confirmado. Las 18 competencias y el cupo de Pericia sí están. Es un efecto de una línea, y `abilityScoreBonus` ya lo usan otras 93 dotes |
| **«Lanzamiento de la Marca»** de Marca Dracónica Potente: espacio de conjuro adicional de nivel ⌈nivel/2⌉ hasta 5, recuperado en descanso corto | `feats.json`, dote `potent-dragonmark` | Sin mecanismo. Es un espacio **fuera** de la tabla de la clase, que hoy no se puede expresar |
| **Los 12 `greater-mark-of-*`**: tres `passiveTrait` cada uno, cero efectos estructurados | `feats.json` | El segundo escalón de las marcas quedó sin cargar cuando se cargó el primero. Es exactamente la advertencia de método que ya dejó escrita la primera pasada: cargar la parte grande de un rasgo no garantiza haber mirado el resto |

### Sospechas sin verificar

No entran como defectos hasta comprobarlas contra la fuente, que es la
disciplina que este apartado viene a instalar:

- **Nomenclatura fuera de las dotes**: «Sentir el Peligro» y «Aprendiz de Mucho»
  (`classes.json`), «Truco Potente» (`subclasses.json`). La tanda de dotes
  encontró 33 nombres inventados; nadie hizo la misma pasada sobre rasgos de
  clase y subclase. Pide el PHB 2024 en español al lado, término por término.

### Cómo verificar sin creerle a este archivo

```bash
cd packages/dnd_engine && dart analyze && dart test
```

`test/feature_promises_test.dart` es el guardián que importa: cruza la prosa de
cada rasgo contra los efectos que declara, y su trinquete de «rasgos que solo
son texto» (hoy 300) falla si alguien **suma** uno. Es el único mecanismo del
repositorio que detecta esta clase de defecto sin que nadie lo busque a mano.
