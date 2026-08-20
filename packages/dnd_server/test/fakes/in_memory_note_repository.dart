import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';
import 'package:dnd_server/src/repositories/note_repository.dart';

import 'in_memory_campaign_repository.dart';
import 'in_memory_chapter_repository.dart';

/// Doble de [NoteRepository] en memoria para las pruebas HTTP.
///
/// Se engancha a **dos** borrados para reproducir las claves foráneas en
/// cascada de la tabla real: la campaña se lleva sus notas, y el capítulo
/// también — una nota vive dentro de un capítulo y sin él no tendría dónde
/// mostrarse.
class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository(
    InMemoryCampaignRepository campaigns,
    InMemoryChapterRepository chapters,
  ) {
    campaigns.onCampaignDeleted.add(
      (dmUserId, campaignId) => _byCampaign.remove(_key(dmUserId, campaignId)),
    );
    chapters.onChapterDeleted.add(
      (dmUserId, campaignId, chapterId) =>
          _byCampaign[_key(dmUserId, campaignId)]?.removeWhere(
            (n) => n.chapterId == chapterId,
          ),
    );
  }

  /// Notas por `dmUserId|campaignId`, en orden de alta.
  final Map<String, List<Note>> _byCampaign = {};
  int _generatedIdCounter = 0;

  String _key(String dmUserId, String campaignId) => '$dmUserId|$campaignId';

  /// El real ordena por capítulo y después por alta; acá se reproduce igual
  /// para que la pantalla reciba el mismo orden en las pruebas que en la mesa.
  @override
  Future<List<Note>> listFor(String dmUserId, String campaignId) async {
    final all = [...?_byCampaign[_key(dmUserId, campaignId)]];
    final byChapter = <String, List<Note>>{};
    for (final note in all) {
      byChapter.putIfAbsent(note.chapterId, () => []).add(note);
    }
    final chapterIds = byChapter.keys.toList()..sort();
    return [for (final id in chapterIds) ...byChapter[id]!];
  }

  @override
  Future<Note> create(String dmUserId, String campaignId, Note note) async {
    final existing = _byCampaign.putIfAbsent(
      _key(dmUserId, campaignId),
      () => [],
    );
    final id = resolveStorageId(
      requestedId: note.id,
      existingIds: {for (final n in existing) n.id},
      fallbackId: () => 'generated-${_generatedIdCounter++}',
    );
    final stored = id == note.id
        ? note
        : Note.fromJson(note.toJson()..['id'] = id);
    existing.add(stored);
    return stored;
  }

  @override
  Future<Note?> find(String dmUserId, String campaignId, String id) async =>
      _byCampaign[_key(dmUserId, campaignId)]
          ?.where((n) => n.id == id)
          .firstOrNull;

  @override
  Future<void> upsert(String dmUserId, String campaignId, Note note) async {
    final existing = _byCampaign.putIfAbsent(
      _key(dmUserId, campaignId),
      () => [],
    );
    final at = existing.indexWhere((n) => n.id == note.id);
    // Reemplazar en su lugar: editar una nota no la manda al final del
    // capítulo, igual que con los capítulos.
    if (at < 0) {
      existing.add(note);
    } else {
      existing[at] = note;
    }
  }

  @override
  Future<void> delete(String dmUserId, String campaignId, String id) async {
    _byCampaign[_key(dmUserId, campaignId)]?.removeWhere((n) => n.id == id);
  }
}
