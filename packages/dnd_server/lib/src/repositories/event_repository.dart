import 'package:postgres/postgres.dart';

/// Un aviso esperando a que su destinatario abra la aplicación.
class UserEvent {
  final String id;

  /// Qué pasó, en clave estable (`character_linked`, …). El texto en español
  /// lo redacta el cliente a partir de esto y de [payload]: guardar la frase
  /// armada obligaría a migrar la base para corregir una redacción.
  final String kind;

  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const UserEvent({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Contrato de los avisos entre cuentas.
///
/// Existen porque el resultado de una acción le llega solo a quien la ejecuta.
/// Que a un personaje lo echen de una campaña, o que un jugador se vaya, le
/// pasa a alguien que no estaba mirando la pantalla: sin esto, se enteraría
/// por notar que algo desapareció.
abstract class EventRepository {
  Future<void> append(String userId, String kind, Map<String, dynamic> payload);

  Future<List<UserEvent>> listUnseen(String userId);

  /// Marca vistos los avisos de [ids] **que pertenezcan a [userId]**. Los
  /// ajenos se ignoran en silencio en vez de fallar: quien manda un id que no
  /// es suyo no debe poder distinguir eso de un id inexistente.
  Future<void> markSeen(String userId, List<String> ids);
}

class PostgresEventRepository implements EventRepository {
  final Session _session;

  const PostgresEventRepository(this._session);

  @override
  Future<void> append(
    String userId,
    String kind,
    Map<String, dynamic> payload,
  ) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO user_events (user_id, kind, payload)
        VALUES (@userId, @kind, @payload)
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'kind': TypedValue(Type.text, kind),
        'payload': TypedValue(Type.jsonb, payload),
      },
    );
  }

  @override
  Future<List<UserEvent>> listUnseen(String userId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, kind, payload, created_at FROM user_events
        WHERE user_id = @userId AND seen_at IS NULL
        ORDER BY created_at
      '''),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    return [
      for (final columns in result.map((row) => row.toColumnMap()))
        UserEvent(
          id: columns['id'] as String,
          kind: columns['kind'] as String,
          payload: (columns['payload'] as Map).cast<String, dynamic>(),
          createdAt: columns['created_at'] as DateTime,
        ),
    ];
  }

  @override
  Future<void> markSeen(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    await _session.execute(
      Sql.named('''
        UPDATE user_events SET seen_at = now()
        WHERE user_id = @userId AND id = ANY(@ids) AND seen_at IS NULL
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'ids': TypedValue(Type.uuidArray, ids),
      },
    );
  }
}
