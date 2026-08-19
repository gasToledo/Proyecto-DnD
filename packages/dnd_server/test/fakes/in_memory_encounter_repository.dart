import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/encounter_repository.dart';

import 'in_memory_campaign_repository.dart';

/// Doble de [EncounterRepository] en memoria para las pruebas HTTP.
///
/// Necesita el repositorio de campañas por la misma razón que
/// [InMemoryCampaignRepository] necesita el de personajes: [turnFor] resuelve
/// primero a qué campañas está vinculado el personaje (vía
/// `listSharesForCharacter`, que ya trae el `memberId`) y recién ahí mira si
/// alguna de esas campañas tiene un combate abierto.
class InMemoryEncounterRepository implements EncounterRepository {
  final InMemoryCampaignRepository _campaigns;

  InMemoryEncounterRepository(this._campaigns) {
    // Reproduce la clave foránea en cascada: borrada la campaña, su combate
    // abierto y sus logs se van con ella, en el acto.
    _campaigns.onCampaignDeleted.add((dmUserId, campaignId) {
      _byCampaign.remove(_key(dmUserId, campaignId));
      logs.removeWhere(
        (l) => l.dmUserId == dmUserId && l.campaignId == campaignId,
      );
    });
  }

  final Map<String, Encounter> _byCampaign = {};

  /// Los logs cerrados, expuestos para que las pruebas comprueben que quedan
  /// grabados. No hay UI que los lea todavía (ver plan de la Fase 2), así que
  /// la única forma de verificarlos hoy es leer esta lista directamente.
  final List<
    ({String dmUserId, String campaignId, Map<String, dynamic> document})
  >
  logs = [];

  String _key(String dmUserId, String campaignId) => '$dmUserId|$campaignId';

  @override
  Future<Encounter?> find(String dmUserId, String campaignId) async =>
      _byCampaign[_key(dmUserId, campaignId)];

  @override
  Future<void> save(
    String dmUserId,
    String campaignId,
    Encounter encounter,
  ) async {
    _byCampaign[_key(dmUserId, campaignId)] = encounter;
  }

  @override
  Future<void> close(
    String dmUserId,
    String campaignId,
    Map<String, dynamic> log,
  ) async {
    final removed = _byCampaign.remove(_key(dmUserId, campaignId));
    if (removed == null) return;
    logs.add((dmUserId: dmUserId, campaignId: campaignId, document: log));
  }

  @override
  Future<void> discard(String dmUserId, String campaignId) async {
    _byCampaign.remove(_key(dmUserId, campaignId));
  }

  @override
  Future<TurnStatus> turnFor({
    required String userId,
    required String characterId,
  }) async {
    final shares = await _campaigns.listSharesForCharacter(
      ownerUserId: userId,
      characterId: characterId,
    );
    // Igual que el `INNER JOIN` real: se queda con la primera membresía que
    // tenga un combate abierto y devuelve su estado tal cual, sin seguir
    // buscando una mejor — el `LIMIT 1` de la consulta real tampoco lo hace.
    for (final share in shares) {
      final encounter = _byCampaign[_key(share.dmUserId, share.campaignId)];
      if (encounter != null) return encounter.statusFor(share.memberId);
    }
    return TurnStatus.none;
  }
}
