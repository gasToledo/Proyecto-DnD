import 'dart:typed_data';

/// Sustituto sin `dart:html` que ocupa este punto de entrada cuando el
/// código se compila para una plataforma sin navegador (la VM que corre
/// `flutter test`, por ejemplo). Nunca se llama fuera de una interacción real
/// del usuario en el build web (ver `browser_web.dart`), así que no hace
/// falta un no-op silencioso: un `UnsupportedError` señala claramente un uso
/// fuera de lugar, igual que `content_pack_loader_stub.dart` en `dnd_engine`.
void redirectTo(String path) {
  throw UnsupportedError('redirectTo solo está disponible en el build web.');
}

void downloadBytes(
  Uint8List bytes, {
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('downloadBytes solo está disponible en el build web.');
}
