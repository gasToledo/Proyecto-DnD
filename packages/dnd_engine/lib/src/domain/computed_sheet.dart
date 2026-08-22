import 'ability.dart';
import 'creature.dart';
import 'effects.dart';
import 'skill.dart';
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

/// Compañero que el personaje puede invocar, con sus formas ya resueltas
/// contra el catálogo.
///
/// Las fórmulas de cada [Creature] **no** están evaluadas: el Corcel
/// Sobrenatural y el Sirviente Homúnculo dependen del nivel del espacio que se
/// gaste al invocarlos, y eso recién se sabe en la ficha. Quien pinta una
/// instancia llama a `Creature.resolve` con los `CreatureVars` del momento.
class CompanionOption {
  /// Id de la opción (no de la criatura): es lo que ata la instancia guardada
  /// en el personaje con el rasgo que la concede.
  final String id;
  final String name;

  /// Rasgo o dote que lo concedió, para mostrar de dónde sale.
  final String source;

  final List<Creature> forms;
  final int maxActive;

  /// Conjuro que hay que lanzar para invocarlo, o null si lo concede un rasgo
  /// por sí solo (el Cañón Arcano, el Defensor de Acero). Es lo que decide si
  /// invocarlo gasta un espacio y si arranca una concentración.
  final String? spellId;

  /// Nivel mínimo del espacio con que se lo puede invocar: el del conjuro que
  /// lo concede, o 0 si no depende de ninguno.
  ///
  /// Sin esto, las fórmulas que cuentan niveles *por encima* del suyo dan
  /// basura: un Espíritu infernal invocado con un espacio de nivel 1 sale con
  /// `50 + 15×(1−6)` = −25 puntos de golpe.
  final int minSpellLevel;

  const CompanionOption({
    required this.id,
    required this.name,
    required this.source,
    required this.forms,
    this.maxActive = 1,
    this.spellId,
    this.minSpellLevel = 0,
  });

  /// Invocarlo gasta un espacio de conjuro y sus números dependen del nivel.
  /// Alcanza con mirar la primera forma: un compañero no mezcla formas que
  /// escalan con formas que no.
  bool get scalesWithSpellLevel =>
      forms.isNotEmpty && forms.first.scalesWithSpellLevel;

  /// La forma que usa una instancia ya invocada.
  ///
  /// Si el id no está entre las formas **y el compañero tiene una sola**, se
  /// devuelve esa: es el caso del Artillero que sube a nivel 9 con el cañón en
  /// el suelo y pasa a tener el Cañón Explosivo. El compañero creció, no
  /// desapareció, y obligarlo a despedirlo y volver a invocarlo sería castigar
  /// al jugador por subir de nivel a mitad de combate.
  ///
  /// Con varias formas no se adivina: si un familiar apunta a una bestia que
  /// el catálogo ya no tiene, elegir otra por él sería inventarle la criatura.
  Creature? form(String creatureId) {
    for (final f in forms) {
      if (f.id == creatureId) return f;
    }
    return forms.length == 1 ? forms.single : null;
  }
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

  /// Conjuro que declara el contenido, cuando [spellId] es un reemplazo
  /// elegido. Igual a [spellId] mientras no se haya cambiado nada.
  ///
  /// Es la clave de `Character.innateCantripChoices`: la UI la necesita para
  /// guardar o deshacer el cambio, porque el mapa se indexa por el conjuro
  /// original y no por el que se está lanzando.
  final String grantedSpellId;

  /// Clases de cuyas listas se puede reemplazar este truco tras un descanso
  /// largo; vacío si es fijo. Es el contrato con la aplicación: pregunta a la
  /// ficha en vez de mirar los efectos del linaje por su cuenta.
  final List<String> replaceableFrom;

  const InnateSpell({
    required this.spellId,
    required this.name,
    required this.level,
    required this.ability,
    required this.use,
    required this.saveDc,
    required this.attackBonus,
    this.source = '',
    String? grantedSpellId,
    this.replaceableFrom = const [],
  }) : grantedSpellId = grantedSpellId ?? spellId;

  bool get isCantrip => level == 0;

  /// Si el jugador puede cambiarlo tras un descanso largo.
  bool get isReplaceable => replaceableFrom.isNotEmpty;

