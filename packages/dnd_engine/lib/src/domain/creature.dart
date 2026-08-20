import 'ability.dart';
import 'content_source.dart';
import 'skill.dart';

/// Tipo de criatura del SRD 5.2.1.
///
/// Existe además de [Creature.kind] porque el string de perfil mezcla tipo,
/// tamaño y alineamiento en una sola línea ("Feérico Pequeño (trasgo), caótico
/// neutral") y no se puede filtrar sin parsearlo. El campo estructurado manda
/// cuando está; [fromKind] cubre a las entradas viejas que solo tienen `kind`.
enum CreatureType {
  aberration('aberration', 'Aberración'),
  construct('construct', 'Constructo'),
  beast('beast', 'Bestia'),
  celestial('celestial', 'Celestial'),
  ooze('ooze', 'Cieno'),
  dragon('dragon', 'Dragón'),
  elemental('elemental', 'Elemental'),
  fey('fey', 'Feérico'),
  fiend('fiend', 'Infernal'),
  giant('giant', 'Gigante'),
  humanoid('humanoid', 'Humanoide'),
  monstrosity('monstrosity', 'Monstruosidad'),
  plant('plant', 'Planta'),
  undead('undead', 'Muerto viviente');

  const CreatureType(this.id, this.label);

  /// Id usado por el contenido JSON.
  final String id;

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => id;

  static CreatureType? fromJson(String? v) {
    if (v == null) return null;
    for (final t in CreatureType.values) {
      if (t.id == v) return t;
    }
    return null;
  }

  /// Deduce el tipo del principio de un [Creature.kind] ("Bestia Mediana" →
  /// [beast]), o null si no empieza con ninguno conocido.
  ///
  /// `undead` va primero porque su etiqueta son dos palabras y comparte la
  /// primera con nada más, pero el resto se compara por prefijo y un tipo cuya
  /// etiqueta fuera prefijo de otra se resolvería mal; hoy ninguna lo es.
  static CreatureType? fromKind(String kind) {
    for (final t in CreatureType.values) {
      if (kind.startsWith(t.label)) return t;
    }
    // El catálogo viejo traduce `construct` como «Autómata» en algunas
    // entradas, siguiendo el glosario del SRD en español.
    if (kind.startsWith('Autómata')) return CreatureType.construct;
    return null;
  }
}

/// Tamaño de una criatura.
///
/// [label] es la forma masculina, que es la que usa la ficha del personaje.
/// [fromKind] reconoce además la femenina porque el perfil concuerda con el
/// tipo ("Bestia Mediana" pero "Gigante Grande").
enum CreatureSize {
  tiny('tiny', 'Diminuto', 'Diminuta'),
  small('small', 'Pequeño', 'Pequeña'),
  medium('medium', 'Mediano', 'Mediana'),
  large('large', 'Grande', 'Grande'),
  huge('huge', 'Enorme', 'Enorme'),
  gargantuan('gargantuan', 'Gargantuesco', 'Gargantuesca');

  const CreatureSize(this.id, this.label, this.feminineLabel);

  final String id;
  final String label;
  final String feminineLabel;

  String toJson() => id;

  static CreatureSize? fromJson(String? v) {
    if (v == null) return null;
    for (final s in CreatureSize.values) {
      if (s.id == v) return s;
    }
    return null;
  }

  /// Busca el tamaño en cualquier posición de un [Creature.kind]. No se toma la
  /// última palabra: eso funciona para "Bestia Mediana" pero no para "Gigante
  /// Grande, caótico malvado", donde el tamaño queda en el medio.
  static CreatureSize? fromKind(String kind) {
    for (final s in CreatureSize.values) {
      if (kind.contains(s.label) || kind.contains(s.feminineLabel)) return s;
    }
    return null;
  }
}

/// Valores del personaje que las fórmulas de una criatura pueden leer.
///
/// Un compañero no tiene estadísticas propias en el sentido habitual: casi
/// todas salen de quien lo invoca ("CA 12 + tu modificador por Inteligencia",
/// "PG 5 + cinco veces tu nivel"). Esta bolsa es el único contrato entre la
/// ficha y el catálogo de criaturas.
class CreatureVars {
  final Map<String, int> values;

  const CreatureVars(this.values);

