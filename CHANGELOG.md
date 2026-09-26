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

## [0.12.0+1] - 2026-09-23

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
- Importar como PNJ el personaje que un jugador exportó desde «Mis
  personajes»: entra como PNJ con ficha, y su trasfondo y su Diario pasan al
  PNJ.
- Bandos en el combate: aliado, enemigo o neutral para PNJ y monstruos, con
  cambio de bando a mitad de combate y conteos «en pie» por bando.
- «Convertir en PNJ» desde la fila de un monstruo, conservando su lugar, sus
  PG, su bando y sus efectos.
- Al terminar y guardar un combate se puede marcar qué PNJ caídos murieron.
- El Bestiario filtra por rango de valor de desafío («VD desde» / «VD
  hasta») y ordena por nombre o por VD.
- «Sumar al combate de <campaña>» desde el perfil del Bestiario: suma las
  copias al combate de la campaña seleccionada sin salir del Bestiario ni
  perder la búsqueda y los filtros.

### Modificado

- El buscador de «Sumar al combate» encuentra criaturas sin importar acentos
  ni mayúsculas, muestra el VD de cada una y ya no corta la lista en 30
  resultados.

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

## [0.13.0+1] - 2026-09-24

### Nuevo

- Una cuenta sin personajes ofrece probar con uno de ejemplo: lo suma como
  personaje propio y abre su ficha, para recorrerla antes de crear el primero.
- Creación de personaje: con el conjunto estándar se ofrece aplicar de un
  toque el reparto que el SRD sugiere para la clase elegida.

### Modificado

- Los avisos de error ya no muestran el nombre técnico de la excepción: dicen
  qué no se pudo hacer y, cuando lo hay, el motivo en castellano.
- Textos unificados según un glosario: «especie» en lugar de «raza»
  (incluido el primer paso de creación), «bonificador» en lugar de «bonus»,
  «Borrar» en todas las acciones de borrado y «archivo» en lugar de «pack» al
  importar homebrew. Los conteos ya no usan plurales entre paréntesis.
- Las características se abrevian como en el SRD en castellano (FUE, DES,
  CON, INT, SAB, CAR) y las distancias dicen «pies» en todas partes.
- En el tema claro, el texto de los botones dorados pasa a blanco y llega al
  contraste mínimo de accesibilidad (antes quedaba por debajo).
- Un cambio de PG, en la ficha o en el combate del DM, se marca con un destello
  carmesí si bajó y verde si subió, y la barra de la ficha recorre el tramo en
  vez de saltar.
- En el combate del DM, la marca de turno pasa de una fila a la siguiente sin
  saltar, y la planilla se desplaza para que la fila del turno quede a la
  vista.
- El contenido del SRD, el homebrew, los personajes y los ajustes se piden en
  paralelo al abrir la aplicación: el arranque con sesión tarda la mitad.
- Creación de personaje: el paso «Aptitudes» pasa a llamarse
  «Competencias», los métodos de puntuación usan los nombres del SRD
  («Conjunto estándar», «Coste en puntos»), los modificadores dejan de verse
  en carmesí, el resumen incluye las habilidades que da el trasfondo y el
  pie dice qué falta sin cortarse.
- Creación de personaje en el teléfono: cada paso arranca arriba, el stepper
  sigue al paso activo, y elegir especie, clase o trasfondo baja hasta su
  detalle, donde están el linaje, el aumento de características y las
  maestrías. Al terminar se abre la ficha del personaje nuevo.
- Creación de personaje: las opciones de equipo inicial dicen qué trae cada
  una antes de elegirla, y las tarjetas de trasfondo muestran su dote de
  origen y las características a las que suma.
- `dnd_engine`: las clases del catálogo SRD declaran su reparto sugerido
  (`suggestedScores`), y `Ability.code` separa los códigos de datos en inglés
  de la abreviatura que se muestra.

### Eliminado

- Sin cambios.

## [0.13.1+1] - 2026-09-24

### Nuevo

- Sin cambios.

### Modificado

- Los estilos de combate Duelo y Tiro con Arco suman en la ficha: +2 al daño
  con un arma cuerpo a cuerpo a una mano y sin otra arma, y +2 al ataque con
  armas a distancia. Antes eran solo texto.
