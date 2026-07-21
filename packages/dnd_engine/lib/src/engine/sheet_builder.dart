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

  int speed = 30;
  int? darkvision;

  /// Característica que suma a la CA por Defensa sin Armadura (null = ninguna).
  Ability? unarmoredDefenseAbility;

  /// Si la Defensa sin Armadura se conserva con escudo (Bárbaro sí, Monje no).
  bool unarmoredDefenseAllowShield = false;

  /// Rasgo de lanzamiento de conjuros activo (null = no lanza).
  SpellcastingEffect? spellcasting;

  final Set<Ability> saveProficiencies = {};
  final Set<String> skillProficiencies = {};
  final Set<String> armorProficiencies = {};
  final Set<String> weaponProficiencies = {};
  final Set<String> toolProficiencies = {};
  final Set<String> resistances = {};
  final Set<String> immunities = {};

  final List<PassiveTrait> passives = [];
  final Map<String, CharacterResource> _resources = {};

  int weaponMasterySlots = 0;
  int maxExtraAttack = 0;
  int bonusMaxHpFlat = 0;
  int bonusMaxHpPerLevel = 0;
  int acBonus = 0;

  SheetBuilder({required this.baseScores, this.level = 1});

  List<CharacterResource> get resources => _resources.values.toList();

  void addAbilityBonus(Ability a, int amount) =>
      abilityBonuses[a] = abilityBonuses[a]! + amount;

  int finalScore(Ability a) => (baseScores[a] ?? 10) + abilityBonuses[a]!;

  /// Interpreta un efecto sobre este acumulador. Único lugar donde la semántica
  /// de cada tipo de efecto vive; agregar contenido no toca este switch.
  void applyEffect(Effect e) {
    switch (e) {
      case AbilityScoreBonusEffect(:final ability, :final amount):
        addAbilityBonus(ability, amount);
      case SetSpeedEffect(:final feet):
        speed = feet;
      case SpeedBonusEffect(:final feet):
        speed += feet;
      case DarkvisionEffect(:final range):
        darkvision = (darkvision == null || range > darkvision!) ? range : darkvision;
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
      case PassiveTraitEffect(:final name, :final description):
        passives.add(PassiveTrait(name, description));
      case GrantFeatEffect():
        // La dote concreta ya está resuelta en Character.featIds y sus efectos
        // se aplican por separado; este efecto solo informa al wizard.
        break;
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
      case SpellcastingEffect():
        // El último rasgo de lanzamiento gana (una clase por ahora).
        spellcasting = e;
      case ResourceEffect(
          :final id,
          :final name,
          :final max,
          :final recharge,
          :final description,
          :final maxPerLevel
        ):
        _resources[id] = CharacterResource(
          id: id,
          name: name,
          max: maxPerLevel ? level : max,
          recharge: recharge,
          description: description,
        );
    }
  }

  void applyAll(Iterable<Effect> effects) => effects.forEach(applyEffect);
}
