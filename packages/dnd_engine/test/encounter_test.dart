import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

const Ability _dex = Ability.dexterity;

Creature _creature({required int dexScore}) => Creature(
      id: 'goblin',
      name: 'Goblin',
      source: ContentSource.srd2024,
      ac: '15',
      hp: '7',
      abilityScores: {_dex: dexScore},
    );

void main() {
  group('Combatant', () {
    test('conserva sus campos en el round-trip', () {
      const c = Combatant(
        id: 'a',
        kind: CombatantKind.monster,
        name: 'Goblin',
        initiative: 14,
        creatureId: 'goblin',
        currentHp: 5,
        maxHp: 7,
      );

      final r = Combatant.fromJson(c.toJson());

      expect(r.id, 'a');
      expect(r.kind, CombatantKind.monster);
      expect(r.name, 'Goblin');
      expect(r.initiative, 14);
      expect(r.creatureId, 'goblin');
      expect(r.currentHp, 5);
      expect(r.maxHp, 7);
    });

    test('un jugador lleva memberId y no creatureId', () {
      const c = Combatant(
        id: 'a',
        kind: CombatantKind.player,
        name: 'Sagan',
        initiative: 12,
        memberId: 'member-1',
      );

      final r = Combatant.fromJson(c.toJson());

      expect(r.kind, CombatantKind.player);
      expect(r.memberId, 'member-1');
      expect(r.creatureId, isNull);
    });

    test('un tipo desconocido cae en monstruo en vez de romper', () {
      final r = Combatant.fromJson({
        'id': 'a',
        'kind': 'algo-nuevo',
        'initiative': 1,
      });

      expect(r.kind, CombatantKind.monster);
    });

    test('copyWith cambia los PG y conserva el resto', () {
      const c = Combatant(
        id: 'a',
        kind: CombatantKind.monster,
        name: 'Goblin',
        initiative: 14,
        maxHp: 7,
        currentHp: 7,
      );

      final r = c.copyWith(currentHp: 3);

      expect(r.currentHp, 3);
      expect(r.maxHp, 7);
      expect(r.id, 'a');
    });
  });

  group('Encounter — orden y turnos', () {
    test('un encuentro nuevo nace en la ronda 1 sin combatientes', () {
      const e = Encounter(id: 'x');

      expect(e.round, 1);
      expect(e.turnIndex, 0);
      expect(e.combatants, isEmpty);
      expect(e.current, isNull);
      expect(e.onDeck, isNull);
    });

    test('withCombatant ordena por iniciativa descendente', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'a', kind: CombatantKind.player, name: 'A', initiative: 10),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'b', kind: CombatantKind.player, name: 'B', initiative: 20),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'c', kind: CombatantKind.player, name: 'C', initiative: 15),
      );

      expect(e.combatants.map((c) => c.id), ['b', 'c', 'a']);
    });

    // Sumar tres goblins con la misma iniciativa no debe reordenarlos entre
    // sí: cada uno tiene su propia tirada, pero un empate no es motivo para
    // que el tercero salte delante del primero.
    test('un empate de iniciativa conserva el orden en que se sumaron', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'g1',
            kind: CombatantKind.monster,
            name: 'Goblin',
            initiative: 12),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'g2',
            kind: CombatantKind.monster,
            name: 'Goblin 2',
            initiative: 12),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'g3',
            kind: CombatantKind.monster,
            name: 'Goblin 3',
            initiative: 12),
      );

      expect(e.combatants.map((c) => c.id), ['g1', 'g2', 'g3']);
    });

    test('current y onDeck reflejan el orden e envuelven al final', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'a', kind: CombatantKind.player, name: 'A', initiative: 20),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'b', kind: CombatantKind.player, name: 'B', initiative: 10),
      );

      expect(e.current!.id, 'a');
      expect(e.onDeck!.id, 'b');

      final wrapped = e.next();
      expect(wrapped.current!.id, 'b');
      expect(wrapped.onDeck!.id, 'a');
    });

    test('next avanza turno y suma ronda al volver al primero', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'a', kind: CombatantKind.player, name: 'A', initiative: 20),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'b', kind: CombatantKind.player, name: 'B', initiative: 10),
      );

      final afterA = e.next();
      expect(afterA.round, 1);
      expect(afterA.current!.id, 'b');

      final afterB = afterA.next();
      expect(afterB.round, 2);
      expect(afterB.current!.id, 'a');
    });

    test('withCombatant no pierde el turno en curso al reordenar', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'a', kind: CombatantKind.player, name: 'A', initiative: 20),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'b', kind: CombatantKind.player, name: 'B', initiative: 10),
      );
      e = e.next(); // el turno es de 'b'

      // Sumar un tercero con iniciativa altísima reordena la lista entera,
      // pero el turno tiene que seguir siendo el de 'b'.
      e = e.withCombatant(
        const Combatant(
            id: 'c', kind: CombatantKind.monster, name: 'C', initiative: 99),
      );

      expect(e.current!.id, 'b');
    });

    test('withoutCombatant saca a alguien sin perder el turno de otro', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
            id: 'a', kind: CombatantKind.player, name: 'A', initiative: 20),
      );
      e = e.withCombatant(
        const Combatant(
            id: 'b', kind: CombatantKind.player, name: 'B', initiative: 10),
      );
      e = e.next(); // el turno es de 'b'

      e = e.withoutCombatant('a');

      expect(e.combatants.map((c) => c.id), ['b']);
      expect(e.current!.id, 'b');
    });

    test('withHp clampea los PG entre 0 y el máximo', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'g',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 10,
          currentHp: 7,
          maxHp: 7,
        ),
      );

      expect(e.withHp('g', -5).combatants.single.currentHp, 0);
      expect(e.withHp('g', 999).combatants.single.currentHp, 7);
      expect(e.withHp('g', 3).combatants.single.currentHp, 3);
    });
  });

  group('Encounter.statusFor', () {
    late Encounter e;

    setUp(() {
      e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'a',
          kind: CombatantKind.player,
          name: 'A',
          initiative: 20,
          memberId: 'member-a',
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'b',
          kind: CombatantKind.player,
          name: 'B',
          initiative: 10,
          memberId: 'member-b',
        ),
      );
    });

    test('el combatiente del turno actual está activo', () {
      expect(e.statusFor('member-a'), TurnStatus.active);
    });

    test('el siguiente en el orden está en espera inmediata', () {
      expect(e.statusFor('member-b'), TurnStatus.next);
    });

    test('un tercero en la mesa que no es ni actual ni siguiente espera', () {
      final threePlayers = e.withCombatant(
        const Combatant(
          id: 'c',
          kind: CombatantKind.player,
          name: 'C',
          initiative: 5,
          memberId: 'member-c',
        ),
      );

      expect(threePlayers.statusFor('member-c'), TurnStatus.waiting);
    });

    test('un personaje sin vínculo a este combate no ve nada', () {
      expect(e.statusFor('member-ajeno'), TurnStatus.none);
    });

    test('sin combate abierto, nadie tiene turno', () {
      const empty = Encounter(id: 'x');
      expect(empty.statusFor('member-a'), TurnStatus.none);
    });
  });

  group('Encounter — versionado', () {
    test('el documento estampa la versión de esquema actual', () {
      const e = Encounter(id: 'x');
      expect(e.toJson()['schemaVersion'], Encounter.currentSchemaVersion);
    });

    test('un documento sin versión se trata como la 1', () {
      expect(Encounter.schemaVersionOf({'id': 'x'}), 1);
    });

    test('rechaza una versión futura con un error comprensible', () {
      expect(
        () => Encounter.migrateJson({
          'schemaVersion': Encounter.currentSchemaVersion + 1,
          'id': 'x',
        }),
        throwsA(
          isA<UnsupportedDataVersionException>()
              .having((e) => e.dataType, 'tipo', 'encuentro')
              .having(
                (e) => e.found,
                'versión encontrada',
                Encounter.currentSchemaVersion + 1,
              ),
        ),
      );
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = <String, dynamic>{'id': 'x', 'round': 2};
      Encounter.migrateJson(source);
      expect(source, {'id': 'x', 'round': 2});
    });
  });

  group('rollInitiative', () {
    test('suma 1d20 al modificador de Destreza de la criatura', () {
      final creature = _creature(dexScore: 14); // modificador +2
      final result = rollInitiative(creature, random: Random(1));
      final roll = Random(1).nextInt(20) + 1;

      expect(result, roll + 2);
    });

    test('una Destreza baja resta al resultado', () {
      final creature = _creature(dexScore: 6); // modificador -2
      final result = rollInitiative(creature, random: Random(1));
      final roll = Random(1).nextInt(20) + 1;

      expect(result, roll - 2);
    });
  });
}
