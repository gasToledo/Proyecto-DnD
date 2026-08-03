import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'backup_bundle.dart';

/// Exportación e importación en ZIP versionado, con lectura compatible de los
/// JSON usados por las versiones anteriores.
///
/// Sin plugins (evita el requisito de Modo Desarrollador de Windows): exporta a
/// una carpeta visible del usuario y la importación lee archivos por ruta.
class TransferService {
  static const int formatVersion = 1;

  Directory? _dir;
  final String? dataRoot;

  TransferService({this.dataRoot});

  Future<Directory> exportsDir() async {
    if (_dir != null) return _dir!;
    final dir = Directory(fichasDir('exports', dataRoot));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _fileStamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  static Character _characterFromJson(Map<String, dynamic> json) {
    final character = Character.fromJson(json);
    requireSafePathSegment(character.id, label: 'id de personaje');
    return character;
  }

  static void _requireCompatibleLegacyVersion(
    Map<String, dynamic> document,
    String dataType,
  ) {
    final version = document['formatVersion'] ?? 1;
    if (version is! int || version < 1) {
      throw FormatException(
        'La versión de $dataType debe ser un entero positivo.',
      );
    }
    if (version > formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: dataType,
        found: version,
        supported: formatVersion,
      );
    }
    if (version != formatVersion) {
      throw FormatException('Versión de $dataType no compatible: $version.');
    }
  }

  /// Exporta un personaje. Devuelve la ruta del archivo escrito.
  Future<String> exportCharacter(Character c) async {
    final dir = await exportsDir();
    final safeId = requireSafePathSegment(c.id, label: 'id de personaje');
    final bytes = await BackupBundleCodec.encode(
      scope: BackupScope.character,
      characters: [c],
    );
    final file = File(p.join(dir.path, '${_safe(c.name)}-$safeId.zip'));
    await writeBytesAtomic(file, bytes);
    return file.path;
  }

  /// Exporta un respaldo completo. Devuelve la ruta del archivo escrito.
  Future<String> exportBackup(
    List<Character> all, {
    Map<String, List<Map<String, dynamic>>>? homebrew,
    Map<String, dynamic>? preferences,
  }) async {
    final dir = await exportsDir();
    final bytes = await BackupBundleCodec.encode(
      scope: BackupScope.full,
      characters: all,
      homebrew: homebrew,
      preferences: preferences,
    );
    final file = File(p.join(dir.path, 'backup-${_fileStamp()}.zip'));
    await writeBytesAtomic(file, bytes);
    return file.path;
  }

  /// Exporta todo el contenido homebrew (listas JSON por tipo) a un archivo con
  /// envoltorio `dnd_homebrew`. Devuelve la ruta escrita.
  Future<String> exportHomebrew(
    Map<String, List<Map<String, dynamic>>> content,
  ) async {
    final dir = await exportsDir();
    final envelope = {
      'type': 'dnd_homebrew',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'content': content,
    };
    final file = File(p.join(dir.path, 'homebrew-${_fileStamp()}.json'));
    await writeJsonAtomic(file, envelope);
    return file.path;
  }

