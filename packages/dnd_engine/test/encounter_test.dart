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

    // Regresión: cargar al jugador primero y a los monstruos después le daba
    // el primer turno al jugador aunque todos le ganaran la iniciativa,
    // porque `withCombatant` le conservaba un turno que en realidad nadie
    // había empezado a jugar.
    test(
        'mientras se arma el orden, el turno queda en la iniciativa más '
        'alta sin importar el orden de carga', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'sagan',
          kind: CombatantKind.player,
          name: 'Sagan',
          initiative: 8,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'g1',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 15,
          currentHp: 7,
          maxHp: 7,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'g2',
          kind: CombatantKind.monster,
          name: 'Goblin 2',
          initiative: 12,
          currentHp: 7,
          maxHp: 7,
        ),
      );

      expect(e.combatants.map((c) => c.id), ['g1', 'g2', 'sagan']);
      expect(e.current!.id, 'g1');
      expect(e.round, 1);
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

  group('Combatant.isDown', () {
    test('un monstruo a 0 PG está caído', () {
      const c = Combatant(
        id: 'g',
        kind: CombatantKind.monster,
        name: 'Goblin',
        initiative: 10,
        currentHp: 0,
        maxHp: 7,
      );
      expect(c.isDown, isTrue);
    });

    test('un monstruo con PG restantes no está caído', () {
      const c = Combatant(
        id: 'g',
        kind: CombatantKind.monster,
        name: 'Goblin',
        initiative: 10,
        currentHp: 1,
        maxHp: 7,
      );
      expect(c.isDown, isFalse);
    });

    // Los PG de un jugador nunca se llevan acá (maxHp queda en 0 por
    // defecto), así que esta condición no puede dispararse por accidente
    // aunque algo mande currentHp en 0 para un jugador.
    test('un jugador nunca está "caído" según este chequeo', () {
      const c = Combatant(
        id: 'p',
        kind: CombatantKind.player,
        name: 'Sagan',
        initiative: 10,
        currentHp: 0,
        maxHp: 0,
      );
      expect(c.isDown, isFalse);
    });
  });

  group('Encounter — turnos y monstruos caídos', () {
    // g está a 0 PG desde el arranque: el turno tiene que saltarlo entero,
    // como si nunca hubiera podido actuar.
    Encounter tableWithDowned() {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'a',
          kind: CombatantKind.player,
          name: 'A',
          initiative: 20,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'g',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 15,
          currentHp: 0,
          maxHp: 7,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'c',
          kind: CombatantKind.player,
          name: 'C',
          initiative: 10,
        ),
      );
      return e;
    }

    test('next salta directo al siguiente en pie', () {
      final e = tableWithDowned().next();
      expect(e.current!.id, 'c');
      expect(e.round, 1);
    });

    test('onDeck también salta al caído', () {
      expect(tableWithDowned().onDeck!.id, 'c');
    });

    // Bajar a alguien a 0 PG en medio de su propio turno (justo antes de que
    // el DM avance) tiene que saltarlo igual: no importa cuándo cayó.
    test('un combatiente que cae en su propio turno se salta al avanzar', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'g',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 20,
          currentHp: 7,
          maxHp: 7,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'a',
          kind: CombatantKind.player,
          name: 'A',
          initiative: 10,
        ),
      );
      e = e.withHp('g', 0); // el DM le pega el golpe final en su propio turno

      expect(e.next().current!.id, 'a');
    });

    // Con un solo sobreviviente, "avanzar" es una vuelta entera de ronda que
    // vuelve a caer en la misma persona — no queda nadie más a quién pasarle
    // la posta.
    test('con un solo sobreviviente, next le da otra ronda a él mismo', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'a',
          kind: CombatantKind.player,
          name: 'A',
          initiative: 20,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'g',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 10,
          currentHp: 0,
          maxHp: 7,
        ),
      );

      final after = e.next();
      expect(after.current!.id, 'a');
      expect(after.round, 2);
      expect(e.onDeck, isNull);
    });

    // Si no queda nadie en pie, no hay a quién pasarle el turno: mejor no
    // avanzar que fingir un turno que no le toca a nadie.
    test('si todos están caídos, next no cambia nada', () {
      var e = const Encounter(id: 'x');
      e = e.withCombatant(
        const Combatant(
          id: 'g1',
          kind: CombatantKind.monster,
          name: 'Goblin',
          initiative: 20,
          currentHp: 0,
          maxHp: 7,
        ),
      );
      e = e.withCombatant(
        const Combatant(
          id: 'g2',
          kind: CombatantKind.monster,
          name: 'Goblin 2',
          initiative: 10,
          currentHp: 0,
          maxHp: 7,
        ),
      );

      final after = e.next();
      expect(after.round, e.round);
      expect(after.turnIndex, e.turnIndex);
      // Igual muestra a alguien en vez de un turno vacío: no hay nadie mejor.
      expect(e.current, isNotNull);
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

  group('tags de combatiente', () {
    Encounter conUno({List<String> tags = const []}) => Encounter(
          id: 'e1',
          combatants: [
            Combatant(
              id: 'm1',
              kind: CombatantKind.monster,
              name: 'Goblin',
              initiative: 12,
              currentHp: 7,
              maxHp: 7,
              tags: tags,
            ),
          ],
        );

    test('un combatiente nace sin tags', () {
      expect(conUno().combatants.single.tags, isEmpty);
    });

    test('sobreviven el round-trip', () {
      final e = conUno(tags: ['Envenenado', 'marcado por el pícaro']);
      final r = Encounter.fromJson(e.toJson());
      expect(r.combatants.single.tags, ['Envenenado', 'marcado por el pícaro']);
    });

    // Un combate viejo no los trae, y el DM no puede perder la ronda por eso.
    test('un documento sin tags carga igual', () {
      final r = Encounter.fromJson({
        'id': 'e1',
        'combatants': [
          {'id': 'm1', 'kind': 'monster', 'name': 'Goblin', 'initiative': 12},
        ],
      });
      expect(r.combatants.single.tags, isEmpty);
    });

    test('lo que no sea texto se descarta en vez de romper el combate', () {
      final r = Encounter.fromJson({
        'id': 'e1',
        'combatants': [
          {
            'id': 'm1',
            'kind': 'monster',
            'name': 'Goblin',
            'initiative': 12,
            'tags': ['Envenenado', '', '   ', 7, null],
          },
        ],
      });
      expect(r.combatants.single.tags, ['Envenenado']);
    });

    test('withTags reemplaza los del combatiente que se nombra', () {
      final e = conUno(tags: ['Envenenado']);
      final r = e.withTags('m1', ['Derribado', 'Asustado']);
      expect(r.combatants.single.tags, ['Derribado', 'Asustado']);
    });

    test('withTags normaliza: sin repetidos, sin vacíos, en orden', () {
      final r = conUno().withTags('m1', [
        'Envenenado',
        '  Derribado  ',
        'Envenenado',
        '',
        '   ',
      ]);
      expect(r.combatants.single.tags, ['Envenenado', 'Derribado']);
    });

    test('withTags no toca a los demás ni al turno', () {
      final e = Encounter(
        id: 'e1',
        round: 3,
        turnIndex: 1,
        combatants: const [
          Combatant(
            id: 'a',
            kind: CombatantKind.monster,
            name: 'Ogro',
            initiative: 15,
            currentHp: 20,
            maxHp: 20,
          ),
          Combatant(
            id: 'b',
            kind: CombatantKind.player,
            name: 'Sagan',
            initiative: 10,
          ),
        ],
      );

      final r = e.withTags('b', ['Asustado']);
      expect(r.round, 3);
      expect(r.turnIndex, 1);
      expect(r.combatants.first.tags, isEmpty);
      expect(r.combatants.last.tags, ['Asustado']);
      // Y los PG siguen donde estaban: los tags no son una edición del estado.
      expect(r.combatants.first.currentHp, 20);
    });

    test('un id que no está no cambia nada', () {
      final e = conUno(tags: ['Envenenado']);
      expect(e.withTags('fantasma', ['x']).combatants.single.tags, [
        'Envenenado',
      ]);
    });
  });
}
