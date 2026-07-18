import 'ability.dart';

/// Tipo de descanso que recarga un recurso.
enum RechargeOn { shortRest, longRest, none }

RechargeOn _rechargeFromJson(String? v) => switch (v) {
      'short' => RechargeOn.shortRest,
      'long' => RechargeOn.longRest,
      _ => RechargeOn.none,
    };

String _rechargeToJson(RechargeOn v) => switch (v) {
      RechargeOn.shortRest => 'short',
      RechargeOn.longRest => 'long',
      RechargeOn.none => 'none',
    };

/// Un [Effect] es la unidad atómica y **serializable** de lo que un rasgo hace.
///
/// Razas, clases, trasfondos, dotes y objetos son *datos* que declaran una
/// lista de efectos; el [CharacterCompiler] los interpreta para producir la
/// ficha derivada. Esto hace que contenido oficial y homebrew usen exactamente
/// la misma maquinaria: agregar contenido nuevo es cargar JSON, no programar.
sealed class Effect {
  const Effect();

  Map<String, dynamic> toJson();

  /// Deserializa un efecto despachando según el campo `type`.
  factory Effect.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'abilityScoreBonus' => AbilityScoreBonusEffect(
          ability: Ability.fromKey(json['ability'] as String),
          amount: json['amount'] as int,
        ),
      'speedBonus' => SpeedBonusEffect(json['feet'] as int),
      'setSpeed' => SetSpeedEffect(json['feet'] as int),
      'darkvision' => DarkvisionEffect(json['range'] as int),
      'skillProficiency' => SkillProficiencyEffect(json['skill'] as String),
      'savingThrowProficiency' => SavingThrowProficiencyEffect(
          Ability.fromKey(json['ability'] as String),
        ),
      'armorProficiency' => ArmorProficiencyEffect(json['category'] as String),
      'weaponProficiency' =>
        WeaponProficiencyEffect(json['category'] as String),
      'toolProficiency' => ToolProficiencyEffect(json['tool'] as String),
      'resistance' => ResistanceEffect(json['damageType'] as String),
      'immunity' => ImmunityEffect(json['damageType'] as String),
      'passiveTrait' => PassiveTraitEffect(
          name: json['name'] as String,
          description: json['description'] as String? ?? '',
        ),
      'grantFeat' => GrantFeatEffect(featId: json['featId'] as String?),
      'weaponMasterySlots' =>
        WeaponMasterySlotsEffect(json['count'] as int),
      'extraAttack' => ExtraAttackEffect(json['extra'] as int),
      'bonusMaxHpFlat' => BonusMaxHpFlatEffect(json['amount'] as int),
      'bonusMaxHpPerLevel' =>
        BonusMaxHpPerLevelEffect(json['perLevel'] as int),
      'armorClassBonus' => ArmorClassBonusEffect(json['amount'] as int),
      'resource' => ResourceEffect(
          id: json['id'] as String,
          name: json['name'] as String,
          max: json['max'] as int,
          recharge: _rechargeFromJson(json['recharge'] as String?),
        ),
      _ => throw ArgumentError('Tipo de efecto desconocido: "$type"'),
    };
  }

  static List<Effect> listFromJson(dynamic json) => (json as List? ?? const [])
      .map((e) => Effect.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Suma (o resta) puntos a una característica. Fuente: trasfondo 2024, ASI, dote.
class AbilityScoreBonusEffect extends Effect {
  final Ability ability;
  final int amount;
  const AbilityScoreBonusEffect({required this.ability, required this.amount});
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'abilityScoreBonus', 'ability': ability.name, 'amount': amount};
}

/// Suma pies a la velocidad base.
class SpeedBonusEffect extends Effect {
  final int feet;
  const SpeedBonusEffect(this.feet);
  @override
  Map<String, dynamic> toJson() => {'type': 'speedBonus', 'feet': feet};
}

/// Fija la velocidad base (usada por la raza).
class SetSpeedEffect extends Effect {
  final int feet;
  const SetSpeedEffect(this.feet);
  @override
  Map<String, dynamic> toJson() => {'type': 'setSpeed', 'feet': feet};
}

/// Visión en la oscuridad, en pies. Se queda con el mayor alcance concedido.
class DarkvisionEffect extends Effect {
  final int range;
  const DarkvisionEffect(this.range);
  @override
  Map<String, dynamic> toJson() => {'type': 'darkvision', 'range': range};
}

