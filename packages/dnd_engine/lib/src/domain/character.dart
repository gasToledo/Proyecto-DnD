import 'ability.dart';
import 'alignment.dart';
import 'data_version.dart';

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

/// Un compañero que está invocado ahora mismo: el cañón que hay en el suelo,
/// el defensor que camina al lado.
///
/// Guarda solo lo que cambia en la mesa. Todo lo demás (CA, ataques, rasgos)
/// se recalcula desde el catálogo con el nivel del personaje, así que subir de
/// nivel no deja una instancia con números viejos.
class CompanionInstance {
  /// Id de la opción que lo concede (`CompanionOption.id`).
  final String optionId;

  /// Forma elegida al invocarlo (`Creature.id`).
  final String creatureId;

  /// Nivel del espacio de conjuro gastado, o 0 si no aplica. Los números del
  /// Corcel Sobrenatural y del Sirviente Homúnculo cuelgan de esto, así que se
  /// congela al invocar: subir de nivel no mejora un corcel ya convocado.
  final int spellLevel;

  /// Se lo invocó con un conjuro de concentración, así que se va cuando la
  /// concentración termina.
  final bool concentration;

  int currentHp;
  int tempHp;
  final Set<String> conditions;

  CompanionInstance({
    required this.optionId,
    required this.creatureId,
    this.spellLevel = 0,
    this.concentration = false,
    this.currentHp = 0,
    this.tempHp = 0,
    Set<String>? conditions,
  }) : conditions = conditions ?? {};

  Map<String, dynamic> toJson() => {
        'optionId': optionId,
        'creatureId': creatureId,
        'spellLevel': spellLevel,
        'concentration': concentration,
        'currentHp': currentHp,
        'tempHp': tempHp,
        'conditions': conditions.toList(),
      };

