import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

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
  final String? _dataRoot;
  final String? _legacyDirectory;
  final List<DataRecoveryIssue> recoveryIssues = [];

  CharacterStore({String? dataRoot, String? legacyDirectory})
    : _dataRoot = dataRoot,
      _legacyDirectory =
          legacyDirectory ?? (dataRoot == null ? legacyCharactersDir() : null);

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final dir = Directory(fichasDir('characters', _dataRoot));
    if (!await dir.exists()) await dir.create(recursive: true);
    await _migrateLegacyCharacters(dir);
    _dir = dir;
    return dir;
  }

  File _fileFor(String id, Directory dir) => File(
    p.join(
      dir.path,
      '${requireSafePathSegment(id, label: 'id de personaje')}.json',
    ),
  );

  Future<void> _migrateLegacyCharacters(Directory destination) async {
    final legacyPath = _legacyDirectory;
    if (legacyPath == null) return;
    final marker = File(p.join(destination.path, '.legacy-migrated-v1'));
    if (await marker.exists()) return;
    final legacy = Directory(legacyPath);
    if (!await legacy.exists()) return;

    await for (final entity in legacy.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final target = File(p.join(destination.path, p.basename(entity.path)));
      if (!await target.exists()) {
        await writeBytesAtomic(target, await entity.readAsBytes());
      }
    }
    await marker.writeAsString(
      'Migración completada ${DateTime.now().toIso8601String()}',
      flush: true,
    );
  }

  /// Carga todos los personajes guardados (ignora archivos corruptos, sin
  /// romper el arranque de la app).
  Future<List<Character>> loadAll() async {
    final dir = await _ensureDir();
    final result = <Character>[];
    recoveryIssues.clear();
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await entity.readAsString());
          final character = Character.fromJson(json as Map<String, dynamic>);
          requireSafePathSegment(character.id, label: 'id de personaje');
          result.add(character);
        } catch (error) {
          recoveryIssues.add(
            await recoverCorruptFile(entity, error, dataRoot: _dataRoot),
          );
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
    await writeJsonAtomic(_fileFor(c.id, dir), c.toJson());
  }

  /// Guarda un conjunto completo como una sola operación lógica. Si falla una
  /// escritura, el helper revierte los archivos que ya hubiera reemplazado.
  Future<void> saveAll(Iterable<Character> characters) async {
    final dir = await _ensureDir();
    await writeJsonBatchAtomic({
      for (final character in characters)
        _fileFor(character.id, dir): character.toJson(),
    });
  }

  Future<void> delete(String id) async {
    final dir = await _ensureDir();
    final f = _fileFor(id, dir);
    if (await f.exists()) await f.delete();
  }

  /// Ruta del directorio de datos (para mostrarla o para export/import).
  Future<String> directoryPath() async => (await _ensureDir()).path;
}
