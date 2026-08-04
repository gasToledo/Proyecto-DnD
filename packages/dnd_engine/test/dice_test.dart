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

  group('compra de puntos', () {
    test('la tabla de costes es la del capítulo 2', () {
      expect(pointBuyBudget, 27);
      expect(pointBuyMin, 8);
      expect(pointBuyMax, 15);
      expect(pointBuyCosts,
          {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9});
    });

    test('los dos últimos escalones cuestan doble', () {
      // Lo que hace no lineal a la tabla: de 12 a 13 cuesta 1, de 13 a 14
      // cuesta 2. Es la regla que desalienta concentrar todo en una sola.
      expect(pointBuyCost(13)! - pointBuyCost(12)!, 1);
      expect(pointBuyCost(14)! - pointBuyCost(13)!, 2);
      expect(pointBuyCost(15)! - pointBuyCost(14)!, 2);
    });

    test('fuera de rango no cuesta 0: no se puede comprar', () {
      expect(pointBuyCost(7), isNull);
      expect(pointBuyCost(16), isNull);
      expect(pointBuyCost(0), isNull);
    });

    test('un reparto clásico de 27 entra justo', () {
      // 15/15/15/8/8/8 gasta exactamente el presupuesto.
      expect(pointBuySpent([15, 15, 15, 8, 8, 8]), 27);
      // 14/14/14/12/10/8 también, por otro camino.
      expect(pointBuySpent([14, 14, 14, 12, 10, 8]), 27);
    });

    test('las seis en el mínimo no gastan nada', () {
      expect(pointBuySpent([8, 8, 8, 8, 8, 8]), 0);
    });
  });
}
