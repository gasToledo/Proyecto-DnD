import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import 'id_allocation.dart';

/// Contrato de persistencia de los capítulos de una campaña.
///
/// No cruza cuentas: un capítulo es del DM y ningún jugador lo lee. Aun así la
/// autorización viaja **dentro de cada consulta** (`dm_user_id` en el `WHERE`),
/// como en todo el resto del proyecto, para que no exista forma de llamar a un
/// método de acá y saltearla.
abstract class ChapterRepository {
  /// Los capítulos de una campaña, en orden de alta. Vacío si la campaña no es
  /// de este DM, sin distinguirlo de una campaña sin capítulos.
  Future<List<Chapter>> listFor(String dmUserId, String campaignId);

  /// Crea un capítulo. Si el id ya existe en la campaña se guarda con uno
  /// libre, nunca se sobrescribe, igual que `CampaignRepository.create`.
  Future<Chapter> create(String dmUserId, String campaignId, Chapter chapter);

  /// `null` si no existe o no es de este DM: la ausencia y el acceso cruzado no
  /// se distinguen.
  Future<Chapter?> find(String dmUserId, String campaignId, String id);

  Future<void> upsert(String dmUserId, String campaignId, Chapter chapter);

  Future<void> delete(String dmUserId, String campaignId, String id);
}

class PostgresChapterRepository implements ChapterRepository {
  final Session _session;

  const PostgresChapterRepository(this._session);

  @override
  Future<List<Chapter>> listFor(String dmUserId, String campaignId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM chapters
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId
        ORDER BY created_at
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    return [for (final row in result) Chapter.fromJson(_documentOf(row))];
  }

  @override
  Future<Chapter> create(
    String dmUserId,
    String campaignId,
    Chapter chapter,
  ) async {
    var candidate = chapter;
    while (true) {
      try {
        await _insert(dmUserId, campaignId, candidate);
        return candidate;
      } on UniqueViolationException {
        candidate = Chapter.fromJson(
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

  Future<void> _insert(String dmUserId, String campaignId, Chapter chapter) =>
      _session.execute(
        Sql.named('''
          INSERT INTO chapters (dm_user_id, campaign_id, id, document)
          VALUES (@dmUserId, @campaignId, @id, @document)
        '''),
        parameters: {
          'dmUserId': TypedValue(Type.uuid, dmUserId),
          'campaignId': TypedValue(Type.text, campaignId),
          'id': TypedValue(Type.text, chapter.id),
          'document': TypedValue(Type.jsonb, chapter.toJson()),
        },
      );

  @override
  Future<Chapter?> find(String dmUserId, String campaignId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM chapters
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    return Chapter.fromJson(_documentOf(result.first));
  }

  @override
  Future<void> upsert(
    String dmUserId,
    String campaignId,
    Chapter chapter,
  ) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO chapters (dm_user_id, campaign_id, id, document, updated_at)
        VALUES (@dmUserId, @campaignId, @id, @document, now())
        ON CONFLICT (dm_user_id, campaign_id, id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'id': TypedValue(Type.text, chapter.id),
        'document': TypedValue(Type.jsonb, chapter.toJson()),
      },
    );
  }

  @override
  Future<void> delete(String dmUserId, String campaignId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM chapters
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'id': TypedValue(Type.text, id),
      },
    );
  }

  Map<String, dynamic> _documentOf(ResultRow row) =>
      (row.toColumnMap()['document'] as Map).cast<String, dynamic>();

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