  factory CompanionInstance.fromJson(Map<String, dynamic> j) =>
      CompanionInstance(
        optionId: j['optionId'] as String,
        creatureId: j['creatureId'] as String,
        spellLevel: j['spellLevel'] as int? ?? 0,
        concentration: j['concentration'] as bool? ?? false,
        currentHp: j['currentHp'] as int? ?? 0,
        tempHp: j['tempHp'] as int? ?? 0,
        conditions: (j['conditions'] as List? ?? const [])
            .map((e) => e as String)
            .toSet(),
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

  /// Espacios de conjuro gastados por nivel de conjuro (nivel → cantidad usada).
  final Map<int, int> spellSlotsUsed;

  /// Conjuro en el que se está concentrando (nombre), o null.
  String? concentratingOn;

  /// Compañeros invocados ahora mismo. Es una lista y no un mapa por opción
  /// porque el Artillero de nivel 15 tiene dos cañones a la vez.
  final List<CompanionInstance> companions;

  CombatState({
    this.currentHp = 0,
    this.tempHp = 0,
    this.deathSuccesses = 0,
    this.deathFailures = 0,
    this.hitDiceUsed = 0,
    this.exhaustion = 0,
    Set<String>? conditions,
    Map<String, int>? resourceUsage,
    Map<int, int>? spellSlotsUsed,
    this.concentratingOn,
    List<CompanionInstance>? companions,
  })  : conditions = conditions ?? {},
        resourceUsage = resourceUsage ?? {},
        spellSlotsUsed = spellSlotsUsed ?? {},
        companions = companions ?? [];

  Map<String, dynamic> toJson() => {
        'currentHp': currentHp,
        'tempHp': tempHp,
        'deathSuccesses': deathSuccesses,
        'deathFailures': deathFailures,
        'hitDiceUsed': hitDiceUsed,
        'exhaustion': exhaustion,
        'conditions': conditions.toList(),
        'resourceUsage': resourceUsage,
        'spellSlotsUsed': {
          for (final e in spellSlotsUsed.entries) '${e.key}': e.value
        },
        'concentratingOn': concentratingOn,
        'companions': [for (final c in companions) c.toJson()],
      };

  factory CombatState.fromJson(Map<String, dynamic> j) => CombatState(
        currentHp: j['currentHp'] as int? ?? 0,
        tempHp: j['tempHp'] as int? ?? 0,
        deathSuccesses: j['deathSuccesses'] as int? ?? 0,
        deathFailures: j['deathFailures'] as int? ?? 0,
        hitDiceUsed: j['hitDiceUsed'] as int? ?? 0,
        exhaustion: j['exhaustion'] as int? ?? 0,
        conditions: (j['conditions'] as List? ?? const [])
            .map((e) => e as String)
            .toSet(),
        resourceUsage: {
          for (final e in (j['resourceUsage'] as Map? ?? const {}).entries)
            e.key as String: e.value as int,
        },
        spellSlotsUsed: {
          for (final e in (j['spellSlotsUsed'] as Map? ?? const {}).entries)
            int.parse(e.key as String): e.value as int,
        },
        concentratingOn: j['concentratingOn'] as String?,
        companions: [
          for (final c in (j['companions'] as List? ?? const []))
            CompanionInstance.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );
}

enum CharacterStatus { active, archivedInactive, dead }

/// Centinela para distinguir "no se pasó el argumento" de "se pasó null" en
/// [Character.copyWith] (necesario para poder **desequipar** la armadura).
const Object _unset = Object();

/// Personaje con todas las **elecciones resueltas**. Es la fuente de verdad y
/// también, serializado, el formato de exportación individual.
class Character {
  static const int currentSchemaVersion = 16;

  final String id;
  String name;
  CharacterStatus status;

  final String raceId;
  final String classId;
  final String backgroundId;

  /// Subclase elegida (id), o null si aún no se eligió (nivel < subclassLevel).
  final String? subclassId;

  /// Linaje de especie elegido (Linaje Élfico, Ascendencia Dracónica…).
  /// Null si la especie no exige uno o si todavía no se eligió.
  final String? lineageId;

  /// Aptitud mágica elegida para los conjuros concedidos por la especie o su
  /// linaje. En 2024, Elfo, Gnomo y Tiefling eligen INT, SAB o CAR.
  final Ability? speciesSpellcastingAbility;

  /// Tamaño elegido, para las especies que lo ofrecen (Humano, Tiefling y
  /// Aasimar son Mediano o Pequeño). Null significa "sin elegir": la ficha cae
  /// al tamaño por defecto de la especie, que es lo que hace que una ficha
  /// vieja siga compilando igual sin migración.
  final String? chosenSize;

  /// Trucos innatos reemplazados tras un descanso largo: id del truco que
  /// concede el rasgo → id del que se lanza en su lugar.
  ///
  /// La clave es el conjuro **del contenido**, no el elegido, para que el
  /// reemplazo se pueda deshacer y para que cambiar de linaje deje la entrada
  /// huérfana en vez de pisar otra. Un rasgo que no declare
  /// `GrantSpellEffect.replaceableFrom` ignora lo que haya acá.
  final Map<String, String> innateCantripChoices;

  int level;

  /// Puntuaciones asignadas por el método elegido (4d6 o array), antes de
  /// bonos de trasfondo/ASI/dote.
  final Map<Ability, int> assignedScores;

  /// Distribución del aumento de característica del trasfondo 2024.
  final Map<Ability, int> backgroundAbilityBonuses;

  /// Habilidades elegidas (de las opciones de raza/clase/trasfondo).
  final List<String> chosenSkills;

  /// Competencias elegidas por una **dote** (Habilidoso, Mente Aguda). Van
  /// mezcladas habilidades y herramientas, porque Habilidoso deja elegir entre
  /// unas y otras; el compilador las separa mirando el catálogo de habilidades.
  ///
  /// Aparte de [chosenSkills] a propósito: esa lista es la elección fija de
  /// especie y clase, y su cuenta esperada no depende de las dotes que tenga
  /// el personaje.
  final List<String> chosenProficiencies;

  /// Elecciones de competencia por origen estable.
  final Map<String, List<String>> proficiencyChoices;

  /// Los idiomas que **elige** el jugador al crear el personaje: dos de la
  /// tabla de estándar (`Language.originChoiceCount`).
  ///
  /// No incluye Común, que todo personaje sabe, ni los que concede un rasgo
  /// con `LanguageEffect`: esos los suma el compilador. Guardar solo lo
  /// elegido es lo que permite cambiar de clase sin perder los idiomas ni
  /// arrastrar el Druídico de un Druida que ya no se es.
  final List<String> languages;

  /// Idiomas elegidos por un **rasgo** que los concede a elección (la Jerga de
  /// Ladrones del Pícaro): id de grupo → ids de idioma.
  ///
  /// Aparte de [languages] porque no salen del origen sino de la clase: si el
  /// personaje deja de tener el rasgo, esta elección queda huérfana y la
  /// validación lo dice, mientras que los del origen se conservan siempre.
  final Map<String, List<String>> languageChoices;

  /// Elecciones abiertas resueltas: id de grupo → ids de opción elegidos.
  ///
  /// El grupo lo declara un `FeatureChoiceEffect` del contenido y las opciones
  /// son dotes de la categoría que ese efecto nombra. Reemplaza al viejo
  /// `fightingStyleId`, que era un único id sin noción de nivel ni cantidad y
  /// por eso no servía para Paladín/Explorador (nivel 2) ni para las
  /// Invocaciones del Brujo (varias, crecientes).
  final Map<String, List<String>> featureChoices;

  /// Conjuros elegidos por un rasgo que los deja **siempre preparados**: id de
  /// grupo → ids de conjuro. El grupo lo declara un `SpellChoiceEffect`.
  ///
  /// Aparte de [featureChoices] porque las opciones son conjuros y no dotes, y
  /// aparte de [spellIds] porque estos no gastan cupo de preparados: el
  /// compilador los vuelca en `alwaysPreparedSpellIds`.
  final Map<String, List<String>> spellChoices;

  /// Grupo del Estilo de Combate. Es un id de contenido, pero vive acá porque
  /// la migración desde `fightingStyleId` tiene que nombrarlo.
  static const String fightingStyleGroup = 'fighting-style';

  /// Lectura de conveniencia del estilo elegido. Para escribir va siempre por
  /// [featureChoices].
  String? get fightingStyleId {
    final chosen = featureChoices[fightingStyleGroup];
    return (chosen == null || chosen.isEmpty) ? null : chosen.first;
  }

  /// Armas en las que se eligió Maestría (2024).
  final List<String> weaponMasteryChoices;

  /// Trucos elegidos (ids de conjuro de nivel 0).
  final List<String> cantripIds;

  /// Conjuros conocidos o preparados (ids de conjuro de nivel 1+).
  final List<String> spellIds;

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

  /// Armas empuñadas en la mano secundaria. id de arma → mano secundaria.
  ///
  /// Se marca explícitamente y no se infiere del orden de equipado: el ataque
  /// de mano secundaria cambia el daño y la economía de acciones, así que
  /// adivinarlo daría una ficha distinta sin que el jugador lo haya pedido.
  final Map<String, bool> weaponOffHand;

  /// Claves opacas de retrato guardado, resueltas por la plataforma que las
  /// muestra (disco local en la aplicación de escritorio, blob de la cuenta
  /// en el cliente web). MUST NOT contener rutas absolutas del sistema de
  /// archivos: el documento tiene que ser portable entre máquinas y cuentas.
  /// La primera es la que se muestra como retrato activo.
  final List<String> portraitPaths;

  /// Notas libres del jugador (autoguardadas).
  String notes;

  /// Alineamiento (sabor, opcional). No afecta ninguna regla.
  final CharacterAlignment? alignment;

  /// Rasgo de personalidad en una línea (sabor, opcional).
  final String personalityTrait;

  final TableConfig tableConfig;
  final CombatState combat;

  Character({
    required this.id,
    required this.name,
    this.status = CharacterStatus.active,
    required this.raceId,
    required this.classId,
    required this.backgroundId,
    this.subclassId,
    this.lineageId,
    this.speciesSpellcastingAbility,
    this.chosenSize,
    this.innateCantripChoices = const {},
    this.level = 1,
    required this.assignedScores,
    this.backgroundAbilityBonuses = const {},
    this.chosenSkills = const [],
    this.chosenProficiencies = const [],
    this.proficiencyChoices = const {},
    this.languages = const [],
    this.languageChoices = const {},
    this.featureChoices = const {},
    this.spellChoices = const {},
    this.weaponMasteryChoices = const [],
    this.cantripIds = const [],
    this.spellIds = const [],
    this.featIds = const [],
    this.asiChoices = const [],
    this.hpPerLevel = const [],
    this.equippedArmorId,
    this.shieldEquipped = false,
    this.equippedWeaponIds = const [],
    this.weaponTwoHanded = const {},
    this.weaponOffHand = const {},
    this.portraitPaths = const [],
    this.notes = '',
    this.alignment,
    this.personalityTrait = '',
    this.tableConfig = const TableConfig(),
    CombatState? combat,
  }) : combat = combat ?? CombatState();

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'status': status.name,
        'raceId': raceId,
        'classId': classId,
        'backgroundId': backgroundId,
        'subclassId': subclassId,
        'lineageId': lineageId,
        'speciesSpellcastingAbility': speciesSpellcastingAbility?.name,
        'chosenSize': chosenSize,
        'innateCantripChoices': innateCantripChoices,
        'level': level,
        'assignedScores': _abilityMapToJson(assignedScores),
        'backgroundAbilityBonuses': _abilityMapToJson(backgroundAbilityBonuses),
        'chosenSkills': chosenSkills,
        'chosenProficiencies': chosenProficiencies,
        'proficiencyChoices': proficiencyChoices,
        'languages': languages,
        'languageChoices': languageChoices,
        'featureChoices': featureChoices,
        'spellChoices': spellChoices,
        'weaponMasteryChoices': weaponMasteryChoices,
        'cantripIds': cantripIds,
        'spellIds': spellIds,
        'featIds': featIds,
        'asiChoices': asiChoices.map((e) => e.toJson()).toList(),
        'hpPerLevel': hpPerLevel,
        'equippedArmorId': equippedArmorId,
        'shieldEquipped': shieldEquipped,
        'equippedWeaponIds': equippedWeaponIds,
        'weaponTwoHanded': weaponTwoHanded,
        'weaponOffHand': weaponOffHand,
        'portraitPaths': portraitPaths,
        'notes': notes,
        'alignment': alignment?.toJson(),
        'personalityTrait': personalityTrait,
        'tableConfig': tableConfig.toJson(),
        'combat': combat.toJson(),
      };

  /// Mapa "id de arma → bandera" tolerante: descarta las entradas cuyo tipo no
  /// corresponde en vez de tirar. Las importaciones son datos no confiables y un
  /// valor basura en una bandera de equipo no justifica perder la ficha entera.
  static Map<String, bool> _boolMap(dynamic raw) => {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String && e.value is bool) e.key as String: e.value,
      };

