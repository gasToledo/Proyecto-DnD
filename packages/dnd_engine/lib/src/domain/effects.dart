import 'ability.dart';
import 'spell_slots.dart';

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
      'weaponMasterySlots' => WeaponMasterySlotsEffect(json['count'] as int),
      'extraAttack' => ExtraAttackEffect(json['extra'] as int),
      'bonusMaxHpFlat' => BonusMaxHpFlatEffect(json['amount'] as int),
      'bonusMaxHpPerLevel' => BonusMaxHpPerLevelEffect(json['perLevel'] as int),
      'armorClassBonus' => ArmorClassBonusEffect(json['amount'] as int),
      'unarmoredDefense' => UnarmoredDefenseEffect(
          Ability.fromKey(json['ability'] as String),
          allowShield: json['allowShield'] as bool? ?? false,
        ),
      'unarmoredMovement' => UnarmoredMovementEffect(
          json['feet'] as int,
          allowShield: json['allowShield'] as bool? ?? false,
          heavyArmorOnly: json['heavyArmorOnly'] as bool? ?? false,
        ),
      'spellcasting' => SpellcastingEffect(
          ability: Ability.fromKey(json['ability'] as String),
          progression:
              CasterProgression.fromJson(json['progression'] as String?),
          preparation:
              SpellPreparation.fromJson(json['preparation'] as String?),
          spellList: json['spellList'] as String,
          cantripsKnown: json['cantripsKnown'] as int? ?? 0,
          cantripIncreases: (json['cantripIncreases'] as List?)
              ?.map((e) => e as int)
              .toList(),
        ),
      'resource' => ResourceEffect(
          id: json['id'] as String,
          name: json['name'] as String,
          max: json['max'] as int? ?? 0,
          recharge: _rechargeFromJson(json['recharge'] as String?),
          shortRestRecovery: json['shortRestRecovery'] as int? ?? 0,
          description: json['description'] as String? ?? '',
          maxPerLevel: json['maxPerLevel'] as bool? ?? false,
          maxFromAbility: json['maxFromAbility'] != null
              ? Ability.fromKey(json['maxFromAbility'] as String)
              : null,
          maxFromProficiency: json['maxFromProficiency'] as bool? ?? false,
        ),
      'grantSpell' => GrantSpellEffect(
          spellId: json['spellId'] as String,
          ability: Ability.fromKey(json['ability'] as String),
          use: InnateSpellUse.fromJson(json['use'] as String?),
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

/// Competencia con armadura: 'light' | 'medium' | 'heavy' | 'shield'.
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

/// Concede un conjuro concreto por fuera de la magia de clase (linajes de
/// especie, dotes). La característica de lanzamiento la fija el contenido: los
/// linajes 2024 dejan elegirla, pero eso todavía no se modela.
///
/// Si [use] es `oncePerLongRest`, el compilador además crea el recurso que
/// registra ese uso gratuito, para que la ficha lo muestre y lo gaste como
/// cualquier otro.
class GrantSpellEffect extends Effect {
  final String spellId;
  final Ability ability;
  final InnateSpellUse use;
  const GrantSpellEffect({
    required this.spellId,
    required this.ability,
    this.use = InnateSpellUse.atWill,
  });
  @override
  Map<String, dynamic> toJson() => {
        'type': 'grantSpell',
        'spellId': spellId,
        'ability': ability.name,
        'use': use.toJson(),
      };
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
  Map<String, dynamic> toJson() => {'type': 'bonusMaxHpFlat', 'amount': amount};
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

/// Defensa sin Armadura: cuando no se lleva armadura, la CA base pasa a ser
/// 10 + mod. de Destreza + mod. de [ability]. El Bárbaro usa Constitución y el
/// Monje Sabiduría. Si hay armadura equipada, este efecto se ignora.
///
/// [allowShield]: el Bárbaro conserva la Defensa sin Armadura con escudo; el
/// Monje la pierde si empuña un escudo (regla 2024).
class UnarmoredDefenseEffect extends Effect {
  final Ability ability;
  final bool allowShield;
  const UnarmoredDefenseEffect(this.ability, {this.allowShield = false});
  @override
  Map<String, dynamic> toJson() => {
        'type': 'unarmoredDefense',
        'ability': ability.name,
        'allowShield': allowShield,
      };
}

/// Movimiento sin Armadura: aumenta la velocidad en [feet] pies, pero **solo
/// mientras no se lleve armadura** (el Monje también lo pierde con escudo). Se
/// acumula con otros del mismo tipo (Monje: +10/+15/+20 por nivel).
///
/// [allowShield]: si un escudo no anula el bono (Bárbaro sí lo permite; Monje no).
/// [heavyArmorOnly]: si solo la armadura **pesada** lo anula (Movimiento Rápido
/// del Bárbaro), en vez de cualquier armadura (Monje).
class UnarmoredMovementEffect extends Effect {
  final int feet;
  final bool allowShield;
  final bool heavyArmorOnly;
  const UnarmoredMovementEffect(
    this.feet, {
    this.allowShield = false,
    this.heavyArmorOnly = false,
  });
  @override
  Map<String, dynamic> toJson() => {
        'type': 'unarmoredMovement',
        'feet': feet,
        'allowShield': allowShield,
        'heavyArmorOnly': heavyArmorOnly,
      };
}

/// Concede lanzamiento de conjuros: característica de lanzamiento, progresión de
/// espacios, forma de obtención (preparados/conocidos) y de qué lista de clase
/// se nutre. La CD y el bono de ataque de conjuro se derivan en la ficha.
class SpellcastingEffect extends Effect {
  final Ability ability;
  final CasterProgression progression;
  final SpellPreparation preparation;

  /// Id de la lista de conjuros de la que se nutre (p.ej. 'wizard').
  final String spellList;

  /// Trucos conocidos a nivel 1 (por simplicidad, valor base; el escalado por
  /// nivel puede refinarse luego con efectos gated).
  final int cantripsKnown;

  /// Niveles de personaje en los que se gana un truco adicional. `null`
  /// conserva el escalado por defecto (+1 a nivel 4 y +1 a nivel 10 para
  /// lanzadores completos y semi-lanzadores con trucos; +1 a nivel 10 para
  /// `third`), que es el que usan las 8 clases y 2 subclases existentes. El
  /// Artífice, con trucos a niveles 1/10/14, es el primer caso que necesita
  /// una progresión propia.
  final List<int>? cantripIncreases;

  const SpellcastingEffect({
    required this.ability,
    required this.progression,
    required this.preparation,
    required this.spellList,
    this.cantripsKnown = 0,
    this.cantripIncreases,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'spellcasting',
        'ability': ability.name,
        'progression': progression.toJson(),
        'preparation': preparation.toJson(),
        'spellList': spellList,
        'cantripsKnown': cantripsKnown,
        if (cantripIncreases != null) 'cantripIncreases': cantripIncreases,
      };
}

/// Plantilla de un recurso consumible (Segundo Aliento, Oleada de Acción).
///
/// El máximo puede ser fijo ([max]), escalar con el nivel de personaje
/// ([maxPerLevel] = true, p.ej. Puntos de Enfoque del Monje = nivel de Monje)
/// escalar con un modificador de característica ([maxFromAbility], p.ej.
/// Magia de Manitas del Artífice = mod. de Inteligencia) o escalar con el
/// bonificador por competencia ([maxFromProficiency], p.ej. Linaje gigante del
/// Goliat y Ataque de aliento del Dracónido). Con [maxFromAbility] el [max] es
/// el piso (normalmente 1, "mínimo una vez"); con [maxFromProficiency] se
/// ignora, porque el bonificador nunca baja de 2.
/// Para recursos con tramos por nivel (p.ej. Furia del Bárbaro: 2/3/4/5/6) se
/// declaran varios ResourceEffect con el mismo [id] a distintos niveles: el de
/// mayor nivel aplicable sobrescribe a los previos.
class ResourceEffect extends Effect {
  final String id;
  final String name;
  final int max;
  final RechargeOn recharge;
  final int shortRestRecovery;
  final String description;
  final bool maxPerLevel;
  final Ability? maxFromAbility;
  final bool maxFromProficiency;
  const ResourceEffect({
    required this.id,
    required this.name,
    required this.max,
    required this.recharge,
    this.shortRestRecovery = 0,
    this.description = '',
    this.maxPerLevel = false,
    this.maxFromAbility,
    this.maxFromProficiency = false,
  });
  @override
  Map<String, dynamic> toJson() => {
        'type': 'resource',
        'id': id,
        'name': name,
        'max': max,
        'recharge': _rechargeToJson(recharge),
        if (shortRestRecovery > 0) 'shortRestRecovery': shortRestRecovery,
        'description': description,
        'maxPerLevel': maxPerLevel,
        if (maxFromAbility != null) 'maxFromAbility': maxFromAbility!.name,
        if (maxFromProficiency) 'maxFromProficiency': true,
      };
}
