import 'package:dnd_server/src/repositories/campaign_repository.dart';
import 'package:test/test.dart';

import 'fakes/recording_session.dart';

void main() {
  late RecordingSession session;
  late PostgresCampaignRepository repository;

  setUp(() {
    session = RecordingSession();
    repository = PostgresCampaignRepository(session);
  });

  test(
    'lee todas las campañas del jugador con una sentencia agrupada',
    () async {
      session.nextRows = [
        _projectionRow(
          memberId: 'member-a',
          campaignId: 'campaign-a',
          campaignName: 'Alfa',
          party: ['Mirna'],
          chapters: [
            {
              'schemaVersion': 1,
              'id': 'chapter-a',
              'name': 'La cripta',
              'state': 'completed',
              'grantsLevel': false,
              'grantsGold': 250,
              'grantsItems': <String>[],
            },
          ],
          battles: [
            {
              'schemaVersion': 1,
              'id': 'battle-a',
              'rounds': 4,
              'players': ['Sagan'],
              'monsters': <Map<String, dynamic>>[],
            },
          ],
        ),
        _projectionRow(
          memberId: 'member-b',
          campaignId: 'campaign-b',
          campaignName: 'Beta',
        ),
      ];

      final projections = await repository.listPlayerCampaignProjection(
        ownerUserId: '11111111-1111-1111-1111-111111111111',
        characterId: 'sagan',
      );

      expect(session.executedCount, 1);
      expect(projections, hasLength(2));
      expect(projections.map((projection) => projection.campaign.name), [
        'Alfa',
        'Beta',
      ]);
      expect(projections.first.memberId, 'member-a');
      expect(projections.first.party, ['Mirna']);
      expect(projections.first.chapters.single.summary, isEmpty);
      expect(projections.first.battles.single.rounds, 4);
      expect(projections.last.party, isEmpty);
      expect(projections.last.chapters, isEmpty);
      expect(projections.last.battles, isEmpty);
    },
  );
}

Map<String, Object?> _projectionRow({
  required String memberId,
  required String campaignId,
  required String campaignName,
  List<String> party = const [],
  List<Map<String, dynamic>> chapters = const [],
  List<Map<String, dynamic>> battles = const [],
}) => {
  'member_id': memberId,
  'campaign_document': {
    'schemaVersion': 1,
    'id': campaignId,
    'name': campaignName,
    'premise': '',
    'state': 'active',
  },
  'party': party,
  'chapters': chapters,
  'battles': battles,
};
