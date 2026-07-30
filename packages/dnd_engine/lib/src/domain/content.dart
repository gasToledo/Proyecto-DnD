import 'ability.dart';
import 'effects.dart';

/// Origen del contenido. Oficial y homebrew comparten estructura; solo cambia
/// esta etiqueta (y de qué edición proviene lo oficial).
///
/// `srd2024` es lo licenciable bajo CC BY 4.0. `phb2024` es contenido oficial
/// del Player's Handbook 2024 que **no** está en el SRD 5.2.1 y por lo tanto no
/// queda cubierto por esa atribución: la distinción es de licencia, no cosmética.
/// `foa2025` es *Forge of the Artificer*, una expansión aparte: tampoco está en
/// el SRD, y además el jugador necesita ver que una opción viene de otro libro
/// antes de comprometer un personaje con ella.
enum ContentSource {
  srd2024,
  phb2024,
  foa2025,
  srd2014,
  homebrew;

  /// Un valor desconocido degrada a [homebrew] a propósito: este parser también
  /// procesa importaciones, que se tratan como datos no confiables y no deben
  /// hacer fallar la carga. La red de seguridad del contenido oficial es
  /// `content_integrity_test.dart`, no una excepción en tiempo de carga.
  static ContentSource fromJson(String? v) => switch (v) {
        'srd_2024' => ContentSource.srd2024,
        'phb_2024' => ContentSource.phb2024,
        'foa_2025' => ContentSource.foa2025,
        'srd_2014' => ContentSource.srd2014,
        'homebrew' => ContentSource.homebrew,
        _ => ContentSource.homebrew,
      };

