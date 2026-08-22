import 'ability.dart';
import 'content_source.dart';
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
      'setAbilityScore' => SetAbilityScoreEffect(
          ability: Ability.fromKey(json['ability'] as String),
          score: json['score'] as int,
        ),
      'savingThrowBonus' => SavingThrowBonusEffect(json['amount'] as int),
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
      'companion' => CompanionEffect(
          id: json['id'] as String,
          name: json['name'] as String,
          creatureIds: (json['creatureIds'] as List? ?? const [])
              .map((e) => e as String)
              .toList(),
          maxActive: json['maxActive'] as int? ?? 1,
          requiresSpell: json['requiresSpell'] as String?,
        ),
      'wildShapeForms' => WildShapeFormsEffect(
          count: json['count'] as int,
          maxCr: json['maxCr'] as num,
          allowFly: json['allowFly'] as bool? ?? false,
        ),
      'castWhileWildShaped' => const CastWhileWildShapedEffect(),
      'offHandAbilityDamage' => const OffHandAbilityDamageEffect(),
      'heroicInspirationOnLongRest' =>
        const HeroicInspirationOnLongRestEffect(),
      'targetChoice' => TargetChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String? ?? '',
          count: json['count'] as int? ?? 1,
          replaceable: json['replaceable'] as bool? ?? false,
          existingFilter: json.containsKey('existingFilter')
              ? WeaponFilter.fromJson(
                  (json['existingFilter'] as Map?)?.cast<String, dynamic>(),
                )
              : null,
          createFilter: json.containsKey('createFilter')
              ? WeaponFilter.fromJson(
                  (json['createFilter'] as Map?)?.cast<String, dynamic>(),
                )
              : null,
        ),
      'weaponRule' => WeaponRuleEffect(
          targetGroupId: json['targetGroupId'] as String?,
          filter: WeaponFilter.fromJson(
            (json['filter'] as Map?)?.cast<String, dynamic>(),
          ),
          grantsProficiency: json['grantsProficiency'] as bool? ?? false,
          abilityOptions: (json['abilityOptions'] as List? ?? const [])
              .map((e) => Ability.fromKey(e as String))
              .toList(),
          damageTypeOptions: (json['damageTypeOptions'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          spellcastingFocus: json['spellcastingFocus'] as bool? ?? false,
          extraAttacks: json['extraAttacks'] as int? ?? 0,
        ),
      'featureChoice' => FeatureChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String,
          featCategory:
              json['featCategory'] as String? ?? json['groupId'] as String,
          count: json['count'] as int? ?? 1,
          replaceable: json['replaceable'] as bool? ?? false,
          options: (json['options'] as List? ?? const [])
              .map((e) => FeatureOption.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      'itemChoice' => ItemChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String,
          countByLevel: (json['countByLevel'] as Map? ?? const {})
              .map((k, v) => MapEntry(int.parse(k as String), v as int)),
          options: (json['options'] as List? ?? const [])
              .map((e) =>
                  ItemChoiceOption.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
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
      'prepareSpellListAdditions' => const PrepareSpellListAdditionsEffect(),
      'abilityScoreBonusFromFeatChoice' =>
        AbilityScoreBonusFromFeatChoiceEffect(
          featCategory: json['featCategory'] as String,
          amount: json['amount'] as int? ?? 1,
        ),
      'skillBonus' => SkillBonusEffect(
          skill: json['skill'] as String,
          fromAbility: Ability.fromKey(json['fromAbility'] as String),
          minimum: json['minimum'] as int? ?? 0,
        ),
      'language' => LanguageEffect(json['language'] as String),
      'languageChoice' => LanguageChoiceEffect(
          groupId: json['groupId'] as String,
          name: json['name'] as String? ?? '',
          count: json['count'] as int? ?? 1,
          standardOnly: json['standardOnly'] as bool? ?? false,
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
          ritualOnly: json['ritualOnly'] as bool? ?? false,
          countFromProficiency: json['countFromProficiency'] as bool? ?? false,
          ability: json['ability'] == null
              ? null
              : Ability.fromKey(json['ability'] as String),
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

class ItemChoiceOption {
  final String itemId;
  final int minLevel;
  const ItemChoiceOption({required this.itemId, this.minLevel = 1});

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        if (minLevel != 1) 'minLevel': minLevel,
      };

  factory ItemChoiceOption.fromJson(Map<String, dynamic> json) =>
      ItemChoiceOption(
        itemId: json['itemId'] as String,
        minLevel: json['minLevel'] as int? ?? 1,
      );
}

/// Elección de planos: conocer una opción no aplica los efectos del objeto.
class ItemChoiceEffect extends Effect {
  final String groupId;
  final String name;
  final Map<int, int> countByLevel;
  final List<ItemChoiceOption> options;
  final bool replaceable;

  const ItemChoiceEffect({
    required this.groupId,
    required this.name,
    required this.countByLevel,
    this.options = const [],
    this.replaceable = false,
  });

  int countAt(int level) {
    var result = 0;
    for (final entry in countByLevel.entries) {
      if (entry.key <= level && entry.value > result) result = entry.value;
    }
    return result;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'itemChoice',
        'groupId': groupId,
        'name': name,
        'countByLevel': {
          for (final e in countByLevel.entries) '${e.key}': e.value
        },
        'options': options.map((e) => e.toJson()).toList(),
        if (replaceable) 'replaceable': true,
      };
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

/// Fija un mínimo de puntuación mientras la fuente está activa.
class SetAbilityScoreEffect extends Effect {
  final Ability ability;
  final int score;
  const SetAbilityScoreEffect({required this.ability, required this.score});
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'setAbilityScore', 'ability': ability.name, 'score': score};
}

/// Bono plano a todas las salvaciones (Anillo/Capa de Protección).
class SavingThrowBonusEffect extends Effect {
  final int amount;
  const SavingThrowBonusEffect(this.amount);
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'savingThrowBonus', 'amount': amount};
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
  /// [groupId], y en ese caso el JSON puede omitirla. Se ignora cuando el
  /// efecto trae [options] propias.
  final String featCategory;

  /// Cantidad total de opciones a este nivel.
  final int count;

  /// Si al subir de nivel se puede cambiar una elección ya hecha.
  final bool replaceable;

  /// Opciones declaradas por el propio rasgo, para las elecciones de clase que
  /// **no** son dotes: Orden Primordial del Druida y Orden Divina del Clérigo.
  /// Vacío es el caso normal y las opciones salen de [featCategory].
  final List<FeatureOption> options;

  const FeatureChoiceEffect({
    required this.groupId,
    required this.name,
    required this.featCategory,
    this.count = 1,
    this.replaceable = false,
    this.options = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'featureChoice',
        'groupId': groupId,
        'name': name,
        'featCategory': featCategory,
        'count': count,
        'replaceable': replaceable,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
      };
}

/// Una de las opciones en línea de un [FeatureChoiceEffect].
///
/// Es deliberadamente más chica que `Feat`: no tiene categoría, ni
/// prerrequisito, ni es repetible. Una orden de clase no se toma en el nivel 4
/// ni compite con las dotes, así que meterla en el catálogo de dotes la
/// mostraría donde no corresponde y movería sus conteos.
class FeatureOption {
  final String id;
  final String name;
  final String description;
  final ContentSource source;
  final List<Effect> effects;

  const FeatureOption({
    required this.id,
    required this.name,
    required this.source,
    this.description = '',
    this.effects = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        if (description.isNotEmpty) 'description': description,
        'effects': effects.map((e) => e.toJson()).toList(),
      };

  factory FeatureOption.fromJson(Map<String, dynamic> json) => FeatureOption(
        id: json['id'] as String,
        name: json['name'] as String,
        source: ContentSource.fromJson(json['source'] as String?),
        description: json['description'] as String? ?? '',
        effects: Effect.listFromJson(json['effects']),
      );
}

/// Deja **siempre preparados** los conjuros que otros rasgos hayan sumado a la
/// lista elegible. Marca Dracónica Potente: "tenés siempre preparados los
/// conjuros de tu lista de Conjuros de la Marca, si la tenés".
///
/// Se resuelve al final, cuando ya se aplicaron todos los rasgos: la dote no
/// sabe qué marca tiene el personaje ni tiene por qué saberlo.
class PrepareSpellListAdditionsEffect extends Effect {
  const PrepareSpellListAdditionsEffect();
  @override
  Map<String, dynamic> toJson() => {'type': 'prepareSpellListAdditions'};
}

/// Suma [amount] a la característica que el personaje eligió como aptitud
/// mágica de una dote de [featCategory].
///
/// Marca Dracónica Potente sube "la característica de lanzamiento que usa tu
/// dote de marca", y esa característica la eligió el jugador al tomar la marca
/// (vive en `Character.featSpellcastingAbilities`). Sin esto habría que partir
/// la dote en una variante por característica, que movería el conteo del
/// catálogo y ofrecería combinaciones que la regla no permite.
class AbilityScoreBonusFromFeatChoiceEffect extends Effect {
  final String featCategory;
  final int amount;

  const AbilityScoreBonusFromFeatChoiceEffect({
    required this.featCategory,
    this.amount = 1,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'abilityScoreBonusFromFeatChoice',
        'featCategory': featCategory,
        'amount': amount,
      };
}

/// Suma un bonificador a las pruebas de una habilidad concreta, tomado del
/// modificador de otra característica y con un piso.
///
/// Existe por Orden Divina (Taumaturgo) y Orden Primordial (Naturalista):
/// "un bonificador igual a tu modificador por Sabiduría (mínimo de +1)" a
/// Inteligencia (Conocimiento arcano) y otra habilidad. No es competencia ni
/// Pericia —no escala con el bonificador por competencia y no habilita nada—,
/// así que no se puede modelar con [SkillProficiencyEffect].
class SkillBonusEffect extends Effect {
  final String skill;

  /// De qué característica sale el bonificador.
  final Ability fromAbility;

  /// Piso del bonificador. El SRD dice "mínimo de +1".
  final int minimum;

  const SkillBonusEffect({
    required this.skill,
    required this.fromAbility,
    this.minimum = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'skillBonus',
        'skill': skill,
        'fromAbility': fromAbility.name,
        'minimum': minimum,
      };
}

/// Concede un idioma concreto: el Druídico del Druida, la Jerga de Ladrones
/// del Pícaro.
///
/// Es el único camino por el que se obtiene un idioma **inusual**: los dos que
/// elige el jugador salen de la tabla de estándar y viven en
/// `Character.languages`. Un id que el catálogo no conoce se conserva igual
/// —el homebrew puede inventar idiomas— y se muestra capitalizado.
class LanguageEffect extends Effect {
  final String language;
  const LanguageEffect(this.language);
  @override
  Map<String, dynamic> toJson() => {'type': 'language', 'language': language};
}

/// Declara "elegí [count] idiomas": la Jerga de Ladrones del Pícaro concede el
/// suyo **y otro a elección** de las tablas de idiomas.
///
/// Es un **marcador**, como [SpellChoiceEffect]: lo resuelve el compilador,
/// que es quien sabe qué idiomas ya tiene el personaje para no ofrecerlos dos
/// veces. La elección vive en `Character.languageChoices`.
class LanguageChoiceEffect extends Effect {
  /// Clave con la que se guarda la elección.
  final String groupId;

  /// Rótulo para la UI. Vacío significa "usá el nombre del rasgo".
  final String name;

  final int count;

  /// Si el pozo se limita a la tabla de estándar. El Pícaro dice "de las
  /// tablas" —en plural— así que puede tomar uno inusual; un rasgo que diga
  /// "un idioma estándar" declara esto en true.
  final bool standardOnly;

  const LanguageChoiceEffect({
    required this.groupId,
    this.name = '',
    this.count = 1,
    this.standardOnly = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'languageChoice',
        'groupId': groupId,
        if (name.isNotEmpty) 'name': name,
        'count': count,
        'standardOnly': standardOnly,
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

  /// Restringe el pozo a los conjuros con la etiqueta Ritual. Lanzador Ritual
  /// es el único caso: "una cantidad de conjuros de nivel 1 con la etiqueta
  /// Ritual igual a tu bonificador por competencia".
  final bool ritualOnly;

  /// El cupo es el bonificador por competencia en vez de [count]. Lo usa
  /// Lanzador Ritual, cuyo pozo crece solo con el nivel en vez de declarar un
  /// grupo por tramo.
  final bool countFromProficiency;

  /// Característica del lanzamiento gratuito cuando el contenido la fija.
  /// La Marca Dracónica Aberrante usa Constitución; sin esto caería en la de
  /// la clase, que para un Guerrero no existe. `null` deja que mande la
  /// elegida por el personaje y, si tampoco hay, la de la clase.
  final Ability? ability;

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
    this.ritualOnly = false,
    this.countFromProficiency = false,
    this.ability,
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
        if (ritualOnly) 'ritualOnly': true,
        if (countFromProficiency) 'countFromProficiency': true,
        if (ability != null) 'ability': ability!.name,
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

/// El personaje obtiene Inspiración Heroica al terminar un descanso largo
/// (rasgo Ingenioso del Humano).
///
/// **No es un [ResourceEffect] a propósito.** Como recurso se renderizaría
/// solo y el descanso ya lo recargaría, pero un recurso declarado por el
/// Humano dejaría al elfo sin poder tenerla nunca — y la Inspiración Heroica
/// se la concede el DM a quien quiera. Por eso el estado vive en
/// `CombatState.heroicInspiration` y esto solo declara *quién la gana solo*.
///
/// ponytail: el Guerrero Heroico del Campeón la gana al empezar su turno y la
/// dote Músico se la reparte a los aliados tras un descanso. Ninguno de los dos
/// entra por acá, porque su disparador no es el descanso largo del propio
/// personaje; siguen siendo texto de rasgo hasta que ese disparador exista.
class HeroicInspirationOnLongRestEffect extends Effect {
  const HeroicInspirationOnLongRestEffect();
  @override
  Map<String, dynamic> toJson() => {'type': 'heroicInspirationOnLongRest'};
}

/// Filtro serializable para reglas que modifican ataques con armas.
///
/// No resuelve inventario ni consulta catálogos: es solo la parte declarativa.
/// [CharacterCompiler] lo cruza con cada arma equipada. Los campos nulos o las
/// listas vacías significan "sin restricción", de modo que el mismo mecanismo
/// sirve tanto para todas las armas mágicas como para una familia concreta.
class WeaponFilter {
  final bool? magic;
  final bool? melee;
  final List<String> categories;
  final List<String> properties;

  const WeaponFilter({
    this.magic,
    this.melee,
    this.categories = const [],
    this.properties = const [],
  });

  bool get isEmpty =>
      magic == null &&
      melee == null &&
      categories.isEmpty &&
      properties.isEmpty;

  Map<String, dynamic> toJson() => {
        if (magic != null) 'magic': magic,
        if (melee != null) 'melee': melee,
        if (categories.isNotEmpty) 'categories': categories,
        if (properties.isNotEmpty) 'properties': properties,
      };

  factory WeaponFilter.fromJson(Map<String, dynamic>? json) => WeaponFilter(
        magic: json?['magic'] as bool?,
        melee: json?['melee'] as bool?,
        categories: (json?['categories'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        properties: (json?['properties'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );
}

/// Elección de ejemplares de arma para que otras reglas puedan apuntarlos.
///
/// El efecto no conoce inventario ni clases. Declara dos vías independientes:
/// [existingFilter] permite vincular un ejemplar que el personaje ya lleva y
/// [createFilter] permite crear uno desde el catálogo de armas. `null` impide
/// esa vía; un filtro vacío permite cualquier arma.
class TargetChoiceEffect extends Effect {
  final String groupId;
  final String name;
  final int count;
  final bool replaceable;
  final WeaponFilter? existingFilter;
  final WeaponFilter? createFilter;

  const TargetChoiceEffect({
    required this.groupId,
    required this.name,
    this.count = 1,
    this.replaceable = false,
    this.existingFilter,
    this.createFilter,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'targetChoice',
        'groupId': groupId,
        'name': name,
        'count': count,
        if (replaceable) 'replaceable': true,
        if (existingFilter != null) 'existingFilter': existingFilter!.toJson(),
        if (createFilter != null) 'createFilter': createFilter!.toJson(),
      };
}

/// Modificadores que una fuente aplica a los ataques de armas que coincidan.
///
/// Es deliberadamente una regla de **arma**, no de clase: el Herrero de
/// Batalla puede ofrecer Inteligencia para toda arma mágica, mientras que una
/// regla con [targetGroupId] puede quedar limitada al ejemplar elegido por un
/// vínculo. El motor nunca necesita preguntar qué clase o dote la concedió.
class WeaponRuleEffect extends Effect {
  /// Grupo de objetivo dinámico. Null aplica la regla solo por [filter].
  final String? targetGroupId;
  final WeaponFilter filter;
  final bool grantsProficiency;
  final List<Ability> abilityOptions;
  final List<String> damageTypeOptions;
  final bool spellcastingFocus;

  /// Ataques adicionales permitidos con el arma. Como Ataque Adicional, no se
  /// acumulan entre fuentes: al resolver gana el mayor.
  final int extraAttacks;

  const WeaponRuleEffect({
    this.targetGroupId,
    this.filter = const WeaponFilter(),
    this.grantsProficiency = false,
    this.abilityOptions = const [],
    this.damageTypeOptions = const [],
    this.spellcastingFocus = false,
    this.extraAttacks = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'weaponRule',
        if (targetGroupId != null) 'targetGroupId': targetGroupId,
        if (!filter.isEmpty) 'filter': filter.toJson(),
        if (grantsProficiency) 'grantsProficiency': true,
        if (abilityOptions.isNotEmpty)
          'abilityOptions': abilityOptions.map((a) => a.name).toList(),
        if (damageTypeOptions.isNotEmpty)
          'damageTypeOptions': damageTypeOptions,
        if (spellcastingFocus) 'spellcastingFocus': true,
        if (extraAttacks != 0) 'extraAttacks': extraAttacks,
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

/// Concede un compañero invocable: el Cañón Arcano, el Defensor de Acero, un
/// familiar, un corcel.
///
/// Es el **único** punto donde se cablea una criatura a un personaje; el
/// catálogo de `creatures.json` son perfiles puros que no saben quién los
/// invoca.
///
/// Varios rasgos pueden declarar el mismo [id] para hacerlo crecer: el
/// Artillero lo hace a nivel 3, a nivel 9 (el cañón pasa a ser el Explosivo) y
/// a nivel 15 (dos a la vez). **Gana la declaración de mayor nivel**, igual que
/// con [ResourceEffect], así que cada una tiene que traer el cuadro completo y
/// no solo lo que cambia.
class CompanionEffect extends Effect {
  /// Id estable de la opción, no de la criatura: es lo que ata una instancia
  /// guardada en la ficha con el rasgo que la concede.
  final String id;

  /// Rótulo para la UI ("Cañón Arcano", "Familiar").
  final String name;

  /// Formas elegibles. Una sola para el cañón o el defensor; veinticuatro para
  /// el familiar, que elige forma al invocarlo.
  final List<String> creatureIds;

  final int maxActive;

  /// El compañero solo existe si el personaje tiene este conjuro (Encontrar
  /// Familiar, Hallar Corcel). Null = lo concede el rasgo por sí solo.
  final String? requiresSpell;

  const CompanionEffect({
    required this.id,
    required this.name,
    required this.creatureIds,
    this.maxActive = 1,
    this.requiresSpell,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'companion',
        'id': id,
        'name': name,
        'creatureIds': creatureIds,
        'maxActive': maxActive,
        if (requiresSpell != null) 'requiresSpell': requiresSpell,
      };
}

/// Formas de Forma Salvaje que el druida puede tener anotadas, y el pozo del
/// que salen.
///
/// A diferencia de [CompanionEffect], no nombra criaturas: las formas legales
/// son *todas* las bestias del catálogo que entren en el filtro, y son
/// sesenta y pico. Enumerarlas en el contenido sería copiar el catálogo dentro
/// de la clase y tener que tocar el Druida cada vez que se suma una bestia.
///
/// La tabla del Druida sube las tres cosas a la vez a niveles 2, 4 y 8, así que
/// **gana la declaración de mayor nivel** —igual que [ResourceEffect] y
/// [CompanionEffect]— y cada una trae el cuadro completo.
class WildShapeFormsEffect extends Effect {
  /// Cuántas formas puede tener anotadas a la vez.
  final int count;

  /// Valor de desafío máximo de una forma (`0.25`, `0.5`, `1`).
  final num maxCr;

  /// Si se admiten bestias con velocidad de vuelo (recién a nivel 8).
  final bool allowFly;

  const WildShapeFormsEffect({
    required this.count,
    required this.maxCr,
    this.allowFly = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'wildShapeForms',
        'count': count,
        'maxCr': maxCr,
        'allowFly': allowFly,
      };
}

/// Levanta la prohibición de lanzar conjuros en Forma Salvaje (Conjurar como
/// Bestia, nivel 18 del Druida).
///
/// Es un efecto y no un `if (nivel >= 18)` en la pantalla: el nivel al que se
/// concede cada cosa vive en el contenido, y un número de regla escrito en Dart
/// es el que después nadie encuentra cuando la regla cambia.
class CastWhileWildShapedEffect extends Effect {
  const CastWhileWildShapedEffect();

  @override
  Map<String, dynamic> toJson() => {'type': 'castWhileWildShaped'};
}
