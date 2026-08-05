import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/character_repository.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';

/// Doble de [CharacterRepository] en memoria, para probar el contrato
/// (propiedad por cuenta, asignación de id libre, no sobrescritura) sin una
/// base de datos real. `upsertAllOrNothing` no forma parte del contrato: solo
/// existe para simular, en las pruebas, la garantía transaccional que en
/// producción aporta `Pool.runTx` (ver `saveCharactersAtomically`).
class InMemoryCharacterRepository implements CharacterRepository {
  final Map<String, Map<String, Character>> _byUser = {};

  @override
  Future<Character> create(String userId, Character character) async {
    final existing = _byUser.putIfAbsent(userId, () => {});
    var attempt = 0;
    final id = resolveStorageId(
      requestedId: character.id,
      existingIds: existing.keys.toSet(),
      fallbackId: () => 'generated-${attempt++}',
    );
    final stored = id == character.id
        ? character
        : Character.fromJson(character.toJson()..['id'] = id);
    existing[id] = stored;
    return stored;
  }

  @override
  Future<void> upsert(String userId, Character character) async {
    _byUser.putIfAbsent(userId, () => {})[character.id] = character;
  }

  @override
  Future<Character?> find(String userId, String id) async =>
      _byUser[userId]?[id];

  @override
  Future<List<Character>> listForUser(String userId) async {
    final chars = (_byUser[userId]?.values ?? const <Character>[]).toList();
    chars.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return chars;
  }

  @override
  Future<void> delete(String userId, String id) async {
    _byUser[userId]?.remove(id);
  }

  @override
  Future<Set<String>> existingIds(String userId) async =>
      _byUser[userId]?.keys.toSet() ?? const {};

  /// Simula lo que `Pool.runTx` garantiza en producción: si [action] lanza en
  /// cualquier punto, ningún cambio hecho a través de [batch] durante esta
  /// llamada queda aplicado al repositorio real.
  Future<void> upsertAllOrNothing(
    String userId,
    Future<void> Function(CharacterRepository batch) action,
  ) async {
    final before = Map<String, Character>.of(_byUser[userId] ?? const {});
    final staging = InMemoryCharacterRepository()
      .._byUser[userId] = Map.of(before);
    try {
      await action(staging);
      _byUser[userId] = staging._byUser[userId]!;
    } catch (_) {
      _byUser[userId] = before;
      rethrow;
    }
  }
}
