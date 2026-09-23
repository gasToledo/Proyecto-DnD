import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

/// En qué campaña está un PNJ y cómo está en ella.
class NpcCampaignLink {
  final String campaignId;
  final String campaignName;
  final NpcStatus status;

  const NpcCampaignLink({
    required this.campaignId,
    required this.campaignName,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'campaignId': campaignId,
    'campaignName': campaignName,
    'status': status.toJson(),
  };
}

/// Un PNJ de la biblioteca con lo que la biblioteca necesita mostrar al lado:
/// sus campañas y, si la tiene, su ficha de personaje.
class StoredNpc {
  final Npc npc;
  final List<NpcCampaignLink> campaigns;
  final Character? sheet;

  const StoredNpc({required this.npc, this.campaigns = const [], this.sheet});
}

/// Un PNJ visto desde una campaña: con su estado **en esa** campaña.
class CampaignNpc {
  final Npc npc;
  final NpcStatus status;
  final Character? sheet;

  const CampaignNpc({required this.npc, required this.status, this.sheet});
}

/// Contrato de persistencia de la biblioteca de PNJ y de sus vínculos con
/// campañas.
///
/// **Todo es de un solo dueño.** Cada consulta filtra por `dm_user_id = quien
/// pide` dentro del `WHERE`, y los vínculos no pueden cruzar cuentas porque sus
/// dos claves foráneas comparten `dm_user_id`. Lo ajeno y lo inexistente
/// devuelven lo mismo (`null`, `false`, lista vacía).
abstract class NpcRepository {
  /// La biblioteca entera, con campañas y ficha, en **una** lectura agrupada.
  Future<List<StoredNpc>> listForDm(String dmUserId);

  Future<StoredNpc?> find(String dmUserId, String id);

  /// Todos los ids de PNJ de la cuenta, para que uno nuevo no choque.
  Future<Set<String>> existingIds(String dmUserId);

  /// Guarda un PNJ nuevo con el id que trae (ya resuelto por quien llama).
  Future<void> insert(String dmUserId, Npc npc);

  /// Reemplaza el documento. `false` si no existe en la cuenta.
  Future<bool> update(String dmUserId, Npc npc);

  /// Borra el PNJ; sus vínculos caen en cascada. `false` si no había nada.
  Future<bool> delete(String dmUserId, String id);

  /// Los PNJ de una campaña con su estado en ella. Vacío si la campaña no es
  /// de [dmUserId].
  Future<List<CampaignNpc>> listForCampaign(String dmUserId, String campaignId);

  /// Vincula (o actualiza) un PNJ con una campaña, las dos de [dmUserId].
  ///
  /// Sin [status], un vínculo nuevo nace vivo y uno existente conserva el
  /// suyo: sumar dos veces el mismo PNJ no le cambia nada. Devuelve el estado
  /// que quedó, o `null` si el PNJ o la campaña no son de esa cuenta.
  Future<NpcStatus?> link(
    String dmUserId,
    String campaignId,
    String npcId, {
    NpcStatus? status,
  });

  /// Quita el vínculo, y solo el vínculo: el PNJ sigue en la biblioteca.
  Future<bool> unlink(String dmUserId, String campaignId, String npcId);

  /// Marca como muertos en [campaignId] a los [npcIds] que estén vinculados a
  /// ella. Los que no lo estén se ignoran.
  Future<void> markDead(
    String dmUserId,
    String campaignId,
    Iterable<String> npcIds,
  );
}

class PostgresNpcRepository implements NpcRepository {
  final Session _session;

  const PostgresNpcRepository(this._session);

