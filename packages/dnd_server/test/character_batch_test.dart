import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import 'fakes/in_memory_character_repository.dart';

Character _character(String id) => Character(
  id: id,
  name: id,
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  assignedScores: const {},
);

void main() {
  // `upsertAllOrNothing` simula, sobre el repositorio de prueba, la garantía
  // que en producción aporta la transacción de `Pool.runTx` que usa
  // `saveCharactersAtomically`: estas pruebas verifican la política de
  // atomicidad (todo o nada), no la transacción real de Postgres, que
  // requiere una base de datos viva para probarse en los hechos.
  test(
    'un fallo a mitad de una escritura por lotes no deja nada modificado',
    () async {
      final repo = InMemoryCharacterRepository();
      await repo.create('user-a', _character('previo'));

      await expectLater(
        repo.upsertAllOrNothing('user-a', (batch) async {
          await batch.upsert('user-a', _character('nuevo-1'));
          await batch.upsert('user-a', _character('nuevo-2'));
          throw StateError('falla procesando el tercero');
        }),
        throwsA(isA<StateError>()),
      );

      final ids = await repo.existingIds('user-a');
      expect(ids, {'previo'});
    },
  );

  test('un lote sin fallos aplica todos los documentos', () async {
    final repo = InMemoryCharacterRepository();

    await repo.upsertAllOrNothing('user-a', (batch) async {
      await batch.upsert('user-a', _character('nuevo-1'));
      await batch.upsert('user-a', _character('nuevo-2'));
    });

    expect(await repo.existingIds('user-a'), {'nuevo-1', 'nuevo-2'});
  });

  test(
    'un lote sobre una cuenta que ya tiene datos falla sin tocarlos',
    () async {
      final repo = InMemoryCharacterRepository();
      await repo.create('user-a', _character('existente'));
      await repo.create('user-b', _character('de-otra-cuenta'));

      await expectLater(
        repo.upsertAllOrNothing('user-a', (batch) async {
          await batch.upsert('user-a', _character('parcial'));
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await repo.existingIds('user-a'), {'existente'});
      expect(await repo.existingIds('user-b'), {'de-otra-cuenta'});
    },
  );
}
