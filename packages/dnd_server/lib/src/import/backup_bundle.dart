import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import '../util/safe_path.dart';

/// Puerto del lado de lectura de `BackupBundleCodec` (aplicación de
/// escritorio): el escritorio sigue exportando, el servidor solo importa (ver
/// capacidad `account-data-import`). No se porta `encode()` porque el
/// servidor nunca produce un ZIP de respaldo.
enum BackupScope { character, full, legacy }

/// Nombres de credencial que nunca pueden viajar en un respaldo. Incluye las de
/// proveedores retirados: un `settings.json` viejo todavía puede tenerlas.
const portableCredentialKeys = {
  'geminiApiKey',
  'huggingFaceToken',
  'azureApiKey',
  'azureOpenAiApiKey',
};

class BundlePortrait {
  final String fileName;
  final Uint8List bytes;

  const BundlePortrait({required this.fileName, required this.bytes});
}

class BundleCharacter {
  final Character character;
  final List<BundlePortrait> portraits;

  const BundleCharacter({required this.character, this.portraits = const []});
}

class BackupBundle {
  final int formatVersion;
  final BackupScope scope;
  final List<BundleCharacter> characters;
  final Map<String, List<Map<String, dynamic>>>? homebrew;
  final Map<String, dynamic>? preferences;

  const BackupBundle({
    required this.formatVersion,
    required this.scope,
    required this.characters,
    this.homebrew,
    this.preferences,
  });
}

class BackupBundleCodec {
  static const type = 'dnd_bundle';
  static const formatVersion = 2;
  static const maxArchiveBytes = 256 * 1024 * 1024;
  static const maxEntryBytes = 32 * 1024 * 1024;
  static const maxJsonBytes = 8 * 1024 * 1024;

  /// Decodifica y valida un respaldo ZIP. Una versión de formato futura, una
  /// ruta interna que intenta escapar, o cualquier otra inconsistencia se
  /// rechaza acá, antes de que la importación toque la cuenta.
  static BackupBundle decode(List<int> bytes) {
    try {
      return _decode(bytes);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('El respaldo ZIP no es válido: $error');
    }
  }

