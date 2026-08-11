import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/character_repository.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';

/// Doble de [CharacterRepository] en memoria para las pruebas HTTP.
class InMemoryCharacterRepository implements CharacterRepository {
  final Map<String, Map<String, Character>> _byUser = {};

  /// Fecha de alta por (cuenta, id), como la columna `created_at`. El reloj
  /// avanza de a un milisegundo por alta en vez de leer la hora real: así el
  /// orden por antigüedad es determinista aunque dos altas ocurran en el mismo
  /// instante, que en una prueba es lo normal.
  final Map<String, Map<String, DateTime>> _createdAt = {};
  int _clock = 0;

  DateTime _stamp(String userId, String id) => _createdAt
      .putIfAbsent(userId, () => {})
      .putIfAbsent(id, () => DateTime.fromMillisecondsSinceEpoch(_clock++));

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
    _stamp(userId, id);
    return stored;
  }

  @override
  Future<void> upsert(String userId, Character character) async {
    _byUser.putIfAbsent(userId, () => {})[character.id] = character;
    // Solo fija la fecha si el personaje no existía: editar no lo vuelve nuevo.
    _stamp(userId, character.id);
  }

  @override
  Future<Character?> find(String userId, String id) async =>
      _byUser[userId]?[id];

  @override
  Future<List<StoredCharacter>> listForUser(String userId) async {
    final chars = (_byUser[userId]?.values ?? const <Character>[]).toList();
    chars.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (final c in chars)
        StoredCharacter(character: c, createdAt: _stamp(userId, c.id)),
    ];
  }

  @override
  Future<void> delete(String userId, String id) async {
    _byUser[userId]?.remove(id);
  }

  @override
  Future<Set<String>> existingIds(String userId) async =>
      _byUser[userId]?.keys.toSet() ?? const {};
}
