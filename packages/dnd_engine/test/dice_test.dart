import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  test('array estándar es el oficial', () {
    expect(standardArray, [15, 14, 13, 12, 10, 8]);
  });

  test('promedio de dado de golpe (redondeo hacia arriba)', () {
    expect(averageHitDie(6), 4);
    expect(averageHitDie(8), 5);
    expect(averageHitDie(10), 6);
    expect(averageHitDie(12), 7);
  });

  test('4d6 descartando el menor queda en rango 3..18', () {
    final dice = Dice(Random(42));
    for (var i = 0; i < 500; i++) {
      final score = dice.rollAbilityScore4d6DropLowest();
      expect(score, inInclusiveRange(3, 18));
    }
  });

  test('genera un set de 6 puntuaciones', () {
    final set = Dice(Random(1)).rollAbilityScoreSet();
    expect(set, hasLength(6));
    expect(set.every((s) => s >= 3 && s <= 18), isTrue);
  });

  test('roll(n) siempre está en 1..n', () {
    final d = Dice(Random(7));
    for (var i = 0; i < 200; i++) {
      expect(d.roll(20), inInclusiveRange(1, 20));
    }
  });
}
