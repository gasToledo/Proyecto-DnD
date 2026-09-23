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
///
/// **Dos clases de fila comparten la tabla**: los personajes jugadores y las
/// fichas de los PNJ del DM (`kind = 'npc'`). Todo lo que sirve a las rutas de
/// personajes —[find], [listForUser], [exists], [delete]— ve **solo jugadores**,
/// y el filtro va dentro de la consulta: una ficha de PNJ no aparece en «Mis
/// personajes», no se borra por la ruta de personajes y no puede compartirse.
/// Las fichas de PNJ se leen, crean y borran únicamente por los métodos
/// `*NpcSheet`, que usa el repositorio de PNJ.
abstract class CharacterRepository {
  /// Crea un personaje nuevo. Si [character.id] ya existe en la cuenta, se
  /// guarda con un id libre en su lugar (nunca sobrescribe). Devuelve el
  /// personaje con el id efectivamente usado.
  Future<Character> create(String userId, Character character);

  /// Actualiza (o crea) un personaje cuyo id ya se considera asignado a esa
  /// cuenta: a diferencia de [create], no reasigna id ante colisión, porque
  /// la colisión es justamente "es el mismo documento".
  ///
  /// **Nunca cambia el tipo de la fila**: guardar la ficha de un PNJ por esta
  /// vía la deja como PNJ. Es como la ficha de un PNJ se guarda desde la app,
  /// con la misma pantalla que la de un jugador.
  Future<void> upsert(String userId, Character character);

  /// `null` si no existe, pertenece a otra cuenta o es la ficha de un PNJ: la
  /// ausencia y el acceso cruzado no MUST NOT distinguirse en la respuesta
  /// (ver capacidad `user-accounts`).
  Future<Character?> find(String userId, String id);

  Future<List<StoredCharacter>> listForUser(String userId);

  /// Borra un personaje jugador. Devuelve si borró algo: una ficha de PNJ no
  /// se toca, y quien llama no debe tocar tampoco sus retratos.
  Future<bool> delete(String userId, String id);

  /// Los ids de **todas** las filas de la cuenta, jugadores y PNJ: se usa para
  /// que un id nuevo no choque con ninguno, porque comparten la clave primaria
  /// y el espacio del almacén de retratos.
  Future<Set<String>> existingIds(String userId);

  /// Crea la ficha de un PNJ, con la misma regla de ids que [create].
  Future<Character> createNpcSheet(String userId, Character character);

  /// La ficha de un PNJ, o `null` si no existe, es de otra cuenta o es un
  /// personaje jugador.
  Future<Character?> findNpcSheet(String userId, String id);

  /// Borra la ficha de un PNJ, y solo eso.
  Future<void> deleteNpcSheet(String userId, String id);

  /// Si [id] existe en la cuenta, sin traer el documento. Es lo que preguntan
  /// las rutas que solo necesitan saber que el personaje es propio —la del
  /// turno se consulta cada pocos segundos por ficha abierta—, y leer y migrar
  /// la ficha entera para eso era trabajo tirado.
  Future<bool> exists(String userId, String id);
}

class PostgresCharacterRepository implements CharacterRepository {
  final Session _session;

  const PostgresCharacterRepository(this._session);

  @override
  Future<Character> create(String userId, Character character) =>
      _createAs(userId, character, 'player');

  @override
  Future<Character> createNpcSheet(String userId, Character character) =>
      _createAs(userId, character, 'npc');

  Future<Character> _createAs(
    String userId,
    Character character,
    String kind,
  ) async {
    var candidate = character;
    while (true) {
      try {
        await _insert(userId, candidate, kind);
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

  Future<void> _insert(String userId, Character character, String kind) =>
      _session.execute(
        Sql.named('''
          INSERT INTO characters (user_id, id, document, kind)
          VALUES (@userId, @id, @document, @kind)
        '''),
        parameters: {
          'userId': TypedValue(Type.uuid, userId),
          'id': TypedValue(Type.text, character.id),
          'document': TypedValue(Type.jsonb, character.toJson()),
          'kind': TypedValue(Type.text, kind),
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
  Future<Character?> find(String userId, String id) =>
      _findAs(userId, id, 'player');

  @override
  Future<Character?> findNpcSheet(String userId, String id) =>
      _findAs(userId, id, 'npc');

  Future<Character?> _findAs(String userId, String id, String kind) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM characters
        WHERE user_id = @userId AND id = @id AND kind = @kind
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, id),
        'kind': TypedValue(Type.text, kind),
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
        WHERE user_id = @userId AND kind = 'player'
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
  Future<bool> delete(String userId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        DELETE FROM characters
        WHERE user_id = @userId AND id = @id AND kind = 'player'
        RETURNING id
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, id),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> deleteNpcSheet(String userId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM characters
        WHERE user_id = @userId AND id = @id AND kind = 'npc'
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

  @override
  Future<bool> exists(String userId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT 1 FROM characters
        WHERE user_id = @userId AND id = @id AND kind = 'player'
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'id': TypedValue(Type.text, id),
      },
    );
    return result.isNotEmpty;
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