  /// Si lo que se lanza no es lo que declara el contenido.
  bool get isReplaced => spellId != grantedSpellId;

  Map<String, dynamic> toJson() => {
        'spellId': spellId,
        'name': name,
        'level': level,
        'ability': ability.name,
        'use': use.toJson(),
        'saveDc': saveDc,
        'attackBonus': attackBonus,
        'source': source,
        'grantedSpellId': grantedSpellId,
        'replaceableFrom': replaceableFrom,
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
  final String groupId;
  final String name;

  /// Cuántas competencias concede esta dote.
  final int count;

  /// Habilidades elegibles, ya expandidas.
  final List<String> skills;

  /// Herramientas elegibles, ya expandidas (vacío si la dote no las admite).
  final List<String> tools;
  final List<String> chosen;
  final bool replaceable;

  /// Este cupo concede **Pericia**, no competencia. La UI lo necesita para
  /// rotular y, sobre todo, para invertir el bloqueo: en un cupo normal una
  /// habilidad que ya tenés se muestra bloqueada, y acá es al revés, porque ser
  /// competente es el requisito para poder elegirla.
  final bool expertise;

  const ProficiencyChoiceSlot({
    required this.groupId,
    required this.name,
    required this.count,
    required this.skills,
    required this.tools,
    this.chosen = const [],
    this.replaceable = false,
    this.expertise = false,
  });

  /// Todo lo elegible, en el orden en que se muestra.
  List<String> get options => [...skills, ...tools];

  int get pending => (count - chosen.length).clamp(0, count);

  String get featId {
    if (!groupId.startsWith('feat:')) return groupId;
    final value = groupId.substring(5);
    final proficiency = value.indexOf(':proficiency');
    final base = proficiency < 0 ? value : value.substring(0, proficiency);
    final occurrence = base.lastIndexOf(':');
    if (occurrence < 0) return base;
    final suffix = base.substring(occurrence + 1);
    return int.tryParse(suffix) == null ? base : base.substring(0, occurrence);
  }

  String get featName => name;
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

  /// Opciones que trae el propio rasgo. Cuando no está vacío reemplaza a
  /// [featCategory] como pozo: son elecciones de clase que no son dotes.
  final List<FeatureOption> options;

  const FeatureChoiceSlot({
    required this.groupId,
    required this.name,
    required this.featCategory,
    required this.count,
    required this.replaceable,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'featCategory': featCategory,
        'count': count,
        'replaceable': replaceable,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
      };
}

class ItemChoiceSlot {
  final String groupId;
  final String name;
  final int count;
  final int maxActive;
  final bool replaceable;
  final List<String> optionItemIds;
  final List<String> chosenItemIds;

  const ItemChoiceSlot({
    required this.groupId,
    required this.name,
    required this.count,
    required this.maxActive,
    required this.replaceable,
    this.optionItemIds = const [],
    this.chosenItemIds = const [],
  });

  int get pending => (count - chosenItemIds.length).clamp(0, count);
}

/// Elección resuelta de ejemplares de arma para una regla contextual.
///
/// La UI recibe ids concretos y no reimplementa filtros ni consulta dotes.
class TargetChoiceSlot {
  final String groupId;
  final String name;
  final int count;
  final bool replaceable;
  final List<String> eligibleEntryIds;
  final List<String> creatableWeaponIds;
  final List<String> chosenEntryIds;

  const TargetChoiceSlot({
    required this.groupId,
    required this.name,
    required this.count,
    required this.replaceable,
    this.eligibleEntryIds = const [],
    this.creatableWeaponIds = const [],
    this.chosenEntryIds = const [],
  });

  int get pending => (count - chosenEntryIds.length).clamp(0, count);

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'count': count,
        'replaceable': replaceable,
        'eligibleEntryIds': eligibleEntryIds,
        'creatableWeaponIds': creatableWeaponIds,
        'chosenEntryIds': chosenEntryIds,
      };
}

/// Una elección de idiomas pendiente, con el pozo ya resuelto: lo que el
/// personaje ya sabe por otra vía no se ofrece.
class LanguageChoiceSlot {
  final String groupId;
  final String name;
  final int count;

