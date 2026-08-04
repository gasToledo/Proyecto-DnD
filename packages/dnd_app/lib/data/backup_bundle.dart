import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';

enum BackupScope { character, full }

/// Nombres de credencial que nunca pueden viajar en un respaldo. Incluye las de
/// proveedores retirados: un settings.json viejo todavía puede tenerlas.
const portableCredentialKeys = {
  'geminiApiKey',
  'huggingFaceToken',
  'azureApiKey',
  'azureOpenAiApiKey',
};

/// Segmento seguro para usar como nombre de archivo o directorio dentro del
/// ZIP: la misma validación que ya usaba la app de escritorio, ahora sin
/// depender de `app_paths.dart` (que era filesystem-only).
String requireSafePathSegment(String value, {String label = 'identificador'}) {
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
    throw FormatException('El $label contiene caracteres no permitidos.');
  }
  return value;
}

/// Arma el ZIP de respaldo, en memoria. El cliente web solo **produce** este
/// formato para exportar/descargar (ver `design.md`, decisión D10): la
/// lectura de un ZIP subido la hace el servidor en `POST /api/import`, que
/// tiene su propia copia de este códec del lado de la confianza — este
/// cliente nunca decodifica un ZIP ajeno, así que no necesita esa mitad.
class BackupBundleCodec {
  static const type = 'dnd_bundle';
  static const formatVersion = 2;
  static const maxArchiveBytes = 256 * 1024 * 1024;
  static const maxEntryBytes = 32 * 1024 * 1024;

  /// [readPortrait] resuelve los bytes de cada clave de retrato del
  /// personaje; en el cliente web viene de una petición autenticada al
  /// servidor (`ApiClient.fetchPortraitBytes`), no de disco — esa es la
  /// única diferencia con la versión que usaba la aplicación de escritorio.
  /// Una clave que ya no resuelve a nada (`null`) se omite en vez de fallar
  /// todo el respaldo.
  static Future<Uint8List> encode({
    required BackupScope scope,
    required List<Character> characters,
    Map<String, List<Map<String, dynamic>>>? homebrew,
    Map<String, dynamic>? preferences,
    required Future<Uint8List?> Function(String portraitKey) readPortrait,
  }) async {
    final archive = Archive();
    final characterEntries = <Map<String, dynamic>>[];
    final characterIds = <String>{};
    final portablePreferences = Map<String, dynamic>.of(preferences ?? const {})
      // Las credenciales nunca salen del equipo. Se listan por nombre, e
      // incluyen las de proveedores ya retirados: un respaldo puede armarse a
      // partir de un settings.json viejo que todavía las tenga.
      ..removeWhere((key, _) => portableCredentialKeys.contains(key));

    for (final character in characters) {
      final id = requireSafePathSegment(character.id, label: 'id de personaje');
      if (!characterIds.add(id)) {
        throw const FormatException(
          'No se puede exportar dos veces el mismo personaje.',
        );
      }
      final characterPath = 'characters/$id.json';
      final portraitEntries = <String>[];

      for (var i = 0; i < character.portraitPaths.length; i++) {
        final bytes = await readPortrait(character.portraitPaths[i]);
        if (bytes == null) continue;
        if (bytes.length > maxEntryBytes) {
          throw const FormatException(
            'Un retrato supera el tamaño máximo permitido.',
          );
        }
        final archivePath = 'portraits/$id/$i.png';
        archive.add(ArchiveFile.bytes(archivePath, bytes));
        portraitEntries.add(archivePath);
      }

      archive.add(
        ArchiveFile.string(
          characterPath,
          const JsonEncoder.withIndent('  ').convert(character.toJson()),
        ),
      );
      characterEntries.add({
        'id': id,
        'file': characterPath,
        'portraits': portraitEntries,
      });
    }

    String? homebrewPath;
    if (scope == BackupScope.full && homebrew != null) {
      homebrewPath = 'homebrew/content.json';
      archive.add(
        ArchiveFile.string(
          homebrewPath,
          const JsonEncoder.withIndent('  ').convert(homebrew),
        ),
      );
    }

    String? preferencesPath;
    if (scope == BackupScope.full && preferences != null) {
      preferencesPath = 'settings/preferences.json';
      archive.add(
        ArchiveFile.string(
          preferencesPath,
          const JsonEncoder.withIndent('  ').convert(portablePreferences),
        ),
      );
    }

    final manifest = <String, dynamic>{
      'type': type,
      'formatVersion': formatVersion,
      'scope': scope.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'characters': characterEntries,
      'homebrewFile': ?homebrewPath,
      'preferencesFile': ?preferencesPath,
    };
    archive.add(
      ArchiveFile.string(
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert(manifest),
      ),
    );

    final encoded = ZipEncoder().encodeBytes(archive);
    if (encoded.length > maxArchiveBytes) {
      throw const FormatException('El respaldo supera el tamaño máximo.');
    }
    return encoded;
  }
}
