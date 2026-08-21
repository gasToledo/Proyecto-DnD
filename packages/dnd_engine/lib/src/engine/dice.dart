import 'dart:math';

/// Utilidades de tirada de dados (dado virtual del wizard y de subida de nivel).
class Dice {
  final Random _rng;
  Dice([Random? rng]) : _rng = rng ?? Random();

  /// Tira un dado de [sides] caras (1..sides).
  int roll(int sides) => _rng.nextInt(sides) + 1;

  /// Tira [count] dados de [sides] caras y devuelve cada resultado.
  List<int> rollMany(int count, int sides) =>
      List.generate(count, (_) => roll(sides));

  /// Puntuación por 4d6 descartando el menor (método del brief §3.A.4).
  /// Devuelve la suma de los 3 dados mayores.
  int rollAbilityScore4d6DropLowest() {
    final dice = rollMany(4, 6)..sort();
    return dice.skip(1).fold(0, (s, v) => s + v);
  }

  /// Genera las seis puntuaciones por 4d6 descartando el menor.
  List<int> rollAbilityScoreSet() =>
      List.generate(6, (_) => rollAbilityScore4d6DropLowest());

  /// PG al subir de nivel: tirar el dado de golpe.
  int rollHitDie(int sides) => roll(sides);
}

/// Array estándar oficial (brief §3.A.4).
const List<int> standardArray = [15, 14, 13, 12, 10, 8];

/// Compra de puntos (PHB 2024, cap. 2), el tercer método oficial: 27 puntos
/// para repartir entre las seis características, cada una entre 8 y 15.
///
/// El coste **no** es lineal: pasar de 13 a 14 cuesta 2 y de 14 a 15 cuesta 2
/// más, que es lo que desalienta concentrar todo en una sola característica.
/// La tabla es la del manual y por eso vive acá y no en la UI.
const int pointBuyBudget = 27;
const int pointBuyMin = 8;
const int pointBuyMax = 15;

const Map<int, int> pointBuyCosts = {
  8: 0,
  9: 1,
  10: 2,
  11: 3,
  12: 4,
  13: 5,
  14: 7,
  15: 9,
};

/// Coste de una puntuación en la compra de puntos. Fuera del rango 8-15
/// devuelve `null`: no es que cueste 0, es que no se puede comprar.
int? pointBuyCost(int score) => pointBuyCosts[score];

/// Puntos gastados por un reparto completo. Ignora las puntuaciones fuera de
/// rango, que el llamador ya debería haber rechazado.
int pointBuySpent(Iterable<int> scores) =>
    scores.fold(0, (sum, score) => sum + (pointBuyCost(score) ?? 0));

/// PG promedio/fijo de un dado de golpe al subir de nivel (redondeo hacia
/// arriba de la media): d6→4, d8→5, d10→6, d12→7.
int averageHitDie(int sides) => (sides ~/ 2) + 1;

/// Una tirada escrita como la imprime el libro: `"16d12 + 96"`, `"2d6"`,
/// `"3d6 - 3"`.
///
/// Existe para los dados de golpe de las criaturas (`Creature.hitDice`), que es
/// hoy el único lugar del proyecto donde hace falta tirar una fórmula que viene
/// como texto. **No es un evaluador de expresiones**: cubre exactamente las tres
/// formas que imprime el SRD y nada más. Cualquier otra cosa devuelve `null` en
/// [tryParse], que es lo que corresponde — inventar un resultado para algo que
/// no se entendió sería peor que no ofrecer la tirada.
class DiceFormula {
  final int count;
  final int sides;

  /// Lo que se suma o se resta al final. 0 cuando la fórmula no lo trae.
  final int modifier;

  const DiceFormula({
    required this.count,
    required this.sides,
    this.modifier = 0,
  });

  static final _pattern = RegExp(r'^(\d+)d(\d+)(?:\s*([+-])\s*(\d+))?$');

  /// La fórmula, o `null` si el texto no es una de las formas conocidas.
  static DiceFormula? tryParse(String source) {
    final m = _pattern.firstMatch(source.trim());
    if (m == null) return null;
    final magnitude = int.tryParse(m[4] ?? '0') ?? 0;
    return DiceFormula(
      count: int.parse(m[1]!),
      sides: int.parse(m[2]!),
      modifier: m[3] == '-' ? -magnitude : magnitude,
    );
  }

  /// El promedio que el libro imprime al lado de la fórmula, **redondeando
  /// hacia abajo**: «17d12 + 102» da 212.
  ///
  /// Es hacia abajo y no hacia arriba, a diferencia de [averageHitDie], que
  /// resuelve otra cosa (los PG que gana un personaje al subir de nivel).
  /// Verificado contra las 330 criaturas del catálogo que declaran dados: el
  /// promedio derivado coincide con el `hp` impreso en las 330.
  int get average => (count * (sides + 1) / 2 + modifier).floor();

  /// Tira los dados. El resultado nunca baja de 1: una criatura con «1d4 - 1»
  /// que saque un 1 tendría 0 PG, o sea que entraría al combate ya caída.
  int roll(Dice dice) {
    final total =
        dice.rollMany(count, sides).fold(modifier, (sum, v) => sum + v);
    return total < 1 ? 1 : total;
  }

  @override
  String toString() =>
      '${count}d$sides${modifier == 0 ? '' : modifier > 0 ? ' + $modifier' : ' - ${-modifier}'}';
}
