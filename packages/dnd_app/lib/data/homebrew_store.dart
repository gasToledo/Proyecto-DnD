import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

/// Almacén local de contenido homebrew (razas, dotes, armas, armaduras,
/// trasfondos). Mismo esquema que el pack oficial: se guarda un archivo JSON
/// por tipo en `~/FichasDnD/homebrew/` y se fusiona al [ContentRepository].
class HomebrewStore {
  static const int currentSchemaVersion = 2;

  final String? dataRoot;
  final Map<String, Weapon> weapons = {};
  final Map<String, Armor> armor = {};
  final Map<String, Feat> feats = {};
  final Map<String, Race> races = {};
  final Map<String, Background> backgrounds = {};
  final Map<String, Spell> spells = {};
  final List<DataRecoveryIssue> recoveryIssues = [];
  final List<DataMigrationBackup> migrationBackups = [];
  final Set<String> _protectedFutureFiles = {};

  HomebrewStore({this.dataRoot});

  String _path(String file) => p.join(fichasDir('homebrew', dataRoot), file);

  Future<List<Map<String, dynamic>>> _readList(
    String file,
    void Function(Map<String, dynamic>) validate,
  ) async {
    final f = File(_path(file));
    if (!await f.exists()) return const [];
    late int originalVersion;
    late List<Map<String, dynamic>> items;
    try {
      final decoded = jsonDecode(await f.readAsString());
      final List<dynamic> rawItems;
      if (decoded is List) {
        originalVersion = 1;
        rawItems = decoded;
      } else if (decoded is Map) {
        final document = decoded.cast<String, dynamic>();
        final version = document['schemaVersion'];
        if (version is! int || version < 1) {
          throw const FormatException(
            'La versión de Homebrew debe ser un entero positivo.',
          );
        }
        if (version > currentSchemaVersion) {
          throw UnsupportedDataVersionException(
            dataType: 'Homebrew',
            found: version,
            supported: currentSchemaVersion,
          );
        }
        originalVersion = version;
        final items = document['items'];
        if (items is! List) {
          throw const FormatException(
            'El documento Homebrew no contiene una lista de elementos.',
          );
        }
        rawItems = items;
      } else {
        throw const FormatException(
          'El archivo Homebrew no contiene un documento válido.',
        );
      }

      items = rawItems.map((e) => (e as Map).cast<String, dynamic>()).toList();
      for (final item in items) {
        validate(item);
      }
    } on UnsupportedDataVersionException catch (error) {
      _protectedFutureFiles.add(file);
      recoveryIssues.add(
        DataRecoveryIssue(
          originalPath: f.path,
          recoveryPath: f.path,
          error: error.toString(),
        ),
      );
      return const [];
    } catch (error) {
      recoveryIssues.add(
        await recoverCorruptFile(f, error, dataRoot: dataRoot),
      );
      return const [];
    }

    if (originalVersion < currentSchemaVersion) {
      try {
        final backup = await backupBeforeMigration(
          f,
          fromVersion: originalVersion,
          toVersion: currentSchemaVersion,
          dataRoot: dataRoot,
        );
        await writeJsonAtomic(f, _document(items));
        migrationBackups.add(backup);
      } catch (error) {
        recoveryIssues.add(
          DataRecoveryIssue(
            originalPath: f.path,
            recoveryPath: f.path,
            error: 'No se pudo guardar la migración: $error',
          ),
        );
      }
    }
    return items;
  }

  Future<void> _writeList(
    String file,
    Iterable<Map<String, dynamic>> items,
  ) async {
    if (_protectedFutureFiles.contains(file) &&
        await File(_path(file)).exists()) {
      throw StateError(
        'No se sobrescribió $file porque usa una versión futura.',
      );
    }
    final dir = Directory(fichasDir('homebrew', dataRoot));
    if (!await dir.exists()) await dir.create(recursive: true);
    await writeJsonAtomic(File(_path(file)), _document(items));
  }

  Map<String, dynamic> _document(Iterable<Map<String, dynamic>> items) => {
    'schemaVersion': currentSchemaVersion,
    'items': items.toList(),
  };

