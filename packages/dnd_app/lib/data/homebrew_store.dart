import 'package:dnd_engine/dnd_engine.dart';

import '../api/api_client.dart';

class HomebrewLoadIssue {
  final String category;
  final String id;
  final String message;

  const HomebrewLoadIssue({
    required this.category,
    required this.id,
    required this.message,
  });
}

/// Contenido homebrew de la cuenta autenticada, respaldado por la API del
/// servidor (ver `design.md`, decisión D6: reemplaza al almacén de archivos
/// de escritorio, no lo porta). Mismo esquema en memoria que la versión de
/// escritorio para que la UI de `homebrew/` no necesite cambios: un mapa por
/// categoría, fusionable en un [ContentRepository].
class HomebrewStore {
  final ApiClient api;
  final Map<String, Weapon> weapons = {};
  final Map<String, Armor> armor = {};
  final Map<String, Item> items = {};
  final Map<String, Feat> feats = {};
  final Map<String, Race> races = {};
  final Map<String, Background> backgrounds = {};
  final Map<String, Spell> spells = {};
  final Map<String, Creature> creatures = {};
  final List<HomebrewLoadIssue> loadIssues = [];

  HomebrewStore(this.api);

  Future<void> load() async {
    final content = await api.listHomebrew();
    loadIssues.clear();
    _loadCategory(content, 'weapons', weapons, Weapon.fromJson);
    _loadCategory(content, 'armor', armor, Armor.fromJson);
    _loadCategory(content, 'items', items, Item.fromJson);
    _loadCategory(content, 'feats', feats, Feat.fromJson);
    _loadCategory(content, 'races', races, Race.fromJson);
    _loadCategory(content, 'backgrounds', backgrounds, Background.fromJson);
    _loadCategory(content, 'spells', spells, Spell.fromJson);
    _loadCategory(content, 'creatures', creatures, Creature.fromJson);
  }

  void _loadCategory<T>(
    Map<String, List<Map<String, dynamic>>> content,
    String category,
    Map<String, T> target,
    T Function(Map<String, dynamic>) parse,
  ) {
    target.clear();
    for (final document in content[category] ?? const []) {
      final rawId = document['id'];
      final issueId = rawId is String && rawId.isNotEmpty ? rawId : '(sin id)';
      try {
        if (rawId is! String || rawId.isEmpty) {
          throw const FormatException('El id está ausente o vacío.');
        }
        if (document['source'] != 'homebrew') {
          throw const FormatException('El origen debe ser homebrew.');
        }
        target[rawId] = parse(document);
      } catch (error) {
        loadIssues.add(
          HomebrewLoadIssue(
            category: category,
            id: issueId,
            message: error.toString(),
          ),
        );
      }
    }
  }

  /// Todo el contenido homebrew serializado a listas JSON por tipo, para
  /// exportarlo. Las claves coinciden con las categorías del servidor.
  Map<String, List<Map<String, dynamic>>> exportContent() => {
    'weapons': weapons.values.map((e) => e.toJson()).toList(),
    'armor': armor.values.map((e) => e.toJson()).toList(),
    'items': items.values.map((e) => e.toJson()).toList(),
    'feats': feats.values.map((e) => e.toJson()).toList(),
    'races': races.values.map((e) => e.toJson()).toList(),
    'backgrounds': backgrounds.values.map((e) => e.toJson()).toList(),
    'spells': spells.values.map((e) => e.toJson()).toList(),
    'creatures': creatures.values.map((e) => e.toJson()).toList(),
  };

