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

  static String urlFor(String portraitKey) => '/api/portraits/$portraitKey';

  /// [ImageProvider] para widgets que no aceptan un [Widget] de imagen
  /// directamente (por ejemplo un medallón con retrato de fondo).
  static ImageProvider provider(String portraitKey) =>
      NetworkImage(urlFor(portraitKey));

  @override
  Widget build(BuildContext context) {
    return Image.network(
      urlFor(portraitKey),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