- Al subir de nivel, el editor de conjuros muestra los preparados en la
  creación (abría en «0 de N»), y cambiarlos desde la ficha o la subida
  reemplaza de verdad los anteriores en vez de sumarse a ellos.
- El editor de conjuros nombra la clase («Paladín») y no su identificador.
- Los estilos «Guerrero Bendito» y «Guerrero Druídico» aparecían en inglés.
- Creación de personaje: el pie de faltantes ya no deja un punto antes de
  «(y N cosas más)».
- `dnd_engine`: `WeaponRuleEffect` admite bonos fijos al ataque y al daño con
  la condición de empuñar el arma sola en una mano, y `Character` resuelve los
  conjuros por clase con `spellIdsFor`, `cantripIdsFor` y `withClassSpells`.

### Eliminado

- Sin cambios.

## [0.14.0+1] - 2026-09-24

### Nuevo

- El Códice: todo el contenido del juego para leer sin crear un personaje
  ni editar nada. Se abre desde el panel lateral; tiene búsqueda en todo el
  catálogo, una lista con filtro por categoría (nivel de conjuro, rareza,
  categoría de dote) y el detalle de cada entrada. Las criaturas usan el
  Bestiario y el perfil del Modo DM, sin nada de combate.
- Un recurso puede declarar la CD que impone y el daño que causa por tramo de
  nivel; la ficha los muestra ya calculados. El Ataque de Aliento del
  Draconato es el primero: «CD 12 de DES · 1d10».
- En un teléfono, «Subir nivel» está en la barra de la ficha, sin abrir el
  menú.
- En el inventario, el nombre de un objeto mágico o de un paquete abre su
  descripción. Hasta ahora qué hacía un objeto no se podía leer en la app.

### Modificado

- Creación de personaje: los nombres de especie, clase y trasfondo usan hasta
  dos líneas (los «Heredero de Casa…» de Eberron se cortaban); el Draconato
  muestra su Ataque de Aliento y su visión en la oscuridad.
- Subida de nivel: la subclase elegida muestra los rasgos que da en ese nivel.
- Todo el catálogo pasa a voseo: subclases, clases, dotes, especies, conjuros
  y objetos mágicos tenían «puedes», «ganas» y plurales de vosotros
  («tenéis», «podéis») mezclados con el resto, y los objetos mágicos del SRD
  estaban enteros en tuteo. `tool/apply_voseo.dart` lo vuelve a aplicar
  después de regenerar, y un test falla si vuelve el tuteo.
- Las descripciones de los objetos mágicos se vuelven a extraer del PDF: ya
  no hay palabras partidas («pue-des»), títulos metidos en medio de una
  oración ni texto de un objeto en otro, y se leen por párrafos. Vuelven las
  frases que se cortaban (el Anillo de calidez, la Baraja misteriosa entera) y
  los nombres en cursiva que faltaban. Los centímetros pasan a pies y
  pulgadas, con la escala del manual (30 cm = 1 pie, 2,5 cm = 1 pulgada), y
  los pesos a libras y onzas (0,5 kg = 1 libra, 30 g = 1 onza), que es la
  unidad de la barra de carga. Los viajes pasan a millas (1,5 km = 1 milla) y
  los volúmenes a pies cúbicos.
- Los objetos mágicos cuyo texto dice cuánto pesan suman ese peso a la carga
  (la Bolsa de contención y el morral, 5 libras; el espejo atrapavidas, 50).
  Pesaban todos 0; los que el SRD no pesa siguen en 0.
- Creación de personaje: con escudo ya no se ofrece empuñar a dos manos, y la
  mano secundaria solo aparece con dos armas; las elecciones de objeto dicen
  si son de la clase o del trasfondo; «Coste en puntos» avisa los puntos sin
  gastar; con más de una elección de competencias, cada lista dice de qué
  origen es; las características muestran su nombre completo y su ayuda ya no
  tapa el valor.
