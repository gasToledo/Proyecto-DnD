import '../domain/ability.dart';
import '../domain/computed_sheet.dart';
import '../domain/effects.dart';

/// Acumulador mutable que los [Effect] van poblando. El [CharacterCompiler]
/// lo finaliza en un [ComputedSheet] inmutable.
class SheetBuilder {
  final Map<Ability, int> baseScores;

  /// Nivel de personaje, necesario para recursos que escalan (maxPerLevel).
  final int level;

  final Map<Ability, int> abilityBonuses = {
    for (final a in Ability.values) a: 0,
  };

  /// Los mismos aportes que suma [abilityBonuses], pero uno por uno y con su
  /// fuente. El mapa responde "cuánto"; esta lista responde "por qué".
  final List<AbilityBonus> abilityBonusSources = [];

  int speed = 30;
  int? darkvision;

  /// Característica que suma a la CA por Defensa sin Armadura (null = ninguna).
  Ability? unarmoredDefenseAbility;

  /// Si la Defensa sin Armadura se conserva con escudo (Bárbaro sí, Monje no).
  bool unarmoredDefenseAllowShield = false;

  /// Bono de velocidad por Movimiento sin Armadura (acumulado), y sus
  /// condiciones. Solo se aplica si no se lleva armadura (ver condiciones).
  int unarmoredMovementBonus = 0;
  bool unarmoredMovementAllowShield = false;
  bool unarmoredMovementHeavyOnly = false;

  /// Rasgo de lanzamiento de conjuros activo (null = no lanza).
  SpellcastingEffect? spellcasting;

  final Set<Ability> saveProficiencies = {};
  final Set<String> skillProficiencies = {};

  /// Habilidades con Pericia. Lo llena el compilador en su segunda pasada, no
  /// [applyEffect]: las opciones dependen de qué competencias quedaron, y eso
  /// solo se sabe cuando ya se aplicaron todos los efectos.
  final Set<String> expertiseSkills = {};

  final Set<String> armorProficiencies = {};
  final Set<String> weaponProficiencies = {};
  final Set<String> toolProficiencies = {};
  final Set<String> resistances = {};
  final Set<String> immunities = {};

  /// Idiomas que conceden los rasgos. Los dos que elige el jugador y el Común
  /// los suma el compilador: no vienen de un efecto.
  final Set<String> languages = {};

  final List<PassiveTrait> passives = [];

  /// Conjuros concedidos por rasgos, sin resolver (el compilador los cruza con
  /// el repositorio para armar los [InnateSpell]).
  final List<GrantSpellEffect> grantedSpells = [];

  /// Conjuros siempre preparados por un rasgo. Se guardan por id: resolver
  /// nombre y nivel necesita el repositorio, que vive en el compilador.
  final Set<String> alwaysPreparedSpellIds = {};

  /// Conjuros que un rasgo suma a la lista elegible (Conjuros de la Marca).
  final Set<String> spellListAdditionIds = {};

  final Map<String, ResourceEffect> _resources = {};

  /// Compañeros concedidos, por id de opción. **Gana el último**, que por el
  /// orden de `featuresUpTo` es el del nivel más alto: es la misma convención
  /// que los recursos, y es lo que deja al Artillero pasar del cañón base al
  /// Cañón Explosivo a nivel 9 y a dos cañones a nivel 15 redeclarando el
  /// mismo id.
  ///
  /// Se guardan crudos: resolver las formas contra el catálogo y descartar las
  /// que dependen de un conjuro que el personaje no tiene necesita el
  /// repositorio, que vive en el compilador.
  final Map<String, CompanionEffect> companions = {};

  /// Cupo de formas de Forma Salvaje, o null si el personaje no lo tiene. Uno
  /// solo y no un mapa: el rasgo es único y sus tres escalones (niveles 2, 4 y
  /// 8) se pisan entre sí, quedando el del nivel más alto.
  WildShapeFormsEffect? wildShapeForms;

  /// Puede lanzar conjuros transformado (Conjurar como Bestia, nivel 18).
  bool castWhileWildShaped = false;

