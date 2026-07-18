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

/// PG promedio/fijo de un dado de golpe al subir de nivel (redondeo hacia
/// arriba de la media): d6→4, d8→5, d10→6, d12→7.
int averageHitDie(int sides) => (sides ~/ 2) + 1;
