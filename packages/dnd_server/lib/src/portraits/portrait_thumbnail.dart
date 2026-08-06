import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Anchos de miniatura que este servidor acepta generar.
///
/// La escalera existe porque el ancho lo pide el cliente y un valor libre
/// sería CPU y disco sin techo: cada valor distinto es una decodificación y un
/// archivo derivado más. Con estos ocho peldaños, el medallón más grande a
/// cualquier densidad de pantalla razonable cae a menos de un tercio por
/// encima del tamaño en que se dibuja, que es un reajuste que el filtrado del
/// navegador resuelve sin que se note.
///
/// Un ancho fuera de la lista no es un error: se sirve el original (ver
/// `PortraitBlobStore.read`). Servir de más es peor que servir a medida, pero
/// mucho mejor que dejar el medallón vacío por una discrepancia de tabla entre
/// el cliente y el servidor.
const List<int> portraitThumbnailWidths = [
  96,
  128,
  160,
  192,
  256,
  320,
  384,
  512,
];

/// El peldaño más chico de [portraitThumbnailWidths] que alcanza para dibujar
/// [neededWidth] píxeles físicos, o `null` si hace falta más que el peldaño
/// más grande: ahí corresponde el original, no una miniatura estirada.
int? portraitThumbnailWidthFor(int neededWidth) {
  for (final width in portraitThumbnailWidths) {
    if (width >= neededWidth) return width;
  }
  return null;
}

/// Reduce [original] a [width] píxeles de ancho y lo devuelve como PNG.
///
/// Devuelve `null` cuando la miniatura no aporta nada y hay que servir el
/// original: si [width] no es uno de los [portraitThumbnailWidths], si el
/// original ya es igual o más chico que [width] —agrandar acá solo gastaría
/// bytes, la nitidez no se inventa— o si los bytes no se pueden decodificar.
///
/// Ese último caso es el que obliga a atrapar todo lo que tire el
/// decodificador, y no solo su `null`: los retratos se validan **por cabecera**
/// al guardarlos (ver `sniffPortraitImageType`), nunca decodificándolos, así
/// que un archivo truncado o mal formado recién se descubre acá. Un retrato
/// roto tiene que degradar a servir los bytes tal cual, no tumbar la petición.
///
/// El remuestreo es **promedio de área** (`Interpolation.average`), no cúbico.
/// La reducción típica acá es de 1024 a 192, unas cinco veces: a esa escala un
/// filtro cúbico muestrea unos pocos píxeles de origen por píxel de destino y
/// descarta el resto, que es exactamente el dentado que se quería sacar. El
/// promedio de área mira todos los píxeles que caen en el destino.
Uint8List? encodePortraitThumbnail(Uint8List original, int width) {
  if (!portraitThumbnailWidths.contains(width)) return null;

  try {
    final decoded = img.decodeImage(original);
    if (decoded == null) return null;
    if (decoded.width <= width) return null;

    final resized = img.copyResize(
      decoded,
      width: width,
      interpolation: img.Interpolation.average,
    );
    return img.encodePng(resized);
  } catch (_) {
    return null;
  }
}
