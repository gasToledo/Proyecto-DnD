import 'ability.dart';

Map<String, int> _abilityMapToJson(Map<Ability, int> m) =>
    {for (final e in m.entries) e.key.name: e.value};

Map<Ability, int> _abilityMapFromJson(dynamic j) => {
      for (final e in (j as Map? ?? const {}).entries)
        Ability.fromKey(e.key as String): e.value as int,
    };

/// Sistema de progresión de la mesa. Solo define si se anota PX como
/// referencia; la subida de nivel es siempre manual (ver brief §6).
enum Progression { xp, milestone }

/// Configuración de reglas de la mesa que afecta la creación/progresión.
class TableConfig {
  /// 'srd_2024' | 'srd_2014'. Baseline del proyecto: 2024.
  final String edition;
  final Progression progression;

  /// Reglas opcionales activas (p.ej. 'human_variant' en 2014).
  final Set<String> optionalRules;

  const TableConfig({
    this.edition = 'srd_2024',
    this.progression = Progression.milestone,
    this.optionalRules = const {},
  });

  Map<String, dynamic> toJson() => {
        'edition': edition,
        'progression': progression.name,
        'optionalRules': optionalRules.toList(),
      };

  factory TableConfig.fromJson(Map<String, dynamic> j) => TableConfig(
        edition: j['edition'] as String? ?? 'srd_2024',
        progression: Progression.values.firstWhere(
          (p) => p.name == (j['progression'] as String?),
          orElse: () => Progression.milestone,
        ),
        optionalRules: (j['optionalRules'] as List? ?? const [])
            .map((e) => e as String)
            .toSet(),
      );
}

/// Elección en un nivel de Mejora de Característica (ASI): subir características
/// o tomar una dote.
class AsiChoice {
  final int level;

  /// Aumentos de característica (p.ej. {STR:2} o {STR:1, CON:1}).
  final Map<Ability, int> abilityIncreases;

  /// Dote elegida en su lugar (excluyente con [abilityIncreases]).
  final String? featId;

  const AsiChoice({
    required this.level,
    this.abilityIncreases = const {},
    this.featId,
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'abilityIncreases': _abilityMapToJson(abilityIncreases),
        'featId': featId,
      };

  factory AsiChoice.fromJson(Map<String, dynamic> j) => AsiChoice(
        level: j['level'] as int,
        abilityIncreases: _abilityMapFromJson(j['abilityIncreases']),
        featId: j['featId'] as String?,
      );
}

/// Estado mutable durante la partida. No influye en la ficha derivada
/// (`ComputedSheet`); se persiste aparte y se guarda con debounce.
class CombatState {
  int currentHp;
  int tempHp;
  int deathSuccesses;
  int deathFailures;
  int hitDiceUsed;
  int exhaustion;
  final Set<String> conditions;

  /// Usos consumidos por recurso (id de recurso → cantidad usada).
  final Map<String, int> resourceUsage;

  CombatState({
    this.currentHp = 0,
    this.tempHp = 0,
    this.deathSuccesses = 0,
    this.deathFailures = 0,
    this.hitDiceUsed = 0,
    this.exhaustion = 0,
    Set<String>? conditions,
    Map<String, int>? resourceUsage,
  })  : conditions = conditions ?? {},
        resourceUsage = resourceUsage ?? {};

  Map<String, dynamic> toJson() => {
        'currentHp': currentHp,
        'tempHp': tempHp,
        'deathSuccesses': deathSuccesses,
        'deathFailures': deathFailures,
        'hitDiceUsed': hitDiceUsed,
        'exhaustion': exhaustion,
        'conditions': conditions.toList(),
        'resourceUsage': resourceUsage,
      };

  factory CombatState.fromJson(Map<String, dynamic> j) => CombatState(
        currentHp: j['currentHp'] as int? ?? 0,
        tempHp: j['tempHp'] as int? ?? 0,
        deathSuccesses: j['deathSuccesses'] as int? ?? 0,
        deathFailures: j['deathFailures'] as int? ?? 0,
        hitDiceUsed: j['hitDiceUsed'] as int? ?? 0,
        exhaustion: j['exhaustion'] as int? ?? 0,
        conditions:
            (j['conditions'] as List? ?? const []).map((e) => e as String).toSet(),
        resourceUsage: {
          for (final e in (j['resourceUsage'] as Map? ?? const {}).entries)
            e.key as String: e.value as int,
        },
      );
}

enum CharacterStatus { active, archivedInactive, dead }

/// Personaje con todas las **elecciones resueltas**. Es la fuente de verdad y
/// también, serializado, el formato de exportación individual.
class Character {
  final String id;
  String name;
  CharacterStatus status;

  final String raceId;
  final String classId;
  final String backgroundId;
  int level;

  /// Puntuaciones asignadas por el método elegido (4d6 o array), antes de
  /// bonos de trasfondo/ASI/dote.
  final Map<Ability, int> assignedScores;

  /// Distribución del aumento de característica del trasfondo 2024.
  final Map<Ability, int> backgroundAbilityBonuses;

  /// Habilidades elegidas (de las opciones de raza/clase/trasfondo).
  final List<String> chosenSkills;

  /// Estilo de combate (una dote con category 'fighting-style').
  final String? fightingStyleId;

  /// Armas en las que se eligió Maestría (2024).
  final List<String> weaponMasteryChoices;

  /// Dotes tomadas por elección: dote de origen de la especie (Humano
  /// "Versátil") y dotes generales de niveles ASI.
  final List<String> featIds;

  /// Elecciones tomadas en cada nivel de ASI.
  final List<AsiChoice> asiChoices;

  /// Aporte base de PG por nivel (tirada o promedio), sin sumar el mod. de CON.
  /// `hpPerLevel[0]` es el nivel 1 (máximo del dado de golpe).
  final List<int> hpPerLevel;

