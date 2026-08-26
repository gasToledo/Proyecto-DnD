import 'package:dnd_server/src/repositories/event_repository.dart';

/// Doble de [EventRepository] en memoria para las pruebas HTTP.
class InMemoryEventRepository implements EventRepository {
  final Map<String, List<UserEvent>> _byUser = {};
  final Set<String> _seen = {};
  int _counter = 0;
  Object? failAppendWith;

  Object snapshot() => (
    byUser: {
      for (final entry in _byUser.entries) entry.key: List.of(entry.value),
    },
    seen: Set.of(_seen),
    counter: _counter,
  );

  void restore(Object raw) {
    final snapshot =
        raw
            as ({
              Map<String, List<UserEvent>> byUser,
              Set<String> seen,
              int counter,
            });
    _byUser
      ..clear()
      ..addAll(snapshot.byUser);
    _seen
      ..clear()
      ..addAll(snapshot.seen);
    _counter = snapshot.counter;
  }

  /// Los ids son UUID en la base y los handlers validan su forma.
  String _nextId() =>
      '00000000-0000-4000-9000-${(_counter++).toString().padLeft(12, '0')}';

  @override
  Future<void> append(
    String userId,
    String kind,
    Map<String, dynamic> payload,
  ) async {
    if (failAppendWith case final failure?) throw failure;
    _byUser
        .putIfAbsent(userId, () => [])
        .add(
          UserEvent(
            id: _nextId(),
            kind: kind,
            payload: payload,
            // Contador en vez del reloj real: dos avisos del mismo instante
            // tienen que quedar ordenados igual en cada corrida.
            createdAt: DateTime.fromMillisecondsSinceEpoch(_counter),
          ),
        );
  }

  @override
  Future<List<UserEvent>> listUnseen(String userId) async => [
    for (final event in _byUser[userId] ?? const <UserEvent>[])
      if (!_seen.contains(event.id)) event,
  ];

  @override
  Future<void> markSeen(String userId, List<String> ids) async {
    final own = {for (final e in _byUser[userId] ?? const <UserEvent>[]) e.id};
    // Marcar un aviso ajeno no falla, simplemente no hace nada: quien manda un
    // id que no es suyo no debe poder distinguirlo de uno inexistente.
    _seen.addAll(ids.where(own.contains));
  }
}