  Future<void> load() async {
    recoveryIssues.clear();
    migrationBackups.clear();
    _protectedFutureFiles.clear();
    for (final j in await _readList('weapons.json', Weapon.fromJson)) {
      weapons[j['id'] as String] = Weapon.fromJson(j);
    }
    for (final j in await _readList('armor.json', Armor.fromJson)) {
      armor[j['id'] as String] = Armor.fromJson(j);
    }
    for (final j in await _readList('feats.json', Feat.fromJson)) {
      feats[j['id'] as String] = Feat.fromJson(j);
    }
    for (final j in await _readList('races.json', Race.fromJson)) {
      races[j['id'] as String] = Race.fromJson(j);
    }
    for (final j in await _readList('backgrounds.json', Background.fromJson)) {
      backgrounds[j['id'] as String] = Background.fromJson(j);
    }
    for (final j in await _readList('spells.json', Spell.fromJson)) {
      spells[j['id'] as String] = Spell.fromJson(j);
    }
  }

  /// Todo el contenido homebrew serializado a listas JSON por tipo, para
  /// exportarlo. Las claves coinciden con los nombres de archivo del store.
  Map<String, List<Map<String, dynamic>>> exportContent() => {
    'weapons': weapons.values.map((e) => e.toJson()).toList(),
    'armor': armor.values.map((e) => e.toJson()).toList(),
    'feats': feats.values.map((e) => e.toJson()).toList(),
    'races': races.values.map((e) => e.toJson()).toList(),
    'backgrounds': backgrounds.values.map((e) => e.toJson()).toList(),
    'spells': spells.values.map((e) => e.toJson()).toList(),
  };

  /// Cuántas entradas de [content] tienen un id que **ya existe** en el store
  /// (es decir, que un [importContent] sobrescribiría). Cero = import puramente
  /// aditivo. La UI lo usa para pedir confirmación antes de pisar homebrew.
  int countCollisions(Map<String, List<Map<String, dynamic>>> content) {
    final existingIds = <String, Set<String>>{
      'weapons': weapons.keys.toSet(),
      'armor': armor.keys.toSet(),
      'feats': feats.keys.toSet(),
      'races': races.keys.toSet(),
      'backgrounds': backgrounds.keys.toSet(),
      'spells': spells.keys.toSet(),
    };
    var n = 0;
    for (final entry in content.entries) {
      final ids = existingIds[entry.key];
      if (ids == null) continue;
      for (final j in entry.value) {
        if (ids.contains(j['id'] as String?)) n++;
      }
    }
    return n;
  }

  /// Importa contenido homebrew (mismo formato que [exportContent]) fusionándolo
  /// por id: una entrada con id existente se sobrescribe. Persiste cada tipo una
  /// sola vez. Devuelve la cantidad total de entradas importadas.
  Future<int> importContent(
    Map<String, List<Map<String, dynamic>>> content,
  ) async {
    if (_protectedFutureFiles.isNotEmpty) {
      throw StateError(
        'No se importó Homebrew porque hay archivos de una versión futura.',
      );
    }
    var count = 0;
    List<Map<String, dynamic>> list(String k) => content[k] ?? const [];

    final nextWeapons = Map<String, Weapon>.of(weapons);
    final nextArmor = Map<String, Armor>.of(armor);
    final nextFeats = Map<String, Feat>.of(feats);
    final nextRaces = Map<String, Race>.of(races);
    final nextBackgrounds = Map<String, Background>.of(backgrounds);
    final nextSpells = Map<String, Spell>.of(spells);

    for (final j in list('weapons')) {
      nextWeapons[j['id'] as String] = Weapon.fromJson(j);
      count++;
    }
    for (final j in list('armor')) {
      nextArmor[j['id'] as String] = Armor.fromJson(j);
      count++;
    }
    for (final j in list('feats')) {
      nextFeats[j['id'] as String] = Feat.fromJson(j);
      count++;
    }
    for (final j in list('races')) {
      nextRaces[j['id'] as String] = Race.fromJson(j);
      count++;
    }
    for (final j in list('backgrounds')) {
      nextBackgrounds[j['id'] as String] = Background.fromJson(j);
      count++;
    }
    for (final j in list('spells')) {
      nextSpells[j['id'] as String] = Spell.fromJson(j);
      count++;
    }

    await writeJsonBatchAtomic({
      File(_path('weapons.json')): _document(
        nextWeapons.values.map((e) => e.toJson()),
      ),
      File(_path('armor.json')): _document(
        nextArmor.values.map((e) => e.toJson()),
      ),
      File(_path('feats.json')): _document(
        nextFeats.values.map((e) => e.toJson()),
      ),
      File(_path('races.json')): _document(
        nextRaces.values.map((e) => e.toJson()),
      ),
      File(_path('backgrounds.json')): _document(
        nextBackgrounds.values.map((e) => e.toJson()),
      ),
      File(_path('spells.json')): _document(
        nextSpells.values.map((e) => e.toJson()),
      ),
    });

    weapons
      ..clear()
      ..addAll(nextWeapons);
    armor
      ..clear()
      ..addAll(nextArmor);
    feats
      ..clear()
      ..addAll(nextFeats);
    races
      ..clear()
      ..addAll(nextRaces);
    backgrounds
      ..clear()
      ..addAll(nextBackgrounds);
    spells
      ..clear()
      ..addAll(nextSpells);
    return count;
  }