  /// Idiomas elegibles, ya sin los que el personaje sabe por otra vía.
  final List<String> options;

  /// Lo elegido, ya revalidado contra [options].
  final List<String> chosen;

  const LanguageChoiceSlot({
    required this.groupId,
    required this.name,
    required this.count,
    required this.options,
    this.chosen = const [],
  });

  int get pending => (count - chosen.length).clamp(0, count);

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'count': count,
        'options': options,
        'chosen': chosen,
      };
}

/// Una elección de conjuros pendiente, con el pozo ya filtrado: la ficha
/// entrega ids concretos y la UI no vuelve a interpretar los filtros.
///
/// Lleva la forma autocontenida de [ProficiencyChoiceSlot] —[chosen] y
/// [pending] adentro— y no la declarativa de [FeatureChoiceSlot], porque
/// revalidar la elección contra el pozo es trabajo del compilador y no algo que
/// la UI deba repetir.
class SpellChoiceSlot {
  final String groupId;
  final String name;

  /// Cuántos conjuros concede este cupo.
  final int count;

  /// Conjuros elegibles, ya filtrados por nivel, lista, escuela y tiempo de
  /// lanzamiento, y sin lo que otro rasgo ya concede.
  final List<String> options;

  /// Lo elegido, ya revalidado contra [options]: lo guardado que dejó de
  /// calificar no llega hasta acá.
  final List<String> chosen;

  /// Si una elección ya hecha se puede cambiar más adelante.
  final bool replaceable;

  const SpellChoiceSlot({
    required this.groupId,
    required this.name,
    required this.count,
    required this.options,
    this.chosen = const [],
    this.replaceable = false,
  });

  int get pending => (count - chosen.length).clamp(0, count);

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'count': count,
        'options': options,
        'chosen': chosen,
        'replaceable': replaceable,
      };
}

/// Las formas de Forma Salvaje del druida: el pozo legal a su nivel y las que
/// tiene anotadas.
///
/// Lleva criaturas y no ids, igual que [CompanionOption]: la pantalla que
/// elige una forma muestra su CA, sus PG y su mordisco, y hacerla volver al
/// catálogo por cada una sería mandarla a buscar lo que la ficha ya tiene.
class WildShapeSlot {
  /// Cuántas formas puede tener anotadas.
  final int count;

  /// Bestias elegibles, ya filtradas por valor de desafío y vuelo, ordenadas
  /// por nombre.
  final List<Creature> options;

  /// Las anotadas, ya revalidadas contra [options]: una forma guardada que
  /// dejó de calificar —porque bajó de nivel— no llega hasta acá.
  final List<Creature> chosen;

  /// Puede lanzar conjuros transformado. Falso hasta nivel 18, y lo declara el
  /// contenido: acá no hay ningún número de nivel escrito.
  final bool canCast;

  const WildShapeSlot({
    required this.count,
    required this.options,
    this.chosen = const [],
    this.canCast = false,
  });

  int get pending => (count - chosen.length).clamp(0, count);
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
  final String baseWeaponId;
  final String? sourceEntryId;
  final String name;
  final int attackBonus;
  final bool proficient;
  final Ability abilityUsed;

  /// Cadena de daño lista para mostrar, p.ej. "1d8 + 3".
  final String damage;
  final String damageType;
  final List<String> damageTypeOptions;

  /// Puede usarse como canalizador mientras esta regla de arma esté activa.
  final bool spellcastingFocus;

