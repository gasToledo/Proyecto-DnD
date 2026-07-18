import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

/// Almacén local de personajes basado en archivos JSON (un archivo por
/// personaje) en el directorio de datos del usuario. 100% offline.
///
/// Elegimos archivos JSON (en vez de SQLite) porque el personaje ya ES un
/// documento JSON: guardar/leer/exportar se vuelve trivial y sin generación de
/// código. Usamos Dart puro (sin el plugin path_provider) para el directorio,
/// evitando el requisito de "Modo Desarrollador" en Windows; al portar a
/// móvil se reintroduce path_provider detrás de esta misma interfaz.
class CharacterStore {
  Directory? _dir;

  String _dataRoot() {
    final env = Platform.environment;
    final root = env['LOCALAPPDATA'] ??
        env['APPDATA'] ??
        env['XDG_DATA_HOME'] ??
        env['HOME'] ??
        Directory.systemTemp.path;
    return root;
  }

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final dir = Directory(p.join(_dataRoot(), 'FichasDnD', 'characters'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  File _fileFor(String id, Directory dir) => File(p.join(dir.path, '$id.json'));

  /// Carga todos los personajes guardados (ignora archivos corruptos, sin
  /// romper el arranque de la app).
  Future<List<Character>> loadAll() async {
    final dir = await _ensureDir();
    final result = <Character>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await entity.readAsString());
          result.add(Character.fromJson(json as Map<String, dynamic>));
        } catch (_) {
          // Archivo dañado: se omite en vez de abortar la carga.
        }
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// Guarda (o sobrescribe) un personaje. Escritura atómica: se escribe a un
  /// temporal y luego se renombra, para no dejar archivos a medias ante un
  /// cierre inesperado (criterio de calidad del brief §8).
  Future<void> save(Character c) async {
    final dir = await _ensureDir();
    final tmp = File(p.join(dir.path, '${c.id}.tmp'));
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(c.toJson()));
    await tmp.rename(_fileFor(c.id, dir).path);
  }

  Future<void> delete(String id) async {
    final dir = await _ensureDir();
    final f = _fileFor(id, dir);
    if (await f.exists()) await f.delete();
  }

  /// Ruta del directorio de datos (para mostrarla o para export/import).
  Future<String> directoryPath() async => (await _ensureDir()).path;
}
