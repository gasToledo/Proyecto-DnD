import 'package:postgres/postgres.dart';

import 'campaign_repository.dart';
import 'chapter_repository.dart';
import 'character_repository.dart';
import 'encounter_repository.dart';
import 'event_repository.dart';
import 'homebrew_repository.dart';
import 'npc_repository.dart';

class TransactionRepositories {
  final CharacterRepository characters;
  final CampaignRepository campaigns;
  final ChapterRepository chapters;
  final EventRepository events;

  /// Los PNJ entran a la transacción porque crear uno con ficha escribe dos
  /// tablas, y borrarlo se lleva la ficha.
  final NpcRepository npcs;

  /// El combate entra porque cerrarlo y marcar muertos a los PNJ caídos tiene
  /// que pasar todo junto o nada: un combate archivado con los muertos sin
  /// marcar obligaría al DM a acordarse de hacerlo a mano.
  final EncounterRepository encounters;

  /// El homebrew entra porque importar un PNJ puede traer el contenido que usa
  /// su ficha, y un PNJ importado sin ese contenido no abriría.
  final HomebrewRepository homebrew;

  const TransactionRepositories({
    required this.characters,
    required this.campaigns,
    required this.chapters,
    required this.events,
    required this.npcs,
    required this.encounters,
    required this.homebrew,
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
        npcs: PostgresNpcRepository(session),
        encounters: PostgresEncounterRepository(session),
        homebrew: PostgresHomebrewRepository(session),
      ),
    ),
  );
}