- Subida de nivel: el total de pasos no cambia al resolver una elección; los
  puntos de golpe y las elecciones de rasgos figuran como decisiones y no
  como cambios automáticos; antes de tirar no se muestra un total que parece
  el resultado; el paso de conjuros dice cuántos hay preparados y avisa los
  cupos libres; y se corrigieron textos (sin género para el personaje, sin
  «compilar», voseo en Arma Sagrada, «También ganás»).

### Eliminado

- Sin cambios.

## [0.15.0+1] - 2026-09-24

### Nuevo

- Pacto del Grimorio pide los tres trucos y los dos rituales del Libro de las
  Sombras, al crear el personaje, al subir de nivel y desde la ficha. Quedan
  siempre preparados sin ocupar cupo.
- Descarga Agónica pide a qué truco de Brujo se aplica, y la ficha muestra el
  bono al daño en ese truco y en su detalle («+4 al daño (Descarga
  Agónica)»).
- El asistente de creación pide la aptitud mágica de la dote de origen cuando
  la deja elegir (Iniciado en la Magia del Acólito, entre otros).

### Modificado

- Pasos del Feérico da tantos usos gratis de Paso Brumoso como el modificador
  de Carisma (mínimo uno), como dice la regla. Daba el bonificador por
  competencia: 2 usos a un Brujo con +3.
- La subida de nivel no se confirma con un truco o un conjuro nuevo sin
  elegir, y el resumen marca la revisión de conjuros como decisión cuando el
  nivel trae cupo nuevo. La ficha avisa si faltan trucos o conjuros
  preparados.
- Las elecciones de conjuros de una invocación tomada en la misma subida
  aparecen en el paso de conjuros a elección; antes no se veían hasta
  confirmar.
- El equipo inicial arranca puesto: armadura, escudo y armas del paquete con
  los que la clase es competente. El paso lo explica y respeta lo que el
  jugador cambie a mano.
- Las opciones de conjuros con botón de información ya no desbordan la línea
  con nombres largos.

### Eliminado

- Sin cambios.

## [Unreleased]

### Nuevo

- Sin cambios.

### Modificado

- El paso de conjuros de la subida de nivel muestra el cupo de trucos junto al
  de preparados y dice qué falta elegir. Con el conjuro listo y el truco
  pendiente decía «Conjuros actualizados» y el truco solo aparecía en el aviso
  del pie.
- La revisión final de la subida cuenta bien los trucos y conjuros elegidos:
  después de pasar por el editor mostraba «4 → 0».
- En el paso de conjuros a elección de la subida, los cupos que el nivel trae
  sin llenar van primero y los ya elegidos quedan abajo, bajo «Elegidos en
  niveles anteriores». El truco de Descarga Agónica aparecía al fondo, debajo
  del Libro de las Sombras y de Iniciado en la Magia ya completos.
- Homebrew es una sección del Modo DM, junto al Bestiario y los PNJ, y ya no
  está en el panel del jugador: crear contenido es trabajo del DM. El homebrew
  sigue siendo de la cuenta y se usa igual en sus personajes. En pantallas
  angostas sus categorías se abren desde la barra de la sección, y el menú del
  Modo DM sigue arriba para ir a otra.
- En pantallas angostas el Códice tiene la flecha de volver a la izquierda y
  las categorías en un botón a la derecha. El menú de categorías ocupaba el
  lugar de la flecha y no había forma de salir. La barra dice en qué categoría
  se está («Códice · Dotes»).
- En Homebrew, el botón de categorías usa otro ícono que el menú del Modo DM:
  en un teléfono eran dos ☰ iguales, uno encima del otro.
- Importar un PNJ con ficha suma su homebrew al catálogo en el momento. Se
  guardaba en la cuenta, pero la ficha mostraba esos objetos como «No está en
  el catálogo» hasta recargar la página.
- La dote Alerta suma el bonificador por competencia a la iniciativa, y el
  Emboscador Temible del Acechador en la Penumbra suma el modificador de
  Sabiduría. Los dos eran solo texto: un Guardia con DES +2 mostraba +2 en vez
  de +4. En Forma Salvaje el druida conserva esos bonos sobre la Destreza de
  la bestia.

### Eliminado

- El Códice ya no muestra las criaturas: lo abre cualquier jugador y los
  perfiles de los monstruos son del DM. Se siguen leyendo en el Bestiario del
  Modo DM.
