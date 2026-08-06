import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../util/safe_path.dart';
import 'portrait_blob_store.dart';
import 'portrait_image_type.dart';
import 'portrait_thumbnail.dart';

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
    int? width,
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

    final dir = p.join(root, safeUserId, safeCharacterId);
    final file = File(p.join(dir, safeFileName));
    if (!await file.exists()) return null;

    if (width != null) {
      final thumbnail = await _thumbnail(dir, safeFileName, file, width);
      if (thumbnail != null) return thumbnail;
    }
    return PortraitBlob(await file.readAsBytes(), type.contentType);
  }

  /// Miniatura de [width] píxeles de ancho, generada una vez y guardada al
  /// lado del original, o `null` si corresponde servir el original.
  ///
  /// El derivado se llama `<original>@<ancho>.png`. La arroba es deliberada:
  /// [requireSafePathSegment] no la admite, así que un derivado **no puede
  /// pedirse como clave de retrato** aunque esté en la misma carpeta. Es lo
  /// que evita tener que distinguirlos al leer, al borrar un personaje o al
  /// armar un respaldo, que trabajan sobre las claves guardadas en la ficha.
  ///
  /// No hace falta invalidar nada: un retrato nuevo se guarda con un nombre
  /// nuevo (ver [save]) y ningún archivo se reescribe, así que el derivado no
  /// puede quedar desactualizado respecto de su original.
  Future<PortraitBlob?> _thumbnail(
    String dir,
    String fileName,
    File original,
    int width,
  ) async {
    final cached = File(p.join(dir, '$fileName@$width.png'));
    if (await cached.exists()) {
      return PortraitBlob(await cached.readAsBytes(), 'image/png');
    }

    final bytes = encodePortraitThumbnail(await original.readAsBytes(), width);
    if (bytes == null) return null;

    // Escritura por archivo temporal y renombrado: dos peticiones simultáneas
    // del mismo retrato generan la misma miniatura a la vez, y un lector no
    // debe poder encontrarse con un PNG a medio escribir.
    final temp = File(
      '${cached.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temp.writeAsBytes(bytes);
    await temp.rename(cached.path);
    return PortraitBlob(bytes, 'image/png');
  }
}
