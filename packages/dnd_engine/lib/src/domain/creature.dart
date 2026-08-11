import 'ability.dart';
import 'content_source.dart';

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

/// Acción o reacción de una criatura. Cuando [attackBonus] está presente es un
/// ataque y la ficha lo pinta con el mismo formato que los del personaje; si no,
/// es una acción descriptiva (Reparar, Detonar, Protector).
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

  /// Reacción en vez de acción: cambia solo cómo se rotula en la ficha.
  final bool reaction;

  const CreatureAction({
    required this.name,
    this.description = '',
    this.attackBonus,
    this.damage,
    this.damageType,
    this.reach = '',
    this.reaction = false,
  });

  bool get isAttack => attackBonus != null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'attackBonus': attackBonus,
        'damage': damage,
        'damageType': damageType,
        'reach': reach,
        'reaction': reaction,
      };

  factory CreatureAction.fromJson(Map<String, dynamic> j) => CreatureAction(
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        attackBonus: j['attackBonus'] as String?,
        damage: j['damage'] as String?,
        damageType: j['damageType'] as String?,
        reach: j['reach'] as String? ?? '',
        reaction: j['reaction'] as bool? ?? false,
      );

  ResolvedCreatureAction resolve(CreatureVars vars) => ResolvedCreatureAction(
        name: name,
        description: resolveCreatureFormula(description, vars),
        attackBonus:
            attackBonus == null ? null : resolveCreatureInt(attackBonus!, vars),
        damage: damage == null ? null : resolveCreatureFormula(damage!, vars),
        damageType: damageType,
        reach: reach,
        reaction: reaction,
      );
}

class ResolvedCreatureAction {
  final String name;
  final String description;
  final int? attackBonus;
  final String? damage;
  final String? damageType;
  final String reach;
  final bool reaction;

  const ResolvedCreatureAction({
    required this.name,
    required this.description,
    required this.attackBonus,
    required this.damage,
    required this.damageType,
    required this.reach,
    required this.reaction,
  });

  bool get isAttack => attackBonus != null;
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

  /// Tipo y tamaño juntos, como se leen en un perfil ("Constructo Mediano").
  final String kind;

  /// Fórmulas de clase de armadura y puntos de golpe.
  final String ac;
  final String hp;

  final String speed;
  final Map<Ability, int> abilityScores;
  final String senses;
  final String languages;

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
    required this.ac,
    required this.hp,
    this.speed = '',
    this.abilityScores = const {},
    this.senses = '',
    this.languages = '',
    this.defenses = '',
    this.cr,
    this.scalesWithSpellLevel = false,
    this.traits = const [],
    this.actions = const [],
  });

  int abilityModifierFor(Ability a) => abilityModifier(abilityScores[a] ?? 10);

  /// Es una bestia, y por lo tanto forma legal de Forma Salvaje.
  ///
  /// Se lee de [kind] en vez de guardarse aparte porque el tipo ya está escrito
  /// ahí, y un dato duplicado se puede contradecir con el que ya existe.
  bool get isBeast => kind.startsWith('Bestia');

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
        'ac': ac,
        'hp': hp,
        'speed': speed,
        'abilityScores': {
          for (final e in abilityScores.entries)
            e.key.abbr.toLowerCase(): e.value,
        },
        'senses': senses,
        'languages': languages,
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
        ac: j['ac'] as String,
        hp: j['hp'] as String,
        speed: j['speed'] as String? ?? '',
        abilityScores: {
          for (final e in (j['abilityScores'] as Map? ?? const {}).entries)
            Ability.fromKey(e.key as String): e.value as int,
        },
        senses: j['senses'] as String? ?? '',
        languages: j['languages'] as String? ?? '',
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
        senses: resolveCreatureFormula(senses, vars),
        languages: languages,
        defenses: defenses,
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
  final String senses;
  final String languages;
  final String defenses;
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
    required this.senses,
    required this.languages,
    required this.defenses,
    required this.traits,
    required this.actions,
  });

  int abilityModifierFor(Ability a) => abilityModifier(abilityScores[a] ?? 10);
}
