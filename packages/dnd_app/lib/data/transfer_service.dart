import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

/// Exportación e importación de personajes en JSON versionado (brief §3.E).
///
/// Sin plugins (evita el requisito de Modo Desarrollador de Windows): exporta a
/// una carpeta visible del usuario y la importación lee archivos por ruta.
/// Dos formatos, ambos con envoltorio versionado:
///  - `dnd_character`: un solo personaje.
///  - `dnd_backup`: todos los personajes (respaldo completo).
class TransferService {
  static const int formatVersion = 1;

  Directory? _dir;

  String _homeRoot() {
    final env = Platform.environment;
    return env['USERPROFILE'] ??
        env['HOME'] ??
        env['LOCALAPPDATA'] ??
        Directory.systemTemp.path;
  }

  Future<Directory> exportsDir() async {
    if (_dir != null) return _dir!;
    final dir = Directory(p.join(_homeRoot(), 'FichasDnD', 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Exporta un personaje. Devuelve la ruta del archivo escrito.
  Future<String> exportCharacter(Character c) async {
    final dir = await exportsDir();
    final envelope = {
      'type': 'dnd_character',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'character': c.toJson(),
    };
    final file = File(p.join(dir.path, '${_safe(c.name)}-${c.id}.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope));
    return file.path;
  }

  /// Exporta un respaldo completo. Devuelve la ruta del archivo escrito.
  Future<String> exportBackup(List<Character> all) async {
    final dir = await exportsDir();
    final envelope = {
      'type': 'dnd_backup',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'characters': all.map((c) => c.toJson()).toList(),
    };
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'backup-$stamp.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope));
    return file.path;
  }

  /// Exporta todo el contenido homebrew (listas JSON por tipo) a un archivo con
  /// envoltorio `dnd_homebrew`. Devuelve la ruta escrita.
  Future<String> exportHomebrew(
      Map<String, List<Map<String, dynamic>>> content) async {
    final dir = await exportsDir();
    final envelope = {
      'type': 'dnd_homebrew',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'content': content,
    };
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(dir.path, 'homebrew-$stamp.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope));
    return file.path;
  }

  /// Parsea un export de homebrew (`dnd_homebrew`) a listas JSON por tipo.
  /// Lógica pura (testeable).
  static Map<String, List<Map<String, dynamic>>> parseHomebrewImport(
      String jsonText) {
    final data = jsonDecode(jsonText);
    if (data is Map<String, dynamic> && data['type'] == 'dnd_homebrew') {
      final content = (data['content'] as Map?)?.cast<String, dynamic>() ?? {};
      return {
        for (final key in const [
          'weapons', 'armor', 'feats', 'races', 'backgrounds', 'spells'
        ])
          key: ((content[key] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList(),
      };
    }
    throw const FormatException(
        'El archivo no es un pack de contenido homebrew válido.');
  }

  Future<Map<String, List<Map<String, dynamic>>>> importHomebrewFromFile(
      String path) async {
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
        return (data['characters'] as List)
            .map((e) => Character.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (type == 'dnd_character') {
        return [
          Character.fromJson((data['character'] as Map).cast<String, dynamic>())
        ];
      }
      // Personaje crudo (p.ej. un archivo del propio almacén).
      if (data.containsKey('classId')) {
        return [Character.fromJson(data)];
      }
    }
    throw const FormatException('Formato de archivo no reconocido.');
  }

  Future<List<Character>> importFromFile(String path) async {
    final file = File(path.trim());
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', path);
    }
    return parseImport(await file.readAsString());
  }

  /// Lista los archivos .json en la carpeta de exportación (para elegir al
  /// importar sin selector nativo).
  Future<List<File>> listExportFiles() async {
    final dir = await exportsDir();
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) files.add(e);
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
