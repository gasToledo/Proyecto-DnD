import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Daño y curación', () {
    test('el daño consume primero PG temporales', () {
      final c = CombatState(currentHp: 12, tempHp: 5);
      CombatOps.applyDamage(c, 8);
      expect(c.tempHp, 0);
      expect(c.currentHp, 9); // 12 - (8 - 5)
    });

    test('el daño no baja de 0', () {
      final c = CombatState(currentHp: 4);
      CombatOps.applyDamage(c, 10);
      expect(c.currentHp, 0);
    });

    test('curar desde 0 limpia las salvaciones de muerte', () {
      final c = CombatState(currentHp: 0, deathFailures: 2, deathSuccesses: 1);
      CombatOps.applyHealing(c, 12, 5);
      expect(c.currentHp, 5);
      expect(c.deathFailures, 0);
      expect(c.deathSuccesses, 0);
    });

    test('la curación no supera el máximo', () {
      final c = CombatState(currentHp: 10);
      CombatOps.applyHealing(c, 12, 999);
      expect(c.currentHp, 12);
    });
  });

  group('Salvaciones de muerte', () {
    test('3 éxitos estabiliza y resetea', () {
      final c = CombatState(currentHp: 0);
      expect(CombatOps.recordDeathSave(c, success: true), isNull);
      expect(CombatOps.recordDeathSave(c, success: true), isNull);
      expect(CombatOps.recordDeathSave(c, success: true), 'stable');
      expect(c.deathSuccesses, 0);
    });

    test('3 fallos es muerte', () {
      final c = CombatState(currentHp: 0);
      CombatOps.recordDeathSave(c, success: false);
      CombatOps.recordDeathSave(c, success: false);
      expect(CombatOps.recordDeathSave(c, success: false), 'dead');
    });
  });

  group('Descansos', () {
    final resources = [
      const CharacterResource(
          id: 'second_wind',
          name: 'Tomar Aliento',
          max: 2,
          recharge: RechargeOn.longRest,
          shortRestRecovery: 1),
      const CharacterResource(
          id: 'action_surge',
          name: 'Oleada de Acción',
          max: 1,
          recharge: RechargeOn.shortRest),
    ];

    test('descanso corto aplica recuperación completa o parcial', () {
      final c = CombatState()
        ..resourceUsage['second_wind'] = 2
        ..resourceUsage['action_surge'] = 1;
      CombatOps.shortRest(c, resources);
      expect(c.resourceUsage['second_wind'], 1);
      expect(c.resourceUsage['action_surge'], 0);

      CombatOps.shortRest(c, resources);
      expect(c.resourceUsage['second_wind'], 0);
    });

    test('descanso largo restaura PG, agotamiento y dados de golpe', () {
      final c =
          CombatState(currentHp: 3, tempHp: 4, exhaustion: 2, hitDiceUsed: 4);
      CombatOps.longRest(c, 20, resources, 4);
      expect(c.currentHp, 20);
      expect(c.tempHp, 0);
      expect(c.exhaustion, 1);
      expect(c.hitDiceUsed, 2); // recupera la mitad de 4
    });

    test('el descanso largo concede Inspiración Heroica si un rasgo la da', () {
      final c = CombatState(currentHp: 3);
      CombatOps.longRest(c, 20, resources, 4, grantsHeroicInspiration: true);
      expect(c.heroicInspiration, isTrue);
    });

    test('sin el rasgo, el descanso largo no la regala', () {
      final c = CombatState(currentHp: 3);
      CombatOps.longRest(c, 20, resources, 4);
      expect(c.heroicInspiration, isFalse);
    });

    test('tenerla ya y volver a ganarla no acumula nada', () {
      // Nunca hay más de una: quien la tenía la desperdicia, no junta dos.
      final c = CombatState(currentHp: 3, heroicInspiration: true);
      CombatOps.longRest(c, 20, resources, 4, grantsHeroicInspiration: true);
      expect(c.heroicInspiration, isTrue);
    });

    test('el descanso largo no le saca la Inspiración a quien la tenía', () {
      final c = CombatState(currentHp: 3, heroicInspiration: true);
      CombatOps.longRest(c, 20, resources, 4);
      expect(c.heroicInspiration, isTrue);
    });
  });

  test('gastar dado de golpe cura (tirada + mod CON) de forma determinista',
      () {
    // Sheet mínima con CON +2 y dado de golpe d10.
    final sheet = ComputedSheet(
      level: 1,
      proficiencyBonus: 2,
      abilityScores: {for (final a in Ability.values) a: 10}
        ..[Ability.constitution] = 14,
      abilityModifiers: {for (final a in Ability.values) a: 0}
        ..[Ability.constitution] = 2,
      savingThrowProficiencies: {},
      skillProficiencies: {},
      armorProficiencies: {},
      weaponProficiencies: {},
      toolProficiencies: {},
      maxHp: 20,
      hitDie: 10,
      armorClass: 10,
      speed: 30,
      initiative: 0,
      darkvision: null,
      resistances: {},
      immunities: {},
      weaponMasterySlots: 0,
      attacksPerAction: 1,
      attacks: const [],
      passives: const [],
      resources: const [],
    );
    final c = CombatState(currentHp: 5);
    final healed = CombatOps.spendHitDie(c, sheet, 1, dice: Dice(Random(1)));
    expect(healed, greaterThanOrEqualTo(3)); // mínimo 1 (tirada) + 2 (CON)
    expect(c.hitDiceUsed, 1);
    expect(c.currentHp, 5 + healed);
  });
}
