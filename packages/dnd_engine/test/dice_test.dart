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

  group('DiceFormula', () {
    test('lee las tres formas que imprime el libro', () {
      expect(
          DiceFormula.tryParse('16d12 + 96'),
          isA<DiceFormula>()
              .having((f) => f.count, 'dados', 16)
              .having((f) => f.sides, 'caras', 12)
              .having((f) => f.modifier, 'modificador', 96));

      expect(DiceFormula.tryParse('2d6')!.modifier, 0);
      expect(DiceFormula.tryParse('3d6 - 3')!.modifier, -3);
    });

    // No es un evaluador de expresiones y no debe pretender serlo: para algo
    // que no entiende, no ofrecer la tirada es mejor que inventar un número.
    test('lo que no es una de esas formas no parsea', () {
      for (final texto in [
        '',
        '200',
        'd20',
        '2d',
        '16d12 + 96 + 4',
        '2d6 * 3',
        'la mitad de los pg de su invocador',
      ]) {
        expect(DiceFormula.tryParse(texto), isNull, reason: texto);
      }
    });

    // El promedio del libro redondea hacia abajo, al revés que `averageHitDie`,
    // que resuelve otra cosa (los PG que gana un personaje al subir de nivel).
    test('el promedio es el que imprime el libro', () {
      expect(DiceFormula.tryParse('17d12 + 102')!.average, 212);
      expect(DiceFormula.tryParse('16d12 + 96')!.average, 200);
      expect(DiceFormula.tryParse('3d6 - 3')!.average, 7);
      expect(DiceFormula.tryParse('1d4 - 1')!.average, 1);
      expect(DiceFormula.tryParse('2d6')!.average, 7);
    });

    test('la tirada queda entre el mínimo y el máximo posibles', () {
      final formula = DiceFormula.tryParse('4d8 + 4')!;
      final dice = Dice(Random(7));
      for (var i = 0; i < 200; i++) {
        expect(formula.roll(dice), inInclusiveRange(8, 36));
      }
    });

    // «1d4 - 1» puede dar 0, y una criatura con 0 PG entraría al combate ya
    // caída: el tracker la saltearía sin que nadie entienda por qué.
    test('nunca devuelve menos de 1', () {
      final formula = DiceFormula.tryParse('1d4 - 1')!;
      final dice = Dice(Random(3));
      for (var i = 0; i < 200; i++) {
        expect(formula.roll(dice), greaterThanOrEqualTo(1));
      }
    });

    test('vuelve a escribirse como vino', () {
      for (final texto in ['16d12 + 96', '2d6', '3d6 - 3']) {
        expect(DiceFormula.tryParse(texto).toString(), texto);
      }
    });
  });
}
