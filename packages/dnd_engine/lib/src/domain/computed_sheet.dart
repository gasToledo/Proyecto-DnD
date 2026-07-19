import 'ability.dart';
import 'effects.dart';

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
  });

  /// Tirada de salvación total para [a] (mod + competencia si aplica).
  int savingThrow(Ability a) =>
      abilityModifiers[a]! +
      (savingThrowProficiencies.contains(a) ? proficiencyBonus : 0);
}
