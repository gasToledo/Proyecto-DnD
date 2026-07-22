import 'ability.dart';
import 'effects.dart';
import 'spell_slots.dart';

/// Rasgo pasivo mostrado en la ficha.
class PassiveTrait {
  final String name;
  final String description;
  const PassiveTrait(this.name, [this.description = '']);

  Map<String, dynamic> toJson() =>
      {'name': name, 'description': description};
}

/// Recurso consumible con su máximo y cómo se recarga.
class CharacterResource {
  final String id;
  final String name;
  final int max;
  final RechargeOn recharge;
  final String description;
  const CharacterResource({
    required this.id,
    required this.name,
    required this.max,
    required this.recharge,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'max': max,
        'recharge': recharge.name,
        'description': description,
      };
}

/// Ataque calculado a partir del arma equipada.
class Attack {
  final String weaponId;
  final String name;
  final int attackBonus;

  /// Cadena de daño lista para mostrar, p.ej. "1d8 + 3".
  final String damage;
  final String damageType;

  /// Maestría aplicada si el arma está entre las elegidas (2024).
  final String? mastery;

  const Attack({
    required this.weaponId,
    required this.name,
    required this.attackBonus,
    required this.damage,
    required this.damageType,
    this.mastery,
  });

  Map<String, dynamic> toJson() => {
        'weaponId': weaponId,
        'name': name,
        'attackBonus': attackBonus,
        'damage': damage,
        'damageType': damageType,
        'mastery': mastery,
      };
}

/// Bloque de lanzamiento de conjuros derivado. Presente solo si el personaje
/// tiene una clase (o rasgo) lanzadora.
class Spellcasting {
  final Ability ability;
  final CasterProgression progression;
  final SpellPreparation preparation;
  final String spellList;

  /// CD de salvación = 8 + competencia + mod. de característica de lanzamiento.
  final int saveDc;

  /// Bono de ataque de conjuro = competencia + mod. de característica.
  final int attackBonus;

  final int cantripsKnown;

  /// Conjuros que se pueden preparar (si [preparation] es prepared): nivel de
  /// clase lanzadora + mod. de característica (mínimo 1).
  final int preparedCount;

  /// Espacios de conjuro por nivel (nivel de conjuro → cantidad).
  final Map<int, int> slotsByLevel;

  const Spellcasting({
    required this.ability,
    required this.progression,
    required this.preparation,
    required this.spellList,
    required this.saveDc,
    required this.attackBonus,
    required this.cantripsKnown,
    required this.preparedCount,
    required this.slotsByLevel,
  });

  Map<String, dynamic> toJson() => {
        'ability': ability.name,
        'progression': progression.toJson(),
        'preparation': preparation.toJson(),
        'spellList': spellList,
        'saveDc': saveDc,
        'attackBonus': attackBonus,
        'cantripsKnown': cantripsKnown,
        'preparedCount': preparedCount,
        'slotsByLevel': {for (final e in slotsByLevel.entries) '${e.key}': e.value},
      };
}

/// Resultado **derivado y de solo lectura** de compilar un personaje.
/// La UI de la ficha lee de aquí; nunca recalcula a mano.
class ComputedSheet {
  final int level;
  final int proficiencyBonus;
  final Map<Ability, int> abilityScores;
  final Map<Ability, int> abilityModifiers;
  final Set<Ability> savingThrowProficiencies;
  final Set<String> skillProficiencies;
  final Set<String> armorProficiencies;
  final Set<String> weaponProficiencies;
  final Set<String> toolProficiencies;

  final int maxHp;
  final int hitDie;
  final int armorClass;
  final int speed;
  final int initiative;
  final int passivePerception;
  final int? darkvision;

  final Set<String> resistances;
  final Set<String> immunities;

  final int weaponMasterySlots;
  final int attacksPerAction;

  final List<Attack> attacks;
  final List<PassiveTrait> passives;
  final List<CharacterResource> resources;

  /// Bloque de lanzamiento de conjuros, o null si el personaje no lanza.
  final Spellcasting? spellcasting;

  const ComputedSheet({
    required this.level,
    required this.proficiencyBonus,
    required this.abilityScores,
    required this.abilityModifiers,
    required this.savingThrowProficiencies,
    required this.skillProficiencies,
    required this.armorProficiencies,
    required this.weaponProficiencies,
    required this.toolProficiencies,
    required this.maxHp,
    required this.hitDie,
    required this.armorClass,
    required this.speed,
    required this.initiative,
    required this.passivePerception,
    required this.darkvision,
    required this.resistances,
    required this.immunities,
    required this.weaponMasterySlots,
    required this.attacksPerAction,
    required this.attacks,
    required this.passives,
    required this.resources,
    this.spellcasting,
  });

  /// Tirada de salvación total para [a] (mod + competencia si aplica).
  int savingThrow(Ability a) =>
      abilityModifiers[a]! +
      (savingThrowProficiencies.contains(a) ? proficiencyBonus : 0);
}
