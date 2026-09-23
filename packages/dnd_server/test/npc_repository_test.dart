import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/npc_repository.dart';
import 'package:test/test.dart';

import 'fakes/recording_session.dart';

void main() {
  late RecordingSession session;
  late PostgresNpcRepository repository;

  setUp(() {
    session = RecordingSession();
    repository = PostgresNpcRepository(session);
  });

  Map<String, Object?> row(
    String id,
    String name, {
    List<Map<String, dynamic>> campaigns = const [],
    Map<String, dynamic>? sheet,
  }) => {
    'document': Npc(id: id, name: name, sheetKind: NpcSheetKind.none).toJson(),
    'sheet': sheet,
    'campaigns': campaigns,
  };

  // La biblioteca trae las campañas y el estado de cada PNJ en la misma
  // lectura: con una consulta por PNJ, abrirla con cien PNJ serían cien viajes
  // a la base (el mismo problema que resolvió `eliminate-campaigns-n-plus-one`).
  test('lee la biblioteca entera con una sola sentencia', () async {
    session.nextRows = [
      for (var i = 0; i < 50; i++)
        row(
          'npc-$i',
          'PNJ $i',
          campaigns: [
            {'campaignId': 'a', 'campaignName': 'Alfa', 'status': 'dead'},
          ],
        ),
    ];

    final all = await repository.listForDm(
      '11111111-1111-1111-1111-111111111111',
    );

    expect(session.executedCount, 1);
    expect(all, hasLength(50));
    expect(all.first.campaigns.single.campaignName, 'Alfa');
    expect(all.first.campaigns.single.status, NpcStatus.dead);
    expect(all.first.sheet, isNull);
  });

  test('un PNJ sin campañas llega con la lista vacía', () async {
    session.nextRows = [row('npc-1', 'Toblen')];

    final all = await repository.listForDm(
      '11111111-1111-1111-1111-111111111111',
    );

    expect(all.single.npc.name, 'Toblen');
    expect(all.single.campaigns, isEmpty);
  });
}
