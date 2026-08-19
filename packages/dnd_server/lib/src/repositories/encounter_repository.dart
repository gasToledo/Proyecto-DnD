import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

/// Contrato de persistencia del combate activo de una campaña, y de su log al
/// cerrarlo.
///
/// Es la segunda parte del servidor (después de `CampaignRepository`) que
/// cruza cuentas: [turnFor] es la única consulta acá que la ejecuta el
/// **jugador**, no el DM, y su autorización vive en el propio `WHERE` como en
/// todo lo demás de campañas — sin un vínculo suyo a esa campaña, no hay
/// combate que ver.
abstract class EncounterRepository {
  /// El combate abierto de [campaignId], o `null` si no hay ninguno o la
  /// campaña no es de [dmUserId]. Los dos casos no se distinguen.
  Future<Encounter?> find(String dmUserId, String campaignId);

  /// Guarda el documento entero. No hay operaciones fïnas de "avanzar turno"
  /// o "dañar monstruo": el cliente del DM es dueño del estado y lo manda
  /// completo en cada acción, así que acá no hay nada que se pueda
  /// desincronizar entre rutas.
  Future<void> save(String dmUserId, String campaignId, Encounter encounter);

  /// Cierra el combate: borra la fila de `encounters` y archiva [log] en
  /// `encounter_logs`. Si no había combate abierto, no hace nada — silencioso,
  /// como cualquier borrado del proyecto que no encuentra qué borrar.
  Future<void> close(
    String dmUserId,
    String campaignId,
    Map<String, dynamic> log,
  );

  /// El turno de [characterId], visto por su dueño [userId]. `none` si el
  /// personaje no está vinculado a ninguna campaña con combate abierto — el
  /// mismo valor que si el vínculo o el combate no existieran, para no
  /// filtrar cuál de los dos casos fue.
  Future<TurnStatus> turnFor({
    required String userId,
    required String characterId,
  });
}

class PostgresEncounterRepository implements EncounterRepository {
  final Session _session;

  const PostgresEncounterRepository(this._session);

  @override
  Future<Encounter?> find(String dmUserId, String campaignId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM encounters
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    if (result.isEmpty) return null;
    return Encounter.fromJson(_documentOf(result.first));
  }

  @override
  Future<void> save(
    String dmUserId,
    String campaignId,
    Encounter encounter,
  ) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO encounters (dm_user_id, campaign_id, document, updated_at)
        VALUES (@dmUserId, @campaignId, @document, now())
        ON CONFLICT (dm_user_id, campaign_id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'document': TypedValue(Type.jsonb, encounter.toJson()),
      },
    );
  }

  /// Borrar el combate y archivar el log es **una sola sentencia**, igual que
  /// el canje de un código de compartir: si no hay combate abierto, `removed`
  /// no devuelve filas y el `INSERT` no inserta nada, sin necesidad de una
  /// comprobación previa ni de abrir una transacción aparte.
  @override
  Future<void> close(
    String dmUserId,
    String campaignId,
    Map<String, dynamic> log,
  ) async {
    await _session.execute(
      Sql.named('''
        WITH removed AS (
          DELETE FROM encounters
          WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId
          RETURNING dm_user_id, campaign_id
        )
        INSERT INTO encounter_logs (dm_user_id, campaign_id, document)
        SELECT dm_user_id, campaign_id, @document FROM removed
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'document': TypedValue(Type.jsonb, log),
      },
    );
  }

  @override
  Future<TurnStatus> turnFor({
    required String userId,
    required String characterId,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT m.id AS member_id, e.document
        FROM campaign_members m
        JOIN encounters e
          ON e.dm_user_id = m.dm_user_id AND e.campaign_id = m.campaign_id
        WHERE m.owner_user_id = @userId AND m.character_id = @characterId
        LIMIT 1
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'characterId': TypedValue(Type.text, characterId),
      },
    );
    if (result.isEmpty) return TurnStatus.none;
    final columns = result.first.toColumnMap();
    final encounter = Encounter.fromJson(
      (columns['document'] as Map).cast<String, dynamic>(),
    );
    return encounter.statusFor(columns['member_id'] as String);
  }

  Map<String, dynamic> _documentOf(ResultRow row) =>
      (row.toColumnMap()['document'] as Map).cast<String, dynamic>();
}
