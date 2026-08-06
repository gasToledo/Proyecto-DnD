import 'package:flutter/widgets.dart';

/// Único punto de la interfaz que traduce una clave opaca de retrato
/// (`Character.portraitPaths`) en la imagen que se muestra. Resuelve contra
/// la API del mismo origen: la cookie de sesión ya autoriza la petición sin
/// que este widget tenga que hacer nada (ver `design.md`, decisión D5).
///
/// A diferencia de la versión de escritorio, no hay forma barata de saber de
/// antemano si la clave resuelve a algo: la imagen se intenta siempre y un
/// 404 (retrato borrado, cuenta ajena) se resuelve con [errorBuilder]/
/// `onError` en el sitio que la usa, en vez de con una comprobación previa.
class PortraitImage extends StatelessWidget {
  final String portraitKey;
  final BoxFit fit;

  const PortraitImage({
    super.key,
    required this.portraitKey,
    this.fit = BoxFit.cover,
  });

  static String urlFor(String portraitKey, {int? width}) => width == null
      ? '/api/portraits/$portraitKey'
      : '/api/portraits/$portraitKey?w=$width';

  /// [ImageProvider] para widgets que no aceptan un [Widget] de imagen
  /// directamente (por ejemplo un medallón con retrato de fondo).
  ///
  /// Con [width] pide una miniatura de ese ancho en píxeles físicos en vez del
  /// original. **Quien dibuje el retrato chico tiene que pedirla**: reducirlo
  /// acá no es una opción, porque la implementación web de [NetworkImage] no
  /// sabe decodificar a un tamaño dado —lo dice su propia documentación— y por
  /// eso `ResizeImage` no hace nada en el navegador. Sin esto, un retrato de
  /// 1024 px termina reducido de un salto por la GPU dentro de un círculo de
  /// menos de cien, que es lo que se veía dentado y borroso.
  static ImageProvider provider(String portraitKey, {int? width}) =>
      NetworkImage(urlFor(portraitKey, width: width));

  /// Anchos de miniatura que el servidor sabe generar
  /// (`portrait_thumbnail.dart` en `dnd_server`). La escalera está duplicada a
  /// propósito: el cliente no puede consultarla antes de pintar el primer
  /// medallón, y un desajuste no rompe nada —el servidor responde el original
  /// ante un ancho que no reconoce—, solo baja más bytes de la cuenta.
  static const List<int> thumbnailWidths = [
    96,
    128,
    160,
    192,
    256,
    320,
    384,
    512,
  ];

  /// El ancho de miniatura que corresponde para dibujar el retrato en un
  /// recuadro de [logicalSize] con densidad [devicePixelRatio], o `null` si
  /// hace falta más que el peldaño más grande y corresponde el original.
  static int? thumbnailWidthFor(double logicalSize, double devicePixelRatio) {
    final needed = (logicalSize * devicePixelRatio).ceil();
    for (final width in thumbnailWidths) {
      if (width >= needed) return width;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      urlFor(portraitKey),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