  String toJson() => switch (this) {
        ContentSource.srd2024 => 'srd_2024',
        ContentSource.phb2024 => 'phb_2024',
        ContentSource.foa2025 => 'foa_2025',
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

  /// Identificador del ícono (mapeado a un ícono de Material en la app).
  /// Null = ícono genérico.
  final String? iconId;

  /// Línea de sabor para las tarjetas de selección. Null = sin tagline.
  final String? tagline;

  const Race({
    required this.id,
    required this.name,
    required this.source,
    this.size = 'Mediano',
    this.speed = 30,
    this.effects = const [],
    this.skillChoiceCount = 0,
    this.skillChoiceFrom = const [],
    this.iconId,
    this.tagline,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'size': size,
        'speed': speed,
        'skillChoiceCount': skillChoiceCount,
        'skillChoiceFrom': skillChoiceFrom,
        'iconId': iconId,
        'tagline': tagline,
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
        iconId: j['iconId'] as String?,
        tagline: j['tagline'] as String?,
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

  Map<String, dynamic> toJson() => {
        'level': level,
        'name': name,
        'description': description,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

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

  /// Si la clase concede una elección de Estilo de Combate (Guerrero; en el
  /// futuro Paladín/Explorador con su propia integración).
  final bool grantsFightingStyle;

  /// Color de acento de la clase, en hex ("#RRGGBB"), para la personalización
  /// visual. Null = sin acento propio (la UI usa el color por defecto).
  final String? accentColor;

  /// Identificador del ícono de la clase (mapeado a un ícono de Material en la
  /// app, p.ej. "shield" → Icons.shield). Null = ícono genérico.
  final String? iconId;

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
    this.grantsFightingStyle = false,
    this.accentColor,
    this.iconId,
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
        grantsFightingStyle: j['grantsFightingStyle'] as bool? ?? false,
        accentColor: j['accentColor'] as String?,
        iconId: j['iconId'] as String?,
        features: (j['features'] as List? ?? const [])
            .map((e) => ClassFeature.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Subclase (Camino Primario, Escuela Arcana, Dominio, etc.). Pertenece a una
/// clase (`classId`) y aporta rasgos por nivel igual que la clase base. Se
/// elige al `subclassLevel` de la clase (2024: nivel 3 en todas). Oficial y
/// homebrew comparten este modelo.
class Subclass {
  final String id;
  final String name;
  final String classId;
  final ContentSource source;
  final String description;
  final List<ClassFeature> features;

  const Subclass({
    required this.id,
    required this.name,
    required this.classId,
    required this.source,
    this.description = '',
    this.features = const [],
  });

  /// Rasgos de subclase activos hasta [level] inclusive.
  List<ClassFeature> featuresUpTo(int level) =>
      features.where((f) => f.level <= level).toList();

  /// Rasgos de subclase ganados exactamente al alcanzar [level].
  List<ClassFeature> featuresAt(int level) =>
      features.where((f) => f.level == level).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'classId': classId,
        'source': source.toJson(),
        'description': description,
        'features': features.map((f) => f.toJson()).toList(),
      };

  factory Subclass.fromJson(Map<String, dynamic> j) => Subclass(
        id: j['id'] as String,
        name: j['name'] as String,
        classId: j['classId'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        description: j['description'] as String? ?? '',
        features: (j['features'] as List? ?? const [])
            .map((e) => ClassFeature.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Linaje de especie (Linaje Élfico, Ascendencia Dracónica, Legado Diabólico,
/// Ascendencia de Gigante…). Es el equivalente de [Subclass] para las especies:
/// pertenece a una especie (`raceId`) y aporta rasgos por nivel.
///
/// En 2024 no hay "subrazas": cada especie que lo requiere ofrece una elección
/// interna que se hace al crear el personaje y que puede seguir dando
/// beneficios a niveles superiores. Oficial y homebrew comparten este modelo.
class Lineage {
  final String id;
  final String name;
  final String raceId;
  final ContentSource source;
  final String description;
  final List<ClassFeature> features;

  const Lineage({
    required this.id,
    required this.name,
    required this.raceId,
    required this.source,
    this.description = '',
    this.features = const [],
  });

  /// Rasgos activos hasta [level] inclusive.
  List<ClassFeature> featuresUpTo(int level) =>
      features.where((f) => f.level <= level).toList();

  /// Rasgos ganados exactamente al alcanzar [level].
  List<ClassFeature> featuresAt(int level) =>
      features.where((f) => f.level == level).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'raceId': raceId,
        'source': source.toJson(),
        'description': description,
        'features': features.map((f) => f.toJson()).toList(),
      };

  factory Lineage.fromJson(Map<String, dynamic> j) => Lineage(
        id: j['id'] as String,
        name: j['name'] as String,
        raceId: j['raceId'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        description: j['description'] as String? ?? '',
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

  /// Identificador del ícono (mapeado a un ícono de Material en la app).
  final String? iconId;

  /// Línea de sabor para las tarjetas de selección.
  final String? tagline;

  const Background({
    required this.id,
    required this.name,
    required this.source,
    this.abilityOptions = const [],
    this.skillProficiencies = const [],
    this.toolProficiencies = const [],
    this.originFeatId,
    this.effects = const [],
    this.iconId,
    this.tagline,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'abilityOptions': abilityOptions.map((a) => a.name).toList(),
        'skillProficiencies': skillProficiencies,
        'toolProficiencies': toolProficiencies,
        'originFeatId': originFeatId,
        'iconId': iconId,
        'tagline': tagline,
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
        iconId: j['iconId'] as String?,
        tagline: j['tagline'] as String?,
      );
}

/// Prerrequisitos de una dote (p.ej. Forcejeador exige Fuerza 13, Iniciado
/// Mágico exige ser competente con conjuros). Todos los campos son opcionales
/// y se combinan con Y lógico; ausentes = sin restricción de ese tipo.
class FeatPrerequisite {
  /// Puntuación mínima requerida por característica. Se combinan con Y lógico:
  /// hay que cumplirlas todas.
  final Map<Ability, int> minAbilityScores;

  /// Puntuaciones mínimas de las que basta cumplir **una**. El PHB 2024 usa
  /// mucho esta forma ("Fuerza o Destreza 13 o más"), que [minAbilityScores]
  /// no puede expresar porque exige todas sus entradas.
  final Map<Ability, int> anyAbilityScores;

  /// Competencia requerida (id o categoría de arma/armadura/herramienta),
  /// o 'spellcasting' para exigir alguna competencia de lanzamiento.
  final String? requiredProficiency;

  /// Dotes de las que hay que tener **alguna**. Forge of the Artificer las usa
  /// para encadenar marcas: Marca Mayor de Tormenta exige Marca de Tormenta.
  final List<String> requiredFeatIds;

  /// Categoría de dote de la que hay que tener alguna. Cubre la forma
  /// "cualquier dote de Marca Dracónica", que no se puede escribir como lista
  /// sin repetir las trece.
  final String? requiredFeatCategory;

  /// Nombre de un rasgo de clase que debe haber obtenido el personaje.
  /// Permite expresar requisitos como "rasgo Estilo de combate" sin fingir
  /// que se trata de una competencia.
  final String? requiredClassFeature;

  final int? minLevel;

  const FeatPrerequisite({
    this.minAbilityScores = const {},
    this.anyAbilityScores = const {},
    this.requiredProficiency,
    this.requiredFeatIds = const [],
    this.requiredFeatCategory,
    this.requiredClassFeature,
    this.minLevel,
  });

  bool get isEmpty =>
      minAbilityScores.isEmpty &&
      anyAbilityScores.isEmpty &&
      requiredProficiency == null &&
      requiredFeatIds.isEmpty &&
      requiredFeatCategory == null &&
      requiredClassFeature == null &&
      minLevel == null;

  Map<String, dynamic> toJson() => {
        'minAbilityScores': _abilityMapToJson(minAbilityScores),
        'anyAbilityScores': _abilityMapToJson(anyAbilityScores),
        'requiredProficiency': requiredProficiency,
        'requiredFeatIds': requiredFeatIds,
        'requiredFeatCategory': requiredFeatCategory,
        'requiredClassFeature': requiredClassFeature,
        'minLevel': minLevel,
      };

  factory FeatPrerequisite.fromJson(Map<String, dynamic> j) => FeatPrerequisite(
        minAbilityScores: _abilityMapFromJson(j['minAbilityScores']),
        anyAbilityScores: _abilityMapFromJson(j['anyAbilityScores']),
        requiredProficiency: j['requiredProficiency'] as String?,
        requiredFeatIds: (j['requiredFeatIds'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        requiredFeatCategory: j['requiredFeatCategory'] as String?,
        requiredClassFeature: j['requiredClassFeature'] as String?,
        minLevel: j['minLevel'] as int?,
      );
}

Map<String, int> _abilityMapToJson(Map<Ability, int> m) =>
    {for (final e in m.entries) e.key.name: e.value};

Map<Ability, int> _abilityMapFromJson(dynamic j) => {
      for (final e in (j as Map? ?? const {}).entries)
        Ability.fromKey(e.key as String): e.value as int,
    };

/// Dote. `category`: 'origin' | 'general' | 'fighting-style' | 'dragonmark' |
/// 'epic-boon'.
///
/// Las dos últimas vienen de Forge of the Artificer. `dragonmark` se elige como
/// dote de origen (los trasfondos de casa la conceden a nivel 1) o en cualquier
/// elección libre posterior; `epic-boon` solo a nivel 19 o más.
class Feat {
  final String id;
  final String name;
  final ContentSource source;
  final String category;
  final bool repeatable;
  final String? exclusiveGroup;
  final List<Effect> effects;
  final FeatPrerequisite? prerequisite;

  const Feat({
    required this.id,
    required this.name,
    required this.source,
    this.category = 'general',
    this.repeatable = false,
    this.exclusiveGroup,
    this.effects = const [],
    this.prerequisite,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'category': category,
        'repeatable': repeatable,
        if (exclusiveGroup != null) 'exclusiveGroup': exclusiveGroup,
        'effects': effects.map((e) => e.toJson()).toList(),
        'prerequisite': prerequisite?.toJson(),
      };

  factory Feat.fromJson(Map<String, dynamic> j) => Feat(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        category: j['category'] as String? ?? 'general',
        repeatable: j['repeatable'] as bool? ?? false,
        exclusiveGroup: j['exclusiveGroup'] as String?,
        effects: Effect.listFromJson(j['effects']),
        prerequisite: j['prerequisite'] == null
            ? null
            : FeatPrerequisite.fromJson(
                (j['prerequisite'] as Map).cast<String, dynamic>()),
      );

  /// Las marcas dracónicas son mutuamente excluyentes por regla de Forge.
  String? get effectiveExclusiveGroup =>
      exclusiveGroup ?? (category == 'dragonmark' ? 'dragonmark' : null);
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

/// Conjuro. Es contenido como cualquier otro: oficial y homebrew comparten
/// este modelo. `level` 0 = truco (cantrip). `classes` lista los ids de clase
/// cuya lista lo incluye (p.ej. ['wizard', 'sorcerer']).
class Spell {
  final String id;
  final String name;
  final ContentSource source;
  final int level;
  final String school;
  final String castingTime;
  final String range;
  final String components;
  final String duration;
  final bool concentration;
  final bool ritual;
  final String description;
  final List<String> classes;

  const Spell({
    required this.id,
    required this.name,
    required this.source,
    required this.level,
    this.school = '',
    this.castingTime = 'Acción',
    this.range = '',
    this.components = '',
    this.duration = '',
    this.concentration = false,
    this.ritual = false,
    this.description = '',
    this.classes = const [],
  });

  bool get isCantrip => level == 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'level': level,
        'school': school,
        'castingTime': castingTime,
        'range': range,
        'components': components,
        'duration': duration,
        'concentration': concentration,
        'ritual': ritual,
        'description': description,
        'classes': classes,
      };

  factory Spell.fromJson(Map<String, dynamic> j) => Spell(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        level: j['level'] as int,
        school: j['school'] as String? ?? '',
        castingTime: j['castingTime'] as String? ?? 'Acción',
        range: j['range'] as String? ?? '',
        components: j['components'] as String? ?? '',
        duration: j['duration'] as String? ?? '',
        concentration: j['concentration'] as bool? ?? false,
        ritual: j['ritual'] as bool? ?? false,
        description: j['description'] as String? ?? '',
        classes: (j['classes'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
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