  /// La ficha de personaje entra por `LEFT JOIN` filtrando `kind = 'npc'`: un
  /// PNJ nunca puede traerse la ficha de un personaje jugador, ni siquiera si
  /// alguien escribiera ese id a mano en su documento.
  @override
  Future<List<StoredNpc>> listForDm(String dmUserId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT n.document,
               sheet.document AS sheet,
               COALESCE(
                 jsonb_agg(
                   jsonb_build_object(
                     'campaignId', c.id,
                     'campaignName', c.name,
                     'status', cn.status
                   )
                   ORDER BY c.name
                 ) FILTER (WHERE c.id IS NOT NULL),
                 '[]'::jsonb
               ) AS campaigns
        FROM npcs n
        LEFT JOIN characters sheet
          ON sheet.user_id = n.dm_user_id
         AND sheet.id = n.character_id
         AND sheet.kind = 'npc'
        LEFT JOIN campaign_npcs cn
          ON cn.dm_user_id = n.dm_user_id AND cn.npc_id = n.id
        LEFT JOIN campaigns c
          ON c.dm_user_id = cn.dm_user_id AND c.id = cn.campaign_id
        WHERE n.dm_user_id = @dmUserId
        GROUP BY n.dm_user_id, n.id, n.name, n.document, sheet.document
        ORDER BY n.name
      '''),
      parameters: {'dmUserId': TypedValue(Type.uuid, dmUserId)},
    );
    return [for (final row in result) _storedOf(row.toColumnMap())];
  }

  @override
  Future<StoredNpc?> find(String dmUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT n.document,
               sheet.document AS sheet,
               COALESCE(
                 jsonb_agg(
                   jsonb_build_object(
                     'campaignId', c.id,
                     'campaignName', c.name,
                     'status', cn.status
                   )
                   ORDER BY c.name
                 ) FILTER (WHERE c.id IS NOT NULL),
                 '[]'::jsonb
               ) AS campaigns
        FROM npcs n
        LEFT JOIN characters sheet
          ON sheet.user_id = n.dm_user_id
         AND sheet.id = n.character_id
         AND sheet.kind = 'npc'
        LEFT JOIN campaign_npcs cn
          ON cn.dm_user_id = n.dm_user_id AND cn.npc_id = n.id
        LEFT JOIN campaigns c
          ON c.dm_user_id = cn.dm_user_id AND c.id = cn.campaign_id
        WHERE n.dm_user_id = @dmUserId AND n.id = @id
        GROUP BY n.dm_user_id, n.id, n.document, sheet.document
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    return _storedOf(result.first.toColumnMap());
  }

  @override
  Future<Set<String>> existingIds(String dmUserId) async {
    final result = await _session.execute(
      Sql.named('SELECT id FROM npcs WHERE dm_user_id = @dmUserId'),
      parameters: {'dmUserId': TypedValue(Type.uuid, dmUserId)},
    );
    return {for (final row in result) row.toColumnMap()['id'] as String};
  }

  @override
  Future<void> insert(String dmUserId, Npc npc) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO npcs (dm_user_id, id, document, character_id)
        VALUES (@dmUserId, @id, @document, @characterId)
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, npc.id),
        'document': TypedValue(Type.jsonb, npc.toJson()),
        'characterId': TypedValue(Type.text, npc.characterId),
      },
    );
  }

  /// No toca `character_id`: la ficha de un PNJ se fija al crearlo y no se
  /// reapunta editando el documento.
  @override
  Future<bool> update(String dmUserId, Npc npc) async {
    final result = await _session.execute(
      Sql.named('''
        UPDATE npcs SET document = @document, updated_at = now()
        WHERE dm_user_id = @dmUserId AND id = @id
        RETURNING id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, npc.id),
        'document': TypedValue(Type.jsonb, npc.toJson()),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> delete(String dmUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        DELETE FROM npcs WHERE dm_user_id = @dmUserId AND id = @id
        RETURNING id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<List<CampaignNpc>> listForCampaign(
    String dmUserId,
    String campaignId,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT n.document, cn.status, sheet.document AS sheet
        FROM campaign_npcs cn
        JOIN npcs n ON n.dm_user_id = cn.dm_user_id AND n.id = cn.npc_id
        LEFT JOIN characters sheet
          ON sheet.user_id = n.dm_user_id
         AND sheet.id = n.character_id
         AND sheet.kind = 'npc'
        WHERE cn.dm_user_id = @dmUserId AND cn.campaign_id = @campaignId
        ORDER BY n.name
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    return [
      for (final columns in result.map((row) => row.toColumnMap()))
        CampaignNpc(
          npc: Npc.fromJson(_object(columns['document'])!),
          status: NpcStatus.fromJson(columns['status'] as String?),
          sheet: _sheetOf(columns['sheet']),
        ),
    ];
  }

  /// `INSERT … SELECT` desde las dos filas del mismo dueño: si el PNJ o la
  /// campaña no son de [dmUserId], el `SELECT` no devuelve nada y no se
  /// escribe ningún vínculo.
  @override
  Future<NpcStatus?> link(
    String dmUserId,
    String campaignId,
    String npcId, {
    NpcStatus? status,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        INSERT INTO campaign_npcs (dm_user_id, campaign_id, npc_id, status)
        SELECT c.dm_user_id, c.id, n.id, COALESCE(@status, 'alive')
        FROM campaigns c
        JOIN npcs n ON n.dm_user_id = c.dm_user_id
        WHERE c.dm_user_id = @dmUserId
          AND c.id = @campaignId
          AND n.id = @npcId
        ON CONFLICT (dm_user_id, campaign_id, npc_id)
        DO UPDATE SET status = COALESCE(@status, campaign_npcs.status)
        RETURNING status
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'npcId': TypedValue(Type.text, npcId),
        'status': TypedValue(Type.text, status?.toJson()),
      },
    );
    if (result.isEmpty) return null;
    return NpcStatus.fromJson(result.first.toColumnMap()['status'] as String?);
  }