  /// Arma la bolsa desde la ficha ya compilada. [spellLevel] es el nivel del
  /// espacio gastado al invocar (0 = la criatura no escala con conjuros).
  factory CreatureVars.from({
    required int level,
    required int proficiencyBonus,
    required Map<Ability, int> abilityModifiers,
    int spellAttackBonus = 0,
    int spellSaveDc = 0,
    int spellLevel = 0,
  }) =>
      CreatureVars({
        'level': level,
        'PB': proficiencyBonus,
        for (final a in Ability.values) a.abbr: abilityModifiers[a] ?? 0,
        'SPELLATK': spellAttackBonus,
        'SPELLDC': spellSaveDc,
        'spellLevel': spellLevel,
      });

  int? operator [](String name) => values[name];
}

/// Error de una fórmula mal escrita en el contenido. No se degrada en silencio:
/// una CA que se evalúa a basura es peor que una que no carga, y
/// `content_integrity_test.dart` la caza antes de que llegue a una ficha.
class CreatureFormulaException implements Exception {
  final String formula;
  final String reason;

  const CreatureFormulaException(this.formula, this.reason);

  @override
  String toString() => 'Fórmula de criatura inválida "$formula": $reason';
}

/// Resuelve los tramos `{...}` de una plantilla y deja el resto literal.
///
/// Es lo que permite que `"1d8+{2+INT}"` conviva con `"{5+5*level}"` sin
/// inventar un lenguaje de dados: adentro de las llaves hay aritmética de
/// enteros, afuera hay texto que se copia tal cual.
String resolveCreatureFormula(String template, CreatureVars vars) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final open = template.indexOf('{', i);
    if (open < 0) {
      buffer.write(template.substring(i));
      break;
    }
    final close = template.indexOf('}', open);
    if (close < 0) {
      throw CreatureFormulaException(template, 'falta cerrar una llave');
    }
    buffer.write(template.substring(i, open));
    buffer.write(_eval(template.substring(open + 1, close), vars, template));
    i = close + 1;
  }
  return buffer.toString();
}

/// Evalúa un campo que **tiene que** dar un entero: CA, PG, bono de ataque.
///
/// Acá no hay llaves ni texto alrededor — la expresión es todo el campo, así
/// que se escribe `"12+INT"` y no `"{12+INT}"`. Es a propósito: con la sintaxis
/// de llaves, un `"12+{INT}"` deja el `12+` afuera como texto y da "12+4" en
/// vez de 16, un error que se lee bien y calcula mal.
int resolveCreatureInt(String expr, CreatureVars vars) =>
    _eval(expr, vars, expr);

/// Evaluador de la aritmética de adentro de las llaves: enteros, `+ - * /`,
/// paréntesis y los nombres de [CreatureVars]. Precedencia normal, y la
/// división redondea hacia abajo porque así redondea 5e.
int _eval(String expr, CreatureVars vars, String source) {
  final tokens = _tokenize(expr, source);
  var pos = 0;

  // Declarada antes de `primary` porque los paréntesis la vuelven recursiva:
  // `primary` la llama y ella termina llamando a `primary`.
  late final int Function() expression;

  int primary() {
    if (pos >= tokens.length) {
      throw CreatureFormulaException(source, 'expresión incompleta');
    }
    final t = tokens[pos++];
    if (t == '(') {
      final value = expression();
      if (pos >= tokens.length || tokens[pos] != ')') {
        throw CreatureFormulaException(source, 'falta cerrar un paréntesis');
      }
      pos++;
      return value;
    }
    // Un signo delante de un número o variable: "{-1+INT}".
    if (t == '-') return -primary();
    if (t == '+') return primary();
    final literal = int.tryParse(t);
    if (literal != null) return literal;
    final value = vars[t];
    if (value == null) {
      throw CreatureFormulaException(source, 'variable desconocida "$t"');
    }
    return value;
  }

  int term() {
    var value = primary();
    while (pos < tokens.length && (tokens[pos] == '*' || tokens[pos] == '/')) {
      final op = tokens[pos++];
      final rhs = primary();
      if (op == '*') {
        value *= rhs;
        continue;
      }
      if (rhs == 0) {
        throw CreatureFormulaException(source, 'división por cero');
      }
      // División entera hacia abajo, que es como redondea 5e ("la mitad de tu
      // nivel, redondeando hacia abajo"). El `~/` de Dart trunca hacia cero y
      // daría el resultado equivocado con negativos.
      value = (value / rhs).floor();
    }
    return value;
  }

  expression = () {
    var value = term();
    while (pos < tokens.length && (tokens[pos] == '+' || tokens[pos] == '-')) {
      final op = tokens[pos++];
      final rhs = term();
      value = op == '+' ? value + rhs : value - rhs;
    }
    return value;
  };

  final result = expression();
  if (pos != tokens.length) {
    throw CreatureFormulaException(source, 'sobra "${tokens[pos]}"');
  }
  return result;
}

