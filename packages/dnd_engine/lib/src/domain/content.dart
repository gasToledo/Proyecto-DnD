import 'ability.dart';
import 'content_source.dart';
import 'effects.dart';

/// Raza (o especie, en terminología 2024).
class Race {
  final String id;
  final String name;
  final ContentSource source;

  /// Tipo de criatura de la especie (Humanoide, Feérico, Aberración, etc.).
  final String creatureType;

  /// Tamaño de la especie. Cuando [sizeOptions] no está vacío es solo el valor
  /// por defecto: el que manda es el elegido por el personaje.
  final String size;

  /// Tamaños entre los que elige el jugador al seleccionar la especie. Vacío
  /// significa "sin elección": el tamaño es [size] y no hay nada que preguntar.
  final List<String> sizeOptions;

  final int speed;
  final List<Effect> effects;

  /// Cantidad de competencias de habilidad a elegir libremente y de qué lista
  /// (vacía = cualquiera). Ej.: Humano 2024 → 1 habilidad ("Habilidoso").
  final int skillChoiceCount;
  final List<String> skillChoiceFrom;

  /// Identificador del ícono (mapeado a un ícono de Material en la app).
  /// Null = ícono genérico.
  final String? iconId;

  /// Línea de sabor para las tarjetas de selección. Null = sin tagline.
  final String? tagline;

  /// Presentación narrativa de la especie, separada de sus reglas mecánicas.
  final String description;

