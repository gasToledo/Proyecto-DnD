import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import 'character_repository.dart';

/// Guarda varios personajes como una única operación lógica: todo o nada.
///
/// La atomicidad la aporta la transacción de Postgres (`Pool.runTx`): si
/// [characters] lanza una excepción al construirse, o [PostgresCharacterRepository.upsert]
/// falla para cualquiera de ellos, `runTx` revierte la transacción completa y
/// ningún documento de esta llamada queda modificado. Esta función no agrega
/// lógica de reintento ni de compensación propia porque no la necesita: basta
/// con que todas las escrituras compartan la misma sesión transaccional.
Future<void> saveCharactersAtomically(
  Pool pool,
  String userId,
  Iterable<Character> characters,
) {
  return pool.runTx((session) async {
    final repo = PostgresCharacterRepository(session);
    for (final character in characters) {
      await repo.upsert(userId, character);
    }
  });
}