  /// Elecciones abiertas declaradas por el contenido, por grupo. Gana la de
  /// mayor [FeatureChoiceEffect.count], porque el contenido declara el
  /// acumulado a cada nivel y no el incremento.
  final Map<String, FeatureChoiceEffect> featureChoiceSlots = {};

  int weaponMasterySlots = 0;
  int maxExtraAttack = 0;

  /// El ataque de mano secundaria conserva el modificador de característica al
  /// daño (estilo Combate con Dos Armas).
  bool offHandAbilityDamage = false;
  int bonusMaxHpFlat = 0;
  int bonusMaxHpPerLevel = 0;
  int acBonus = 0;

  SheetBuilder({required this.baseScores, this.level = 1});

  /// Resuelve las plantillas de recurso acumuladas a su [CharacterResource]
  /// final. Se hace acá, y no en [applyEffect], porque un [ResourceEffect]
  /// puede escalar con un modificador de característica ([maxFromAbility]),
  /// y los modificadores finales solo se conocen después de aplicar todos los
  /// efectos de bonus a características.
  List<CharacterResource> resolveResources(Map<Ability, int> mods, int level) {
    return _resources.values.map((e) {
      final max = e.maxFromProficiency
          ? proficiencyBonusForLevel(level) * e.proficiencyMultiplier
          : e.maxFromAbility != null
              ? [e.max, mods[e.maxFromAbility]!].reduce((a, b) => a > b ? a : b)
              : (e.maxPerLevel ? level + e.max : e.max);
      return CharacterResource(
        id: e.id,
        name: e.name,
        max: max,
        recharge: e.recharge,
        shortRestRecovery: e.shortRestRecovery,
        description: e.description,
      );
    }).toList();
  }

  /// Suma [amount] a [a] y **anota de dónde vino**. El total sin la
  /// procedencia no se puede explicar después: es lo que hacía imposible
  /// responder "¿por qué tengo 20 de Inteligencia?" desde la ficha.
  ///
  /// [source] queda vacío solo si quien llama no sabe la fuente; la UI trata
  /// esos aportes como anónimos en vez de inventarles un nombre.
  void addAbilityBonus(Ability a, int amount, {String source = ''}) {
    abilityBonuses[a] = abilityBonuses[a]! + amount;
    abilityBonusSources.add(
      AbilityBonus(ability: a, amount: amount, source: source),
    );
  }

  int finalScore(Ability a) => (baseScores[a] ?? 10) + abilityBonuses[a]!;