  static BackupBundle _decode(List<int> bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('El respaldo supera el tamaño máximo.');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, ArchiveFile>{};
    var totalSize = 0;

    for (final entry in archive) {
      if (!entry.isFile || entry.isSymbolicLink) {
        throw const FormatException(
          'El respaldo contiene entradas no permitidas.',
        );
      }
      final name = entry.name;
      if (!_isSafeArchivePath(name) || files.containsKey(name)) {
        throw const FormatException(
          'El respaldo contiene una ruta interna no permitida.',
        );
      }
      if (entry.size > maxEntryBytes) {
        throw const FormatException(
          'El respaldo contiene un archivo demasiado grande.',
        );
      }
      totalSize += entry.size;
      if (totalSize > maxArchiveBytes) {
        throw const FormatException(
          'El contenido descomprimido del respaldo es demasiado grande.',
        );
      }
      files[name] = entry;
    }

    final manifest = _readJsonMap(files, 'manifest.json');
    if (manifest['type'] != type) {
      throw const FormatException('El ZIP no es un respaldo de Fichas D&D.');
    }
    final version = manifest['formatVersion'];
    if (version != formatVersion) {
      throw FormatException(
        'Versión de respaldo no compatible: ${version ?? "ausente"}.',
      );
    }
    final scope = switch (manifest['scope']) {
      'character' => BackupScope.character,
      'full' => BackupScope.full,
      _ => throw const FormatException('Alcance de respaldo no reconocido.'),
    };

    final rawCharacters = manifest['characters'];
    if (rawCharacters is! List) {
      throw const FormatException('El manifiesto no contiene personajes.');
    }
    final characters = <BundleCharacter>[];
    final ids = <String>{};
    for (final raw in rawCharacters) {
      if (raw is! Map) {
        throw const FormatException('Entrada de personaje inválida.');
      }
      final item = raw.cast<String, dynamic>();
      final id = requireSafePathSegment(
        item['id'] as String? ?? '',
        label: 'id de personaje',
      );
      if (!ids.add(id)) {
        throw const FormatException(
          'El respaldo contiene ids de personaje repetidos.',
        );
      }
      final characterPath = item['file'] as String?;
      if (characterPath == null || characterPath != 'characters/$id.json') {
        throw const FormatException('Ruta de personaje inválida.');
      }
      final character = _characterFromJson(_readJsonMap(files, characterPath));
      if (character.id != id) {
        throw const FormatException(
          'El id del personaje no coincide con el manifiesto.',
        );
      }

      final portraits = <BundlePortrait>[];
      final rawPortraits = item['portraits'] as List? ?? const [];
      for (final rawPath in rawPortraits) {
        if (rawPath is! String ||
            !rawPath.startsWith('portraits/$id/') ||
            !_isSafeArchivePath(rawPath)) {
          throw const FormatException('Ruta de retrato inválida.');
        }
        final entry = files[rawPath];
        if (entry == null) {
          throw const FormatException('Falta un retrato declarado.');
        }
        portraits.add(
          BundlePortrait(
            fileName: _safeFileName(p.posix.basename(rawPath)),
            bytes: _readBytes(entry),
          ),
        );
      }
      characters.add(
        BundleCharacter(
          character: character.copyWith(portraitPaths: const []),
          portraits: portraits,
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>>? homebrew;
    final homebrewPath = manifest['homebrewFile'] as String?;
    if (homebrewPath != null) {
      if (scope != BackupScope.full ||
          homebrewPath != 'homebrew/content.json') {
        throw const FormatException('Ruta de homebrew inválida.');
      }
      homebrew = _parseHomebrew(_readJsonMap(files, homebrewPath));
    }

    Map<String, dynamic>? preferences;
    final preferencesPath = manifest['preferencesFile'] as String?;
    if (preferencesPath != null) {
      if (scope != BackupScope.full ||
          preferencesPath != 'settings/preferences.json') {
        throw const FormatException('Ruta de ajustes inválida.');
      }
      preferences = _readJsonMap(files, preferencesPath);
      if (preferences.keys.any(portableCredentialKeys.contains)) {
        throw const FormatException(
          'El respaldo contiene credenciales que no deberían importarse.',
        );
      }
    }

    return BackupBundle(
      formatVersion: formatVersion,
      scope: scope,
      characters: characters,
      homebrew: homebrew,
      preferences: preferences,
    );
  }

  static Map<String, dynamic> _readJsonMap(
    Map<String, ArchiveFile> files,
    String name,
  ) {
    final entry = files[name];
    if (entry == null || entry.size > maxJsonBytes) {
      throw FormatException('Falta $name o tiene un tamaño inválido.');
    }
    final decoded = jsonDecode(utf8.decode(_readBytes(entry)));
    if (decoded is! Map) {
      throw FormatException('$name no contiene un objeto JSON.');
    }
    return decoded.cast<String, dynamic>();
  }

  static Uint8List _readBytes(ArchiveFile entry) {
    final bytes = entry.readBytes();
    if (bytes == null) {
      throw FormatException('No se pudo leer ${entry.name}.');
    }
    return bytes;
  }

  static Character _characterFromJson(Map<String, dynamic> json) {
    final character = Character.fromJson(json);
    requireSafePathSegment(character.id, label: 'id de personaje');
    return character;
  }

  static Map<String, List<Map<String, dynamic>>> _parseHomebrew(
    Map<String, dynamic> content,
  ) => {
    for (final key in const [
      'weapons',
      'armor',
      'feats',
      'races',
      'backgrounds',
      'spells',
    ])
      key: ((content[key] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
  };

  static bool _isSafeArchivePath(String name) {
    if (name.isEmpty ||
        name.contains('\\') ||
        name.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(name)) {
      return false;
    }
    final segments = name.split('/');
    return !segments.contains('') &&
        !segments.contains('.') &&
        !segments.contains('..') &&
        p.posix.normalize(name) == name;
  }

  static String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty || safe == '.' || safe == '..' ? 'archivo' : safe;
  }
}
