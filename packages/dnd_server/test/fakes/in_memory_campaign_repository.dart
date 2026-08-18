import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/campaign_repository.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';
import 'package:dnd_server/src/sharing/share_code.dart';

import 'in_memory_character_repository.dart';

class _StoredShareCode {
  final String ownerUserId;
  final String characterId;
  final DateTime expiresAt;

  const _StoredShareCode({
    required this.ownerUserId,
    required this.characterId,
    required this.expiresAt,
  });
}

/// Doble de [CampaignRepository] en memoria para las pruebas HTTP.
///
/// Necesita el repositorio de personajes porque el vínculo es una referencia:
/// listar los miembros de una campaña es leer las fichas reales de sus dueños,
/// no copias guardadas al vincular.
class InMemoryCampaignRepository implements CampaignRepository {
  final InMemoryCharacterRepository _characters;

  InMemoryCampaignRepository(this._characters);

  final Map<String, Map<String, Campaign>> _byDm = {};
  final Map<String, _StoredShareCode> _codes = {};
  final List<CampaignLink> _links = [];
  int _memberCounter = 0;

  /// Los ids de vínculo son UUID en la base y los handlers validan su forma,
  /// así que el doble tiene que producir algo con esa misma forma.
  String _nextMemberId() =>
      '00000000-0000-4000-8000-${(_memberCounter++).toString().padLeft(12, '0')}';

  /// La clave foránea de la base borra en cascada los vínculos de un personaje
  /// que ya no existe. Acá se hace al leer, que produce lo mismo de cara afuera.
  Future<void> _pruneDeletedCharacters() async {
    final dead = <CampaignLink>[];
    for (final link in _links) {
      if (await _characters.find(link.ownerUserId, link.characterId) == null) {
        dead.add(link);
      }
    }
    _links.removeWhere(dead.contains);
  }

  @override
  Future<Campaign> create(String dmUserId, Campaign campaign) async {
    final existing = _byDm.putIfAbsent(dmUserId, () => {});
    var attempt = 0;
    final id = resolveStorageId(
      requestedId: campaign.id,
      existingIds: existing.keys.toSet(),
      fallbackId: () => 'generated-${attempt++}',
    );
    final stored = id == campaign.id
        ? campaign
        : Campaign.fromJson(campaign.toJson()..['id'] = id);
    existing[id] = stored;
    return stored;
  }

  @override
  Future<void> upsert(String dmUserId, Campaign campaign) async {
    _byDm.putIfAbsent(dmUserId, () => {})[campaign.id] = campaign;
  }

  @override
  Future<Campaign?> find(String dmUserId, String id) async =>
      _byDm[dmUserId]?[id];

  @override
  Future<List<Campaign>> listForDm(String dmUserId) async {
    final all = (_byDm[dmUserId]?.values ?? const <Campaign>[]).toList();
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  @override
  Future<void> delete(String dmUserId, String id) async {
    _byDm[dmUserId]?.remove(id);
    _links.removeWhere((l) => l.dmUserId == dmUserId && l.campaignId == id);
  }

  @override
  Future<String> createShareCode({
    required String ownerUserId,
    required String characterId,
    Duration ttl = PostgresCampaignRepository.defaultShareTtl,
  }) async {
    _codes.removeWhere((_, c) => !c.expiresAt.isAfter(DateTime.now().toUtc()));
    final code = generateShareCode();
    _codes[hashShareCode(code)] = _StoredShareCode(
      ownerUserId: ownerUserId,
      characterId: characterId,
      expiresAt: DateTime.now().toUtc().add(ttl),
    );
    return code;
  }

  @override
  Future<CampaignLink?> redeemShareCode({
    required String dmUserId,
    required String campaignId,
    required String code,
  }) async {
    final hash = hashShareCode(code);
    final stored = _codes[hash];
    if (stored == null) return null;
    if (!stored.expiresAt.isAfter(DateTime.now().toUtc())) {
      _codes.remove(hash);
      return null;
    }
    // La sentencia real revierte entera si la campaña no es del DM, así que el
    // código no se quema. El doble tiene que respetarlo o la prueba mentiría.
    if (_byDm[dmUserId]?[campaignId] == null) return null;
    _codes.remove(hash);

    final existing = _links
        .where(
          (l) =>
              l.dmUserId == dmUserId &&
              l.campaignId == campaignId &&
              l.ownerUserId == stored.ownerUserId &&
              l.characterId == stored.characterId,
        )
        .firstOrNull;
    if (existing != null) return existing;

    final link = CampaignLink(
      memberId: _nextMemberId(),
      dmUserId: dmUserId,
      campaignId: campaignId,
      ownerUserId: stored.ownerUserId,
      characterId: stored.characterId,
    );
    _links.add(link);
    return link;
  }

  @override
  Future<List<CampaignMember>> listMembers(
    String dmUserId,
    String campaignId,
  ) async {
    await _pruneDeletedCharacters();
    final members = <CampaignMember>[];
    for (final link in _links) {
      if (link.dmUserId != dmUserId || link.campaignId != campaignId) continue;
      final character = await _characters.find(
        link.ownerUserId,
        link.characterId,
      );
      if (character == null) continue;
      members.add(
        CampaignMember(memberId: link.memberId, character: character),
      );
    }
    members.sort(
      (a, b) => a.character.name.toLowerCase().compareTo(
        b.character.name.toLowerCase(),
      ),
    );
    return members;
  }

  @override
  Future<CampaignMember?> findMember({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  }) async {
    final link = await findMemberLink(
      dmUserId: dmUserId,
      campaignId: campaignId,
      memberId: memberId,
    );
    if (link == null) return null;
    final character = await _characters.find(
      link.ownerUserId,
      link.characterId,
    );
    if (character == null) return null;
    return CampaignMember(memberId: link.memberId, character: character);
  }

  @override
  Future<CampaignLink?> findMemberLink({
    required String dmUserId,
    required String campaignId,
    required String memberId,
  }) async {
    await _pruneDeletedCharacters();
    return _links
        .where(
          (l) =>
              l.memberId == memberId &&
              l.dmUserId == dmUserId &&
              l.campaignId == campaignId,
        )
        .firstOrNull;
  }

  @override
  Future<List<CharacterShare>> listSharesForCharacter({
    required String ownerUserId,
    required String characterId,
  }) async {
    await _pruneDeletedCharacters();
    final shares = [
      for (final link in _links)
        if (link.ownerUserId == ownerUserId && link.characterId == characterId)
          CharacterShare(
            memberId: link.memberId,
            dmUserId: link.dmUserId,
            campaignId: link.campaignId,
            campaignName: _byDm[link.dmUserId]?[link.campaignId]?.name ?? '',
          ),
    ];
    shares.sort(
      (a, b) =>
          a.campaignName.toLowerCase().compareTo(b.campaignName.toLowerCase()),
    );
    return shares;
  }

  @override
  Future<CampaignLink?> deleteMember(String userId, String memberId) async {
    final link = _links
        .where(
          (l) =>
              l.memberId == memberId &&
              (l.dmUserId == userId || l.ownerUserId == userId),
        )
        .firstOrNull;
    if (link == null) return null;
    _links.remove(link);
    return link;
  }
}
