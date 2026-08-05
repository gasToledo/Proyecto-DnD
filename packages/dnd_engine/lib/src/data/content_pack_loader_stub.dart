import 'content_repository.dart';

/// Sustituto sin `dart:io` que ocupa este punto de entrada cuando el motor se
/// compila para web. `loadFromDirectory` no tiene sentido sin sistema de
/// archivos local: el cliente web carga el contenido oficial como asset
/// empaquetado, no desde un directorio.
Future<ContentRepository> loadContentRepositoryFromDirectory(String dirPath) {
  throw UnsupportedError(
    'ContentRepository.loadFromDirectory no está disponible en la '
    'plataforma web; use el contenido empaquetado como asset.',
  );
}
