import 'ability.dart';
import 'effects.dart';

/// Origen del contenido. Oficial y homebrew comparten estructura; solo cambia
/// esta etiqueta (y de qué edición proviene lo oficial).
enum ContentSource {
  srd2024,
  srd2014,
  homebrew;

  static ContentSource fromJson(String? v) => switch (v) {
        'srd_2024' => ContentSource.srd2024,
        'srd_2014' => ContentSource.srd2014,
        'homebrew' => ContentSource.homebrew,
        _ => ContentSource.homebrew,
      };

  String toJson() => switch (this) {
        ContentSource.srd2024 => 'srd_2024',
        ContentSource.srd2014 => 'srd_2014',
        ContentSource.homebrew => 'homebrew',
      };
}

/// Raza (o especie, en terminología 2024).
class Race {
  final String id;
  final String name;
  final ContentSource source;
  final String size;
  final int speed;
  final List<Effect> effects;

  /// Cantidad de competencias de habilidad a elegir libremente y de qué lista
  /// (vacía = cualquiera). Ej.: Humano 2024 → 1 habilidad ("Hábil").
  final int skillChoiceCount;
  final List<String> skillChoiceFrom;

  const Race({
    required this.id,
    required this.name,
    required this.source,
    this.size = 'Mediano',
    this.speed = 30,
    this.effects = const [],
    this.skillChoiceCount = 0,
    this.skillChoiceFrom = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'size': size,
        'speed': speed,
        'skillChoiceCount': skillChoiceCount,
        'skillChoiceFrom': skillChoiceFrom,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

  factory Race.fromJson(Map<String, dynamic> j) => Race(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        size: j['size'] as String? ?? 'Mediano',
        speed: j['speed'] as int? ?? 30,
        effects: Effect.listFromJson(j['effects']),
        skillChoiceCount: j['skillChoiceCount'] as int? ?? 0,
        skillChoiceFrom: (j['skillChoiceFrom'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// Rasgo de clase que se obtiene a un nivel concreto.
class ClassFeature {
  final int level;
  final String name;
  final String description;
  final List<Effect> effects;

  const ClassFeature({
    required this.level,
    required this.name,
    this.description = '',
    this.effects = const [],
  });

  factory ClassFeature.fromJson(Map<String, dynamic> j) => ClassFeature(
        level: j['level'] as int,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        effects: Effect.listFromJson(j['effects']),
      );
}

class CharacterClass {
  final String id;
  final String name;
  final ContentSource source;
  final int hitDie;
  final List<Ability> savingThrows;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final int skillChoiceCount;
  final List<String> skillChoiceFrom;

  /// Nivel al que se elige subclase (Guerrero 2024: nivel 3).
  final int subclassLevel;

  /// Niveles de Mejora de Característica (ASI). El Guerrero suma extras (6 y 14).
  final List<int> asiLevels;

  final List<ClassFeature> features;

  const CharacterClass({
    required this.id,
    required this.name,
    required this.source,
    required this.hitDie,
    this.savingThrows = const [],
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.skillChoiceCount = 0,
    this.skillChoiceFrom = const [],
    this.subclassLevel = 3,
    this.asiLevels = const [4, 8, 12, 16, 19],
    this.features = const [],
  });

  /// Rasgos activos hasta [level] inclusive.
  List<ClassFeature> featuresUpTo(int level) =>
      features.where((f) => f.level <= level).toList();

  /// Rasgos ganados exactamente al alcanzar [level] (para mostrarlos al subir).
  List<ClassFeature> featuresAt(int level) =>
      features.where((f) => f.level == level).toList();

  bool isAsiLevel(int level) => asiLevels.contains(level);

  factory CharacterClass.fromJson(Map<String, dynamic> j) => CharacterClass(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        hitDie: j['hitDie'] as int,
        savingThrows: (j['savingThrows'] as List? ?? const [])
            .map((e) => Ability.fromKey(e as String))
            .toList(),
        armorProficiencies: (j['armorProficiencies'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        weaponProficiencies: (j['weaponProficiencies'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        skillChoiceCount: j['skillChoiceCount'] as int? ?? 0,
        skillChoiceFrom: (j['skillChoiceFrom'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        subclassLevel: j['subclassLevel'] as int? ?? 3,
        asiLevels: (j['asiLevels'] as List?)?.map((e) => e as int).toList() ??
            const [4, 8, 12, 16, 19],
        features: (j['features'] as List? ?? const [])
            .map((e) => ClassFeature.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Trasfondo. En 2024 otorga una distribución de +característica, competencias
/// fijas y una **dote de origen**.
class Background {
  final String id;
  final String name;
  final ContentSource source;

  /// Las tres características entre las que se reparte el aumento (2024).
  final List<Ability> abilityOptions;
  final List<String> skillProficiencies;
  final List<String> toolProficiencies;
  final String? originFeatId;
  final List<Effect> effects;

  const Background({
    required this.id,
    required this.name,
    required this.source,
    this.abilityOptions = const [],
    this.skillProficiencies = const [],
    this.toolProficiencies = const [],
    this.originFeatId,
    this.effects = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'abilityOptions': abilityOptions.map((a) => a.name).toList(),
        'skillProficiencies': skillProficiencies,
        'toolProficiencies': toolProficiencies,
        'originFeatId': originFeatId,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

  factory Background.fromJson(Map<String, dynamic> j) => Background(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        abilityOptions: (j['abilityOptions'] as List? ?? const [])
            .map((e) => Ability.fromKey(e as String))
            .toList(),
        skillProficiencies: (j['skillProficiencies'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        toolProficiencies: (j['toolProficiencies'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        originFeatId: j['originFeatId'] as String?,
        effects: Effect.listFromJson(j['effects']),
      );
}

/// Dote. `category`: 'origin' | 'general' | 'fighting-style'.
class Feat {
  final String id;
  final String name;
  final ContentSource source;
  final String category;
  final bool repeatable;
  final List<Effect> effects;

  const Feat({
    required this.id,
    required this.name,
    required this.source,
    this.category = 'general',
    this.repeatable = false,
    this.effects = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'category': category,
        'repeatable': repeatable,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

  factory Feat.fromJson(Map<String, dynamic> j) => Feat(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        category: j['category'] as String? ?? 'general',
        repeatable: j['repeatable'] as bool? ?? false,
        effects: Effect.listFromJson(j['effects']),
      );
}

class Weapon {
  final String id;
  final String name;
  final ContentSource source;

  /// 'simple' | 'martial'.
  final String category;

  /// Dado de daño base, p.ej. "1d8".
  final String damageDice;
  final String damageType;

  /// Propiedades: finesse, versatile, two-handed, light, heavy, thrown,
  /// ranged, ammunition, reach, loading.
  final List<String> properties;

  /// Dado de daño a dos manos si es versátil, p.ej. "1d10".
  final String? versatileDice;

  /// Propiedad de Maestría 2024 (sap, graze, nick, cleave, ...).
  final String? mastery;

  const Weapon({
    required this.id,
    required this.name,
    required this.source,
    required this.category,
    required this.damageDice,
    required this.damageType,
    this.properties = const [],
    this.versatileDice,
    this.mastery,
  });

  bool get isRanged => properties.contains('ranged');
  bool get isFinesse => properties.contains('finesse');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'category': category,
        'damageDice': damageDice,
        'damageType': damageType,
        'properties': properties,
        'versatileDice': versatileDice,
        'mastery': mastery,
      };

  factory Weapon.fromJson(Map<String, dynamic> j) => Weapon(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        category: j['category'] as String,
        damageDice: j['damageDice'] as String,
        damageType: j['damageType'] as String,
        properties: (j['properties'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        versatileDice: j['versatileDice'] as String?,
        mastery: j['mastery'] as String?,
      );
}

class Armor {
  final String id;
  final String name;
  final ContentSource source;

  /// 'light' | 'medium' | 'heavy' | 'shield'.
  final String category;
  final int baseAc;
  final bool addDexMod;
  final int? maxDexBonus;
  final int? strengthRequirement;
  final bool stealthDisadvantage;

  const Armor({
    required this.id,
    required this.name,
    required this.source,
    required this.category,
    required this.baseAc,
    this.addDexMod = false,
    this.maxDexBonus,
    this.strengthRequirement,
    this.stealthDisadvantage = false,
  });

  bool get isShield => category == 'shield';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'category': category,
        'baseAc': baseAc,
        'addDexMod': addDexMod,
        'maxDexBonus': maxDexBonus,
        'strengthRequirement': strengthRequirement,
        'stealthDisadvantage': stealthDisadvantage,
      };

  factory Armor.fromJson(Map<String, dynamic> j) => Armor(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        category: j['category'] as String,
        baseAc: j['baseAc'] as int,
        addDexMod: j['addDexMod'] as bool? ?? false,
        maxDexBonus: j['maxDexBonus'] as int?,
        strengthRequirement: j['strengthRequirement'] as int?,
        stealthDisadvantage: j['stealthDisadvantage'] as bool? ?? false,
      );
}
