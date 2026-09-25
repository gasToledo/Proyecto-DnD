# Textos de la interfaz

Cómo le habla la app a quien juega. Vale para todo texto visible: etiquetas,
avisos, diálogos, estados vacíos y los mensajes de error que devuelve el
servidor.

## Voz

- **Voseo rioplatense**, siempre: «Elegí», «Revisá», «podés», «tenés». Nunca
  «elige», «puedes» ni «usted».
- **Sin género para quien no lo eligió**: «Lo pega en su campaña», no «Él lo
  pega». El DM y los jugadores pueden ser cualquiera.

## Ayudas y explicaciones de reglas

- Primero el efecto práctico, después el nombre de la regla.
- Nada de definiciones circulares: «Pericia es tener pericia».
- En el flujo principal, bloques de tres frases como máximo; lo demás va a un
  «Más información».
- Una advertencia importante nunca vive solo en un tooltip, que en pantallas
  táctiles no se ve.

## Glosario

El término de referencia es el del catálogo SRD en español
(`packages/dnd_engine/lib/assets/srd_2024/`). Si la app y el catálogo dicen
cosas distintas, gana el catálogo.

| Se dice | No se dice | Nota |
| --- | --- | --- |
| especie | raza | Terminología de 2024. «Linaje» es la subdivisión de una especie, no un sinónimo. |
| bonificador | bonus | «Bonificador **por** competencia», no «de». |
| salvación | tirada de salvación, TS | «SALV» solo como abreviatura en plaquetas. |
| PG | HP | «Puntos de golpe» cuando hay lugar para la forma larga. |
| CA | AC | |
| maltrecho | bloodied, ensangrentado | Con la mitad de los PG o menos, como lo define el glosario del SRD. |
| conjuro | hechizo | |
| espacio de conjuro | ranura | |
| PNJ | NPC | La colección global es la «Biblioteca de PNJ»; «PNJ» a secas es la sección de una campaña. |
| mesa | — | Los jugadores de una campaña. Dentro de Combate se dice «combate»: «Sumar al combate», «Sacar del combate». |
| DM | máster, DJ | Es el nombre del modo: «Modo DM». |
| homebrew | contenido casero | En minúscula dentro de una frase. |
| archivo (al importar o exportar) | pack | Es lo que la persona ve en su disco. |
| iniciar sesión | login | |
| FUE, DES, CON, INT, SAB, CAR | STR, DEX, WIS, CHA | `Ability.abbr`. Los códigos en inglés quedan en `Ability.code`, solo para datos. |
| pies | ft | |
| conjunto estándar, coste en puntos | array estándar, compra de puntos | Los métodos de puntuación, como los nombra el SRD. |
| habilidades (lo que se elige en creación) | competencias de clase | Se gana *competencia* en una *habilidad*. |
| el orden de tus personajes | roster | |

Los nombres de reglas que vienen del catálogo («Ataque Adicional», «Acción
Adicional» como tiempo de lanzamiento) se muestran tal como están ahí.

## Acciones

| Acción | Etiqueta |
| --- | --- |
| Borrar algo | **Borrar**, y el título del diálogo «¿Borrar …?». Nunca «Eliminar». |
| Descartar un diálogo | **Cancelar** |
| Volver a probar | **Reintentar** |
| Guardar | **Guardar** |

## Errores

Todo error empieza con **«No se pudo …»**, nunca con «Error al …».

Cuando el aviso nace de una excepción, se arma con `failureMessage(qué, error)`
(`packages/dnd_app/lib/theme/app_widgets.dart`) y nunca interpolando `$e`.
Así solo aparece un motivo si la excepción trae un texto en castellano
(`ApiException`, `FormatException`, `UnsupportedDataVersionException`), y
cualquier otro error queda en la frase sola, sin jerga ni nombres de clases.

El detalle técnico, cuando sirve, va en «Ver detalles» de `AppErrorView`.

## Búsquedas sin resultados

- En una pantalla o una lista principal, la frase completa, con lo buscado:
  `Ningún personaje coincide con «Sagan».`
- En un diálogo o una lista chica dentro de un paso: `Sin coincidencias.`

Nunca «Sin resultados». Y «no hay nada todavía» es otro estado, con otra
acción: ver `AppEmptyState` en [Diseño web](diseno-web.md).

## Tipografía

- Comillas latinas «», también alrededor de lo que escribió el usuario.
- Puntos suspensivos con el carácter `…`, no con tres puntos.
- Plurales reales según la cantidad (`n == 1 ? '1 imagen' : '$n imágenes'`),
  nunca «imagen(es)».