  /// Interpreta un efecto sobre este acumulador. Único lugar donde la semántica
  /// de cada tipo de efecto vive; agregar contenido no toca este switch.
  ///
  /// [sourceName] es el nombre legible de la fuente que trajo el efecto, para
  /// que los bonus a características puedan explicarse. Lo pasa `applyAll`.
  void applyEffect(
    Effect e, {
    Ability? spellAbilityOverride,
    String sourceName = '',
  }) {
    switch (e) {
      case AbilityScoreBonusEffect(:final ability, :final amount):
        addAbilityBonus(ability, amount, source: sourceName);
      case SetSpeedEffect(:final feet):
        speed = feet;
      case SpeedBonusEffect(:final feet):
        speed += feet;
      case DarkvisionEffect(:final range):
        darkvision =
            (darkvision == null || range > darkvision!) ? range : darkvision;
      case SkillProficiencyEffect(:final skill):
        skillProficiencies.add(skill);
      case SavingThrowProficiencyEffect(:final ability):
        saveProficiencies.add(ability);
      case ArmorProficiencyEffect(:final category):
        armorProficiencies.add(category);
      case WeaponProficiencyEffect(:final category):
        weaponProficiencies.add(category);
      case ToolProficiencyEffect(:final tool):
        toolProficiencies.add(tool);
      case ResistanceEffect(:final damageType):
        resistances.add(damageType);
      case ImmunityEffect(:final damageType):
        immunities.add(damageType);
      case LanguageEffect(:final language):
        languages.add(language);
      case LanguageChoiceEffect():
        // Marcador: lo resuelve el compilador, que sabe qué idiomas ya tiene
        // el personaje y por eso puede armar el pozo sin repetidos.
        break;
      case PassiveTraitEffect(:final name, :final description):
        passives.add(PassiveTrait(name, description));
      case GrantFeatEffect():
        // La dote concreta ya está resuelta en Character.featIds y sus efectos
        // se aplican por separado; este efecto solo informa al wizard.
        break;
      case GrantSpellEffect():
        // Se guarda crudo: resolver nombre y nivel del conjuro necesita el
        // repositorio, que vive en el compilador.
        grantedSpells.add(
          spellAbilityOverride == null
              ? e
              : GrantSpellEffect(
                  spellId: e.spellId,
                  ability: spellAbilityOverride,
                  use: e.use,
                  replaceableFrom: e.replaceableFrom,
                ),
        );
      case AlwaysPreparedSpellEffect(:final spellId):
        alwaysPreparedSpellIds.add(spellId);
      case SpellListAdditionEffect(:final spellId):
        spellListAdditionIds.add(spellId);
      case ProficiencyChoiceEffect():
        // Marcador: la competencia concreta ya está en
        // Character.chosenProficiencies y el compilador la aplica. Los cupos
        // los arma él también, porque necesita saber de qué dote sale cada uno
        // y acá esa procedencia ya se perdió.
        break;
      case SpellChoiceEffect():
        // Marcador, igual que ProficiencyChoiceEffect: la elección vive en
        // Character.spellChoices y la resuelve el compilador, que tiene el
        // repositorio para filtrar el pozo y el bloque de lanzamiento para
        // saber hasta qué nivel llega.
        break;
      case LeveledEffect(:final minLevel, :final effects):
        // Por el camino normal no llega ninguno: el compilador los expande en
        // `applySource` para que las pasadas que leen la lista de efectos de
        // cada fuente vean el contenido y no el envoltorio. Esto es la red para
        // quien use SheetBuilder directo, que es público.
        if (level >= minLevel) {
          applyAll(
            effects,
            spellAbilityOverride: spellAbilityOverride,
            sourceName: sourceName,
          );
        }
      case OffHandAbilityDamageEffect():
        offHandAbilityDamage = true;
      case FeatureChoiceEffect(:final groupId, :final count):
        final prev = featureChoiceSlots[groupId];
        if (prev == null || count > prev.count) {
          featureChoiceSlots[groupId] = e;
        }
      case WeaponMasterySlotsEffect(:final count):
        if (count > weaponMasterySlots) weaponMasterySlots = count;
      case ExtraAttackEffect(:final extra):
        if (extra > maxExtraAttack) maxExtraAttack = extra;
      case BonusMaxHpFlatEffect(:final amount):
        bonusMaxHpFlat += amount;
      case BonusMaxHpPerLevelEffect(:final perLevel):
        bonusMaxHpPerLevel += perLevel;
      case ArmorClassBonusEffect(:final amount):
        acBonus += amount;
      case UnarmoredDefenseEffect(:final ability, :final allowShield):
        unarmoredDefenseAbility = ability;
        unarmoredDefenseAllowShield = allowShield;
      case UnarmoredMovementEffect(
          :final feet,
          :final allowShield,
          :final heavyArmorOnly
        ):
        unarmoredMovementBonus += feet;
        unarmoredMovementAllowShield = allowShield;
        unarmoredMovementHeavyOnly = heavyArmorOnly;
      case SpellcastingEffect():
        // El último rasgo de lanzamiento gana (una clase por ahora).
        spellcasting = e;
      case ResourceEffect(:final id):
        // El máximo puede depender de un modificador de característica que
        // todavía no está disponible acá; se resuelve en [resolveResources].
        _resources[id] = e;
      case CompanionEffect(:final id):
        companions[id] = e;
      case WildShapeFormsEffect():
        wildShapeForms = e;
      case CastWhileWildShapedEffect():
        castWhileWildShaped = true;
    }
  }

  void applyAll(
    Iterable<Effect> effects, {
    Ability? spellAbilityOverride,
    String sourceName = '',
  }) {
    for (final effect in effects) {
      applyEffect(
        effect,
        spellAbilityOverride: spellAbilityOverride,
        sourceName: sourceName,
      );
    }
  }
}