List<String> _tokenize(String expr, String source) {
  final tokens = <String>[];
  var i = 0;
  while (i < expr.length) {
    final c = expr[i];
    if (c.trim().isEmpty) {
      i++;
    } else if ('+-*/()'.contains(c)) {
      tokens.add(c);
      i++;
    } else if (_isWordChar(c)) {
      final start = i;
      while (i < expr.length && _isWordChar(expr[i])) {
        i++;
      }
      tokens.add(expr.substring(start, i));
    } else {
      throw CreatureFormulaException(source, 'carácter inesperado "$c"');
    }
  }
  if (tokens.isEmpty) {
    throw CreatureFormulaException(source, 'expresión vacía');
  }
  return tokens;
}

bool _isWordChar(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 48 && code <= 57) || // 0-9
      (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122); // a-z
}

/// Rasgo pasivo de una criatura (Anfibio, Vuelo Rasante, Vínculo de Acero…).
class CreatureTrait {
  final String name;
  final String description;

  const CreatureTrait({required this.name, required this.description});

  Map<String, dynamic> toJson() => {'name': name, 'description': description};

  factory CreatureTrait.fromJson(Map<String, dynamic> j) => CreatureTrait(
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
      );

  CreatureTrait resolve(CreatureVars vars) => CreatureTrait(
        name: name,
        description: resolveCreatureFormula(description, vars),
      );
}

/// En qué parte del turno se usa una acción de criatura.
///
/// Un solo enum en vez de una lista por tipo: el perfil las muestra agrupadas
/// pero son la misma clase de cosa, y cuatro listas paralelas duplicarían el
/// parseo y el render. Un enum tampoco admite los estados imposibles que sí
/// permitirían cuatro booleanos.
enum CreatureActionKind {
  action('action', 'Acción'),
  bonus('bonus', 'Acción adicional'),
  reaction('reaction', 'Reacción'),
  legendary('legendary', 'Acción legendaria');

  const CreatureActionKind(this.id, this.label);

  final String id;

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => id;

  /// Tolerante: ausente o desconocido cae en [action], que es el tipo por
  /// defecto de cualquier acción del catálogo viejo.
  static CreatureActionKind fromJson(String? v) {
    for (final k in CreatureActionKind.values) {
      if (k.id == v) return k;
    }
    return CreatureActionKind.action;
  }
}

/// Acción de una criatura. Cuando [attackBonus] está presente es un ataque y la
/// ficha lo pinta con el mismo formato que los del personaje; si no, es una
/// acción descriptiva (Reparar, Detonar, Protector).
class CreatureAction {
  final String name;
  final String description;

  /// Expresión del bono de ataque (`"SPELLATK"`, `"2+INT+PB"`), o null si la
  /// acción no es un ataque. Sin llaves: es un entero entero.
  final String? attackBonus;

  /// Plantilla del daño, que sí mezcla dados con cálculo ("1d8+{2+INT}").
  final String? damage;

  /// Id de [DamageType] (no la etiqueta), para que la UI lo traduzca igual que
  /// el daño de las armas.
  final String? damageType;

  final String reach;

  /// En qué parte del turno se usa: cambia solo cómo se rotula en la ficha.
  ///
  /// No lleva un costo en acciones legendarias: la regla 2024 lo sacó, y los
  /// perfiles del SRD 5.2.1 declaran el presupuesto una sola vez en la criatura
  /// ([Creature.legendaryActionsPerRound]) gastando una por entrada.
  final CreatureActionKind kind;

  const CreatureAction({
    required this.name,
    this.description = '',
    this.attackBonus,
    this.damage,
    this.damageType,
    this.reach = '',
    this.kind = CreatureActionKind.action,
  });

  bool get isAttack => attackBonus != null;

