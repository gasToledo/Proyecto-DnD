import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/character_repository.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';

/// Doble de [CharacterRepository] en memoria para las pruebas HTTP.
///
/// Reproduce la separación por tipo de la tabla real: las fichas de PNJ viven
/// en el mismo mapa pero ninguna lectura de jugador las ve. Un doble que las
/// mostrara dejaría pasar justo el error que las pruebas negativas buscan.
class InMemoryCharacterRepository implements CharacterRepository {
  final Map<String, Map<String, Character>> _byUser = {};

  /// Ids de las fichas de PNJ por cuenta, como la columna `kind = 'npc'`.
  final Map<String, Set<String>> _npcSheets = {};

  /// Fecha de alta por (cuenta, id), como la columna `created_at`. El reloj
  /// avanza de a un milisegundo por alta en vez de leer la hora real: así el
  /// orden por antigüedad es determinista aunque dos altas ocurran en el mismo
  /// instante, que en una prueba es lo normal.
  final Map<String, Map<String, DateTime>> _createdAt = {};
  int _clock = 0;

  Object snapshot() => (
    byUser: {
      for (final entry in _byUser.entries) entry.key: Map.of(entry.value),
    },
    npcSheets: {
      for (final entry in _npcSheets.entries) entry.key: Set.of(entry.value),
    },
    createdAt: {
      for (final entry in _createdAt.entries) entry.key: Map.of(entry.value),
    },
    clock: _clock,
  );

  void restore(Object raw) {
    final snapshot =
        raw
            as ({
              Map<String, Map<String, Character>> byUser,
              Map<String, Set<String>> npcSheets,
              Map<String, Map<String, DateTime>> createdAt,
              int clock,
            });
    _byUser
      ..clear()
      ..addAll(snapshot.byUser);
    _npcSheets
      ..clear()
      ..addAll(snapshot.npcSheets);
    _createdAt
      ..clear()
      ..addAll(snapshot.createdAt);
    _clock = snapshot.clock;
  }

  bool _isNpc(String userId, String id) =>
      _npcSheets[userId]?.contains(id) ?? false;

  DateTime _stamp(String userId, String id) => _createdAt
      .putIfAbsent(userId, () => {})
      .putIfAbsent(id, () => DateTime.fromMillisecondsSinceEpoch(_clock++));

  @override
  Future<Character> create(String userId, Character character) =>
      _create(userId, character, npc: false);

  @override
  Future<Character> createNpcSheet(String userId, Character character) =>
      _create(userId, character, npc: true);

  Future<Character> _create(
    String userId,
    Character character, {
    required bool npc,
  }) async {
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
    if (npc) _npcSheets.putIfAbsent(userId, () => {}).add(id);
    _stamp(userId, id);
    return stored;
  }

  /// Como en la tabla, guardar no cambia el tipo de la fila.
  @override
  Future<void> upsert(String userId, Character character) async {
    _byUser.putIfAbsent(userId, () => {})[character.id] = character;
    // Solo fija la fecha si el personaje no existía: editar no lo vuelve nuevo.
    _stamp(userId, character.id);
  }

  @override
  Future<Character?> find(String userId, String id) async {
    if (_isNpc(userId, id)) return null;
    return _byUser[userId]?[id];
  }

  @override
  Future<Character?> findNpcSheet(String userId, String id) async {
    if (!_isNpc(userId, id)) return null;
    return _byUser[userId]?[id];
  }

  @override
  Future<List<StoredCharacter>> listForUser(String userId) async {
    final chars = [
      for (final c in _byUser[userId]?.values ?? const <Character>[])
        if (!_isNpc(userId, c.id)) c,
    ];
    chars.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (final c in chars)
        StoredCharacter(character: c, createdAt: _stamp(userId, c.id)),
    ];
  }

  @override
  Future<bool> delete(String userId, String id) async {
    if (_isNpc(userId, id)) return false;
    return _byUser[userId]?.remove(id) != null;
  }

  @override
  Future<void> deleteNpcSheet(String userId, String id) async {
    if (!_isNpc(userId, id)) return;
    _byUser[userId]?.remove(id);
    _npcSheets[userId]?.remove(id);
  }

  @override
  Future<Set<String>> existingIds(String userId) async =>
      _byUser[userId]?.keys.toSet() ?? const {};

  @override
  Future<bool> exists(String userId, String id) async =>
      !_isNpc(userId, id) && (_byUser[userId]?.containsKey(id) ?? false);
}