  /// Parsea un export de homebrew (`dnd_homebrew`) a listas JSON por tipo.
  /// Lógica pura (testeable).
  static Map<String, List<Map<String, dynamic>>> parseHomebrewImport(
    String jsonText,
  ) {
    final data = jsonDecode(jsonText);
    if (data is Map<String, dynamic> && data['type'] == 'dnd_homebrew') {
      _requireCompatibleLegacyVersion(data, 'exportación Homebrew');
      final content = (data['content'] as Map?)?.cast<String, dynamic>() ?? {};
      return {
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
    }
    throw const FormatException(
      'El archivo no es un pack de contenido homebrew válido.',
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> importHomebrewFromFile(
    String path,
  ) async {
    final file = File(path.trim());
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', path);
    }
    return parseHomebrewImport(await file.readAsString());
  }

  /// Parsea el contenido de un archivo exportado a una lista de personajes.
  /// Acepta ambos envoltorios y, de forma tolerante, un personaje "crudo".
  /// Lógica pura (testeable).
  static List<Character> parseImport(String jsonText) {
    final data = jsonDecode(jsonText);
    if (data is Map<String, dynamic>) {
      final type = data['type'];
      if (type == 'dnd_backup') {
        _requireCompatibleLegacyVersion(data, 'respaldo JSON');
        return (data['characters'] as List)
            .map((e) => _characterFromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (type == 'dnd_character') {
        _requireCompatibleLegacyVersion(data, 'exportación de personaje');
        return [
          _characterFromJson(
            (data['character'] as Map).cast<String, dynamic>(),
          ),
        ];
      }
      // Personaje crudo (p.ej. un archivo del propio almacén).
      if (data.containsKey('classId')) {
        return [_characterFromJson(data)];
      }
    }
    throw const FormatException('Formato de archivo no reconocido.');
  }

  Future<List<Character>> importFromFile(String path) async {
    final bundle = await readBundleOrLegacy(path);
    return bundle.characters.map((entry) => entry.character).toList();
  }

  Future<BackupBundle> readBundleOrLegacy(String path) async {
    final file = File(path.trim());
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', path);
    }
    final bytes = await file.readAsBytes();
    final isZip =
        p.extension(file.path).toLowerCase() == '.zip' ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4b &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04);
    if (isZip) return BackupBundleCodec.decode(bytes);
    return BackupBundle.legacy(parseImport(utf8.decode(bytes)));
  }

  /// Materializa los retratos en rutas locales y evita sobrescribir ids.
  Future<PreparedCharacterImport> prepareCharacterImport(
    BackupBundle bundle,
    Set<String> existingIds,
  ) async {
    final reservedIds = Set<String>.of(existingIds);
    final prepared = <Character>[];
    final createdDirectories = <Directory>[];
    final portraitsRoot = Directory(fichasDir('portraits', dataRoot));

    try {
      for (var i = 0; i < bundle.characters.length; i++) {
        final entry = bundle.characters[i];
        var id = entry.character.id;
        var target = Directory(p.join(portraitsRoot.path, id));
        if (reservedIds.contains(id) || await target.exists()) {
          do {
            id = '${DateTime.now().microsecondsSinceEpoch}-$i';
            target = Directory(p.join(portraitsRoot.path, id));
          } while (reservedIds.contains(id) || await target.exists());
        }
        reservedIds.add(id);

        final portraitPaths = <String>[];
        if (entry.portraits.isNotEmpty) {
          await target.create(recursive: true);
          createdDirectories.add(target);
          for (final portrait in entry.portraits) {
            final name = requireSafePathSegment(
              portrait.fileName,
              label: 'nombre de retrato',
            );
            final destination = File(p.join(target.path, name));
            await writeBytesAtomic(destination, portrait.bytes);
            portraitPaths.add(destination.path);
          }
        }

        var character = entry.character;
        if (character.id != id) {
          character = Character.fromJson(character.toJson()..['id'] = id);
        }
        prepared.add(character.copyWith(portraitPaths: portraitPaths));
      }
      return PreparedCharacterImport(
        characters: prepared,
        createdPortraitDirectories: createdDirectories,
      );
    } catch (_) {
      await _deleteDirectories(createdDirectories);
      rethrow;
    }
  }

  /// Lista respaldos ZIP y exportaciones JSON antiguas.
  Future<List<File>> listExportFiles() async {
    final dir = await exportsDir();
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File) {
        final extension = p.extension(e.path).toLowerCase();
        if (extension == '.json' || extension == '.zip') files.add(e);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Abre la carpeta de exportación en el explorador de archivos (Windows).
  Future<void> openExportsFolder() async {
    final dir = await exportsDir();
    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    }
  }
}

class PreparedCharacterImport {
  final List<Character> characters;
  final List<Directory> createdPortraitDirectories;

  const PreparedCharacterImport({
    required this.characters,
    required this.createdPortraitDirectories,
  });

  Future<void> rollbackPortraits() =>
      _deleteDirectories(createdPortraitDirectories);
}

Future<void> _deleteDirectories(List<Directory> directories) async {
  for (final directory in directories.reversed) {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