  /// Compatibilidad con quien solo distingue reacción de lo demás.
  bool get reaction => kind == CreatureActionKind.reaction;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'attackBonus': attackBonus,
        'damage': damage,
        'damageType': damageType,
        'reach': reach,
        if (kind != CreatureActionKind.action) 'kind': kind.toJson(),
      };

  /// El catálogo anterior a [CreatureActionKind] marcaba la reacción con un
  /// booleano; se sigue leyendo para no tener que reescribir esas entradas.
  factory CreatureAction.fromJson(Map<String, dynamic> j) => CreatureAction(
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        attackBonus: j['attackBonus'] as String?,
        damage: j['damage'] as String?,
        damageType: j['damageType'] as String?,
        reach: j['reach'] as String? ?? '',
        kind: j.containsKey('kind')
            ? CreatureActionKind.fromJson(j['kind'] as String?)
            : (j['reaction'] as bool? ?? false)
                ? CreatureActionKind.reaction
                : CreatureActionKind.action,
      );

  ResolvedCreatureAction resolve(CreatureVars vars) => ResolvedCreatureAction(
        name: name,
        description: resolveCreatureFormula(description, vars),
        attackBonus:
            attackBonus == null ? null : resolveCreatureInt(attackBonus!, vars),
        damage: damage == null ? null : resolveCreatureFormula(damage!, vars),
        damageType: damageType,
        reach: reach,
        kind: kind,
      );
}

class ResolvedCreatureAction {
  final String name;
  final String description;
  final int? attackBonus;
  final String? damage;
  final String? damageType;
  final String reach;
  final CreatureActionKind kind;

  const ResolvedCreatureAction({
    required this.name,
    required this.description,
    required this.attackBonus,
    required this.damage,
    required this.damageType,
    required this.reach,
    this.kind = CreatureActionKind.action,
  });

  bool get isAttack => attackBonus != null;

  /// Compatibilidad con quien solo distingue reacción de lo demás.
  bool get reaction => kind == CreatureActionKind.reaction;
}

/// Perfil de una criatura invocable: cañón, defensor, familiar, corcel.
///
/// Es contenido puro y no sabe quién la invoca — eso lo declara el efecto
/// `companion`. Los campos numéricos son fórmulas y no enteros porque casi
/// todos dependen del personaje, y vienen en dos sabores: los que tienen que
/// dar un número ([ac], [hp], el bono de ataque) son expresiones sueltas
/// (`"12+INT"`), y los que son texto con cuentas adentro ([speed], el daño)
/// llevan la cuenta entre llaves (`"1d8+{2+INT}"`).
class Creature {
  final String id;
  final String name;
  final ContentSource source;

  /// Tipo, tamaño y alineamiento juntos, como se leen en la primera línea de un
  /// perfil ("Constructo Mediano", "Feérico Pequeño (trasgo), caótico neutral").
  ///
  /// Sigue siendo lo que se muestra: es la línea del libro, con su etiqueta
  /// descriptiva y su alineamiento, y ninguna combinación de campos la
  /// reconstruye igual. [type] y [size] existen aparte para poder filtrar.
  final String kind;

  /// Tipo de criatura, o null en las entradas viejas que solo traen [kind] y en
  /// los perfiles que ofrecen varios a elección ("Celestial, feérico o infernal
  /// Grande (a tu elección)"). Preferir [creatureType], que cae a [kind].
  final CreatureType? type;

  /// Tamaño, o null por los mismos dos motivos que [type]. Preferir
  /// [creatureSize].
  final CreatureSize? size;

  /// Fórmulas de clase de armadura y puntos de golpe.
  final String ac;
  final String hp;

  final String speed;
  final Map<Ability, int> abilityScores;

  /// Salvaciones con competencia, ya sumadas. Vacío si el perfil no declara
  /// ninguna, que es el caso de la mayoría de las bestias.
  final Map<Ability, int> savingThrows;

  /// Habilidades con competencia, ya sumadas (Percepción +5).
  final Map<Skill, int> skills;

  final String senses;
  final String languages;

  /// Percepción pasiva. Las entradas viejas la llevan adentro de [senses] como
  /// texto; preferir [passivePerceptionValue], que la lee de ahí si falta.
  final int? passivePerception;

  /// Cuántas acciones legendarias puede gastar por ronda, o null si no tiene.
  final int? legendaryActionsPerRound;

  /// Bonificador de iniciativa impreso en el perfil, o null para usar DES.
  ///
  /// La regla 2024 deja que un monstruo tenga competencia en iniciativa, así
  /// que el número del perfil no siempre es el modificador de Destreza. Se
  /// guarda solo cuando difiere; preferir [initiativeModifier].
  final int? initiativeBonus;

