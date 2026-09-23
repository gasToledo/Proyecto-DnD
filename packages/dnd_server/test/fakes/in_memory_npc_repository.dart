import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/npc_repository.dart';

import 'in_memory_campaign_repository.dart';
import 'in_memory_character_repository.dart';

/// Doble de [NpcRepository] en memoria para las pruebas HTTP.
///
/// Reproduce lo que en la base hacen las claves foráneas: un vínculo solo se
/// escribe si el PNJ y la campaña son del mismo DM, borrar la campaña se lleva
/// sus vínculos y borrar el PNJ los suyos.
class InMemoryNpcRepository implements NpcRepository {
  final InMemoryCampaignRepository _campaigns;
  final InMemoryCharacterRepository _characters;

  InMemoryNpcRepository(this._campaigns, this._characters) {
    _campaigns.onCampaignDeleted.add((dmUserId, campaignId) {
      _links.removeWhere(
        (key, _) => key.dmUserId == dmUserId && key.campaignId == campaignId,
      );
    });
  }

  final Map<String, Map<String, Npc>> _byDm = {};
  final Map<({String dmUserId, String campaignId, String npcId}), NpcStatus>
  _links = {};

  Object snapshot() => (
    byDm: {for (final e in _byDm.entries) e.key: Map.of(e.value)},
    links: Map.of(_links),
  );

  void restore(Object raw) {
    final s =
        raw
            as ({
              Map<String, Map<String, Npc>> byDm,
              Map<
                ({String dmUserId, String campaignId, String npcId}),
                NpcStatus
              >
              links,
            });
    _byDm
      ..clear()
      ..addAll(s.byDm);
    _links
      ..clear()
      ..addAll(s.links);
  }

  Future<StoredNpc> _stored(String dmUserId, Npc npc) async {
    final campaigns = <NpcCampaignLink>[];
    for (final entry in _links.entries) {
      if (entry.key.dmUserId != dmUserId || entry.key.npcId != npc.id) {
        continue;
      }
      final campaign = await _campaigns.find(dmUserId, entry.key.campaignId);
      if (campaign == null) continue;
      campaigns.add(
        NpcCampaignLink(
          campaignId: campaign.id,
          campaignName: campaign.name,
          status: entry.value,
        ),
      );
    }
    campaigns.sort((a, b) => a.campaignName.compareTo(b.campaignName));
    final sheetId = npc.characterId;
    return StoredNpc(
      npc: npc,
      campaigns: campaigns,
      sheet: sheetId == null
          ? null
          : await _characters.findNpcSheet(dmUserId, sheetId),
    );
  }

  @override
  Future<List<StoredNpc>> listForDm(String dmUserId) async {
    final all = (_byDm[dmUserId]?.values ?? const <Npc>[]).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [for (final npc in all) await _stored(dmUserId, npc)];
  }

  @override
  Future<StoredNpc?> find(String dmUserId, String id) async {
    final npc = _byDm[dmUserId]?[id];
    return npc == null ? null : _stored(dmUserId, npc);
  }

  @override
  Future<Set<String>> existingIds(String dmUserId) async =>
      _byDm[dmUserId]?.keys.toSet() ?? const {};

  @override
  Future<void> insert(String dmUserId, Npc npc) async {
    final existing = _byDm.putIfAbsent(dmUserId, () => {});
    if (existing.containsKey(npc.id)) {
      throw StateError('Clave primaria repetida: ${npc.id}');
    }
    existing[npc.id] = npc;
  }

  @override
  Future<bool> update(String dmUserId, Npc npc) async {
    final existing = _byDm[dmUserId];
    if (existing == null || !existing.containsKey(npc.id)) return false;
    existing[npc.id] = npc;
    return true;
  }

  @override
  Future<bool> delete(String dmUserId, String id) async {
    final removed = _byDm[dmUserId]?.remove(id);
    _links.removeWhere((key, _) => key.dmUserId == dmUserId && key.npcId == id);
    return removed != null;
  }

  @override
  Future<List<CampaignNpc>> listForCampaign(
    String dmUserId,
    String campaignId,
  ) async {
    final result = <CampaignNpc>[];
    for (final entry in _links.entries) {
      if (entry.key.dmUserId != dmUserId ||
          entry.key.campaignId != campaignId) {
        continue;
      }
      final npc = _byDm[dmUserId]?[entry.key.npcId];
      if (npc == null) continue;
      final stored = await _stored(dmUserId, npc);
      result.add(
        CampaignNpc(npc: npc, status: entry.value, sheet: stored.sheet),
      );
    }
    result.sort((a, b) => a.npc.name.compareTo(b.npc.name));
    return result;
  }

  @override
  Future<NpcStatus?> link(
    String dmUserId,
    String campaignId,
    String npcId, {
    NpcStatus? status,
  }) async {
    if (await _campaigns.find(dmUserId, campaignId) == null) return null;
    if (_byDm[dmUserId]?[npcId] == null) return null;
    final key = (dmUserId: dmUserId, campaignId: campaignId, npcId: npcId);
    final next = status ?? _links[key] ?? NpcStatus.alive;
    _links[key] = next;
    return next;
  }

  @override
  Future<bool> unlink(String dmUserId, String campaignId, String npcId) async =>
      _links.remove((
        dmUserId: dmUserId,
        campaignId: campaignId,
        npcId: npcId,
      )) !=
      null;

  @override
  Future<void> markDead(
    String dmUserId,
    String campaignId,
    Iterable<String> npcIds,
  ) async {
    for (final id in npcIds) {
      final key = (dmUserId: dmUserId, campaignId: campaignId, npcId: id);
      if (_links.containsKey(key)) _links[key] = NpcStatus.dead;
    }
  }

  /// El estado de un vínculo, para las pruebas.
  NpcStatus? statusOf(String dmUserId, String campaignId, String npcId) =>
      _links[(dmUserId: dmUserId, campaignId: campaignId, npcId: npcId)];
}
