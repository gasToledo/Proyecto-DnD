import 'package:postgres/postgres.dart';

import 'campaign_repository.dart';
import 'chapter_repository.dart';
import 'character_repository.dart';
import 'event_repository.dart';

class TransactionRepositories {
  final CharacterRepository characters;
  final CampaignRepository campaigns;
  final ChapterRepository chapters;
  final EventRepository events;

  const TransactionRepositories({
    required this.characters,
    required this.campaigns,
    required this.chapters,
    required this.events,
  });
}

abstract class RepositoryTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(TransactionRepositories repositories) operation,
  );
}

class PostgresRepositoryTransactionRunner
    implements RepositoryTransactionRunner {
  final Pool pool;

  const PostgresRepositoryTransactionRunner(this.pool);

  @override
  Future<T> run<T>(
    Future<T> Function(TransactionRepositories repositories) operation,
  ) => pool.runTx(
    (session) => operation(
      TransactionRepositories(
        characters: PostgresCharacterRepository(session),
        campaigns: PostgresCampaignRepository(session),
        chapters: PostgresChapterRepository(session),
        events: PostgresEventRepository(session),
      ),
    ),
  );
}