class SkillProficiencyEffect extends Effect {
  final String skill;
  const SkillProficiencyEffect(this.skill);
  @override
  Map<String, dynamic> toJson() => {'type': 'skillProficiency', 'skill': skill};
}

class SavingThrowProficiencyEffect extends Effect {
  final Ability ability;
  const SavingThrowProficiencyEffect(this.ability);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'savingThrowProficiency', 'ability': ability.name};
}

/// Competencia con armadura: 'light' | 'medium' | 'heavy' | 'shields'.
class ArmorProficiencyEffect extends Effect {
  final String category;
  const ArmorProficiencyEffect(this.category);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'armorProficiency', 'category': category};
}

/// Competencia con armas: 'simple' | 'martial' | o el id de un arma concreta.
class WeaponProficiencyEffect extends Effect {
  final String category;
  const WeaponProficiencyEffect(this.category);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'weaponProficiency', 'category': category};
}

class ToolProficiencyEffect extends Effect {
  final String tool;
  const ToolProficiencyEffect(this.tool);
  @override
  Map<String, dynamic> toJson() => {'type': 'toolProficiency', 'tool': tool};
}

class ResistanceEffect extends Effect {
  final String damageType;
  const ResistanceEffect(this.damageType);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'resistance', 'damageType': damageType};
}

class ImmunityEffect extends Effect {
  final String damageType;
  const ImmunityEffect(this.damageType);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'immunity', 'damageType': damageType};
}

/// Rasgo pasivo/narrativo que se muestra en la ficha (Segundo Aliento,
/// Oleada de Acción, Inspiración Heroica, etc.).
class PassiveTraitEffect extends Effect {
  final String name;
  final String description;
  const PassiveTraitEffect({required this.name, this.description = ''});
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'passiveTrait', 'name': name, 'description': description};
}

/// Concede una dote. Si [featId] es null, es una dote **a elección** del
/// jugador (p.ej. la dote de origen 2024 que otorga el trasfondo).
class GrantFeatEffect extends Effect {
  final String? featId;
  const GrantFeatEffect({this.featId});
  @override
  Map<String, dynamic> toJson() => {'type': 'grantFeat', 'featId': featId};
}

/// Cantidad de armas en las que se puede elegir Maestría (Guerrero 2024: 3).
class WeaponMasterySlotsEffect extends Effect {
  final int count;
  const WeaponMasterySlotsEffect(this.count);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'weaponMasterySlots', 'count': count};
}

/// Ataques adicionales por acción de Ataque (Guerrero nivel 5+).
class ExtraAttackEffect extends Effect {
  final int extra;
  const ExtraAttackEffect(this.extra);
  @override
  Map<String, dynamic> toJson() => {'type': 'extraAttack', 'extra': extra};
}

class BonusMaxHpFlatEffect extends Effect {
  final int amount;
  const BonusMaxHpFlatEffect(this.amount);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'bonusMaxHpFlat', 'amount': amount};
}

/// PG máximos adicionales por nivel de personaje (p.ej. dote Robustez).
class BonusMaxHpPerLevelEffect extends Effect {
  final int perLevel;
  const BonusMaxHpPerLevelEffect(this.perLevel);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'bonusMaxHpPerLevel', 'perLevel': perLevel};
}

/// Bonus plano a la Clase de Armadura (p.ej. estilo de combate Defensa).
/// (El condicionamiento "solo con armadura" es un refinamiento futuro; por
/// ahora se aplica de forma plana.)
class ArmorClassBonusEffect extends Effect {
  final int amount;
  const ArmorClassBonusEffect(this.amount);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'armorClassBonus', 'amount': amount};
}

/// Plantilla de un recurso consumible (Segundo Aliento, Oleada de Acción).
class ResourceEffect extends Effect {
  final String id;
  final String name;
  final int max;
  final RechargeOn recharge;
  const ResourceEffect({
    required this.id,
    required this.name,
    required this.max,
    required this.recharge,
  });
  @override
  Map<String, dynamic> toJson() => {
        'type': 'resource',
        'id': id,
        'name': name,
        'max': max,
        'recharge': _rechargeToJson(recharge),
      };
}