  /// Mapa "grupo → ids elegidos" tolerante, por el mismo motivo que [_boolMap].
  static Map<String, List<String>> _choiceMap(dynamic raw) => {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String && e.value is List)
              e.key as String: (e.value as List).whereType<String>().toList(),
      };

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión de la ficha debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Cuatro conjuros del catálogo quedaron con un identificador inglés que no
  /// era el suyo: el nombre y las reglas eran correctos, pero el id apuntaba a
  /// otro conjuro. Corregirlo en el pack dejaría huérfana la elección de una
  /// ficha guardada, así que la ficha se reescribe al abrirla.
  static const Map<String, String> _spellIdRenames3to4 = {
    'negative-energy-flood': 'antilife-shell',
    'bless-the-ground': 'hallow',
    'fabricate-shadow': 'creation',
    // Los dos de Conjurar intercambian id, así que el orden del mapa no alcanza:
    // se resuelven contra el mapa original, nunca en cadena.
    'conjure-volley': 'conjure-barrage',
    'conjure-volley-arrows': 'conjure-volley',
  };

  /// Cinco entradas conservaban ids de conjuros 2014 distintos pese a que su
  /// nombre y sus reglas ya correspondían a los reemplazos del PHB 2024.
  static const Map<String, String> _spellIdRenames4to5 = {
    'feeblemind': 'befuddlement',
    'snare': 'cordon-of-arrows',
    'dispel-good-and-evil': 'dispel-evil-and-good',
    'holy-word': 'divine-word',
    'branding-smite': 'shining-smite',
  };

  static void _renameSpellIds(
      Map<String, dynamic> j, Map<String, String> renames) {
    for (final key in const ['cantripIds', 'spellIds']) {
      final list = j[key];
      if (list is! List) continue;
      j[key] = [
        for (final id in list) id is String ? (renames[id] ?? id) : id,
      ];
    }
  }

  /// Dotes que pasaron a tener una variante por característica, porque el
  /// manual deja elegir el +1 y el catálogo lo asignaba solo.
  ///
  /// Cada id viejo apunta a la variante **con la característica que el catálogo
  /// asignaba**, así la ficha de quien ya la tenía compila idéntica. Las que no
  /// daban ninguna Mejora de Característica —su elección no se podía expresar,
  /// así que el campo estaba vacío— van a la primera que ofrece el manual: ahí
  /// la ficha sí cambia, porque gana el +1 que le correspondía.
  ///
  /// Las seis primeras se dividieron en una tanda anterior sin migración, así
  /// que sus ids llevaban tiempo huérfanos: una ficha que las tuviera perdía la
  /// dote en silencio. Se reparan acá.
  static const Map<String, String> _featIdRenames7to8 = {
    'chef': 'chef-wisdom',
    'crusher': 'crusher-constitution',
    'piercer': 'piercer-dexterity',
    'slasher': 'slasher-strength',
    'fey-touched': 'fey-touched-wisdom',
    'shadow-touched': 'shadow-touched-charisma',
    'athlete': 'athlete-dexterity',
    'charger': 'charger-strength',
    'dual-wielder': 'dual-wielder-dexterity',
    'elemental-adept': 'elemental-adept-intelligence',
    'grappler': 'grappler-strength',
    'heavily-armored': 'heavily-armored-strength',
    'heavy-armor-master': 'heavy-armor-master-constitution',
    'inspiring-leader': 'inspiring-leader-charisma',
    'lightly-armored': 'lightly-armored-dexterity',
    'mage-slayer': 'mage-slayer-strength',
    'martial-weapon-training': 'martial-weapon-training-strength',
    'medium-armor-master': 'medium-armor-master-dexterity',
    'moderately-armored': 'moderately-armored-dexterity',
    'mounted-combatant': 'mounted-combatant-strength',
    'observant': 'observant-wisdom',
    'poisoner': 'poisoner-dexterity',
    'polearm-master': 'polearm-master-dexterity',
    'ritual-caster': 'ritual-caster-intelligence',
    'sentinel': 'sentinel-strength',
    'skill-expert': 'skill-expert-intelligence',
    'speedy': 'speedy-dexterity',
    'spell-sniper': 'spell-sniper-intelligence',
    'telekinetic': 'telekinetic-intelligence',
    'telepathic': 'telepathic-wisdom',
    'war-caster': 'war-caster-intelligence',
    'weapon-master': 'weapon-master-strength',
  };

  /// El PHB 2024 llama *Eldritch Smite* a esta invocación; el catálogo la había
  /// cargado como "Castigo Arcano". El texto de la regla siempre fue el de 2024,
  /// así que la ficha compila igual: sólo cambian el id y el nombre.
  static const Map<String, String> _featIdRenames10to11 = {
    'arcane-smite': 'eldritch-smite',
  };

  /// Renombra ids de dote en **los dos lugares donde se guardan**: `featIds`
  /// (las que se toman con una Mejora de Característica) y las listas de
  /// `featureChoices` (estilo de combate, invocaciones… que también son dotes).
  ///
  /// Recorrer sólo `featIds` dejaba las elecciones abiertas afuera, así que una
  /// invocación renombrada se perdía en silencio. El paso 7→8, que ya usaba este
  /// helper, produce lo mismo que antes: ninguno de sus 32 ids es una opción de
  /// elección abierta.
  static void _renameFeatIds(
      Map<String, dynamic> j, Map<String, String> renames) {
    List<dynamic> renamed(List<dynamic> list) => [
          for (final id in list) id is String ? (renames[id] ?? id) : id,
        ];

    final feats = j['featIds'];
    if (feats is List) j['featIds'] = renamed(feats);

    final choices = j['featureChoices'];
    if (choices is Map) {
      j['featureChoices'] = {
        for (final entry in choices.entries)
          entry.key: entry.value is List ? renamed(entry.value) : entry.value,
      };
    }
  }

  /// Grupo de Versatilidad de Habilidad del Khoravar.
  static const String _khoravarVersatilityGroup =
      'race:khoravar:skill-versatility';

  /// Versatilidad de Habilidad del Khoravar dejó de ser un `skillChoiceCount`
  /// de la especie y pasó a ser un `proficiencyChoice`, porque ahora también
  /// puede gastarse en una herramienta. Las fichas viejas quedaron con esa
  /// habilidad todavía dentro de `chosenSkills`: la cuenta esperada baja a la
  /// de la clase sola y sobra una, que además seguía dando competencia.
  ///
  /// El wizard construye `chosenSkills` como `[...clase, ...especie]`, así que
  /// la de la especie es la última. Se la mueve a su grupo si todavía no eligió
  /// nada; si ya eligió por la interfaz nueva, se descarta la vieja para no
  /// dejar dos competencias donde la especie da una.
  static void _migrateKhoravarSkillVersatility(Map<String, dynamic> j) {
    if (j['raceId'] != 'khoravar') return;
    final skills = j['chosenSkills'];
    if (skills is! List || skills.isEmpty) return;

    final remaining = List<dynamic>.from(skills);
    final legacy = remaining.removeLast();
    j['chosenSkills'] = remaining;

    if (legacy is! String || legacy.isEmpty) return;
    final raw = j['proficiencyChoices'];
    final choices =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final existing = choices[_khoravarVersatilityGroup];
    if (existing is! List || existing.isEmpty) {
      choices[_khoravarVersatilityGroup] = [legacy];
    }
    j['proficiencyChoices'] = choices;
  }

  /// Ajeno a los Sueños del Kalashtar concede una competencia temporal tras
  /// cada descanso largo, no una competencia permanente de especie. El wizard
  /// guardaba esa elección al final de `chosenSkills`, igual que el antiguo
  /// Khoravar, así que se descarta al migrar.
  static void _migrateKalashtarTemporarySkill(Map<String, dynamic> j) {
    if (j['raceId'] != 'kalashtar') return;
    final skills = j['chosenSkills'];
    if (skills is! List || skills.isEmpty) return;
    j['chosenSkills'] = List<dynamic>.from(skills)..removeLast();
  }

  /// Convierte `portraitPaths` de rutas absolutas del sistema de archivos de
  /// origen a claves opacas `<characterId>/<archivo>`. Es el mismo esquema de
  /// carpetas que ya usaba el guardado en disco
  /// (`portraits/<characterId>/<archivo>`), así que la clave resultante sigue
  /// resolviendo al mismo archivo sin mover nada; solo deja de viajar la parte
  /// de la ruta que identificaba la máquina de origen.
  static void _migratePortraitPathsToKeys(Map<String, dynamic> j) {
    final list = j['portraitPaths'];
    if (list is! List) return;
    final characterId = j['id'] as String? ?? '';
    j['portraitPaths'] = [
      for (final entry in list)
        if (entry is String && entry.isNotEmpty)
          '$characterId/${_basename(entry)}',
    ];
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }

  /// Lleva una ficha histórica al esquema actual sin modificar el mapa de
  /// entrada. Cada paso se conserva explícito para que las próximas versiones
  /// puedan encadenarse sin saltos.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final migrated = Map<String, dynamic>.from(source);
    var version = schemaVersionOf(migrated);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'ficha',
        found: version,
        supported: currentSchemaVersion,
      );
    }

    while (version < currentSchemaVersion) {
      switch (version) {
        case 1:
          migrated.putIfAbsent('status', () => CharacterStatus.active.name);
          migrated.putIfAbsent('lineageId', () => null);
          migrated.putIfAbsent('backgroundAbilityBonuses', () => {});
          migrated.putIfAbsent('asiChoices', () => []);
          migrated.putIfAbsent('alignment', () => null);
          migrated.putIfAbsent('personalityTrait', () => '');
          migrated.putIfAbsent('tableConfig', () => {});
          migrated.putIfAbsent('combat', () => {});
          version = 2;
          migrated['schemaVersion'] = version;
        case 2:
          migrated.putIfAbsent('speciesSpellcastingAbility', () => null);
          version = 3;
          migrated['schemaVersion'] = version;
        case 3:
          _renameSpellIds(migrated, _spellIdRenames3to4);
          version = 4;
          migrated['schemaVersion'] = version;
        case 4:
          _renameSpellIds(migrated, _spellIdRenames4to5);
          version = 5;
          migrated['schemaVersion'] = version;
        case 5:
          migrated.putIfAbsent('weaponOffHand', () => <String, dynamic>{});
          version = 6;
          migrated['schemaVersion'] = version;
        case 6:
          // El estilo de combate pasa a ser una elección más. Se quita el campo
          // viejo para que no quede un dato muerto que contradiga al nuevo; si
          // una importación trae los dos, gana `featureChoices`.
          final legacy = migrated.remove('fightingStyleId');
          final raw = migrated['featureChoices'];
          final choices =
              raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          if (legacy is String && legacy.isNotEmpty) {
            choices.putIfAbsent(fightingStyleGroup, () => [legacy]);
          }
          migrated['featureChoices'] = choices;
          version = 7;
          migrated['schemaVersion'] = version;
        case 7:
          _renameFeatIds(migrated, _featIdRenames7to8);
          version = 8;
          migrated['schemaVersion'] = version;
        case 8:
          migrated.putIfAbsent('proficiencyChoices', () => {});
          version = 9;
          migrated['schemaVersion'] = version;
        case 9:
          _migrateKhoravarSkillVersatility(migrated);
          version = 10;
          migrated['schemaVersion'] = version;
        case 10:
          _renameFeatIds(migrated, _featIdRenames10to11);
          version = 11;
          migrated['schemaVersion'] = version;
        case 11:
          // La migración a webapp escribió este paso como 8→9 mientras la rama
          // de escritorio ya había publicado su propio 8→9 (v0.5.1). Los dos
          // números coincidían y significaban cosas distintas, así que al
          // fusionar se renumeró **este**: las fichas de escritorio existentes
          // ya están en 9, 10 u 11 y su cadena no se puede tocar, mientras que
          // el servidor todavía no había guardado ninguna ficha real.
          _migratePortraitPathsToKeys(migrated);
          version = 12;
          migrated['schemaVersion'] = version;
        case 12:
          _migrateKalashtarTemporarySkill(migrated);
          version = 13;
          migrated['schemaVersion'] = version;
        case 13:
          migrated.putIfAbsent('spellChoices', () => {});
          version = 14;
          migrated['schemaVersion'] = version;
        case 14:
          // Arranca vacío a propósito: la ficha vieja no dice qué idiomas
          // eligió el jugador y el motor no se los va a inventar. Queda con
          // los dos pendientes como aviso informativo, igual que pasó con la
          // Pericia, y el editor de la ficha los resuelve.
          migrated.putIfAbsent('languages', () => []);
          migrated.putIfAbsent('languageChoices', () => {});
          version = 15;
          migrated['schemaVersion'] = version;
        case 15:
          // Los compañeros invocados viven dentro de `combat`. Una ficha vieja
          // no tenía ninguno, así que arranca con la lista vacía: el cañón o el
          // defensor se invocan de nuevo desde la ficha.
          final raw = migrated['combat'];
          final combat =
              raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          combat.putIfAbsent('companions', () => []);
          migrated['combat'] = combat;
          version = 16;
          migrated['schemaVersion'] = version;
      }
    }
    return migrated;
  }

  factory Character.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Character(
      id: j['id'] as String,
      name: j['name'] as String,
      status: CharacterStatus.values.firstWhere(
        (s) => s.name == (j['status'] as String?),
        orElse: () => CharacterStatus.active,
      ),
      raceId: j['raceId'] as String,
      classId: j['classId'] as String,
      backgroundId: j['backgroundId'] as String,
      subclassId: j['subclassId'] as String?,
      lineageId: j['lineageId'] as String?,
      speciesSpellcastingAbility:
          _abilityFromJson(j['speciesSpellcastingAbility']),
      chosenSize: j['chosenSize'] as String?,
      innateCantripChoices: {
        for (final e in (j['innateCantripChoices'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      level: j['level'] as int? ?? 1,
      assignedScores: _abilityMapFromJson(j['assignedScores']),
      backgroundAbilityBonuses:
          _abilityMapFromJson(j['backgroundAbilityBonuses']),
      chosenSkills: (j['chosenSkills'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      chosenProficiencies: (j['chosenProficiencies'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      proficiencyChoices: _choiceMap(j['proficiencyChoices']),
      languages: (j['languages'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      languageChoices: _choiceMap(j['languageChoices']),
      featureChoices: _choiceMap(j['featureChoices']),
      spellChoices: _choiceMap(j['spellChoices']),
      weaponMasteryChoices: (j['weaponMasteryChoices'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      cantripIds: (j['cantripIds'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      spellIds:
          (j['spellIds'] as List? ?? const []).map((e) => e as String).toList(),
      featIds:
          (j['featIds'] as List? ?? const []).map((e) => e as String).toList(),
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
      weaponTwoHanded: _boolMap(j['weaponTwoHanded']),
      weaponOffHand: _boolMap(j['weaponOffHand']),
      portraitPaths: (j['portraitPaths'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      notes: j['notes'] as String? ?? '',
      alignment: CharacterAlignment.fromJson(j['alignment'] as String?),
      personalityTrait: j['personalityTrait'] as String? ?? '',
      tableConfig: TableConfig.fromJson(
          (j['tableConfig'] as Map?)?.cast<String, dynamic>() ?? const {}),
      combat: CombatState.fromJson(
          (j['combat'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  /// Copia con overrides. Preserva el [CombatState] por referencia salvo que se
  /// pase uno nuevo. Útil para editar equipo/nivel sin perder estado de partida.
  Character copyWith({
    String? name,
    CharacterStatus? status,
    Object? subclassId = _unset,
    Object? lineageId = _unset,
    Object? speciesSpellcastingAbility = _unset,
    Object? chosenSize = _unset,
    Map<String, String>? innateCantripChoices,
    int? level,
    List<String>? featIds,
    List<AsiChoice>? asiChoices,
    List<int>? hpPerLevel,
    Map<String, List<String>>? featureChoices,
    Map<String, List<String>>? spellChoices,
    List<String>? chosenProficiencies,
    Map<String, List<String>>? proficiencyChoices,
    List<String>? languages,
    Map<String, List<String>>? languageChoices,
    List<String>? cantripIds,
    List<String>? spellIds,
    Object? equippedArmorId = _unset,
    bool? shieldEquipped,
    List<String>? equippedWeaponIds,
    Map<String, bool>? weaponTwoHanded,
    Map<String, bool>? weaponOffHand,
    List<String>? portraitPaths,
    String? notes,
    Object? alignment = _unset,
    String? personalityTrait,
    CombatState? combat,
  }) {
    return Character(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      raceId: raceId,
      classId: classId,
      backgroundId: backgroundId,
      subclassId: identical(subclassId, _unset)
          ? this.subclassId
          : subclassId as String?,
      lineageId:
          identical(lineageId, _unset) ? this.lineageId : lineageId as String?,
      speciesSpellcastingAbility: identical(speciesSpellcastingAbility, _unset)
          ? this.speciesSpellcastingAbility
          : speciesSpellcastingAbility as Ability?,
      chosenSize: identical(chosenSize, _unset)
          ? this.chosenSize
          : chosenSize as String?,
      innateCantripChoices: innateCantripChoices ?? this.innateCantripChoices,
      level: level ?? this.level,
      assignedScores: assignedScores,
      backgroundAbilityBonuses: backgroundAbilityBonuses,
      chosenSkills: chosenSkills,
      chosenProficiencies: chosenProficiencies ?? this.chosenProficiencies,
      proficiencyChoices: proficiencyChoices ?? this.proficiencyChoices,
      languages: languages ?? this.languages,
      languageChoices: languageChoices ?? this.languageChoices,
      featureChoices: featureChoices ?? this.featureChoices,
      spellChoices: spellChoices ?? this.spellChoices,
      weaponMasteryChoices: weaponMasteryChoices,
      cantripIds: cantripIds ?? this.cantripIds,
      spellIds: spellIds ?? this.spellIds,
      featIds: featIds ?? this.featIds,
      asiChoices: asiChoices ?? this.asiChoices,
      hpPerLevel: hpPerLevel ?? this.hpPerLevel,
      // Con el centinela, pasar `equippedArmorId: null` sí desequipa.
      equippedArmorId: identical(equippedArmorId, _unset)
          ? this.equippedArmorId
          : equippedArmorId as String?,
      shieldEquipped: shieldEquipped ?? this.shieldEquipped,
      equippedWeaponIds: equippedWeaponIds ?? this.equippedWeaponIds,
      weaponTwoHanded: weaponTwoHanded ?? this.weaponTwoHanded,
      weaponOffHand: weaponOffHand ?? this.weaponOffHand,
      portraitPaths: portraitPaths ?? this.portraitPaths,
      notes: notes ?? this.notes,
      // Centinela: pasar `alignment: null` sí lo limpia.
      alignment: identical(alignment, _unset)
          ? this.alignment
          : alignment as CharacterAlignment?,
      personalityTrait: personalityTrait ?? this.personalityTrait,
      tableConfig: tableConfig,
      combat: combat ?? this.combat,
    );
  }
}

Ability? _abilityFromJson(Object? value) {
  if (value is! String) return null;
  for (final ability in Ability.values) {
    if (ability.name == value) return ability;
  }
  return null;
}