  /// Ataques permitidos con esta arma al realizar la acción de Atacar. Puede
  /// diferir del valor global cuando una regla está limitada a un objetivo.
  final int attacksPerAction;

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
    String? baseWeaponId,
    this.sourceEntryId,
    required this.name,
    required this.attackBonus,
    this.proficient = false,
    this.abilityUsed = Ability.strength,
    required this.damage,
    required this.damageType,
    List<String>? damageTypeOptions,
    this.spellcastingFocus = false,
    this.attacksPerAction = 1,
    this.mastery,
    this.offHand = false,
    this.action = AttackAction.action,
  })  : baseWeaponId = baseWeaponId ?? weaponId,
        damageTypeOptions = damageTypeOptions ?? const [];

  /// Copia con los campos indicados reemplazados.
  ///
  /// Existe para que las capas que se aplican **sobre** la ficha ya calculada
  /// —la Forma Salvaje, el Cansancio— no tengan que reconstruir los quince
  /// campos a mano. Reconstruir a mano es como se perdieron campos antes.
  Attack copyWith({
    String? weaponId,
    String? baseWeaponId,
    Object? sourceEntryId = _unset,
    String? name,
    int? attackBonus,
    bool? proficient,
    Ability? abilityUsed,
    String? damage,
    String? damageType,
    List<String>? damageTypeOptions,
    bool? spellcastingFocus,
    int? attacksPerAction,
    Object? mastery = _unset,
    bool? offHand,
    AttackAction? action,
  }) =>
      Attack(
        weaponId: weaponId ?? this.weaponId,
        baseWeaponId: baseWeaponId ?? this.baseWeaponId,
        sourceEntryId: identical(sourceEntryId, _unset)
            ? this.sourceEntryId
            : sourceEntryId as String?,
        name: name ?? this.name,
        attackBonus: attackBonus ?? this.attackBonus,
        proficient: proficient ?? this.proficient,
        abilityUsed: abilityUsed ?? this.abilityUsed,
        damage: damage ?? this.damage,
        damageType: damageType ?? this.damageType,
        damageTypeOptions: damageTypeOptions ?? this.damageTypeOptions,
        spellcastingFocus: spellcastingFocus ?? this.spellcastingFocus,
        attacksPerAction: attacksPerAction ?? this.attacksPerAction,
        mastery: identical(mastery, _unset) ? this.mastery : mastery as String?,
        offHand: offHand ?? this.offHand,
        action: action ?? this.action,
      );

  Map<String, dynamic> toJson() => {
        'weaponId': weaponId,
        'baseWeaponId': baseWeaponId,
        if (sourceEntryId != null) 'sourceEntryId': sourceEntryId,
        'name': name,
        'attackBonus': attackBonus,
        'proficient': proficient,
        'abilityUsed': abilityUsed.name,
        'damage': damage,
        'damageType': damageType,
        'damageTypeOptions': damageTypeOptions,
        'spellcastingFocus': spellcastingFocus,
        'attacksPerAction': attacksPerAction,
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

  /// Copia con los campos indicados reemplazados. Ver [Attack.copyWith].
  Spellcasting copyWith({
    Ability? ability,
    CasterProgression? progression,
    SpellPreparation? preparation,
    String? spellList,
    int? saveDc,
    int? attackBonus,
    int? cantripsKnown,
    int? preparedCount,
    Map<int, int>? slotsByLevel,
  }) =>
      Spellcasting(
        ability: ability ?? this.ability,
        progression: progression ?? this.progression,
        preparation: preparation ?? this.preparation,
        spellList: spellList ?? this.spellList,
        saveDc: saveDc ?? this.saveDc,
        attackBonus: attackBonus ?? this.attackBonus,
        cantripsKnown: cantripsKnown ?? this.cantripsKnown,
        preparedCount: preparedCount ?? this.preparedCount,
        slotsByLevel: slotsByLevel ?? this.slotsByLevel,
      );

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

/// Un bonus a una característica junto con **de dónde salió**.
///
/// El total por sí solo no se puede explicar en la mesa: cuando el DM pregunta
/// por qué Inteligencia es 20 y no 18, la respuesta ("+2 del trasfondo") no se
/// puede reconstruir desde el número final. Por eso el acumulador de
/// `SheetBuilder` guarda además cada aporte con su fuente.
class AbilityBonus {
  final Ability ability;
  final int amount;

  /// Nombre legible de la fuente, tal como lo declara el contenido: el nombre
  /// del trasfondo, de la dote, de la especie. No es un id.
  final String source;

  const AbilityBonus({
    required this.ability,
    required this.amount,
    required this.source,
  });
}

/// Un aporte a las pruebas de una habilidad que no es competencia ni Pericia:
/// hoy solo el "+mod. de Sabiduría (mínimo +1)" de Orden Divina y Orden
/// Primordial. Lleva la fuente por el mismo motivo que [AbilityBonus].
class SkillBonus {
  final int amount;
  final String source;
  const SkillBonus({required this.amount, required this.source});
}

/// Centinela para distinguir "no se pasó el argumento" de "se pasó null" en
/// los `copyWith` de este archivo.
///
/// Hace falta de verdad, no es ceremonia: la Forma Salvaje tiene que poder
/// **borrar** la visión en la oscuridad del druida cuando la bestia no la
/// tiene, y sin centinela un `null` explícito sería indistinguible de no haber
/// pasado nada. Mismo recurso que usa `Character.copyWith` para desequipar.
const Object _unset = Object();

/// Resultado **derivado y de solo lectura** de compilar un personaje.
/// La UI de la ficha lee de aquí; nunca recalcula a mano.
class ComputedSheet {
  final int level;
  final int proficiencyBonus;
  final Map<Ability, int> abilityScores;
  final Map<Ability, int> abilityModifiers;

  /// Cada bonus que se sumó a una característica, con su fuente, **en el orden
  /// en que se aplicaron**. Es lo que permite explicar un valor final; el
  /// puntaje asignado en la creación no está acá, se deduce con
  /// [baseAbilityScore].
  final List<AbilityBonus> abilityBonuses;

  /// Modificador situacional que se suma a **toda prueba con d20** —prueba de
  /// característica, salvación, habilidad y tirada de ataque— y a nada más.
  ///
  /// Vive acá y **no descontado de [abilityModifiers]** porque ese mapa además
  /// alimenta el daño, la CD de conjuros, los PG máximos, la CA y la capacidad
  /// de carga, y nada de eso es una tirada. Hoy el único que lo mueve es el
  /// Cansancio (−2 por nivel, ver `applyExhaustion`); es un entero con signo y
  /// no una "penalización" positiva para que sumar sea siempre sumar.
  ///
  /// **Contrato, y es la trampa del doble conteo:** ningún consumidor suma
  /// esto a mano. O llama a un getter de tirada ([abilityCheck],
  /// [savingThrow], [skillModifier], [passivePerception]), que ya lo incluyen,
  /// o lee un entero plano ([initiative], [Attack.attackBonus],
  /// [Spellcasting.attackBonus]) que la capa **ya dejó ajustado**.
  final int d20Modifier;

  /// Si un rasgo le da Inspiración Heroica al terminar un descanso largo
  /// (Ingenioso, del Humano).
  ///
  /// Es solo la declaración de *quién la gana solo*: el estado —si la tiene
  /// ahora mismo— vive en `CombatState.heroicInspiration`, porque cualquier
  /// personaje puede tenerla si el DM se la concede.
  final bool heroicInspirationOnLongRest;

  final Set<Ability> savingThrowProficiencies;
  final int savingThrowBonus;
  final Set<String> skillProficiencies;

  /// Habilidades con **Pericia**: el bonificador por competencia cuenta doble.
  /// Siempre es un subconjunto de [skillProficiencies] — el compilador lo
  /// garantiza, porque la Pericia se elige entre las competencias que ya tenés.
  /// Para leer el modificador de una habilidad no hace falta cruzar los dos
  /// conjuntos a mano: está [skillModifier].
  final Set<String> expertiseSkills;

  /// Aportes extra por habilidad, ya resueltos a número y con su fuente.
  /// [skillModifier] los suma; la ficha los muestra en el desglose.
  final Map<String, List<SkillBonus>> skillBonuses;

  final Set<String> armorProficiencies;
  final Set<String> weaponProficiencies;
  final Set<String> toolProficiencies;

  final int maxHp;
  final int hitDie;
  final int armorClass;

  /// Peso total de la mochila en libras, monedas incluidas.
  ///
  /// Se calcula acá y no en la pantalla porque lo miran dos consumidores —la
  /// ficha y la validación— y dos cuentas separadas se desincronizan.
  final double carriedWeight;

  /// Tamaño ya resuelto: el elegido por el personaje si la especie ofrece la
  /// elección, y si no el de la especie. La UI lee esto y nunca `Race.size`,
  /// que para las especies con `sizeOptions` es solo el valor por defecto.
  final String size;

  final int speed;
  final int initiative;
  final int? darkvision;

  final Set<String> resistances;
  final Set<String> immunities;

  final int weaponMasterySlots;
  final int attacksPerAction;

  final List<Attack> attacks;
  final List<PassiveTrait> passives;
  final List<CharacterResource> resources;

  /// Compañeros invocables a este nivel (Cañón Arcano, Defensor de Acero,
  /// familiar, corcel). Vacío para la enorme mayoría de los personajes.
  final List<CompanionOption> companions;

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
  final List<ItemChoiceSlot> itemChoiceSlots;
  final List<TargetChoiceSlot> targetChoiceSlots;

  /// Competencias que el personaje todavía tiene que elegir por una dote
  /// (Habilidoso, Mente Aguda), con sus opciones ya resueltas.
  ///
  /// Es el contrato con la aplicación: pregunta a la ficha cuántas faltan y de
  /// qué lista salen, en vez de recorrer las dotes por su cuenta.
  final List<ProficiencyChoiceSlot> proficiencyChoiceSlots;

  /// Cupos de **Pericia** pendientes o elegidos, en una lista aparte de
  /// [proficiencyChoiceSlots] a propósito.
  ///
  /// Mezclarlos rompería los consumidores del otro camino: el chequeo de
  /// duplicados de la validación dispararía siempre para una Pericia legal
  /// (la habilidad ya está entre las competencias, que es justamente el
  /// requisito), y la UI bloquea las opciones que ya tenés, que acá son las
  /// únicas elegibles.
  final List<ProficiencyChoiceSlot> expertiseChoiceSlots;

  /// Idiomas que sabe el personaje: Común, los dos elegidos en el origen, los
  /// que conceda un rasgo y los de una elección resuelta, ya unidos y sin
  /// repetir.
  final Set<String> languages;

  /// Idiomas que todavía tiene que elegir por un rasgo (Jerga de Ladrones).
  final List<LanguageChoiceSlot> languageChoiceSlots;

  /// Conjuros que el personaje todavía tiene que elegir por un rasgo, con el
  /// pozo ya filtrado (Conjuros Característicos, Descubrimientos Mágicos).
  ///
  /// Lo ya elegido no queda solo acá: también está en [alwaysPreparedSpellIds],
  /// que es por donde el resto del sistema lo ve.
  final List<SpellChoiceSlot> spellChoiceSlots;

  /// Formas de Forma Salvaje, o null si el personaje no es druida.
  final WildShapeSlot? wildShape;

  /// Bloque de lanzamiento de conjuros, o null si el personaje no lanza.
  final Spellcasting? spellcasting;

  const ComputedSheet({
    required this.level,
    required this.proficiencyBonus,
    required this.abilityScores,
    required this.abilityModifiers,
    this.abilityBonuses = const [],
    this.d20Modifier = 0,
    this.heroicInspirationOnLongRest = false,
    required this.savingThrowProficiencies,
    this.savingThrowBonus = 0,
    required this.skillProficiencies,
    this.expertiseSkills = const {},
    this.skillBonuses = const {},
    required this.armorProficiencies,
    required this.weaponProficiencies,
    required this.toolProficiencies,
    required this.maxHp,
    required this.hitDie,
    required this.armorClass,
    this.carriedWeight = 0,
    this.size = 'Mediano',
    required this.speed,
    required this.initiative,
    required this.darkvision,
    required this.resistances,
    required this.immunities,
    required this.weaponMasterySlots,
    required this.attacksPerAction,
    required this.attacks,
    required this.passives,
    required this.resources,
    this.companions = const [],
    this.innateSpells = const [],
    this.alwaysPreparedSpellIds = const {},
    this.spellListAdditionIds = const {},
    this.featureChoiceSlots = const [],
    this.itemChoiceSlots = const [],
    this.targetChoiceSlots = const [],
    this.proficiencyChoiceSlots = const [],
    this.expertiseChoiceSlots = const [],
    this.spellChoiceSlots = const [],
    this.wildShape,
    this.languages = const {},
    this.languageChoiceSlots = const [],
    this.spellcasting,
  });

  /// Copia con los campos indicados reemplazados.
  ///
  /// Es la herramienta de las capas que se aplican **sobre** la ficha ya
  /// calculada: `applyWildShape` y `applyExhaustion`. Antes cada una
  /// reconstruía el objeto campo por campo, y así fue como la Forma Salvaje
  /// perdió `skillBonuses` y `carriedWeight` sin que nadie se enterara — un
  /// druida transformado se quedaba sin su bono de Orden Primordial y con la
  /// mochila en cero.
  ///
  /// Hay un test que compara los campos de la clase contra los parámetros de
  /// este método: un campo nuevo sin su parámetro acá se perdería en silencio.
  ComputedSheet copyWith({
    int? level,
    int? proficiencyBonus,
    Map<Ability, int>? abilityScores,
    Map<Ability, int>? abilityModifiers,
    List<AbilityBonus>? abilityBonuses,
    int? d20Modifier,
    bool? heroicInspirationOnLongRest,
    Set<Ability>? savingThrowProficiencies,
    int? savingThrowBonus,
    Set<String>? skillProficiencies,
    Set<String>? expertiseSkills,
    Map<String, List<SkillBonus>>? skillBonuses,
    Set<String>? armorProficiencies,
    Set<String>? weaponProficiencies,
    Set<String>? toolProficiencies,
    int? maxHp,
    int? hitDie,
    int? armorClass,
    double? carriedWeight,
    String? size,
    int? speed,
    int? initiative,
    Object? darkvision = _unset,
    Set<String>? resistances,
    Set<String>? immunities,
    int? weaponMasterySlots,
    int? attacksPerAction,
    List<Attack>? attacks,
    List<PassiveTrait>? passives,
    List<CharacterResource>? resources,
    List<CompanionOption>? companions,
    List<InnateSpell>? innateSpells,
    Set<String>? alwaysPreparedSpellIds,
    Set<String>? spellListAdditionIds,
    List<FeatureChoiceSlot>? featureChoiceSlots,
    List<ItemChoiceSlot>? itemChoiceSlots,
    List<TargetChoiceSlot>? targetChoiceSlots,
    List<ProficiencyChoiceSlot>? proficiencyChoiceSlots,
    List<ProficiencyChoiceSlot>? expertiseChoiceSlots,
    List<SpellChoiceSlot>? spellChoiceSlots,
    Object? wildShape = _unset,
    Set<String>? languages,
    List<LanguageChoiceSlot>? languageChoiceSlots,
    Object? spellcasting = _unset,
  }) =>
      ComputedSheet(
        level: level ?? this.level,
        proficiencyBonus: proficiencyBonus ?? this.proficiencyBonus,
        abilityScores: abilityScores ?? this.abilityScores,
        abilityModifiers: abilityModifiers ?? this.abilityModifiers,
        abilityBonuses: abilityBonuses ?? this.abilityBonuses,
        d20Modifier: d20Modifier ?? this.d20Modifier,
        heroicInspirationOnLongRest:
            heroicInspirationOnLongRest ?? this.heroicInspirationOnLongRest,
        savingThrowProficiencies:
            savingThrowProficiencies ?? this.savingThrowProficiencies,
        savingThrowBonus: savingThrowBonus ?? this.savingThrowBonus,
        skillProficiencies: skillProficiencies ?? this.skillProficiencies,
        expertiseSkills: expertiseSkills ?? this.expertiseSkills,
        skillBonuses: skillBonuses ?? this.skillBonuses,
        armorProficiencies: armorProficiencies ?? this.armorProficiencies,
        weaponProficiencies: weaponProficiencies ?? this.weaponProficiencies,
        toolProficiencies: toolProficiencies ?? this.toolProficiencies,
        maxHp: maxHp ?? this.maxHp,
        hitDie: hitDie ?? this.hitDie,
        armorClass: armorClass ?? this.armorClass,
        carriedWeight: carriedWeight ?? this.carriedWeight,
        size: size ?? this.size,
        speed: speed ?? this.speed,
        initiative: initiative ?? this.initiative,
        darkvision: identical(darkvision, _unset)
            ? this.darkvision
            : darkvision as int?,
        resistances: resistances ?? this.resistances,
        immunities: immunities ?? this.immunities,
        weaponMasterySlots: weaponMasterySlots ?? this.weaponMasterySlots,
        attacksPerAction: attacksPerAction ?? this.attacksPerAction,
        attacks: attacks ?? this.attacks,
        passives: passives ?? this.passives,
        resources: resources ?? this.resources,
        companions: companions ?? this.companions,
        innateSpells: innateSpells ?? this.innateSpells,
        alwaysPreparedSpellIds:
            alwaysPreparedSpellIds ?? this.alwaysPreparedSpellIds,
        spellListAdditionIds: spellListAdditionIds ?? this.spellListAdditionIds,
        featureChoiceSlots: featureChoiceSlots ?? this.featureChoiceSlots,
        itemChoiceSlots: itemChoiceSlots ?? this.itemChoiceSlots,
        targetChoiceSlots: targetChoiceSlots ?? this.targetChoiceSlots,
        proficiencyChoiceSlots:
            proficiencyChoiceSlots ?? this.proficiencyChoiceSlots,
        expertiseChoiceSlots: expertiseChoiceSlots ?? this.expertiseChoiceSlots,
        spellChoiceSlots: spellChoiceSlots ?? this.spellChoiceSlots,
        wildShape: identical(wildShape, _unset)
            ? this.wildShape
            : wildShape as WildShapeSlot?,
        languages: languages ?? this.languages,
        languageChoiceSlots: languageChoiceSlots ?? this.languageChoiceSlots,
        spellcasting: identical(spellcasting, _unset)
            ? this.spellcasting
            : spellcasting as Spellcasting?,
      );

  /// Cuánto peso podés llevar: Fuerza × 15 libras (capítulo 1, "Carrying
  /// Capacity"). Getter y no campo guardado: es una multiplicación sobre una
  /// puntuación que ya está acá.
  int get carryingCapacity => (abilityScores[Ability.strength] ?? 10) * 15;

  /// Si la mochila pasa la capacidad. Solo informativo: en 2024 el núcleo no
  /// trae penalizaciones por sobrecarga, así que nada de esto toca la velocidad
  /// ni las tiradas.
  bool get isEncumbered => carriedWeight > carryingCapacity;

  /// Los bonus que recibió [a], en orden de aplicación.
  List<AbilityBonus> bonusesFor(Ability a) => [
        for (final b in abilityBonuses)
          if (b.ability == a) b
      ];

  /// El puntaje **antes** de cualquier bonus: lo que se asignó en la creación.
  /// Se deduce restando en vez de guardarse aparte, así no hay dos fuentes de
  /// verdad que se puedan desincronizar.
  int baseAbilityScore(Ability a) =>
      abilityScores[a]! -
      bonusesFor(a).fold<int>(0, (sum, b) => sum + b.amount);

  /// Prueba de característica: el modificador **más** lo situacional.
  ///
  /// Único lugar donde vive esta suma, por el mismo motivo que
  /// [skillModifier]: la ficha leía `abilityModifiers` directo y una capa que
  /// baje las tiradas no tenía dónde entrar sin ensuciar el daño y la CD.
  int abilityCheck(Ability a) => abilityModifiers[a]! + d20Modifier;

  /// Tirada de salvación total para [a] (mod + competencia si aplica).
  int savingThrow(Ability a) =>
      abilityCheck(a) +
      (savingThrowProficiencies.contains(a) ? proficiencyBonus : 0) +
      savingThrowBonus;

  /// Modificador total de una habilidad: **único lugar donde vive esta suma**.
  /// Antes la hacían a mano la Percepción pasiva y la ficha, cada una por su
  /// lado, y así fue como Pericia no llegó a ninguna de las dos.
  ///
  /// Un id que no está en el catálogo de habilidades devuelve 0 en vez de
  /// reventar: puede venir de contenido homebrew que inventó una habilidad.
  int skillModifier(String skillId) {
    final ability = Skill.fromId(skillId)?.ability;
    if (ability == null) return 0;
    return abilityCheck(ability) +
        (expertiseSkills.contains(skillId)
            ? proficiencyBonus * 2
            : skillProficiencies.contains(skillId)
                ? proficiencyBonus
                : 0) +
        (skillBonuses[skillId] ?? const <SkillBonus>[])
            .fold(0, (sum, b) => sum + b.amount);
  }

  /// Percepción pasiva: 10 + el modificador de Percepción, Pericia incluida.
  int get passivePerception => 10 + skillModifier('perception');
}