  /// Resistencias, inmunidades y vulnerabilidades en una línea, tal como se
  /// leen en un perfil. Es texto y no un conjunto de ids como en el personaje:
  /// un compañero no participa del cálculo de daño, solo se muestra.
  final String defenses;

  /// Valor de desafío, o null si no lo declara. Solo las bestias del catálogo
  /// lo traen: es lo que filtra el pozo de Forma Salvaje, que sube de 1/4 a 1
  /// con el nivel del druida. Se guarda como número (`0.25`) y no como «1/4»
  /// para poder compararlo sin parsear una fracción en cada filtro.
  final num? cr;

  /// La criatura se invoca gastando un espacio de conjuro y sus fórmulas usan
  /// `spellLevel` (Corcel Sobrenatural, Sirviente Homúnculo).
  final bool scalesWithSpellLevel;

  final List<CreatureTrait> traits;
  final List<CreatureAction> actions;

  const Creature({
    required this.id,
    required this.name,
    required this.source,
    this.kind = '',
    this.type,
    this.size,
    required this.ac,
    required this.hp,
    this.speed = '',
    this.abilityScores = const {},
    this.savingThrows = const {},
    this.skills = const {},
    this.senses = '',
    this.languages = '',
    this.passivePerception,
    this.legendaryActionsPerRound,
    this.initiativeBonus,
    this.defenses = '',
    this.cr,
    this.scalesWithSpellLevel = false,
    this.traits = const [],
    this.actions = const [],
  });

  int abilityModifierFor(Ability a) => abilityModifier(abilityScores[a] ?? 10);

  /// Tipo de la criatura: el campo estructurado si lo trae, y si no el que se
  /// deduzca de [kind]. Las entradas viejas del catálogo solo tienen `kind`, y
  /// ninguna necesita reescribirse para que esto funcione.
  CreatureType? get creatureType => type ?? CreatureType.fromKind(kind);

  /// Tamaño de la criatura, con la misma caída a [kind] que [creatureType].
  CreatureSize? get creatureSize => size ?? CreatureSize.fromKind(kind);

