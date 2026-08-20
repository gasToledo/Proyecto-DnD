# Milantus, asistente de aventuras

Aplicación web para crear y llevar personajes de **D&D 5.ª edición con las
reglas de 2024**. Entrás con tu cuenta y encontrás tus fichas donde las
dejaste, desde cualquier navegador.

## Descripción

Milantus hace las cuentas por vos. Vos elegís especie, clase, trasfondo, dotes
y equipo, y el motor resuelve modificadores, competencias, clase de armadura,
puntos de golpe, espacios de conjuro y ataques cada vez que algo cambia. Si
una elección no cierra con las reglas, la validación te avisa y te deja
seguir igual: en la mesa la última palabra la tiene el DM, no el programa.

Las fichas viven en el servidor. Podés armar el personaje en la compu del
escritorio y abrirlo desde el teléfono cuando llega el jueves de partida, con
los puntos de golpe donde los dejaste la sesión pasada. Cada cuenta ve
únicamente lo suyo, salvo lo que elija compartir con la mesa que juega.

El contenido oficial que trae cargado sale del SRD 5.2.1, ampliado con
opciones del PHB 2024 y de *Forge of the Artificer*. Todo pasa por la misma
maquinaria, así que una dote que te inventás funciona igual que una del
manual.

## Funcionalidades

### Crear un personaje

Son ocho pasos, y cada uno muestra solo lo que aplica a lo que venís
eligiendo. El catálogo: 13 clases con 53 subclases, 15 especies con 28
linajes, 33 trasfondos, 189 filas de dotes y opciones equivalentes, 38 armas,
13 armaduras y 392 conjuros.

Las puntuaciones salen de compra por puntos, de una tirada de 4d6 o del
arreglo estándar, y el paso de equipo ya viene con lo que te dan la clase y el
trasfondo descontado, así que no tenés que ir tachando a mano.

### Subir de nivel

Otro recorrido guiado: resumen de lo que cambia, puntos de golpe, subclase
cuando toca, mejora de característica o dote, rasgos nuevos y conjuros. Al
final te muestra todo lo que se modificó antes de confirmar, para que no te
enteres a mitad de un combate.

### Llevar la ficha en la mesa

La ficha se divide en Personaje, Combate, Inventario y Notas. Desde Combate
aplicás daño y curación, sumás puntos de golpe temporales, tirás salvaciones
de muerte, marcás condiciones y concentración, gastás espacios de conjuro y
recursos de clase, y tomás descansos cortos o largos.

Nada de recalcular. Habilidades y salvaciones aparecen con su modificador y su
marca de competencia, y cada arma con su ataque, su daño y la maestría que le
corresponda.

### Ordenar tu roster

El dashboard tiene buscador por nombre o clase, y orden por nombre, nivel,
clase, más recientes o manual. Para el orden manual, mantené pulsada una
tarjeta y arrastrala sobre otra: queda en esa posición y no se mueve más.

Un personaje puede marcarse como favorito desde el menú de la tarjeta. Va
siempre primero, con una estrella junto al nombre y el borde dorado, ordenes
como ordenes el resto.

### Retratos

Podés subir una imagen tuya o generarla con IA desde la ficha. Pollinations
funciona sin configurar nada. Si quien administra el servidor cargó las claves
de Azure AI Foundry, también aparecen Flux y gpt-image-2. Las claves nunca
llegan al navegador.

### Contenido propio

Desde la sección Homebrew creás armas, armaduras, dotes, especies, trasfondos
y conjuros propios, que quedan en tu cuenta y aparecen mezclados con el
contenido oficial en el asistente, en la subida de nivel y en la ficha.

### Modo DM

El botón **Modo DM**, junto a tu cuenta en el panel lateral, abre el otro
sombrero de la misma cuenta: en vez de tus personajes, tus campañas. No hace
falta una segunda cuenta para dirigir, ni deja de existir la primera: entrás
cuando dirigís y volvés atrás cuando terminaste.

Para que un jugador entre a tu mesa, él abre su personaje, toca **Compartir** y
te pasa el código que aparece. Vos lo pegás en **Sumar personaje** dentro de la
campaña y desde ahí ves su ficha con los puntos de golpe y la clase de armadura
al día — no es una copia, es la ficha real, así que lo que él cambie lo ves vos.
Lo que no podés es editarla: el personaje sigue siendo suyo.

El código sirve una sola vez y vence a las 24 horas. El vínculo se corta desde
los dos lados —vos con **Echar personaje**, él dejando de compartir— y ninguna
de las dos cosas toca la ficha. Cada vez que algo de esto pasa, a la otra parte
le llega el aviso la próxima vez que abre la aplicación.

