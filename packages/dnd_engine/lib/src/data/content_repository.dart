import '../domain/content.dart';
import '../domain/data_version.dart';
import '../domain/name_sort.dart';
import 'content_pack_loader_stub.dart'
    if (dart.library.io) 'content_pack_loader_io.dart'
    as _loader;

class ContentPackManifest {
  static const int currentFormatVersion = 1;
  static const String type = 'dnd-content-pack';

  final String id;
  final String ruleset;
  final int formatVersion;

  const ContentPackManifest({
    required this.id,
    required this.ruleset,
    required this.formatVersion,
  });

  factory ContentPackManifest.fromJson(Map<String, dynamic> json) {
    if (json['type'] != type) {
      throw const FormatException(
        'El manifiesto no corresponde a un paquete de contenido D&D.',
      );
    }
    final version = json['formatVersion'];
    if (version is! int || version < 1) {
      throw const FormatException(
        'La versión del paquete debe ser un entero positivo.',
      );
    }
    if (version > currentFormatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'paquete de contenido',
        found: version,
        supported: currentFormatVersion,
      );
    }
    final id = json['id'];
    final ruleset = json['ruleset'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('El paquete de contenido no tiene id.');
    }
    if (ruleset is! String || ruleset.trim().isEmpty) {
      throw const FormatException(
        'El paquete de contenido no declara su reglamento.',
      );
    }
    return ContentPackManifest(
      id: id,
      ruleset: ruleset,
      formatVersion: version,
    );
  }
}

/// Repositorio en memoria de todo el contenido disponible (oficial + homebrew),
/// indexado por id. El compilador resuelve referencias contra esto.
class ContentRepository {
  final Map<String, Race> races;
  final Map<String, CharacterClass> classes;
  final Map<String, Subclass> subclasses;
  final Map<String, Lineage> lineages;
  final Map<String, Background> backgrounds;
  final Map<String, Feat> feats;
  final Map<String, Weapon> weapons;
  final Map<String, Armor> armor;
  final Map<String, Spell> spells;

  ContentRepository({
    Map<String, Race>? races,
    Map<String, CharacterClass>? classes,
    Map<String, Subclass>? subclasses,
    Map<String, Lineage>? lineages,
    Map<String, Background>? backgrounds,
    Map<String, Feat>? feats,
    Map<String, Weapon>? weapons,
    Map<String, Armor>? armor,
    Map<String, Spell>? spells,
  }) : races = races ?? {},
       classes = classes ?? {},
       subclasses = subclasses ?? {},
       lineages = lineages ?? {},
       backgrounds = backgrounds ?? {},
       feats = feats ?? {},
       weapons = weapons ?? {},
       armor = armor ?? {},
       spells = spells ?? {};

  Race? race(String id) => races[id];
  CharacterClass? characterClass(String id) => classes[id];
  Subclass? subclass(String id) => subclasses[id];
  Lineage? lineage(String id) => lineages[id];
  Background? background(String id) => backgrounds[id];
  Feat? feat(String id) => feats[id];
  Weapon? weapon(String id) => weapons[id];
  Armor? armorPiece(String id) => armor[id];
  Spell? spell(String id) => spells[id];

  /// Catálogos completos en orden alfabético, que es como los lista la UI. Los
  /// mapas conservan el orden de carga del JSON, que no le sirve a nadie para
  /// buscar una opción: ordenar acá evita que cada pantalla se arme su propio
  /// criterio (y se olvide de las tildes).
  List<Race> get racesSorted => sortedByName(races.values, (e) => e.name);
  List<CharacterClass> get classesSorted =>
      sortedByName(classes.values, (e) => e.name);
  List<Background> get backgroundsSorted =>
      sortedByName(backgrounds.values, (e) => e.name);
  List<Feat> get featsSorted => sortedByName(feats.values, (e) => e.name);

  /// Opciones de una elección abierta: las dotes de [category], alfabéticas.
  /// Es lo único que hace falta para que un catálogo nuevo (invocaciones,
  /// estilos) sea puro dato: nadie lleva una lista de ids.
  List<Feat> featsByCategory(String category) => sortedByName(
    feats.values.where((f) => f.category == category),
    (e) => e.name,
  );
  List<Weapon> get weaponsSorted => sortedByName(weapons.values, (e) => e.name);
  List<Armor> get armorSorted => sortedByName(armor.values, (e) => e.name);

  /// Subclases que pertenecen a una clase (id de clase), ordenadas por nombre.
  List<Subclass> subclassesForClass(String classId) => sortedByName(
    subclasses.values.where((s) => s.classId == classId),
    (e) => e.name,
  );

  /// Linajes que pertenecen a una especie, ordenados por nombre. Vacío = esa
  /// especie no exige elegir linaje.
  List<Lineage> lineagesForRace(String raceId) => sortedByName(
    lineages.values.where((l) => l.raceId == raceId),
    (e) => e.name,
  );

  /// Conjuros de la lista de una clase (id de clase), ordenados por nivel y
  /// después por nombre: el nivel manda porque es como se leen en la ficha.
  List<Spell> spellsForList(String classId) =>
      spells.values.where((s) => s.classes.contains(classId)).toList()..sort(
        (a, b) => a.level != b.level
            ? a.level.compareTo(b.level)
            : compareContentNames(a.name, b.name),
      );

  /// Todos los conjuros por nivel y nombre (catálogo homebrew, que no filtra
  /// por lista de clase).
  List<Spell> get spellsSorted => spells.values.toList()
    ..sort(
      (a, b) => a.level != b.level
          ? a.level.compareTo(b.level)
          : compareContentNames(a.name, b.name),
    );

  /// Incorpora contenido homebrew (mismo esquema) sobre el oficial.
  void addAll(ContentRepository other) {
    races.addAll(other.races);
    classes.addAll(other.classes);
    subclasses.addAll(other.subclasses);
    lineages.addAll(other.lineages);
    backgrounds.addAll(other.backgrounds);
    feats.addAll(other.feats);
    weapons.addAll(other.weapons);
    armor.addAll(other.armor);
    spells.addAll(other.spells);
  }

  /// Construye un repositorio desde mapas JSON ya decodificados (una lista por
  /// tipo de entidad). Útil para tests y para carga desde assets de Flutter.
  factory ContentRepository.fromJsonPacks({
    List<Map<String, dynamic>> races = const [],
    List<Map<String, dynamic>> classes = const [],
    List<Map<String, dynamic>> subclasses = const [],
    List<Map<String, dynamic>> lineages = const [],
    List<Map<String, dynamic>> backgrounds = const [],
    List<Map<String, dynamic>> feats = const [],
    List<Map<String, dynamic>> weapons = const [],
    List<Map<String, dynamic>> armor = const [],
    List<Map<String, dynamic>> spells = const [],
  }) {
    return ContentRepository(
      races: {for (final j in races) j['id'] as String: Race.fromJson(j)},
      classes: {
        for (final j in classes) j['id'] as String: CharacterClass.fromJson(j),
      },
      subclasses: {
        for (final j in subclasses) j['id'] as String: Subclass.fromJson(j),
      },
      lineages: {
        for (final j in lineages) j['id'] as String: Lineage.fromJson(j),
      },
      backgrounds: {
        for (final j in backgrounds) j['id'] as String: Background.fromJson(j),
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
  ///
  /// Requiere `dart:io` y por eso se resuelve mediante importación
  /// condicional: en web queda inalcanzable en tiempo de compilación en vez
  /// de solo fallar en tiempo de ejecución.
  static Future<ContentRepository> loadFromDirectory(String dirPath) =>
      _loader.loadContentRepositoryFromDirectory(dirPath);
}