  @override
  Future<bool> unlink(String dmUserId, String campaignId, String npcId) async {
    final result = await _session.execute(
      Sql.named('''
        DELETE FROM campaign_npcs
        WHERE dm_user_id = @dmUserId
          AND campaign_id = @campaignId
          AND npc_id = @npcId
        RETURNING npc_id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'npcId': TypedValue(Type.text, npcId),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> markDead(
    String dmUserId,
    String campaignId,
    Iterable<String> npcIds,
  ) async {
    final ids = npcIds.toSet().toList();
    if (ids.isEmpty) return;
    await _session.execute(
      Sql.named('''
        UPDATE campaign_npcs SET status = 'dead'
        WHERE dm_user_id = @dmUserId
          AND campaign_id = @campaignId
          AND npc_id = ANY(@npcIds)
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'npcIds': TypedValue(Type.textArray, ids),
      },
    );
  }

  StoredNpc _storedOf(Map<String, dynamic> columns) => StoredNpc(
    npc: Npc.fromJson(_object(columns['document'])!),
    sheet: _sheetOf(columns['sheet']),
    campaigns: [
      for (final json in _objectList(columns['campaigns']))
        NpcCampaignLink(
          campaignId: json['campaignId'] as String,
          campaignName: json['campaignName'] as String? ?? '',
          status: NpcStatus.fromJson(json['status'] as String?),
        ),
    ],
  );

  Character? _sheetOf(Object? value) {
    final json = _object(value);
    return json == null ? null : Character.fromJson(json);
  }

  /// El driver devuelve `jsonb` ya decodificado; se tolera texto por si una
  /// versión del driver lo entrega crudo.
  Map<String, dynamic>? _object(Object? value) {
    final decoded = value is String ? jsonDecode(value) : value;
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  List<Map<String, dynamic>> _objectList(Object? value) {
    final decoded = value is String ? jsonDecode(value) : value;
    return [
      for (final item in decoded is List ? decoded : const [])
        if (item is Map) item.cast<String, dynamic>(),
    ];
  }
}