La pestaña **Capítulos** divide la campaña en tramos: cada uno con su nombre y
su descripción, y pasando de **Próximamente** a **En marcha** y a **Completado**.
Solo podés tener uno en marcha a la vez. Al cerrar uno, a cada jugador de la
mesa le llega el aviso — y si marcaste que ese capítulo sube de nivel, el aviso
se lo dice. Subir de nivel lo sigue haciendo cada jugador desde su ficha: la
aplicación no se lo aplica a nadie. La descripción que escribís en un capítulo
es solo tuya, los jugadores no la ven.

Dentro de una campaña, la pestaña **Combate** lleva el orden de iniciativa de
tu mesa: sumás a tus jugadores con la iniciativa que tiraron y monstruos del
bestiario, que tiran la suya sola (cada copia la suya, nunca la misma para
todo un grupo). Avanzás turno y ronda, y sos vos quien lleva los puntos de
golpe de los monstruos — los de tus jugadores los ve en vivo, pero se los
siguen anotando ellos en su propia ficha, para que sigan atentos a la mesa.
El jugador al que le toca recibe un aviso discreto en su ficha un turno antes,
sin enterarse de nada más: ni el orden, ni contra qué está peleando.

### Respaldos y traspaso

Exportás un personaje suelto, o un ZIP completo con todas las fichas, los
retratos, el homebrew y las preferencias. No incluye ninguna credencial.

Al importar, un id que ya exista en la cuenta se reasigna a uno libre en vez
de pisar lo que había, así que importar el mismo respaldo dos veces no
duplica ni pierde nada.

### Tu cuenta

El pie del panel lateral muestra con qué cuenta estás entrando, útil cuando
compartís el navegador o tenés más de una. El botón de cerrar sesión termina
también la sesión del proveedor de identidad. La próxima vez te pide
credenciales de verdad.

La sesión viaja en una cookie que el JavaScript de la página no puede leer, y
la identidad la maneja Zitadel autoalojado. Los formatos de personaje,
homebrew y ajustes están versionados: una ficha vieja se migra sola al abrirla
y una de una versión futura se rechaza sin tocarla.

## Cambios a futuro

Cada personaje usa una sola clase por ahora. Multiclase es lo próximo grande,
y la arquitectura dirigida por efectos ya está pensada para soportarla sin
rehacer la ficha.

El Modo DM sigue creciendo: hoy son campañas, las fichas de los jugadores
vinculadas, los capítulos y el seguidor de combate. Falta el cuaderno de
campaña, y que un capítulo pueda repartir oro y objetos además de avisar que
toca subir de nivel.

Después de eso: la foto de perfil de la cuenta en el panel lateral (hoy se
guarda pero no se dibuja) y poder marcar varios favoritos en vez de uno.

## Puesta en marcha

El stack completo se levanta con `docker compose up -d --build` a partir de
`docker-compose.yml` y `.env.example`. El procedimiento paso a paso, incluido
el registro manual de la aplicación en Zitadel, está en
[docs/Informacion tecnica del proyecto/despliegue.md](docs/Informacion%20tecnica%20del%20proyecto/despliegue.md),
junto con respaldo, restauración y las comprobaciones de seguridad previas a
publicar un dominio.

Para tocar el código hacen falta Dart y Flutter en el `PATH`. Cada paquete se
prueba por separado, con `dart test` en `packages/dnd_engine` y
`packages/dnd_server`, o `flutter test` en `packages/dnd_app`. Conviene además
instalar el hook que formatea los archivos preparados, porque CI verifica el
formato antes que nada y un commit sin formatear falla sin llegar a decir nada
útil sobre el código:

```sh
git config core.hooksPath .githooks
```

El cliente mantenido es web y `main` es el único tronco activo. Los cambios se
validan localmente, se commitean y pushean directamente a `main`, y después se
siguen CI y, cuando el cambio toca rutas desplegables, CD hasta comprobarlos en
la web desplegada. La dirección visual, los componentes permitidos y el flujo
completo están en la
[Guía de Diseño Web](docs/Informacion%20tecnica%20del%20proyecto/guia-diseno-web.md).

## Reglas y licencia

Esta obra incluye material procedente del documento de referencia del sistema
5.2.1 ("SRD 5.2.1") de Wizards of the Coast LLC, disponible en
<https://www.dndbeyond.com/srd>. La licencia sobre el SRD 5.2.1 se concede de
acuerdo con la licencia internacional de atribución/reconocimiento 4.0 de
Creative Commons, disponible en
<https://creativecommons.org/licenses/by/4.0/legalcode>.

El catálogo ampliado puede contener opciones del PHB 2024 que no forman parte
del SRD. Se identifican por separado y no se presentan como contenido CC.
