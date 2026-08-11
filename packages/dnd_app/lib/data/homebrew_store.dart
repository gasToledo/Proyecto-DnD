import 'package:dnd_engine/dnd_engine.dart';

import '../api/api_client.dart';

/// Contenido homebrew de la cuenta autenticada, respaldado por la API del
/// servidor (ver `design.md`, decisión D6: reemplaza al almacén de archivos
/// de escritorio, no lo porta). Mismo esquema en memoria que la versión de
/// escritorio para que la UI de `homebrew/` no necesite cambios: un mapa por
/// categoría, fusionable en un [ContentRepository].
class HomebrewStore {
  final ApiClient api;
  final Map<String, Weapon> weapons = {};
  final Map<String, Armor> armor = {};
  final Map<String, Feat> feats = {};
  final Map<String, Race> races = {};
  final Map<String, Background> backgrounds = {};
  final Map<String, Spell> spells = {};

  HomebrewStore(this.api);

  Future<void> load() async {
    final content = await api.listHomebrew();
    weapons
      ..clear()
      ..addEntries(
        (content['weapons'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Weapon.fromJson(j)),
        ),
      );
    armor
      ..clear()
      ..addEntries(
        (content['armor'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Armor.fromJson(j)),
        ),
      );
    feats
      ..clear()
      ..addEntries(
        (content['feats'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Feat.fromJson(j)),
        ),
      );
    races
      ..clear()
      ..addEntries(
        (content['races'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Race.fromJson(j)),
        ),
      );
    backgrounds
      ..clear()
      ..addEntries(
        (content['backgrounds'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Background.fromJson(j)),
        ),
      );
    spells
      ..clear()
      ..addEntries(
        (content['spells'] ?? const []).map(
          (j) => MapEntry(j['id'] as String, Spell.fromJson(j)),
        ),
      );
  }

  /// Todo el contenido homebrew serializado a listas JSON por tipo, para
  /// exportarlo. Las claves coinciden con las categorías del servidor.
  Map<String, List<Map<String, dynamic>>> exportContent() => {
    'weapons': weapons.values.map((e) => e.toJson()).toList(),
    'armor': armor.values.map((e) => e.toJson()).toList(),
    'feats': feats.values.map((e) => e.toJson()).toList(),
    'races': races.values.map((e) => e.toJson()).toList(),
    'backgrounds': backgrounds.values.map((e) => e.toJson()).toList(),
    'spells': spells.values.map((e) => e.toJson()).toList(),
  };

  /// Cuántas entradas de [content] tienen un id que **ya existe** en el store
  /// (es decir, que un [importContent] sobrescribiría). Cero = import
  /// puramente aditivo. La UI lo usa para pedir confirmación antes de pisar
  /// homebrew.
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

  /// Importa contenido homebrew (mismo formato que [exportContent])
  /// fusionándolo por id: una entrada con id existente se sobrescribe. Cada
  /// entrada se guarda con su propia llamada a la API (no hay un endpoint de
  /// importación atómica de homebrew: es un paquete aparte del respaldo
  /// principal, de menor cuenta que el flujo de `/api/import`). Devuelve la
  /// cantidad total de entradas importadas.
  Future<int> importContent(
    Map<String, List<Map<String, dynamic>>> content,
  ) async {
    var count = 0;
    for (final entry in content.entries) {
      for (final json in entry.value) {
        await api.upsertHomebrew(entry.key, json);
        count++;
      }
    }
    await load();
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
    await api.upsertHomebrew('weapons', w.toJson());
    weapons[w.id] = w;
  }

  Future<void> saveArmor(Armor a) async {
    await api.upsertHomebrew('armor', a.toJson());
    armor[a.id] = a;
  }

  Future<void> saveFeat(Feat f) async {
    await api.upsertHomebrew('feats', f.toJson());
    feats[f.id] = f;
  }

  Future<void> saveRace(Race r) async {
    await api.upsertHomebrew('races', r.toJson());
    races[r.id] = r;
  }

  Future<void> saveBackground(Background b) async {
    await api.upsertHomebrew('backgrounds', b.toJson());
    backgrounds[b.id] = b;
  }

  Future<void> saveSpell(Spell s) async {
    await api.upsertHomebrew('spells', s.toJson());
    spells[s.id] = s;
  }

  Future<void> deleteWeapon(String id) async {
    await api.deleteHomebrew('weapons', id);
    weapons.remove(id);
  }

  Future<void> deleteArmor(String id) async {
    await api.deleteHomebrew('armor', id);
    armor.remove(id);
  }

  Future<void> deleteFeat(String id) async {
    await api.deleteHomebrew('feats', id);
    feats.remove(id);
  }

  Future<void> deleteRace(String id) async {
    await api.deleteHomebrew('races', id);
    races.remove(id);
  }

  Future<void> deleteBackground(String id) async {
    await api.deleteHomebrew('backgrounds', id);
    backgrounds.remove(id);
  }

  Future<void> deleteSpell(String id) async {
    await api.deleteHomebrew('spells', id);
    spells.remove(id);
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
