import 'dart:typed_data';

import 'package:dnd_server/src/portraits/portrait_blob_store.dart';
import 'package:dnd_server/src/portraits/portrait_image_type.dart';
import 'package:dnd_server/src/portraits/portrait_thumbnail.dart';
import 'package:dnd_server/src/util/safe_path.dart';

/// Doble en memoria de [PortraitBlobStore], con la misma partición por
/// cuenta y las mismas reglas de validación que la implementación en disco,
/// para poder probar el enrutado sin tocar el sistema de archivos.
class InMemoryPortraitBlobStore implements PortraitBlobStore {
  final int maxBytes;
  final Map<String, Map<String, Map<String, PortraitBlob>>> _byUser = {};
  int _counter = 0;

  InMemoryPortraitBlobStore({this.maxBytes = 8 * 1024 * 1024});

  @override
  Future<String> save({
    required String userId,
    required String characterId,
    required Uint8List bytes,
  }) async {
    if (bytes.length > maxBytes) {
      throw FormatException(
        'La imagen supera el tamaño máximo admitido ($maxBytes bytes).',
      );
    }
    final type = sniffPortraitImageType(bytes);
    if (type == null) {
      throw const FormatException(
        'El archivo no es una imagen admitida (PNG, JPEG o WEBP).',
      );
    }

    final safeCharacterId = requireSafePathSegment(
      characterId,
      label: 'id de personaje',
    );
    final fileName = '${_counter++}.${type.extension}';
    _byUser
        .putIfAbsent(userId, () => {})
        .putIfAbsent(safeCharacterId, () => {})[fileName] = PortraitBlob(
      bytes,
      type.contentType,
    );
    return '$safeCharacterId/$fileName';
  }

  @override
  Future<PortraitBlob?> read({
    required String userId,
    required String portraitKey,
    int? width,
  }) async {
    final segments = portraitKey.split('/');
    if (segments.length != 2) {
      throw FormatException(
        'La clave de retrato "$portraitKey" no tiene el formato esperado.',
      );
    }
    final safeCharacterId = requireSafePathSegment(
      segments[0],
      label: 'id de personaje',
    );
    final safeFileName = requireSafePathSegment(
      segments[1],
      label: 'archivo de retrato',
    );
    final blob = _byUser[userId]?[safeCharacterId]?[safeFileName];
    if (blob == null || width == null) return blob;

    // Sin caché en disco que imitar: acá el interés es que el enrutado pase
    // el ancho hasta el almacén, no la escritura del derivado.
    final thumbnail = encodePortraitThumbnail(blob.bytes, width);
    return thumbnail == null ? blob : PortraitBlob(thumbnail, 'image/png');
  }
}