  final String? equippedArmorId;
  final bool shieldEquipped;
  final List<String> equippedWeaponIds;

  /// Armas empuñadas a dos manos (para daño versátil). id de arma → dos manos.
  final Map<String, bool> weaponTwoHanded;

  /// Rutas locales de retratos guardados. La primera es la activa.
  final List<String> portraitPaths;

  /// Notas libres del jugador (autoguardadas).
  String notes;

  final TableConfig tableConfig;
  final CombatState combat;

  Character({
    required this.id,
    required this.name,
    this.status = CharacterStatus.active,
    required this.raceId,
    required this.classId,
    required this.backgroundId,
    this.level = 1,
    required this.assignedScores,
    this.backgroundAbilityBonuses = const {},
    this.chosenSkills = const [],
    this.fightingStyleId,
    this.weaponMasteryChoices = const [],
    this.featIds = const [],
    this.asiChoices = const [],
    this.hpPerLevel = const [],
    this.equippedArmorId,
    this.shieldEquipped = false,
    this.equippedWeaponIds = const [],
    this.weaponTwoHanded = const {},
    this.portraitPaths = const [],
    this.notes = '',
    this.tableConfig = const TableConfig(),
    CombatState? combat,
  }) : combat = combat ?? CombatState();

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'status': status.name,
        'raceId': raceId,
        'classId': classId,
        'backgroundId': backgroundId,
        'level': level,
        'assignedScores': _abilityMapToJson(assignedScores),
        'backgroundAbilityBonuses':
            _abilityMapToJson(backgroundAbilityBonuses),
        'chosenSkills': chosenSkills,
        'fightingStyleId': fightingStyleId,
        'weaponMasteryChoices': weaponMasteryChoices,
        'featIds': featIds,
        'asiChoices': asiChoices.map((e) => e.toJson()).toList(),
        'hpPerLevel': hpPerLevel,
        'equippedArmorId': equippedArmorId,
        'shieldEquipped': shieldEquipped,
        'equippedWeaponIds': equippedWeaponIds,
        'weaponTwoHanded': weaponTwoHanded,
        'portraitPaths': portraitPaths,
        'notes': notes,
        'tableConfig': tableConfig.toJson(),
        'combat': combat.toJson(),
      };

  factory Character.fromJson(Map<String, dynamic> j) => Character(
        id: j['id'] as String,
        name: j['name'] as String,
        status: CharacterStatus.values.firstWhere(
          (s) => s.name == (j['status'] as String?),
          orElse: () => CharacterStatus.active,
        ),
        raceId: j['raceId'] as String,
        classId: j['classId'] as String,
        backgroundId: j['backgroundId'] as String,
        level: j['level'] as int? ?? 1,
        assignedScores: _abilityMapFromJson(j['assignedScores']),
        backgroundAbilityBonuses:
            _abilityMapFromJson(j['backgroundAbilityBonuses']),
        chosenSkills: (j['chosenSkills'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        fightingStyleId: j['fightingStyleId'] as String?,
        weaponMasteryChoices: (j['weaponMasteryChoices'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        featIds: (j['featIds'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        asiChoices: (j['asiChoices'] as List? ?? const [])
            .map((e) => AsiChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        hpPerLevel:
            (j['hpPerLevel'] as List? ?? const []).map((e) => e as int).toList(),
        equippedArmorId: j['equippedArmorId'] as String?,
        shieldEquipped: j['shieldEquipped'] as bool? ?? false,
        equippedWeaponIds: (j['equippedWeaponIds'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        weaponTwoHanded: {
          for (final e in (j['weaponTwoHanded'] as Map? ?? const {}).entries)
            e.key as String: e.value as bool,
        },
        portraitPaths: (j['portraitPaths'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        notes: j['notes'] as String? ?? '',
        tableConfig: TableConfig.fromJson(
            (j['tableConfig'] as Map?)?.cast<String, dynamic>() ?? const {}),
        combat: CombatState.fromJson(
            (j['combat'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );

  /// Copia con overrides. Preserva el [CombatState] por referencia salvo que se
  /// pase uno nuevo. Útil para editar equipo/nivel sin perder estado de partida.
  Character copyWith({
    String? name,
    CharacterStatus? status,
    int? level,
    List<String>? featIds,
    List<AsiChoice>? asiChoices,
    List<int>? hpPerLevel,
    String? equippedArmorId,
    bool? shieldEquipped,
    List<String>? equippedWeaponIds,
    Map<String, bool>? weaponTwoHanded,
    List<String>? portraitPaths,
    String? notes,
    CombatState? combat,
  }) {
    return Character(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      raceId: raceId,
      classId: classId,
      backgroundId: backgroundId,
      level: level ?? this.level,
      assignedScores: assignedScores,
      backgroundAbilityBonuses: backgroundAbilityBonuses,
      chosenSkills: chosenSkills,
      fightingStyleId: fightingStyleId,
      weaponMasteryChoices: weaponMasteryChoices,
      featIds: featIds ?? this.featIds,
      asiChoices: asiChoices ?? this.asiChoices,
      hpPerLevel: hpPerLevel ?? this.hpPerLevel,
      equippedArmorId: equippedArmorId ?? this.equippedArmorId,
      shieldEquipped: shieldEquipped ?? this.shieldEquipped,
      equippedWeaponIds: equippedWeaponIds ?? this.equippedWeaponIds,
      weaponTwoHanded: weaponTwoHanded ?? this.weaponTwoHanded,
      portraitPaths: portraitPaths ?? this.portraitPaths,
      notes: notes ?? this.notes,
      tableConfig: tableConfig,
      combat: combat ?? this.combat,
    );
  }
}
