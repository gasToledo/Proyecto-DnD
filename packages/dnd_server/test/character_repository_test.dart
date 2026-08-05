import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import 'fakes/in_memory_character_repository.dart';

Character _character(String id, {String name = 'Personaje'}) => Character(
  id: id,
  name: name,
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  assignedScores: const {},
);

void main() {
  late InMemoryCharacterRepository repo;

  setUp(() => repo = InMemoryCharacterRepository());

  test('create guarda un personaje nuevo con su id pedido', () async {
    final stored = await repo.create('user-a', _character('sagan'));

    expect(stored.id, 'sagan');
    expect(await repo.find('user-a', 'sagan'), isNotNull);
  });

  test(
    'create asigna un id libre si el pedido ya existe en la cuenta',
    () async {
      await repo.create('user-a', _character('sagan', name: 'Original'));

      final second = await repo.create(
        'user-a',
        _character('sagan', name: 'Nuevo'),
      );

      expect(second.id, isNot('sagan'));
      final original = await repo.find('user-a', 'sagan');
      expect(original!.name, 'Original');
      final imported = await repo.find('user-a', second.id);
      expect(imported!.name, 'Nuevo');
    },
  );

  test('el mismo id en cuentas distintas no interfiere', () async {
    await repo.create('user-a', _character('sagan', name: 'De A'));
    await repo.create('user-b', _character('sagan', name: 'De B'));

    expect((await repo.find('user-a', 'sagan'))!.name, 'De A');
    expect((await repo.find('user-b', 'sagan'))!.name, 'De B');
  });

  test('find de un personaje ajeno o inexistente devuelve null', () async {
    await repo.create('user-a', _character('sagan'));

    expect(await repo.find('user-b', 'sagan'), isNull);
    expect(await repo.find('user-a', 'no-existe'), isNull);
  });

  test(
    'listForUser solo devuelve los personajes de esa cuenta, alfabético',
    () async {
      await repo.create('user-a', _character('c1', name: 'Zora'));
      await repo.create('user-a', _character('c2', name: 'Anna'));
      await repo.create('user-b', _character('c3', name: 'Otra cuenta'));

      final list = await repo.listForUser('user-a');

      expect(list.map((c) => c.name), ['Anna', 'Zora']);
    },
  );

  test(
    'upsert actualiza un personaje ya asignado a esa cuenta sin cambiar su id',
    () async {
      await repo.create('user-a', _character('sagan', name: 'V1'));

      await repo.upsert('user-a', _character('sagan', name: 'V2'));

      expect((await repo.find('user-a', 'sagan'))!.name, 'V2');
      expect(await repo.existingIds('user-a'), {'sagan'});
    },
  );

  test('delete quita el personaje de esa cuenta', () async {
    await repo.create('user-a', _character('sagan'));

    await repo.delete('user-a', 'sagan');

    expect(await repo.find('user-a', 'sagan'), isNull);
  });

  test('el estado de combate sobrevive a una edición de equipo', () async {
    final withDamage = _character(
      'sagan',
    ).copyWith(combat: CombatState(currentHp: 3, deathSuccesses: 1));
    await repo.create('user-a', withDamage);

    final edited = withDamage.copyWith(equippedArmorId: 'chain-mail');
    await repo.upsert('user-a', edited);

    final reloaded = await repo.find('user-a', 'sagan');
    expect(reloaded!.combat.currentHp, 3);
    expect(reloaded.combat.deathSuccesses, 1);
    expect(reloaded.equippedArmorId, 'chain-mail');
  });
}
