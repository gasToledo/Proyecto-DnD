import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/chapter_repository.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';

import 'in_memory_campaign_repository.dart';

/// Doble de [ChapterRepository] en memoria para las pruebas HTTP.
///
/// Se engancha al borrado de campañas para reproducir la clave foránea en
/// cascada: borrada la campaña, sus capítulos dejan de existir en el acto.
class InMemoryChapterRepository implements ChapterRepository {
  InMemoryChapterRepository(InMemoryCampaignRepository campaigns) {
    campaigns.onCampaignDeleted.add(
      (dmUserId, campaignId) => _byCampaign.remove(_key(dmUserId, campaignId)),
    );
  }

  /// Capítulos por `dmUserId|campaignId`, en orden de alta — el mismo que
  /// devuelve el `ORDER BY created_at` real, y que `Map`/`List` conservan
  /// sin necesidad de un reloj.
  final Map<String, List<Chapter>> _byCampaign = {};
  int _generatedIdCounter = 0;

  /// Ganchos que corren al borrar un capítulo, para que los fakes que cuelgan
  /// de él reproduzcan su clave foránea en cascada — hoy, las notas.
  final List<void Function(String dmUserId, String campaignId, String id)>
  onChapterDeleted = [];

  String _key(String dmUserId, String campaignId) => '$dmUserId|$campaignId';

  @override
  Future<List<Chapter>> listFor(String dmUserId, String campaignId) async => [
    ...?_byCampaign[_key(dmUserId, campaignId)],
  ];

  @override
  Future<Chapter> create(
    String dmUserId,
    String campaignId,
    Chapter chapter,
  ) async {
    final existing = _byCampaign.putIfAbsent(
      _key(dmUserId, campaignId),
      () => [],
    );
    final id = resolveStorageId(
      requestedId: chapter.id,
      existingIds: {for (final c in existing) c.id},
      fallbackId: () => 'generated-${_generatedIdCounter++}',
    );
    final stored = id == chapter.id
        ? chapter
        : Chapter.fromJson(chapter.toJson()..['id'] = id);
    existing.add(stored);
    return stored;
  }

  @override
  Future<Chapter?> find(String dmUserId, String campaignId, String id) async =>
      _byCampaign[_key(dmUserId, campaignId)]
          ?.where((c) => c.id == id)
          .firstOrNull;

  @override
  Future<void> upsert(
    String dmUserId,
    String campaignId,
    Chapter chapter,
  ) async {
    final existing = _byCampaign.putIfAbsent(
      _key(dmUserId, campaignId),
      () => [],
    );
    final at = existing.indexWhere((c) => c.id == chapter.id);
    // Reemplazar en su lugar y no borrar+agregar: el orden de la lista es el
    // orden de alta, y editar un capítulo no lo manda al final.
    if (at < 0) {
      existing.add(chapter);
    } else {
      existing[at] = chapter;
    }
  }

  @override
  Future<void> delete(String dmUserId, String campaignId, String id) async {
    _byCampaign[_key(dmUserId, campaignId)]?.removeWhere((c) => c.id == id);
    for (final cascade in onChapterDeleted) {
      cascade(dmUserId, campaignId, id);
    }
  }
}
