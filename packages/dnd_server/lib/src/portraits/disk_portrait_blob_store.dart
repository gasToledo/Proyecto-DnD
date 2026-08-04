import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../util/safe_path.dart';
import 'portrait_blob_store.dart';
import 'portrait_image_type.dart';

/// Implementación sobre volumen de disco de [PortraitBlobStore].
///
/// Los blobs viven bajo `<root>/<userId>/<characterId>/<archivo>`: partir por
/// cuenta es lo que hace que un retrato ajeno responda como inexistente sin
/// necesidad de consultar la base de datos (ver capacidad
/// `portrait-storage`). El volumen es responsabilidad del despliegue: un
/// retrato guardado con éxito sigue disponible tras reiniciar los
/// contenedores porque el disco no es efímero.
class DiskPortraitBlobStore implements PortraitBlobStore {
  final String root;
  final int maxBytes;

  const DiskPortraitBlobStore({required this.root, required this.maxBytes});

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

    final safeUserId = requireSafePathSegment(userId, label: 'cuenta');
    final safeCharacterId = requireSafePathSegment(
      characterId,
      label: 'id de personaje',
    );
    final dir = Directory(p.join(root, safeUserId, safeCharacterId));
    await dir.create(recursive: true);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}.'
        '${type.extension}';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return '$safeCharacterId/$fileName';
  }

  @override
  Future<PortraitBlob?> read({
    required String userId,
    required String portraitKey,
  }) async {
    final segments = portraitKey.split('/');
    if (segments.length != 2) {
      throw FormatException(
        'La clave de retrato "$portraitKey" no tiene el formato esperado.',
      );
    }
    final safeUserId = requireSafePathSegment(userId, label: 'cuenta');
    final safeCharacterId = requireSafePathSegment(
      segments[0],
      label: 'id de personaje',
    );
    final safeFileName = requireSafePathSegment(
      segments[1],
      label: 'archivo de retrato',
    );

    final type = portraitImageTypeForExtension(p.extension(safeFileName));
    if (type == null) return null;

    final file = File(p.join(root, safeUserId, safeCharacterId, safeFileName));
    if (!await file.exists()) return null;
    return PortraitBlob(await file.readAsBytes(), type.contentType);
  }
}
