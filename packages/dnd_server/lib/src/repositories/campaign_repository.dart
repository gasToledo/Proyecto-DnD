import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import '../sharing/share_code.dart';
import 'id_allocation.dart';

/// Un personaje que un jugador compartió con una campaña.
///
/// Trae la ficha entera porque es lo que el DM mira, y el [memberId] porque es
/// con lo que se corta el vínculo.
class CampaignMember {
  final String memberId;
  final Character character;

  /// Cuenta dueña del personaje, para poder avisarle cuando pasa algo en la
  /// campaña (cerrar un capítulo, por ejemplo). **No se le muestra al DM**:
  /// los handlers arman la respuesta campo por campo y este no viaja, igual
  /// que el `dmUserId` de [CharacterShare].
  final String ownerUserId;

  const CampaignMember({
    required this.memberId,
    required this.character,
    required this.ownerUserId,
  });
}

/// El vínculo visto desde el lado del jugador: en qué campaña está metido este
/// personaje, para poder mostrarlo y para poder salirse.
///
/// Incluye [dmUserId] porque es a quien hay que avisarle cuando el jugador se
/// va o borra el personaje; ese dato no se le muestra al jugador.
class CharacterShare {
  final String memberId;
  final String dmUserId;
  final String campaignId;
  final String campaignName;

  const CharacterShare({
    required this.memberId,
    required this.dmUserId,
    required this.campaignId,
    required this.campaignName,
  });
}

/// Las cuatro puntas de un vínculo. Es lo que devuelve borrarlo, para poder
/// avisarle a la parte que no ejecutó la acción.
class CampaignLink {
  final String memberId;
  final String dmUserId;
  final String campaignId;
  final String ownerUserId;
  final String characterId;

  const CampaignLink({
    required this.memberId,
    required this.dmUserId,
    required this.campaignId,
    required this.ownerUserId,
    required this.characterId,
  });
}

/// Contrato de persistencia de campañas y del vínculo con personajes ajenos.
///
/// Es el único lugar del servidor donde una cuenta alcanza datos de otra, así
/// que la autorización viaja **dentro de cada consulta** y no repartida por los
/// handlers: no existe forma de llamar a un método de acá y saltearla.
abstract class CampaignRepository {
  /// Crea una campaña. Si el id ya existe en la cuenta se guarda con uno libre,
  /// nunca se sobrescribe, igual que `CharacterRepository.create`.
  Future<Campaign> create(String dmUserId, Campaign campaign);

  Future<void> upsert(String dmUserId, Campaign campaign);

  /// `null` si no existe o es de otro DM: la ausencia y el acceso cruzado no
  /// deben distinguirse (ver capacidad `user-accounts`).
  Future<Campaign?> find(String dmUserId, String id);

  Future<List<Campaign>> listForDm(String dmUserId);

  Future<void> delete(String dmUserId, String id);

  /// Emite un código de un solo uso para compartir [characterId]. Devuelve el
  /// código en claro, que es lo único que el servidor no vuelve a ver.
  Future<String> createShareCode({
    required String ownerUserId,
    required String characterId,
    Duration ttl,
  });

  /// Canjea [code] contra una campaña. `null` si el código no sirve —
  /// inexistente, vencido o ya usado, los tres indistinguibles.
  Future<CampaignLink?> redeemShareCode({
    required String dmUserId,
    required String campaignId,
    required String code,
  });

  /// Las fichas vinculadas a una campaña del DM. Vacío si la campaña no es
  /// suya, sin distinguirlo de una campaña sin jugadores.
  Future<List<CampaignMember>> listMembers(String dmUserId, String campaignId);

  /// Resuelve un vínculo a la ficha que apunta, solo si la campaña es del DM.
  Future<CampaignMember?> findMember({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  });

  /// Dueño del personaje detrás de un vínculo, para servir su retrato. Se
  /// devuelve por separado de la ficha porque el retrato se lee del
  /// almacenamiento del dueño, no del que mira.
  Future<CampaignLink?> findMemberLink({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  });

  /// En qué campañas está este personaje. Solo lo puede preguntar su dueño.
  Future<List<CharacterShare>> listSharesForCharacter({
    required String ownerUserId,
    required String characterId,
  });

  /// Corta el vínculo. Lo puede hacer cualquiera de las dos partes, y la
  /// autorización está en la propia sentencia. `null` si el vínculo no existe
  /// o quien pide no es parte de él.
  Future<CampaignLink?> deleteMember(String userId, String memberId);
}