  /// Cuántas entradas de [content] tienen un id que **ya existe** en el store
  /// (es decir, que un [importContent] sobrescribiría). Cero = import
  /// puramente aditivo. La UI lo usa para pedir confirmación antes de pisar
  /// homebrew.
  int countCollisions(Map<String, List<Map<String, dynamic>>> content) {
    final existingIds = <String, Set<String>>{
      'weapons': weapons.keys.toSet(),
      'armor': armor.keys.toSet(),
      'items': items.keys.toSet(),
      'feats': feats.keys.toSet(),
      'races': races.keys.toSet(),
      'backgrounds': backgrounds.keys.toSet(),
      'spells': spells.keys.toSet(),
      'creatures': creatures.keys.toSet(),
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
  /// fusionándolo por id: una entrada con id existente se sobrescribe. El
  /// servidor valida el pack completo y lo guarda en una sola transacción.
  /// Devuelve la cantidad total de entradas importadas.
  Future<int> importContent(
    Map<String, List<Map<String, dynamic>>> content, {
    required ContentRepository repository,
  }) async {
    _validateInventoryIds(content, repository);
    final count = await api.importHomebrew(content);
    await load();
    return count;
  }

  Future<void> deleteInvalid(HomebrewLoadIssue issue) async {
    await api.deleteHomebrew(issue.category, issue.id);
    loadIssues.remove(issue);
  }

  /// Evita que un id de inventario cambie de significado según qué catálogo
  /// lo resuelva primero. Se permite sobrescribir homebrew del mismo tipo; el
  /// contenido oficial y los cruces arma/armadura/objeto son inmutables.
  void _validateInventoryIds(
    Map<String, List<Map<String, dynamic>>> content,
    ContentRepository repository,
  ) {
    final incomingKinds = <String, String>{};
    for (final entry in content.entries) {
      if (!const {'weapons', 'armor', 'items'}.contains(entry.key)) continue;
      for (final json in entry.value) {
        final id = json['id'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException(
            'Un arma, armadura u objeto del pack no tiene un id válido.',
          );
        }
        final previousKind = incomingKinds[id];
        if (previousKind != null && previousKind != entry.key) {
          throw FormatException(
            'El id "$id" aparece en $previousKind y ${entry.key}.',
          );
        }
        incomingKinds[id] = entry.key;

        final matches = <({String kind, ContentSource source})>[
          if (repository.weapons[id] case final value?)
            (kind: 'weapons', source: value.source),
          if (repository.armor[id] case final value?)
            (kind: 'armor', source: value.source),
          if (repository.items[id] case final value?)
            (kind: 'items', source: value.source),
        ];
        if (matches.isEmpty) continue;
        if (matches.length > 1) {
          throw FormatException(
            'El id "$id" ya está repetido entre los catálogos de inventario.',
          );
        }
        final existing = matches.single;
        if (existing.kind != entry.key) {
          throw FormatException(
            'El id "$id" ya pertenece a ${existing.kind} y no puede usarse '
            'en ${entry.key}.',
          );
        }
        if (existing.source != ContentSource.homebrew) {
          throw FormatException(
            'El id "$id" pertenece al catálogo oficial y no puede '
            'sobrescribirse.',
          );
        }
      }
    }
  }

  /// Copia del contenido homebrew como repositorio, para fusionar con el oficial.
  ContentRepository toRepository() => ContentRepository(
    weapons: Map.of(weapons),
    armor: Map.of(armor),
    items: Map.of(items),
    feats: Map.of(feats),
    races: Map.of(races),
    backgrounds: Map.of(backgrounds),
    spells: Map.of(spells),
    creatures: Map.of(creatures),
  );

  Future<void> saveWeapon(Weapon w) async {
    await api.upsertHomebrew('weapons', w.toJson());
    weapons[w.id] = w;
  }

  Future<void> saveArmor(Armor a) async {
    await api.upsertHomebrew('armor', a.toJson());
    armor[a.id] = a;
  }

  Future<void> saveItem(Item i) async {
    await api.upsertHomebrew('items', i.toJson());
    items[i.id] = i;
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

  Future<void> saveCreature(Creature c) async {
    await api.upsertHomebrew('creatures', c.toJson());
    creatures[c.id] = c;
  }

  Future<void> deleteWeapon(String id) async {
    await api.deleteHomebrew('weapons', id);
    weapons.remove(id);
  }

  Future<void> deleteArmor(String id) async {
    await api.deleteHomebrew('armor', id);
    armor.remove(id);
  }

  Future<void> deleteItem(String id) async {
    await api.deleteHomebrew('items', id);
    items.remove(id);
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

  Future<void> deleteCreature(String id) async {
    await api.deleteHomebrew('creatures', id);
    creatures.remove(id);
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
