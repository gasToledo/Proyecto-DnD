import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import 'id_allocation.dart';

/// Un personaje guardado, con los metadatos que la fila conoce y el documento
/// no. [createdAt] lo pone el servidor al insertar: el documento lo manda el
/// cliente, así que no puede declarar su propia antigüedad.
class StoredCharacter {
  final Character character;
  final DateTime createdAt;

  const StoredCharacter({required this.character, required this.createdAt});
}

/// Contrato de persistencia de personajes: documentos versionados,
/// propiedad por cuenta, atómicos frente a escrituras multi-documento (que
/// aporta quien orqueste varias llamadas dentro de una misma transacción de
/// [Session], no esta clase).
abstract class CharacterRepository {
  /// Crea un personaje nuevo. Si [character.id] ya existe en la cuenta, se
  /// guarda con un id libre en su lugar (nunca sobrescribe). Devuelve el
  /// personaje con el id efectivamente usado.
  Future<Character> create(String userId, Character character);

  /// Actualiza (o crea) un personaje cuyo id ya se considera asignado a esa
  /// cuenta: a diferencia de [create], no reasigna id ante colisión, porque
  /// la colisión es justamente "es el mismo documento".
  Future<void> upsert(String userId, Character character);

  /// `null` si no existe o pertenece a otra cuenta: la ausencia y el acceso
  /// cruzado no MUST NOT distinguirse en la respuesta (ver capacidad
  /// `user-accounts`).
  Future<Character?> find(String userId, String id);

  Future<List<StoredCharacter>> listForUser(String userId);

  Future<void> delete(String userId, String id);

  Future<Set<String>> existingIds(String userId);
}

class PostgresCharacterRepository implements CharacterRepository {
  final Session _session;

  const PostgresCharacterRepository(this._session);

  @override
  Future<Character> create(String userId, Character character) async {
    var candidate = character;
    while (true) {
      try {
        await _insert(userId, candidate);
        return candidate;
      } on UniqueViolationException {
        candidate = Character.fromJson(
          candidate.toJson()
            ..['id'] = resolveStorageId(
              requestedId: candidate.id,
              existingIds: {candidate.id},
              fallbackId: _generateId,
            ),
        );
      }
    }
  }

  Future<void> _insert(String userId, Character character) => _session.execute(
    Sql.named('''
          INSERT INTO characters (user_id, id, document)
          VALUES (@userId, @id, @document)
        '''),
    parameters: {
      'userId': TypedValue(Type.uuid, userId),
      'id': TypedValue(Type.text, character.id),
      'document': TypedValue(Type.jsonb, character.toJson()),
    },
  );

  @override
  Future<void> upsert(String userId, Character character) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO characters (user_id, id, document, updated_at)
        VALUES (@userId, @id, @document, now())
        ON CONFLICT (user_id, id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, character.id),
        'document': TypedValue(Type.jsonb, character.toJson()),
      },
    );
  }

  @override
  Future<Character?> find(String userId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM characters
        WHERE user_id = @userId AND id = @id
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    final document = (result.first.toColumnMap()['document'] as Map)
        .cast<String, dynamic>();
    return Character.fromJson(document);
  }

  @override
  Future<List<StoredCharacter>> listForUser(String userId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document, created_at FROM characters
        WHERE user_id = @userId
        ORDER BY name
      '''),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    return [
      for (final row in result)
        StoredCharacter(
          character: Character.fromJson(
            (row.toColumnMap()['document'] as Map).cast<String, dynamic>(),
          ),
          createdAt: row.toColumnMap()['created_at'] as DateTime,
        ),
    ];
  }

  @override
  Future<void> delete(String userId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM characters WHERE user_id = @userId AND id = @id
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, id),
      },
    );
  }

  @override
  Future<Set<String>> existingIds(String userId) async {
    final result = await _session.execute(
      Sql.named('SELECT id FROM characters WHERE user_id = @userId'),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    return {for (final row in result) row.toColumnMap()['id'] as String};
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
