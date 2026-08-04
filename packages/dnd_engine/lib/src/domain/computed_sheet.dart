import 'ability.dart';
import 'effects.dart';
import 'spell_slots.dart';

/// Rasgo pasivo mostrado en la ficha.
class PassiveTrait {
  final String name;
  final String description;
  const PassiveTrait(this.name, [this.description = '']);

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

/// Recurso consumible con su máximo y cómo se recarga.
class CharacterResource {
  final String id;
  final String name;
  final int max;
  final RechargeOn recharge;
  final int shortRestRecovery;
  final String description;
  const CharacterResource({
    required this.id,
    required this.name,
    required this.max,
    required this.recharge,
    this.shortRestRecovery = 0,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'max': max,
        'recharge': recharge.name,
        'shortRestRecovery': shortRestRecovery,
        'description': description,
      };
}

/// Conjuro concedido por un rasgo (linaje, dote), por fuera de la magia de
/// clase. Trae su propia CD y bono de ataque porque se lanza con la
/// característica que fija el rasgo, que puede no ser la de la clase.
class InnateSpell {
  final String spellId;
  final String name;
  final int level;
  final Ability ability;
  final InnateSpellUse use;
  final int saveDc;
  final int attackBonus;

  /// Rasgo que lo concede, para mostrarlo en la ficha (p.ej. "Alto Elfo").
  final String source;

  const InnateSpell({
    required this.spellId,
    required this.name,
    required this.level,
    required this.ability,
    required this.use,
    required this.saveDc,
    required this.attackBonus,
    this.source = '',
  });

  bool get isCantrip => level == 0;

  Map<String, dynamic> toJson() => {
        'spellId': spellId,
        'name': name,
        'level': level,
        'ability': ability.name,
        'use': use.toJson(),
        'saveDc': saveDc,
        'attackBonus': attackBonus,
        'source': source,
      };
}

/// Una elección abierta que el personaje tiene que resolver, ya resuelta a su
/// cantidad final para el nivel actual.
///
/// Es el contrato entre el motor y la aplicación: la UI pregunta a la ficha
/// compilada qué falta elegir en vez de recorrer los rasgos de la clase por su
/// cuenta, así el nivel al que se concede cada elección vive solo en el
/// contenido.
/// Una elección de competencia pendiente, con sus opciones ya resueltas: la
/// ficha entrega ids concretos y la UI no vuelve a interpretar "vacío = todas".
class ProficiencyChoiceSlot {
  /// Dote que la concede. Habilidoso es repetible, así que puede repetirse.
  final String featId;
  final String featName;

  /// Cuántas competencias concede esta dote.
  final int count;

  /// Habilidades elegibles, ya expandidas.
  final List<String> skills;

  /// Herramientas elegibles, ya expandidas (vacío si la dote no las admite).
  final List<String> tools;

  const ProficiencyChoiceSlot({
    required this.featId,
    required this.featName,
    required this.count,
    required this.skills,
    required this.tools,
  });

  /// Todo lo elegible, en el orden en que se muestra.
  List<String> get options => [...skills, ...tools];
}

class FeatureChoiceSlot {
  final String groupId;
  final String name;

  /// Categoría de dote de la que salen las opciones.
  final String featCategory;

  /// Cuántas se pueden tener a este nivel.
  final int count;

  /// Si se puede cambiar una elección ya hecha al subir de nivel.
  final bool replaceable;

  const FeatureChoiceSlot({
    required this.groupId,
    required this.name,
    required this.featCategory,
    required this.count,
    required this.replaceable,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'featCategory': featCategory,
        'count': count,
        'replaceable': replaceable,
      };
}

/// Qué economía de acción consume un ataque.
///
/// La resuelve el motor y no la ficha: derivarla en la UI de `offHand` y la
/// maestría sería reimplementar la regla fuera del motor.
enum AttackAction {
  action,
  bonusAction;

  static AttackAction fromJson(String? v) =>
      v == 'bonusAction' ? AttackAction.bonusAction : AttackAction.action;

  String toJson() => name;
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

  /// Si el arma está empuñada en la mano secundaria.
  final bool offHand;

  /// Acción que consume. El ataque de mano secundaria es acción adicional,
  /// salvo que el arma aplique la maestría Mellar (Nick), que lo mete dentro
  /// de la acción de Atacar.
  final AttackAction action;

  const Attack({
    required this.weaponId,
    required this.name,
    required this.attackBonus,
    required this.damage,
    required this.damageType,
    this.mastery,
    this.offHand = false,
    this.action = AttackAction.action,
  });

  Map<String, dynamic> toJson() => {
        'weaponId': weaponId,
        'name': name,
        'attackBonus': attackBonus,
        'damage': damage,
        'damageType': damageType,
        'mastery': mastery,
        'offHand': offHand,
        'action': action.toJson(),
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
        'slotsByLevel': {
          for (final e in slotsByLevel.entries) '${e.key}': e.value
        },
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

  /// Tamaño ya resuelto: el elegido por el personaje si la especie ofrece la
  /// elección, y si no el de la especie. La UI lee esto y nunca `Race.size`,
  /// que para Humano, Tiefling y Aasimar es solo el valor por defecto.
  final String size;

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

  /// Conjuros concedidos por rasgos (linajes, dotes), fuera de la magia de clase.
  final List<InnateSpell> innateSpells;

  /// Conjuros que un rasgo mantiene **siempre preparados** (los de subclase del
  /// Artífice, los Conjuros de Juramento del Paladín).
  ///
  /// A diferencia de [innateSpells], se lanzan con los espacios normales de la
  /// clase: lo único que los distingue de un preparado común es que no ocupan
  /// cupo y no se pueden desmarcar. Van por id, igual que `Character.spellIds`;
  /// el nombre lo resuelve quien tenga el catálogo.
  final Set<String> alwaysPreparedSpellIds;

  /// Conjuros que un rasgo **suma a la lista** de la que el personaje elige
  /// (los Conjuros de la Marca de las dotes de marca dracónica).
  ///
  /// No están concedidos: elegirlos gasta el cupo normal, igual que cualquier
  /// conjuro de la lista de clase. Es el contrato con la aplicación, que
  /// pregunta a la ficha en vez de recorrer las dotes por su cuenta.
  final Set<String> spellListAdditionIds;

  /// Elecciones abiertas del personaje a este nivel (Estilo de Combate,
  /// Invocaciones Sobrenaturales…), con su cantidad ya resuelta.
  final List<FeatureChoiceSlot> featureChoiceSlots;

  /// Competencias que el personaje todavía tiene que elegir por una dote
  /// (Habilidoso, Mente Aguda), con sus opciones ya resueltas.
  ///
  /// Es el contrato con la aplicación: pregunta a la ficha cuántas faltan y de
  /// qué lista salen, en vez de recorrer las dotes por su cuenta.
  final List<ProficiencyChoiceSlot> proficiencyChoiceSlots;

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
    this.size = 'Mediano',
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
    this.innateSpells = const [],
    this.alwaysPreparedSpellIds = const {},
    this.spellListAdditionIds = const {},
    this.featureChoiceSlots = const [],
    this.proficiencyChoiceSlots = const [],
    this.spellcasting,
  });

  /// Tirada de salvación total para [a] (mod + competencia si aplica).
  int savingThrow(Ability a) =>
      abilityModifiers[a]! +
      (savingThrowProficiencies.contains(a) ? proficiencyBonus : 0);
}
