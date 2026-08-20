import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import 'id_allocation.dart';

/// Contrato de persistencia de las notas del Cuaderno de campaña.
///
/// No cruza cuentas: una nota es del DM y ningún jugador la lee, igual que la
/// descripción de un capítulo. Aun así la autorización viaja **dentro de cada
/// consulta** (`dm_user_id` en el `WHERE`), como en todo el resto del proyecto,
/// para que no exista forma de llamar a un método de acá y saltearla.
abstract class NoteRepository {
  /// Las notas de una campaña, agrupadas por capítulo y de la más vieja a la
  /// más nueva dentro de cada uno. Vacío si la campaña no es de este DM, sin
  /// distinguirlo de una campaña sin notas.
  Future<List<Note>> listFor(String dmUserId, String campaignId);

  /// Crea una nota. Si el id ya existe en la campaña se guarda con uno libre,
  /// nunca se sobrescribe, igual que `ChapterRepository.create`.
  Future<Note> create(String dmUserId, String campaignId, Note note);

  /// `null` si no existe o no es de este DM: la ausencia y el acceso cruzado no
  /// se distinguen.
  Future<Note?> find(String dmUserId, String campaignId, String id);

  Future<void> upsert(String dmUserId, String campaignId, Note note);

  Future<void> delete(String dmUserId, String campaignId, String id);
}

class PostgresNoteRepository implements NoteRepository {
  final Session _session;

  const PostgresNoteRepository(this._session);

  @override
  Future<List<Note>> listFor(String dmUserId, String campaignId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document, updated_at FROM notes
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId
        ORDER BY chapter_id, created_at
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    return [for (final row in result) _noteOf(row)];
  }

  @override
  Future<Note> create(String dmUserId, String campaignId, Note note) async {
    var candidate = note;
    while (true) {
      try {
        await _insert(dmUserId, campaignId, candidate);
        return candidate;
      } on UniqueViolationException {
        candidate = Note.fromJson(
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

  Future<void> _insert(String dmUserId, String campaignId, Note note) =>
      _session.execute(
        Sql.named('''
          INSERT INTO notes (dm_user_id, campaign_id, chapter_id, id, document)
          VALUES (@dmUserId, @campaignId, @chapterId, @id, @document)
        '''),
        parameters: {
          'dmUserId': TypedValue(Type.uuid, dmUserId),
          'campaignId': TypedValue(Type.text, campaignId),
          'chapterId': TypedValue(Type.text, note.chapterId),
          'id': TypedValue(Type.text, note.id),
          'document': TypedValue(Type.jsonb, note.toJson()),
        },
      );

  @override
  Future<Note?> find(String dmUserId, String campaignId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document, updated_at FROM notes
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    return _noteOf(result.first);
  }

  /// Reguardar una nota puede moverla de capítulo, así que `chapter_id` también
  /// se actualiza: es columna propia y no solo un campo del documento porque
  /// de ella cuelga la clave foránea que borra las notas con su capítulo.
  @override
  Future<void> upsert(String dmUserId, String campaignId, Note note) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO notes (dm_user_id, campaign_id, chapter_id, id, document,
                           updated_at)
        VALUES (@dmUserId, @campaignId, @chapterId, @id, @document, now())
        ON CONFLICT (dm_user_id, campaign_id, id)
        DO UPDATE SET chapter_id = excluded.chapter_id,
                      document = excluded.document,
                      updated_at = now()
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'chapterId': TypedValue(Type.text, note.chapterId),
        'id': TypedValue(Type.text, note.id),
        'document': TypedValue(Type.jsonb, note.toJson()),
      },
    );
  }

  @override
  Future<void> delete(String dmUserId, String campaignId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM notes
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'id': TypedValue(Type.text, id),
      },
    );
  }

  /// La columna `updated_at` pisa lo que traiga el documento: la base es la
  /// fuente de verdad de cuándo se guardó, no lo que haya mandado el cliente.
  Note _noteOf(ResultRow row) {
    final columns = row.toColumnMap();
    final document = (columns['document'] as Map).cast<String, dynamic>();
    final updatedAt = columns['updated_at'] as DateTime?;
    return Note.fromJson({
      ...document,
      if (updatedAt != null) 'updatedAt': updatedAt.toIso8601String(),
    });
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