class PostgresCampaignRepository implements CampaignRepository {
  final Session _session;

  const PostgresCampaignRepository(this._session);

  static const Duration defaultShareTtl = Duration(hours: 24);

  @override
  Future<Campaign> create(String dmUserId, Campaign campaign) async {
    var candidate = campaign;
    while (true) {
      try {
        await _insert(dmUserId, candidate);
        return candidate;
      } on UniqueViolationException {
        candidate = Campaign.fromJson(
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

  Future<void> _insert(String dmUserId, Campaign campaign) => _session.execute(
    Sql.named('''
          INSERT INTO campaigns (dm_user_id, id, document)
          VALUES (@dmUserId, @id, @document)
        '''),
    parameters: {
      'dmUserId': TypedValue(Type.uuid, dmUserId),
      'id': TypedValue(Type.text, campaign.id),
      'document': TypedValue(Type.jsonb, campaign.toJson()),
    },
  );

  @override
  Future<void> upsert(String dmUserId, Campaign campaign) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO campaigns (dm_user_id, id, document, updated_at)
        VALUES (@dmUserId, @id, @document, now())
        ON CONFLICT (dm_user_id, id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, campaign.id),
        'document': TypedValue(Type.jsonb, campaign.toJson()),
      },
    );
  }

  @override
  Future<Campaign?> find(String dmUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM campaigns
        WHERE dm_user_id = @dmUserId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    return Campaign.fromJson(_documentOf(result.first));
  }

  @override
  Future<List<Campaign>> listForDm(String dmUserId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT document FROM campaigns
        WHERE dm_user_id = @dmUserId
        ORDER BY name
      '''),
      parameters: {'dmUserId': TypedValue(Type.uuid, dmUserId)},
    );
    return [for (final row in result) Campaign.fromJson(_documentOf(row))];
  }

  @override
  Future<void> delete(String dmUserId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM campaigns WHERE dm_user_id = @dmUserId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
  }

  @override
  Future<String> createShareCode({
    required String ownerUserId,
    required String characterId,
    Duration ttl = defaultShareTtl,
  }) async {
    // El barrido va en el camino de escritura, igual que en las sesiones: es lo
    // único que hace crecer la tabla, así que es lo que paga la limpieza.
    await _session.execute(
      Sql.named('DELETE FROM character_share_codes WHERE expires_at <= now()'),
    );

    final code = generateShareCode();
    await _session.execute(
      Sql.named('''
        INSERT INTO character_share_codes
          (code_hash, owner_user_id, character_id, expires_at)
        VALUES (@codeHash, @ownerUserId, @characterId, @expiresAt)
      '''),
      parameters: {
        'codeHash': TypedValue(Type.text, hashShareCode(code)),
        'ownerUserId': TypedValue(Type.uuid, ownerUserId),
        'characterId': TypedValue(Type.text, characterId),
        'expiresAt': TypedValue(
          Type.timestampWithTimezone,
          DateTime.now().toUtc().add(ttl),
        ),
      },
    );
    return code;
  }

  /// Consumir el código y crear el vínculo es **una sola sentencia**, así que
  /// es atómica sin abrir una transacción: o pasan las dos cosas o no pasa
  /// ninguna.
  ///
  /// Si el `INSERT` viola la clave foránea porque la campaña no existe o es de
  /// otro DM, la sentencia entera se revierte y el código **no** se quema: un
  /// intento contra una campaña ajena no le cuesta su código al jugador.
  @override
  Future<CampaignLink?> redeemShareCode({
    required String dmUserId,
    required String campaignId,
    required String code,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        WITH claimed AS (
          DELETE FROM character_share_codes
          WHERE code_hash = @codeHash AND expires_at > now()
          RETURNING owner_user_id, character_id
        )
        INSERT INTO campaign_members
          (dm_user_id, campaign_id, owner_user_id, character_id)
        SELECT @dmUserId, @campaignId, owner_user_id, character_id FROM claimed
        ON CONFLICT (dm_user_id, campaign_id, owner_user_id, character_id)
        DO UPDATE SET linked_at = now()
        RETURNING id, owner_user_id, character_id
      '''),
      parameters: {
        'codeHash': TypedValue(Type.text, hashShareCode(code)),
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return CampaignLink(
      memberId: row['id'] as String,
      dmUserId: dmUserId,
      campaignId: campaignId,
      ownerUserId: row['owner_user_id'] as String,
      characterId: row['character_id'] as String,
    );
  }

  @override
  Future<List<CampaignMember>> listMembers(
    String dmUserId,
    String campaignId,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT m.id AS member_id, m.owner_user_id, c.document
        FROM campaign_members m
        JOIN characters c
          ON c.user_id = m.owner_user_id AND c.id = m.character_id
        WHERE m.dm_user_id = @dmUserId AND m.campaign_id = @campaignId
        ORDER BY c.name
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    return [
      for (final columns in result.map((row) => row.toColumnMap()))
        CampaignMember(
          memberId: columns['member_id'] as String,
          character: Character.fromJson(
            (columns['document'] as Map).cast<String, dynamic>(),
          ),
          ownerUserId: columns['owner_user_id'] as String,
        ),
    ];
  }

  @override
  Future<CampaignMember?> findMember({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT m.id AS member_id, m.owner_user_id, c.document
        FROM campaign_members m
        JOIN characters c
          ON c.user_id = m.owner_user_id AND c.id = m.character_id
        WHERE m.id = @memberId
          AND m.dm_user_id = @dmUserId
          AND m.campaign_id = @campaignId
      '''),
      parameters: {
        'memberId': TypedValue(Type.uuid, memberId),
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    if (result.isEmpty) return null;
    final columns = result.first.toColumnMap();
    return CampaignMember(
      memberId: columns['member_id'] as String,
      character: Character.fromJson(
        (columns['document'] as Map).cast<String, dynamic>(),
      ),
      ownerUserId: columns['owner_user_id'] as String,
    );
  }

  @override
  Future<CampaignLink?> findMemberLink({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, owner_user_id, character_id
        FROM campaign_members
        WHERE id = @memberId
          AND dm_user_id = @dmUserId
          AND campaign_id = @campaignId
      '''),
      parameters: {
        'memberId': TypedValue(Type.uuid, memberId),
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return CampaignLink(
      memberId: row['id'] as String,
      dmUserId: dmUserId,
      campaignId: campaignId,
      ownerUserId: row['owner_user_id'] as String,
      characterId: row['character_id'] as String,
    );
  }

  @override
  Future<List<CharacterShare>> listSharesForCharacter({
    required String ownerUserId,
    required String characterId,
  }) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT m.id AS member_id, m.dm_user_id, m.campaign_id, c.name
        FROM campaign_members m
        JOIN campaigns c
          ON c.dm_user_id = m.dm_user_id AND c.id = m.campaign_id
        WHERE m.owner_user_id = @ownerUserId
          AND m.character_id = @characterId
        ORDER BY c.name
      '''),
      parameters: {
        'ownerUserId': TypedValue(Type.uuid, ownerUserId),
        'characterId': TypedValue(Type.text, characterId),
      },
    );
    return [
      for (final columns in result.map((row) => row.toColumnMap()))
        CharacterShare(
          memberId: columns['member_id'] as String,
          dmUserId: columns['dm_user_id'] as String,
          campaignId: columns['campaign_id'] as String,
          campaignName: columns['name'] as String,
        ),
    ];
  }

  /// La autorización va en el `WHERE`, no en una comprobación previa: así no
  /// existe forma de borrar un vínculo del que no se es parte, ni siquiera
  /// llamando mal a este método.
  @override
  Future<CampaignLink?> deleteMember(String userId, String memberId) async {
    final result = await _session.execute(
      Sql.named('''
        DELETE FROM campaign_members
        WHERE id = @memberId
          AND (dm_user_id = @userId OR owner_user_id = @userId)
        RETURNING id, dm_user_id, campaign_id, owner_user_id, character_id
      '''),
      parameters: {
        'memberId': TypedValue(Type.uuid, memberId),
        'userId': TypedValue(Type.uuid, userId),
      },
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return CampaignLink(
      memberId: row['id'] as String,
      dmUserId: row['dm_user_id'] as String,
      campaignId: row['campaign_id'] as String,
      ownerUserId: row['owner_user_id'] as String,
      characterId: row['character_id'] as String,
    );
  }

  Map<String, dynamic> _documentOf(ResultRow row) =>
      (row.toColumnMap()['document'] as Map).cast<String, dynamic>();

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