  /// Percepción pasiva, del campo propio o leída de [senses] ("Percepción
  /// pasiva 16"), que es donde la escriben las entradas viejas.
  int? get passivePerceptionValue {
    if (passivePerception != null) return passivePerception;
    final m = RegExp(r'Percepción pasiva (\d+)').firstMatch(senses);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Modificador de iniciativa: el impreso en el perfil si lo trae, y si no el
  /// de Destreza, que es lo que vale para cualquier criatura sin competencia.
  int get initiativeModifier =>
      initiativeBonus ?? abilityModifierFor(Ability.dexterity);

  /// Es una bestia, y por lo tanto forma legal de Forma Salvaje.
  bool get isBeast => creatureType == CreatureType.beast;

  /// Tiene velocidad volando, que la Forma Salvaje prohíbe hasta nivel 8.
  bool get canFly => speed.contains('volar');

  /// Velocidad de caminar en pies, leída del principio de [speed]
  /// ("30 pies, trepar 30 pies" → 30), o 0 si no arranca con un número.
  ///
  /// Derivado y no duplicado, por lo mismo que [isBeast]. Que las 64 criaturas
  /// den un número mayor que cero lo garantiza `content_integrity_test.dart`.
  int get walkSpeed =>
      int.tryParse(RegExp(r'^\s*(\d+)').firstMatch(speed)?.group(1) ?? '') ?? 0;

  /// Alcance de la visión en la oscuridad en pies, leído de [senses], o null si
  /// la criatura no la tiene.
  int? get darkvision {
    final m = RegExp(r'visión en la oscuridad (\d+)').firstMatch(senses);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        'kind': kind,
        if (type != null) 'type': type!.toJson(),
        if (size != null) 'size': size!.toJson(),
        'ac': ac,
        'hp': hp,
        'speed': speed,
        'abilityScores': {
          for (final e in abilityScores.entries)
            e.key.abbr.toLowerCase(): e.value,
        },
        if (savingThrows.isNotEmpty)
          'savingThrows': {
            for (final e in savingThrows.entries)
              e.key.abbr.toLowerCase(): e.value,
          },
        if (skills.isNotEmpty)
          'skills': {for (final e in skills.entries) e.key.id: e.value},
        'senses': senses,
        'languages': languages,
        if (passivePerception != null) 'passivePerception': passivePerception,
        if (legendaryActionsPerRound != null)
          'legendaryActionsPerRound': legendaryActionsPerRound,
        if (initiativeBonus != null) 'initiativeBonus': initiativeBonus,
        'defenses': defenses,
        if (cr != null) 'cr': cr,
        'scalesWithSpellLevel': scalesWithSpellLevel,
        'traits': [for (final t in traits) t.toJson()],
        'actions': [for (final a in actions) a.toJson()],
      };

  factory Creature.fromJson(Map<String, dynamic> j) => Creature(
        id: j['id'] as String,
        name: j['name'] as String,
        source: ContentSource.fromJson(j['source'] as String?),
        kind: j['kind'] as String? ?? '',
        type: CreatureType.fromJson(j['type'] as String?),
        size: CreatureSize.fromJson(j['size'] as String?),
        ac: j['ac'] as String,
        hp: j['hp'] as String,
        speed: j['speed'] as String? ?? '',
        abilityScores: {
          for (final e in (j['abilityScores'] as Map? ?? const {}).entries)
            Ability.fromKey(e.key as String): e.value as int,
        },
        savingThrows: {
          for (final e in (j['savingThrows'] as Map? ?? const {}).entries)
            Ability.fromKey(e.key as String): e.value as int,
        },
        // Una habilidad que no esté entre las 18 se ignora en vez de romper la
        // carga del catálogo entero.
        skills: {
          for (final e in (j['skills'] as Map? ?? const {}).entries)
            if (Skill.fromId(e.key as String) case final s?) s: e.value as int,
        },
        senses: j['senses'] as String? ?? '',
        languages: j['languages'] as String? ?? '',
        passivePerception: j['passivePerception'] as int?,
        legendaryActionsPerRound: j['legendaryActionsPerRound'] as int?,
        initiativeBonus: j['initiativeBonus'] as int?,
        defenses: j['defenses'] as String? ?? '',
        cr: j['cr'] as num?,
        scalesWithSpellLevel: j['scalesWithSpellLevel'] as bool? ?? false,
        traits: [
          for (final t in (j['traits'] as List? ?? const []))
            CreatureTrait.fromJson((t as Map).cast<String, dynamic>()),
        ],
        actions: [
          for (final a in (j['actions'] as List? ?? const []))
            CreatureAction.fromJson((a as Map).cast<String, dynamic>()),
        ],
      );

  /// Cruza el perfil con los valores del personaje y devuelve el bloque que la
  /// ficha puede pintar sin volver a hacer una cuenta.
  ResolvedCreature resolve(CreatureVars vars) => ResolvedCreature(
        id: id,
        name: name,
        kind: kind,
        armorClass: resolveCreatureInt(ac, vars),
        maxHp: resolveCreatureInt(hp, vars),
        speed: resolveCreatureFormula(speed, vars),
        abilityScores: abilityScores,
        savingThrows: savingThrows,
        skills: skills,
        senses: resolveCreatureFormula(senses, vars),
        languages: languages,
        defenses: defenses,
        legendaryActionsPerRound: legendaryActionsPerRound,
        traits: [for (final t in traits) t.resolve(vars)],
        actions: [for (final a in actions) a.resolve(vars)],
      );
}

/// Una [Creature] con todas sus fórmulas ya evaluadas para un personaje
/// concreto. Es lo único que la UI mira.
class ResolvedCreature {
  final String id;
  final String name;
  final String kind;
  final int armorClass;
  final int maxHp;
  final String speed;
  final Map<Ability, int> abilityScores;
  final Map<Ability, int> savingThrows;
  final Map<Skill, int> skills;
  final String senses;
  final String languages;
  final String defenses;
  final int? legendaryActionsPerRound;
  final List<CreatureTrait> traits;
  final List<ResolvedCreatureAction> actions;

  const ResolvedCreature({
    required this.id,
    required this.name,
    required this.kind,
    required this.armorClass,
    required this.maxHp,
    required this.speed,
    required this.abilityScores,
    this.savingThrows = const {},
    this.skills = const {},
    required this.senses,
    required this.languages,
    required this.defenses,
    this.legendaryActionsPerRound,
    required this.traits,
    required this.actions,
  });

  int abilityModifierFor(Ability a) => abilityModifier(abilityScores[a] ?? 10);
}
