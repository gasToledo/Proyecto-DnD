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
          proficiencyMultiplier: json['proficiencyMultiplier'] as int? ?? 1,
        ),
      'offHandAbilityDamage' => const OffHandAbilityDamageEffect(),
      'featureChoice' => FeatureChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String,
          featCategory:
              json['featCategory'] as String? ?? json['groupId'] as String,
          count: json['count'] as int? ?? 1,
          replaceable: json['replaceable'] as bool? ?? false,
        ),
      'grantSpell' => GrantSpellEffect(
          spellId: json['spellId'] as String,
          ability: Ability.fromKey(json['ability'] as String),
          use: InnateSpellUse.fromJson(json['use'] as String?),
          replaceableFrom: (json['replaceableFrom'] as List? ?? const [])
              .whereType<String>()
              .toList(),
        ),
      'alwaysPreparedSpell' => AlwaysPreparedSpellEffect(
          spellId: json['spellId'] as String,
        ),
      'spellListAddition' => SpellListAdditionEffect(
          spellId: json['spellId'] as String,
        ),
      'proficiencyChoice' => ProficiencyChoiceEffect(
          groupId: json['groupId'] as String?,
          name: json['name'] as String?,
          count: json['count'] as int? ?? 1,
          includeSkills: json['includeSkills'] as bool? ?? true,
          skills: (json['skills'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          includeTools: json['includeTools'] as bool? ?? false,
          tools: (json['tools'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          replaceable: json['replaceable'] as bool? ?? false,
          fallbackFor: json['fallbackFor'] as String?,
          expertise: json['expertise'] as bool? ?? false,
          allowNewProficiency: json['allowNewProficiency'] as bool? ?? false,
        ),
      'spellChoice' => SpellChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String? ?? '',
          count: json['count'] as int? ?? 1,
          minLevel: json['minLevel'] as int? ?? 0,
          maxLevel: json['maxLevel'] as int?,
          maxLevelFromSlots: json['maxLevelFromSlots'] as bool? ?? false,
          fromClasses: (json['fromClasses'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          schools: (json['schools'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          castingTimes: (json['castingTimes'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          freeCast: json['freeCast'] == null
              ? null
              : InnateSpellUse.fromJson(json['freeCast'] as String?),
          replaceable: json['replaceable'] as bool? ?? false,
        ),
      'leveled' => LeveledEffect(
          minLevel: json['minLevel'] as int,
          effects: Effect.listFromJson(json['effects']),
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
/// especie, dotes). La característica declarada sirve como valor por defecto;
/// el compilador puede reemplazarla por la elegida para la especie.
///
/// Si [use] es `oncePerLongRest`, el compilador además crea el recurso que
/// registra ese uso gratuito, para que la ficha lo muestre y lo gaste como
/// cualquier otro.
class GrantSpellEffect extends Effect {
  final String spellId;
  final Ability ability;
  final InnateSpellUse use;

  /// Clases de cuyas listas se puede **reemplazar** este truco tras un descanso
  /// largo. Vacío —el caso normal— significa que el conjuro es fijo.
  ///
  /// Es el mecanismo del Alto Elfo ("conocés Prestidigitación; al terminar un
  /// descanso largo podés cambiarlo por otro truco de la lista de Mago") y del
  /// Don Feérico del Khoravar, que puede cambiarlo por uno de **tres** listas
  /// —Clérigo, Druida o Mago— y por eso esto es una lista y no un solo id.
  ///
  /// Se declara por id de clase y no enumerando conjuros para que agregar
  /// contenido no toque el motor: las opciones salen de `spellsForList`, la
  /// misma consulta que usa la magia de clase.
  ///
  /// El reemplazo elegido vive en `Character.innateCantripChoices`, no acá:
  /// esto es contenido y aquello es la elección del jugador.
  final List<String> replaceableFrom;

  const GrantSpellEffect({
    required this.spellId,
    required this.ability,
    this.use = InnateSpellUse.atWill,
    this.replaceableFrom = const [],
  });
  @override
  Map<String, dynamic> toJson() => {
        'type': 'grantSpell',
        'spellId': spellId,
        'ability': ability.name,
        'use': use.toJson(),
        'replaceableFrom': replaceableFrom,
      };
}

/// Un conjuro que el personaje **siempre tiene preparado** por un rasgo: los
/// Conjuros de Juramento del Paladín, los de subclase del Artífice.
///
/// No es lo mismo que [GrantSpellEffect], y por eso son dos efectos. Un conjuro
/// innato se lanza sin gastar espacio, con su propia CD y un límite de usos
/// propio. Este se lanza **con los espacios normales de la clase**, como
/// cualquier conjuro preparado; lo único que cambia es que no ocupa un cupo de
/// `preparedCount` y no se puede desmarcar.
class AlwaysPreparedSpellEffect extends Effect {
  final String spellId;
  const AlwaysPreparedSpellEffect({required this.spellId});
  @override
  Map<String, dynamic> toJson() => {
        'type': 'alwaysPreparedSpell',
        'spellId': spellId,
      };
}

/// Un conjuro que se **suma a la lista** de la que el personaje elige: los
/// Conjuros de la Marca de las dotes de marca dracónica.
///
/// Es el tercero y más débil de los efectos de conjuro, y por eso no alcanzaba
/// con los otros dos. [GrantSpellEffect] lo hace lanzable sin espacio;
/// [AlwaysPreparedSpellEffect] lo deja preparado sin ocupar cupo. Este **no
/// concede nada**: solo habilita a elegirlo, gastando el cupo normal, como si
/// figurara en la lista de la clase desde el principio.
///
/// Si el personaje no lanza conjuros, no hace nada, que es justo lo que dice la
/// regla ("si tenés Lanzamiento de Conjuros o Magia de Pacto…").
class SpellListAdditionEffect extends Effect {
  final String spellId;
  const SpellListAdditionEffect({required this.spellId});
  @override
  Map<String, dynamic> toJson() => {
        'type': 'spellListAddition',
        'spellId': spellId,
      };
}

/// Declara "elegí [count] competencias": Habilidoso (tres, entre habilidades y
/// herramientas) y Mente Aguda (una, entre cinco habilidades).
///
/// Es un **marcador**, igual que [FeatureChoiceEffect]: el [SheetBuilder] lo
/// acumula pero no aplica nada. La elección la resuelve la UI y la escribe en
/// `Character.chosenProficiencies`; el compilador la aplica por separado.
///
/// No se mezcla con el `skillChoiceCount` de especie y clase a propósito. Esa
/// elección es fija —siempre las mismas para un personaje— mientras que esta
/// aparece y desaparece con la dote, y además puede caer sobre una herramienta,
/// que `Character.chosenSkills` no sabe representar.
class ProficiencyChoiceEffect extends Effect {
  final String? groupId;
  final String? name;

  /// Cuántas competencias concede.
  final int count;
  final bool includeSkills;

  /// Habilidades elegibles. **Vacío significa todas**, misma convención que
  /// `skillChoiceFrom` en especie y clase.
  final List<String> skills;

  /// Si además se puede elegir cualquier herramienta. Habilidoso dice
  /// "habilidades o herramientas"; Mente Aguda, solo habilidades.
  final bool includeTools;
  final List<String> tools;
  final bool replaceable;
  final String? fallbackFor;

  /// La elección concede **Pericia** (bonificador por competencia duplicado) en
  /// vez de competencia: Pericia del Pícaro y del Bardo, Académico del Mago,
  /// Explorador Hábil del Explorador.
  ///
  /// Cambia de dónde salen las opciones: solo las habilidades en las que ya sos
  /// competente, porque Pericia se apoya sobre una competencia que ya tenés.
  /// Por eso el compilador la resuelve en una segunda pasada, después de las
  /// competencias, y por eso los slots viajan en una lista aparte de
  /// [ComputedSheet]. Con [expertise] se ignoran [includeTools] y [tools]: la
  /// Pericia es siempre sobre una habilidad.
  final bool expertise;

  /// Variante "competencia, **o** Pericia si ya eras competente" (Mente Aguda).
  /// Las opciones no se filtran a lo que ya tenés, y una habilidad sin
  /// competencia concede competencia normal en vez de Pericia.
  final bool allowNewProficiency;

  const ProficiencyChoiceEffect({
    this.groupId,
    this.name,
    required this.count,
    this.includeSkills = true,
    this.skills = const [],
    this.includeTools = false,
    this.tools = const [],
    this.replaceable = false,
    this.fallbackFor,
    this.expertise = false,
    this.allowNewProficiency = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'proficiencyChoice',
        if (groupId != null) 'groupId': groupId,
        if (name != null) 'name': name,
        'count': count,
        'includeSkills': includeSkills,
        'skills': skills,
        'includeTools': includeTools,
        'tools': tools,
        'replaceable': replaceable,
        if (fallbackFor != null) 'fallbackFor': fallbackFor,
        if (expertise) 'expertise': true,
        if (allowNewProficiency) 'allowNewProficiency': true,
      };
}

/// Declara una elección abierta: "elegí [count] opciones del catálogo
/// [featCategory]". Estilo de Combate e Invocaciones Sobrenaturales son el mismo
/// problema y se resuelven con este efecto.
///
/// Es un **marcador**, igual que [GrantFeatEffect] sin `featId`: el
/// [SheetBuilder] lo acumula pero no aplica nada. La UI resuelve la elección y
/// la escribe en `Character.featureChoices`; los efectos de las opciones
/// elegidas los aplica el compilador por separado.
///
/// Va dentro de un rasgo de clase, así hereda el nivel de `featuresUpTo` en vez
/// de necesitar un campo aparte. [count] es el total **acumulado** a ese nivel,
/// no el incremento: se declara un efecto por cada nivel en que la cantidad
/// crece y gana el mayor, misma convención que [ResourceEffect] (los tramos de
/// Furia) y [WeaponMasterySlotsEffect].
///
/// Agregar un catálogo nuevo es agregar dotes con la categoría que nombra
/// [featCategory]: ni el motor ni la aplicación llevan lista de ids.
class FeatureChoiceEffect extends Effect {
  /// Identificador del grupo, la clave con la que se guarda la elección.
  final String groupId;

  /// Rótulo para la UI ("Estilo de Combate", "Invocaciones Sobrenaturales").
  final String name;

  /// Categoría de [Feat] que provee las opciones. Suele coincidir con
  /// [groupId], y en ese caso el JSON puede omitirla.
  final String featCategory;

  /// Cantidad total de opciones a este nivel.
  final int count;

  /// Si al subir de nivel se puede cambiar una elección ya hecha.
  final bool replaceable;

  const FeatureChoiceEffect({
    required this.groupId,
    required this.name,
    required this.featCategory,
    this.count = 1,
    this.replaceable = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'featureChoice',
        'groupId': groupId,
        'name': name,
        'featCategory': featCategory,
        'count': count,
        'replaceable': replaceable,
      };
}

/// Declara "elegí [count] conjuros de un pozo filtrado; quedan **siempre
/// preparados**". Conjuros Característicos y Maestría sobre Conjuros del Mago,
/// Descubrimientos Mágicos del Colegio del Conocimiento.
///
/// Es un **marcador**, igual que [ProficiencyChoiceEffect]: el [SheetBuilder]
/// no aplica nada. Lo resuelve el compilador, que es quien tiene el repositorio
/// para filtrar el pozo y el bloque de lanzamiento para saber hasta qué nivel
/// llega. La elección del jugador vive en `Character.spellChoices`.
///
/// Lo elegido se vuelca en `ComputedSheet.alwaysPreparedSpellIds`, que es el
/// punto único por el que el resto del sistema deja de cobrarle cupo de
/// preparados: a partir de ahí nada distingue esto de un conjuro que el
/// contenido concedió con [AlwaysPreparedSpellEffect].
///
/// Dos diferencias con [FeatureChoiceEffect] que conviene tener presentes:
///
/// - **[groupId] es obligatorio y un efecto declara un cupo.** Aquel funde por
///   grupo quedándose con el mayor `count`; [ProficiencyChoiceEffect] suma.
///   Acá ninguna de las dos: cuando la elección crece por tramos se declara
///   **otro grupo**, con el nivel en el id, que es la convención que ya usa la
///   Pericia (`class:bard:expertise-2` y `-9`). Dos efectos con el mismo
///   [groupId] producirían dos cupos leyendo la misma lista guardada.
/// - **[fromClasses] son ids de clase, no de conjuro**, por la misma razón que
///   [GrantSpellEffect.replaceableFrom]: agregar contenido no puede tocar el
///   motor. El pozo sale de la misma consulta que usa la magia de clase.
class SpellChoiceEffect extends Effect {
  /// Identificador del grupo, la clave con la que se guarda la elección.
  final String groupId;

  /// Rótulo para la UI. Vacío significa "usá el nombre del rasgo".
  final String name;

  /// Cuántos conjuros concede.
  final int count;

  /// Nivel mínimo elegible. 0 incluye trucos.
  final int minLevel;

  /// Techo propio del rasgo (Conjuros Característicos: nivel 3 y solo 3).
  /// `null` significa que el rasgo no impone uno.
  final int? maxLevel;

  /// Además, techo por los espacios que el personaje tenga. Es la forma de
  /// "trucos o conjuros para los que tengas espacios" de Descubrimientos
  /// Mágicos, que sube sola al subir de nivel.
  final bool maxLevelFromSlots;

  /// Listas de clase de las que se puede elegir. **Vacío significa todas**,
  /// misma convención que [ProficiencyChoiceEffect.skills].
  final List<String> fromClasses;

  /// Escuelas elegibles. Vacío significa todas.
  final List<String> schools;

  /// Tiempos de lanzamiento elegibles, por coincidencia **exacta**. Maestría
  /// sobre Conjuros pide "tiempo de lanzamiento de una acción", y comparar por
  /// subcadena metería "Acción Adicional".
  ///
  /// Es el filtro más frágil de los cuatro, porque `Spell.castingTime` es texto
  /// libre: un homebrew que escriba el valor distinto queda fuera del pozo en
  /// silencio. Se acepta porque la alternativa —ofrecer conjuros que la regla
  /// prohíbe— es peor, y porque el contenido oficial usa un puñado de valores
  /// que un test vigila.
  final List<String> castingTimes;

  /// Si además se puede lanzar sin gastar espacio, y con qué frecuencia.
  /// `null` es el caso normal: solo queda siempre preparado.
  final InnateSpellUse? freeCast;

  /// Si una elección ya hecha se puede cambiar más adelante.
  final bool replaceable;

  const SpellChoiceEffect({
    required this.groupId,
    this.name = '',
    this.count = 1,
    this.minLevel = 0,
    this.maxLevel,
    this.maxLevelFromSlots = false,
    this.fromClasses = const [],
    this.schools = const [],
    this.castingTimes = const [],
    this.freeCast,
    this.replaceable = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'spellChoice',
        'groupId': groupId,
        if (name.isNotEmpty) 'name': name,
        'count': count,
        'minLevel': minLevel,
        if (maxLevel != null) 'maxLevel': maxLevel,
        if (maxLevelFromSlots) 'maxLevelFromSlots': true,
        'fromClasses': fromClasses,
        'schools': schools,
        'castingTimes': castingTimes,
        if (freeCast != null) 'freeCast': freeCast!.toJson(),
        'replaceable': replaceable,
      };
}

/// Envuelve efectos que **solo aplican a partir de [minLevel]**.
///
/// Existe porque una dote se aplica entera y sin nivel, mientras que un rasgo de
/// clase o subclase hereda el suyo de `featuresUpTo`. Cuando un catálogo de
/// [FeatureChoiceEffect] tiene que crecer por tramos —la tabla de conjuros del
/// Círculo de la Tierra escalona 3/5/7/9 y su resistencia llega a 10— la dote
/// necesita declarar ese nivel por su cuenta.
///
/// **Lo expande [CharacterCompiler] en `applySource`, no [SheetBuilder]**, y la
/// diferencia importa. El compilador guarda la lista de efectos de cada fuente
/// para las pasadas que resuelven competencias, Pericia y elección de conjuros,
/// y esas pasadas hacen `whereType<...>()` sobre ella. Si el desenvuelto viviera
/// en el builder, la lista guardada conservaría el envoltorio y una elección
/// escalonada por nivel sería **invisible** para ellas: un defecto que entraría
/// en verde. Expandir antes de repartir es la única forma de que todas vean lo
/// mismo.
///
/// [minLevel] es nivel de **personaje**, no de clase. Hoy son el mismo número
/// —cada personaje usa una sola clase— y un futuro multiclase tendrá que
/// revisarlo, igual que `featuresUpTo`.
class LeveledEffect extends Effect {
  final int minLevel;
  final List<Effect> effects;

  const LeveledEffect({required this.minLevel, required this.effects});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'leveled',
        'minLevel': minLevel,
        'effects': [for (final e in effects) e.toJson()],
      };
}

/// El ataque de mano secundaria suma el modificador de característica al daño.
///
/// Por la regla 2024 ese modificador se omite cuando es **positivo**; este
/// efecto lo devuelve. Hoy solo lo concede el estilo Combate con Dos Armas,
/// pero el motor no pregunta por esa dote: pregunta por el efecto, así un
/// homebrew puede conceder lo mismo sin tocar código.
class OffHandAbilityDamageEffect extends Effect {
  const OffHandAbilityDamageEffect();
  @override
  Map<String, dynamic> toJson() => {'type': 'offHandAbilityDamage'};
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

/// PG máximos adicionales por nivel de personaje (p.ej. dote Duro).
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
/// ([maxPerLevel] = true, p.ej. Puntos de Enfoque del Monje = nivel de Monje),
/// escalar con un modificador de característica ([maxFromAbility], p.ej.
/// Magia de Manitas del Artífice = mod. de Inteligencia) o escalar con el
/// bonificador por competencia ([maxFromProficiency], p.ej. Linaje gigante del
/// Goliat y Ataque de aliento del Dracónido).
///
/// Cómo entra [max] en cada caso:
/// - con [maxPerLevel] es el término constante y **se suma** al nivel, para
///   pozos del tipo "1 + nivel de Brujo" (Luz Sanadora del Patrón Celestial);
///   con `max: 0` queda el nivel pelado, que es el caso del Monje y el
///   Hechicero;
/// - con [maxFromAbility] es el piso (normalmente 1, "mínimo una vez");
/// - con [maxFromProficiency] se ignora, porque el bonificador nunca baja de 2.
///   Ahí el que escala es [proficiencyMultiplier], para "dos veces tu
///   bonificador por competencia" (Energía Psiónica del Guerrero Psiónico y de
///   la Cuchilla Espiritual).
///
/// Para recursos con tramos por nivel (p.ej. Furia del Bárbaro: 2/3/4/5/6) se
/// declaran varios ResourceEffect con el mismo [id] a distintos niveles: el de
/// mayor nivel aplicable sobrescribe a los previos. Eso depende de que los
/// rasgos lleguen ordenados por nivel, que es lo que garantiza
/// `featuresUpToLevel`.
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

  /// Factor sobre el bonificador por competencia. Solo se lee cuando
  /// [maxFromProficiency] es true.
  final int proficiencyMultiplier;

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
    this.proficiencyMultiplier = 1,
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
        if (proficiencyMultiplier != 1)
          'proficiencyMultiplier': proficiencyMultiplier,
      };
}