  const Race({
    required this.id,
    required this.name,
    required this.source,
    this.creatureType = 'Humanoide',
    this.size = 'Mediano',
    this.sizeOptions = const [],
    this.speed = 30,
    this.effects = const [],
    this.skillChoiceCount = 0,
    this.skillChoiceFrom = const [],
    this.iconId,
    this.tagline,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'creatureType': creatureType,
        'size': size,
        'sizeOptions': sizeOptions,
        'speed': speed,
        'skillChoiceCount': skillChoiceCount,
        'skillChoiceFrom': skillChoiceFrom,
        'iconId': iconId,
        'tagline': tagline,
        'description': description,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

  factory Race.fromJson(Map<String, dynamic> j) => Race(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        creatureType: j['creatureType'] as String? ?? 'Humanoide',
        size: j['size'] as String? ?? 'Mediano',
        sizeOptions: (j['sizeOptions'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        speed: j['speed'] as int? ?? 30,
        effects: Effect.listFromJson(j['effects']),
        skillChoiceCount: j['skillChoiceCount'] as int? ?? 0,
        skillChoiceFrom: (j['skillChoiceFrom'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        iconId: j['iconId'] as String?,
        tagline: j['tagline'] as String?,
        description: j['description'] as String? ?? '',
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

/// Los rasgos de [all] hasta [level] inclusive, **en orden de nivel**.
///
/// Ordenar acá no es cosmético: es lo que hace cierta la convención de que
/// varios [ResourceEffect] con el mismo id declaran tramos y **gana el de mayor
/// nivel**. Quien la aplica es `SheetBuilder.applyEffect`, que hace
/// `_resources[id] = e`, o sea gana *el último aplicado*. Los arrays del
/// contenido no están ordenados por nivel (el Guerrero declara
/// 1,1,1,4,4,10,10,16,2,2,5,…), así que sin este orden la convención solo se
/// cumple por casualidad, cuando el autor del contenido declaró los tramos
/// ascendentes.
///
/// El desempate por posición original es necesario porque `List.sort` de Dart
/// no es estable, y entre dos rasgos del mismo nivel el orden del contenido es
/// el que decide (p.ej. cuál de dos efectos sobre el mismo campo pisa al otro).
List<ClassFeature> featuresUpToLevel(List<ClassFeature> all, int level) {
  final selected = [
    for (final (i, f) in all.indexed)
      if (f.level <= level) (i, f),
  ];
  selected.sort((a, b) {
    final (ai, af) = a;
    final (bi, bf) = b;
    return af.level != bf.level
        ? af.level.compareTo(bf.level)
        : ai.compareTo(bi);
  });
  return [for (final (_, f) in selected) f];
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

  /// Color de acento de la clase, en hex ("#RRGGBB"), para la personalización
  /// visual. Null = sin acento propio (la UI usa el color por defecto).
  final String? accentColor;

  /// Identificador del ícono de la clase (mapeado a un ícono de Material en la
  /// app, p.ej. "shield" → Icons.shield). Null = ícono genérico.
  final String? iconId;

  final List<ClassFeature> features;
  final List<StartingEquipmentOption> startingEquipment;

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
    this.accentColor,
    this.iconId,
    this.features = const [],
    this.startingEquipment = const [],
  });

  /// Rasgos activos hasta [level] inclusive, en orden de nivel.
  List<ClassFeature> featuresUpTo(int level) =>
      featuresUpToLevel(features, level);

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
        accentColor: j['accentColor'] as String?,
        iconId: j['iconId'] as String?,
        features: (j['features'] as List? ?? const [])
            .map((e) => ClassFeature.fromJson(e as Map<String, dynamic>))
            .toList(),
        startingEquipment: (j['startingEquipment'] as List? ?? const [])
            .map((e) => StartingEquipmentOption.fromJson(
                (e as Map).cast<String, dynamic>()))
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

  /// Rasgos de subclase activos hasta [level] inclusive, en orden de nivel.
  List<ClassFeature> featuresUpTo(int level) =>
      featuresUpToLevel(features, level);

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

  /// Rasgos activos hasta [level] inclusive, en orden de nivel.
  List<ClassFeature> featuresUpTo(int level) =>
      featuresUpToLevel(features, level);

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
  final List<StartingEquipmentOption> startingEquipment;

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
    this.startingEquipment = const [],
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
        'startingEquipment': startingEquipment.map((e) => e.toJson()).toList(),
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
        startingEquipment: (j['startingEquipment'] as List? ?? const [])
            .map((e) => StartingEquipmentOption.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Una alternativa cerrada de equipo inicial (A, B o C).
class StartingEquipmentOption {
  final String id;
  final String label;
  final List<EquipmentGrant> grants;

  const StartingEquipmentOption({
    required this.id,
    required this.label,
    this.grants = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'grants': grants.map((e) => e.toJson()).toList(),
      };

  factory StartingEquipmentOption.fromJson(Map<String, dynamic> j) =>
      StartingEquipmentOption(
        id: j['id'] as String,
        label: j['label'] as String? ?? j['id'] as String,
        grants: (j['grants'] as List? ?? const [])
            .map((e) =>
                EquipmentGrant.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Un objeto, una cantidad de monedas o una elección dentro de un paquete.
class EquipmentGrant {
  final String? itemId;
  final int quantity;
  final Map<String, int> coins;
  final List<String> chooseFromItemIds;
  final int chooseCount;

  const EquipmentGrant({
    this.itemId,
    this.quantity = 1,
    this.coins = const {},
    this.chooseFromItemIds = const [],
    this.chooseCount = 1,
  });

  bool get isChoice => chooseFromItemIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (itemId != null) 'itemId': itemId,
        if (quantity != 1) 'quantity': quantity,
        if (coins.isNotEmpty) 'coins': coins,
        if (chooseFromItemIds.isNotEmpty)
          'chooseFromItemIds': chooseFromItemIds,
        if (chooseCount != 1) 'chooseCount': chooseCount,
      };

  factory EquipmentGrant.fromJson(Map<String, dynamic> j) => EquipmentGrant(
        itemId: j['itemId'] as String?,
        quantity: j['quantity'] as int? ?? 1,
        coins: (j['coins'] as Map? ?? const {})
            .map((k, v) => MapEntry(k as String, v as int)),
        chooseFromItemIds: (j['chooseFromItemIds'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        chooseCount: j['chooseCount'] as int? ?? 1,
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

  /// Clase que hay que tener para poder elegir esta opción. Existe por los dos
  /// estilos de combate que en XPHB no son dotes abiertas sino una alternativa
  /// concreta de una clase: Blessed Warrior es solo del Paladín y Druidic
  /// Warrior solo del Explorador. Es singular a propósito: no hay ninguna
  /// opción 2024 elegible por dos clases y no por las demás.
  final String? requiredClassId;

  final int? minLevel;

  const FeatPrerequisite({
    this.minAbilityScores = const {},
    this.anyAbilityScores = const {},
    this.requiredProficiency,
    this.requiredFeatIds = const [],
    this.requiredFeatCategory,
    this.requiredClassFeature,
    this.requiredClassId,
    this.minLevel,
  });

  bool get isEmpty =>
      minAbilityScores.isEmpty &&
      anyAbilityScores.isEmpty &&
      requiredProficiency == null &&
      requiredFeatIds.isEmpty &&
      requiredFeatCategory == null &&
      requiredClassFeature == null &&
      requiredClassId == null &&
      minLevel == null;

  Map<String, dynamic> toJson() => {
        'minAbilityScores': _abilityMapToJson(minAbilityScores),
        'anyAbilityScores': _abilityMapToJson(anyAbilityScores),
        'requiredProficiency': requiredProficiency,
        'requiredFeatIds': requiredFeatIds,
        'requiredFeatCategory': requiredFeatCategory,
        'requiredClassFeature': requiredClassFeature,
        'requiredClassId': requiredClassId,
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
        requiredClassId: j['requiredClassId'] as String?,
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

  /// Características entre las que el personaje elige la aptitud mágica de los
  /// conjuros de esta dote. Iniciado en la Magia y las Marcas Dracónicas dicen
  /// "Inteligencia, Sabiduría o Carisma (se elige al tomar la dote)".
  ///
  /// Vacío es el caso normal: la característica la fija el contenido en cada
  /// efecto. La elección vive en `Character.featSpellcastingAbilities`.
  final List<Ability> spellcastingAbilityOptions;

  const Feat({
    required this.id,
    required this.name,
    required this.source,
    this.category = 'general',
    this.repeatable = false,
    this.exclusiveGroup,
    this.effects = const [],
    this.prerequisite,
    this.spellcastingAbilityOptions = const [],
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
        if (spellcastingAbilityOptions.isNotEmpty)
          'spellcastingAbilityOptions':
              spellcastingAbilityOptions.map((a) => a.name).toList(),
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
        spellcastingAbilityOptions:
            (j['spellcastingAbilityOptions'] as List? ?? const [])
                .map((e) => Ability.fromKey(e as String))
                .toList(),
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

  /// La Lanza de caballería es el único caso 2024 en el que `two-handed` no es
  /// incondicional: solo exige dos manos si quien la empuña **no** está
  /// montado. Se modela como calificador de la propiedad y no borrándola, para
  /// que un arma sin el campo (todo el homebrew anterior) siga siendo estricta.
  final bool twoHandedUnlessMounted;

  /// Peso en libras. 0 = sin peso declarado (homebrew viejo).
  final double weight;

  /// Precio en piezas de cobre. Se guarda en cobre y no en oro decimal porque
  /// la tabla del capítulo 6 tiene precios de 5 pc y 1 pp: con `double` en oro
  /// la suma del inventario acumula error de redondeo.
  final int costCp;

  /// Bonificador mágico del arma (+1, +2, +3), que suma al ataque y al daño.
  ///
  /// Vive en el arma y no como efecto porque un efecto no tiene forma de decir
  /// "solo esta arma": `ArmorClassBonusEffect` y compañía son planos. Un arma
  /// mágica es un arma más del catálogo, homebrew o no.
  final int magicBonus;

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
    this.twoHandedUnlessMounted = false,
    this.weight = 0,
    this.costCp = 0,
    this.magicBonus = 0,
  });

  bool get isRanged => properties.contains('ranged');
  bool get isFinesse => properties.contains('finesse');

  /// Propiedad Ligera: requisito del ataque de mano secundaria (2024).
  bool get isLight => properties.contains('light');

  /// Si el arma exige dos manos en este contexto. Única puerta de entrada a
  /// `two-handed`: compilador, validación y ficha preguntan acá para no
  /// resolver la excepción de la lanza cada uno por su cuenta.
  bool requiresTwoHands({bool mounted = false}) =>
      properties.contains('two-handed') && !(mounted && twoHandedUnlessMounted);

  /// Claves de competencia que habilitan esta arma: su id, su categoría y la
  /// media categoría por alcance.
  ///
  /// La media categoría existe porque hay rasgos que no conceden la categoría
  /// entera: el Artillero recibe las armas marciales **a distancia**. Vive en
  /// el arma y no en cada consumidor para que el compilador y el wizard de
  /// creación decidan lo mismo.
  Set<String> get proficiencyKeys => {
        id,
        category,
        '$category-${isRanged ? 'ranged' : 'melee'}',
      };

  /// Si [proficiencies] —las de una ficha compilada o las de una clase—
  /// alcanzan para ser competente con esta arma.
  bool isProficientWith(Iterable<String> proficiencies) =>
      proficiencies.any(proficiencyKeys.contains);

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
        if (twoHandedUnlessMounted) 'twoHandedUnlessMounted': true,
        'weight': weight,
        'costCp': costCp,
        if (magicBonus != 0) 'magicBonus': magicBonus,
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
        twoHandedUnlessMounted: j['twoHandedUnlessMounted'] as bool? ?? false,
        weight: (j['weight'] as num? ?? 0).toDouble(),
        costCp: j['costCp'] as int? ?? 0,
        magicBonus: j['magicBonus'] as int? ?? 0,
      );
}

/// Qué parte de la economía del turno consume lanzar un conjuro. Se deriva de
/// `Spell.castingTime`, que es texto libre del contenido.
///
/// En mesa lo que se decide con esto es "¿puedo lanzarlo *además* de lo que ya
/// hice este turno?": acción, adicional y reacción compiten entre sí, y todo lo
/// que tarda minutos u horas ([longer]) no compite con nada porque no entra en
/// un turno.
enum SpellActionType { action, bonusAction, reaction, longer }

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

  /// El orden importa: "Acción Adicional" también empieza con "Acción", así que
  /// la adicional tiene que descartarse antes que la principal.
  SpellActionType get actionType {
    final t = castingTime.toLowerCase();
    if (t.startsWith('acción adicional')) return SpellActionType.bonusAction;
    if (t.startsWith('reacción')) return SpellActionType.reaction;
    if (t.startsWith('acción')) return SpellActionType.action;
    return SpellActionType.longer;
  }

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

  /// Peso en libras. 0 = sin peso declarado (homebrew viejo).
  final double weight;

  /// Precio en piezas de cobre. Ver [Weapon.costCp].
  final int costCp;

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
    this.weight = 0,
    this.costCp = 0,
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
        'weight': weight,
        'costCp': costCp,
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
        weight: (j['weight'] as num? ?? 0).toDouble(),
        costCp: j['costCp'] as int? ?? 0,
      );
}

/// Objeto de inventario que no es arma ni armadura: equipo de aventurero,
/// herramientas, munición, canalizadores, paquetes, contenedores y objetos
/// mágicos.
///
/// Es un solo tipo con campos opcionales y no una jerarquía (`Gear`, `Tool`,
/// `Container`) porque nada en el motor ramifica por "es una herramienta": la
/// [category] es un dato de presentación. Un tipo por familia multiplicaría los
/// cinco puntos de carga del catálogo, el formulario homebrew y los tests sin
/// comprar ninguna regla.
class Item {
  final String id;
  final String name;
  final ContentSource source;

  /// 'gear' | 'tool' | 'ammunition' | 'focus' | 'pack' | 'container' | 'magic'.
  final String category;

  /// Peso en libras de un paquete de [bundleSize] unidades.
  final double weight;

  /// Precio en piezas de cobre. Ver [Weapon.costCp].
  final int costCp;

  /// Cantidad incluida en una compra. Es mayor que 1 para munición: el peso y
  /// el precio de "Flechas" corresponden al paquete de 20 de la tabla.
  final int bundleSize;

  /// Texto libre. En el catálogo oficial es la descripción del manual; en un
  /// objeto del jugador es donde viven las cartas, las notas y los libros.
  final String description;

  /// null = objeto mundano. 'common' | 'uncommon' | 'rare' | 'very-rare' |
  /// 'legendary' | 'artifact'.
  final String? rarity;

  final bool requiresAttunement;

  /// Bonificador estable aplicado al arma, armadura o escudo base.
  final int magicBonus;

  /// `weapon`, `armor` o `shield` cuando el objeto es una plantilla mágica.
  final String? baseItemKind;

  /// Bases concretas admitidas. Vacío significa cualquier base del tipo.
  final List<String> eligibleBaseItemIds;

  /// Efectos que el objeto aporta a la ficha mientras está equipado (y
  /// sintonizado, si lo exige). Vacío = objeto sin mecánica, que es el caso de
  /// todo el catálogo mundano.
  final List<Effect> effects;

  const Item({
    required this.id,
    required this.name,
    required this.source,
    required this.category,
    this.weight = 0,
    this.costCp = 0,
    this.bundleSize = 1,
    this.description = '',
    this.rarity,
    this.requiresAttunement = false,
    this.magicBonus = 0,
    this.baseItemKind,
    this.eligibleBaseItemIds = const [],
    this.effects = const [],
  });

  bool get isMagic => rarity != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'category': category,
        'weight': weight,
        'costCp': costCp,
        if (bundleSize != 1) 'bundleSize': bundleSize,
        if (description.isNotEmpty) 'description': description,
        if (rarity != null) 'rarity': rarity,
        if (requiresAttunement) 'requiresAttunement': true,
        if (magicBonus != 0) 'magicBonus': magicBonus,
        if (baseItemKind != null) 'baseItemKind': baseItemKind,
        if (eligibleBaseItemIds.isNotEmpty)
          'eligibleBaseItemIds': eligibleBaseItemIds,
        if (effects.isNotEmpty)
          'effects': [for (final e in effects) e.toJson()],
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        category: j['category'] as String,
        weight: (j['weight'] as num? ?? 0).toDouble(),
        costCp: j['costCp'] as int? ?? 0,
        bundleSize: (j['bundleSize'] as int? ?? 1).clamp(1, 1 << 30),
        description: j['description'] as String? ?? '',
        rarity: j['rarity'] as String?,
        requiresAttunement: j['requiresAttunement'] as bool? ?? false,
        magicBonus: j['magicBonus'] as int? ?? 0,
        baseItemKind: j['baseItemKind'] as String?,
        eligibleBaseItemIds: (j['eligibleBaseItemIds'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        effects: Effect.listFromJson(j['effects']),
      );
}

/// Denominaciones de moneda, de menor a mayor. Las claves son las que viajan
/// en `Character.coins`; las etiquetas, las abreviaturas del SRD en español.
const coinDenominations = <String>['cp', 'sp', 'ep', 'gp', 'pp'];
const coinValueCp = <String, int>{
  'cp': 1,
  'sp': 10,
  'ep': 50,
  'gp': 100,
  'pp': 1000,
};
const coinLabels = <String, String>{
  'cp': 'pc',
  'sp': 'pp',
  'ep': 'pe',
  'gp': 'po',
  'pp': 'ppt',
};

/// Cincuenta monedas pesan una libra, sin importar el metal (capítulo 6).
const coinsPerPound = 50;

/// Espacios de sintonización de un personaje (capítulo 6, "Sintonización").
const attunementSlots = 3;

/// Formatea un precio guardado en cobre con la denominación más grande que lo
/// exprese sin fracción: 1500 → "15 po", 5 → "5 pc".
///
/// Solo cobre, plata y oro. El manual cotiza en esas tres y nada más: con
/// electro, "50 pc" saldría como "1 pe", y con platino el catalejo de 1000 po
/// saldría como "100 ppt". Las cinco denominaciones existen igual en la bolsa
/// del personaje, que es otra cosa que un precio de tabla.
///
/// Vive en el motor y no en la app para que la ficha, el catálogo homebrew y
/// los tests no formateen cada uno a su manera.
/// Peso legible en libras, conservando centésimas (las monedas pesan de a
/// 1/50 lb y el dardo pesa 1/4 lb) pero sin ceros finales.
String formatPounds(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String formatCost(int cp) {
  if (cp == 0) return '—';
  for (final key in const ['gp', 'sp']) {
    final value = coinValueCp[key]!;
    if (cp >= value && cp % value == 0) {
      return '${cp ~/ value} ${coinLabels[key]}';
    }
  }
  return '$cp ${coinLabels['cp']}';
}
