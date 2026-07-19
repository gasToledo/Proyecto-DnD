import 'dart:convert';
import 'dart:io';

import '../domain/content.dart';

/// Repositorio en memoria de todo el contenido disponible (oficial + homebrew),
/// indexado por id. El compilador resuelve referencias contra esto.
class ContentRepository {
  final Map<String, Race> races;
  final Map<String, CharacterClass> classes;
  final Map<String, Background> backgrounds;
  final Map<String, Feat> feats;
  final Map<String, Weapon> weapons;
  final Map<String, Armor> armor;
  final Map<String, Spell> spells;

  ContentRepository({
    Map<String, Race>? races,
    Map<String, CharacterClass>? classes,
    Map<String, Background>? backgrounds,
    Map<String, Feat>? feats,
    Map<String, Weapon>? weapons,
    Map<String, Armor>? armor,
    Map<String, Spell>? spells,
  })  : races = races ?? {},
        classes = classes ?? {},
        backgrounds = backgrounds ?? {},
        feats = feats ?? {},
        weapons = weapons ?? {},
        armor = armor ?? {},
        spells = spells ?? {};

  Race? race(String id) => races[id];
  CharacterClass? characterClass(String id) => classes[id];
  Background? background(String id) => backgrounds[id];
  Feat? feat(String id) => feats[id];
  Weapon? weapon(String id) => weapons[id];
  Armor? armorPiece(String id) => armor[id];
  Spell? spell(String id) => spells[id];

  /// Conjuros de la lista de una clase (id de clase), ordenados por nivel y nombre.
  List<Spell> spellsForList(String classId) {
    final list = spells.values.where((s) => s.classes.contains(classId)).toList()
      ..sort((a, b) => a.level != b.level
          ? a.level.compareTo(b.level)
          : a.name.compareTo(b.name));
    return list;
  }

  /// Incorpora contenido homebrew (mismo esquema) sobre el oficial.
  void addAll(ContentRepository other) {
    races.addAll(other.races);
    classes.addAll(other.classes);
    backgrounds.addAll(other.backgrounds);
    feats.addAll(other.feats);
    weapons.addAll(other.weapons);
    armor.addAll(other.armor);
    spells.addAll(other.spells);
  }

  static List<Map<String, dynamic>> _list(dynamic decoded) =>
      (decoded as List).cast<Map<String, dynamic>>();

  /// Construye un repositorio desde mapas JSON ya decodificados (una lista por
  /// tipo de entidad). Útil para tests y para carga desde assets de Flutter.
  factory ContentRepository.fromJsonPacks({
    List<Map<String, dynamic>> races = const [],
    List<Map<String, dynamic>> classes = const [],
    List<Map<String, dynamic>> backgrounds = const [],
    List<Map<String, dynamic>> feats = const [],
    List<Map<String, dynamic>> weapons = const [],
    List<Map<String, dynamic>> armor = const [],
    List<Map<String, dynamic>> spells = const [],
  }) {
    return ContentRepository(
      races: {for (final j in races) j['id'] as String: Race.fromJson(j)},
      classes: {
        for (final j in classes) j['id'] as String: CharacterClass.fromJson(j)
      },
      backgrounds: {
        for (final j in backgrounds) j['id'] as String: Background.fromJson(j)
      },
      feats: {for (final j in feats) j['id'] as String: Feat.fromJson(j)},
      weapons: {for (final j in weapons) j['id'] as String: Weapon.fromJson(j)},
      armor: {for (final j in armor) j['id'] as String: Armor.fromJson(j)},
      spells: {for (final j in spells) j['id'] as String: Spell.fromJson(j)},
    );
  }

  /// Carga un pack desde un directorio con archivos
  /// races.json / classes.json / backgrounds.json / feats.json /
  /// weapons.json / armor.json (cada uno una lista JSON). Los faltantes se
  /// tratan como vacíos.
  static Future<ContentRepository> loadFromDirectory(String dirPath) async {
    Future<List<Map<String, dynamic>>> read(String file) async {
      final f = File('$dirPath/$file');
      if (!await f.exists()) return const [];
      return _list(jsonDecode(await f.readAsString()));
    }

    return ContentRepository.fromJsonPacks(
      races: await read('races.json'),
      classes: await read('classes.json'),
      backgrounds: await read('backgrounds.json'),
      feats: await read('feats.json'),
      weapons: await read('weapons.json'),
      armor: await read('armor.json'),
      spells: await read('spells.json'),
    );
  }
}