  /// Copia del contenido homebrew como repositorio, para fusionar con el oficial.
  ContentRepository toRepository() => ContentRepository(
    weapons: Map.of(weapons),
    armor: Map.of(armor),
    feats: Map.of(feats),
    races: Map.of(races),
    backgrounds: Map.of(backgrounds),
    spells: Map.of(spells),
  );

  Future<void> saveWeapon(Weapon w) async {
    final next = Map<String, Weapon>.of(weapons)..[w.id] = w;
    await _writeList('weapons.json', next.values.map((e) => e.toJson()));
    weapons
      ..clear()
      ..addAll(next);
  }

  Future<void> saveArmor(Armor a) async {
    final next = Map<String, Armor>.of(armor)..[a.id] = a;
    await _writeList('armor.json', next.values.map((e) => e.toJson()));
    armor
      ..clear()
      ..addAll(next);
  }

  Future<void> saveFeat(Feat f) async {
    final next = Map<String, Feat>.of(feats)..[f.id] = f;
    await _writeList('feats.json', next.values.map((e) => e.toJson()));
    feats
      ..clear()
      ..addAll(next);
  }

  Future<void> saveRace(Race r) async {
    final next = Map<String, Race>.of(races)..[r.id] = r;
    await _writeList('races.json', next.values.map((e) => e.toJson()));
    races
      ..clear()
      ..addAll(next);
  }

  Future<void> saveBackground(Background b) async {
    final next = Map<String, Background>.of(backgrounds)..[b.id] = b;
    await _writeList('backgrounds.json', next.values.map((e) => e.toJson()));
    backgrounds
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteWeapon(String id) async {
    final next = Map<String, Weapon>.of(weapons)..remove(id);
    await _writeList('weapons.json', next.values.map((e) => e.toJson()));
    weapons
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteArmor(String id) async {
    final next = Map<String, Armor>.of(armor)..remove(id);
    await _writeList('armor.json', next.values.map((e) => e.toJson()));
    armor
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteFeat(String id) async {
    final next = Map<String, Feat>.of(feats)..remove(id);
    await _writeList('feats.json', next.values.map((e) => e.toJson()));
    feats
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteRace(String id) async {
    final next = Map<String, Race>.of(races)..remove(id);
    await _writeList('races.json', next.values.map((e) => e.toJson()));
    races
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteBackground(String id) async {
    final next = Map<String, Background>.of(backgrounds)..remove(id);
    await _writeList('backgrounds.json', next.values.map((e) => e.toJson()));
    backgrounds
      ..clear()
      ..addAll(next);
  }

  Future<void> saveSpell(Spell s) async {
    final next = Map<String, Spell>.of(spells)..[s.id] = s;
    await _writeList('spells.json', next.values.map((e) => e.toJson()));
    spells
      ..clear()
      ..addAll(next);
  }

  Future<void> deleteSpell(String id) async {
    final next = Map<String, Spell>.of(spells)..remove(id);
    await _writeList('spells.json', next.values.map((e) => e.toJson()));
    spells
      ..clear()
      ..addAll(next);
  }
}

/// Genera un id a partir de un nombre (slug + sufijo para evitar colisiones).
String homebrewId(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)'), '');
  final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'hb-${slug.isEmpty ? 'item' : slug}-$suffix';
}
