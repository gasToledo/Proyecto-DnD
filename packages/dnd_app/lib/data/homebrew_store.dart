import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// Almacén local de contenido homebrew (razas, dotes, armas, armaduras,
/// trasfondos). Mismo esquema que el pack oficial: se guarda un archivo JSON
/// por tipo en `~/FichasDnD/homebrew/` y se fusiona al [ContentRepository].
class HomebrewStore {
  final Map<String, Weapon> weapons = {};
  final Map<String, Armor> armor = {};
  final Map<String, Feat> feats = {};
  final Map<String, Race> races = {};
  final Map<String, Background> backgrounds = {};
  final Map<String, Spell> spells = {};

  String _path(String file) => p.join(fichasDir('homebrew'), file);

  Future<List<Map<String, dynamic>>> _readList(String file) async {
    final f = File(_path(file));
    if (!await f.exists()) return const [];
    try {
      return (jsonDecode(await f.readAsString()) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeList(
      String file, Iterable<Map<String, dynamic>> items) async {
    final dir = Directory(fichasDir('homebrew'));
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(_path(file))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(items.toList()));
  }

  Future<void> load() async {
    for (final j in await _readList('weapons.json')) {
      weapons[j['id'] as String] = Weapon.fromJson(j);
    }
    for (final j in await _readList('armor.json')) {
      armor[j['id'] as String] = Armor.fromJson(j);
    }
    for (final j in await _readList('feats.json')) {
      feats[j['id'] as String] = Feat.fromJson(j);
    }
    for (final j in await _readList('races.json')) {
      races[j['id'] as String] = Race.fromJson(j);
    }
    for (final j in await _readList('backgrounds.json')) {
      backgrounds[j['id'] as String] = Background.fromJson(j);
    }
    for (final j in await _readList('spells.json')) {
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

  /// Importa contenido homebrew (mismo formato que [exportContent]) fusionándolo
  /// por id: una entrada con id existente se sobrescribe. Persiste cada tipo una
  /// sola vez. Devuelve la cantidad total de entradas importadas.
  Future<int> importContent(Map<String, List<Map<String, dynamic>>> content) async {
    var count = 0;
    List<Map<String, dynamic>> list(String k) => content[k] ?? const [];

    for (final j in list('weapons')) {
      weapons[j['id'] as String] = Weapon.fromJson(j);
      count++;
    }
    for (final j in list('armor')) {
      armor[j['id'] as String] = Armor.fromJson(j);
      count++;
    }
    for (final j in list('feats')) {
      feats[j['id'] as String] = Feat.fromJson(j);
      count++;
    }
    for (final j in list('races')) {
      races[j['id'] as String] = Race.fromJson(j);
      count++;
    }
    for (final j in list('backgrounds')) {
      backgrounds[j['id'] as String] = Background.fromJson(j);
      count++;
    }
    for (final j in list('spells')) {
      spells[j['id'] as String] = Spell.fromJson(j);
      count++;
    }

    await _writeList('weapons.json', weapons.values.map((e) => e.toJson()));
    await _writeList('armor.json', armor.values.map((e) => e.toJson()));
    await _writeList('feats.json', feats.values.map((e) => e.toJson()));
    await _writeList('races.json', races.values.map((e) => e.toJson()));
    await _writeList('backgrounds.json', backgrounds.values.map((e) => e.toJson()));
    await _writeList('spells.json', spells.values.map((e) => e.toJson()));
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
    weapons[w.id] = w;
    await _writeList('weapons.json', weapons.values.map((e) => e.toJson()));
  }

  Future<void> saveArmor(Armor a) async {
    armor[a.id] = a;
    await _writeList('armor.json', armor.values.map((e) => e.toJson()));
  }

  Future<void> saveFeat(Feat f) async {
    feats[f.id] = f;
    await _writeList('feats.json', feats.values.map((e) => e.toJson()));
  }

  Future<void> saveRace(Race r) async {
    races[r.id] = r;
    await _writeList('races.json', races.values.map((e) => e.toJson()));
  }

  Future<void> saveBackground(Background b) async {
    backgrounds[b.id] = b;
    await _writeList(
        'backgrounds.json', backgrounds.values.map((e) => e.toJson()));
  }

  Future<void> deleteWeapon(String id) async {
    weapons.remove(id);
    await _writeList('weapons.json', weapons.values.map((e) => e.toJson()));
  }

  Future<void> deleteArmor(String id) async {
    armor.remove(id);
    await _writeList('armor.json', armor.values.map((e) => e.toJson()));
  }

  Future<void> deleteFeat(String id) async {
    feats.remove(id);
    await _writeList('feats.json', feats.values.map((e) => e.toJson()));
  }

  Future<void> deleteRace(String id) async {
    races.remove(id);
    await _writeList('races.json', races.values.map((e) => e.toJson()));
  }

  Future<void> deleteBackground(String id) async {
    backgrounds.remove(id);
    await _writeList(
        'backgrounds.json', backgrounds.values.map((e) => e.toJson()));
  }

  Future<void> saveSpell(Spell s) async {
    spells[s.id] = s;
    await _writeList('spells.json', spells.values.map((e) => e.toJson()));
  }

  Future<void> deleteSpell(String id) async {
    spells.remove(id);
    await _writeList('spells.json', spells.values.map((e) => e.toJson()));
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
