import 'package:dnd_server/src/repositories/repository_transaction_runner.dart';

import 'in_memory_campaign_repository.dart';
import 'in_memory_chapter_repository.dart';
import 'in_memory_character_repository.dart';
import 'in_memory_event_repository.dart';

class InMemoryRepositoryTransactionRunner
    implements RepositoryTransactionRunner {
  final InMemoryCharacterRepository characters;
  final InMemoryCampaignRepository campaigns;
  final InMemoryChapterRepository chapters;
  final InMemoryEventRepository events;
  int runCount = 0;

  InMemoryRepositoryTransactionRunner({
    required this.characters,
    required this.campaigns,
    required this.chapters,
    required this.events,
  });

  @override
  Future<T> run<T>(
    Future<T> Function(TransactionRepositories repositories) operation,
  ) async {
    runCount++;
    final characterSnapshot = characters.snapshot();
    final campaignSnapshot = campaigns.snapshot();
    final chapterSnapshot = chapters.snapshot();
    final eventSnapshot = events.snapshot();
    try {
      return await operation(
        TransactionRepositories(
          characters: characters,
          campaigns: campaigns,
          chapters: chapters,
          events: events,
        ),
      );
    } catch (_) {
      characters.restore(characterSnapshot);
      campaigns.restore(campaignSnapshot);
      chapters.restore(chapterSnapshot);
      events.restore(eventSnapshot);
      rethrow;
    }
  }
}
