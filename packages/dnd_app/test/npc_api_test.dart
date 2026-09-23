import 'dart:convert';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/fake_api_server.dart';

void main() {
  late FakeApiServer server;
  late ApiClient api;

  setUp(() {
    server = FakeApiServer()
      ..campaigns['mesa'] = const Campaign(id: 'mesa', name: 'La mesa');
    api = ApiClient(client: server.client);
  });

  const bandit = Creature(
    id: 'bandit',
    name: 'Bandido',
    source: ContentSource.srd2024,
    ac: '12',
    hp: '11',
  );

  group('ApiClient — PNJ', () {
    test('crea, lista, vincula y cambia el estado', () async {
      final created = await api.createNpc(
        Npc(
          id: 'ignorado',
          name: 'Garrick',
          sheetKind: NpcSheetKind.block,
          block: bandit,
          baseCreatureName: 'Bandido',
        ),
      );
      expect(created.npc.id, isNot('ignorado'));

      expect(
        await api.linkCampaignNpc('mesa', created.npc.id),
        NpcStatus.alive,
      );
      expect(
        await api.linkCampaignNpc(
          'mesa',
          created.npc.id,
          status: NpcStatus.unknown,
        ),
        NpcStatus.unknown,
      );
      // Sin estado, un vínculo existente queda como estaba.
      expect(
        await api.linkCampaignNpc('mesa', created.npc.id),
        NpcStatus.unknown,
      );

      final library = await api.listNpcs();
      expect(library.single.campaigns.single.campaignName, 'La mesa');
      expect(library.single.statusIn('mesa'), NpcStatus.unknown);

      final inCampaign = await api.listCampaignNpcs('mesa');
      expect(inCampaign.single.npc.block!.hp, '11');
    });

    test('un PNJ con ficha trae su ficha', () async {
      final created = await api.createNpc(
        Npc(id: 'x', name: 'Maerith', sheetKind: NpcSheetKind.character),
        sheet: Character(
          id: 'x',
          name: 'Maerith',
          raceId: 'human',
          classId: 'wizard',
          backgroundId: 'sage',
          assignedScores: const {},
        ),
      );
      expect(created.sheet!.name, 'Maerith');
      expect(created.npc.characterId, created.sheet!.id);
      expect(await api.getNpc('npc-no-existe'), isNull);
    });

    test('terminar manda los muertos solo cuando se archiva', () async {
      final bodies = <String>[];
      final recording = ApiClient(
        client: MockClient((request) async {
          bodies.add(request.body);
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }),
      );

      await recording.endEncounter('mesa', deadNpcIds: ['npc-1']);
      await recording.endEncounter(
        'mesa',
        discard: true,
        deadNpcIds: ['npc-1'],
      );
      await recording.endEncounter('mesa');

      expect(jsonDecode(bodies[0]), {
        'deadNpcIds': ['npc-1'],
      });
      expect(bodies[1], isEmpty);
      expect(bodies[2], isEmpty);
    });
  });

  group('FakeApiServer — las mismas podas que el servidor', () {
    test('la ficha de un PNJ no aparece entre los personajes', () async {
      await api.createNpc(
        Npc(id: 'x', name: 'Maerith', sheetKind: NpcSheetKind.character),
        sheet: Character(
          id: 'x',
          name: 'Maerith',
          raceId: 'human',
          classId: 'wizard',
          backgroundId: 'sage',
          assignedScores: const {},
        ),
      );
      expect(await api.listCharacters(), isEmpty);
    });

    test('la campaña vista por el jugador no nombra a ningún PNJ', () async {
      server.characters['mirna'] = Character(
        id: 'mirna',
        name: 'Mirna',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: const {},
      );
      server.campaignMembers['m1'] = (campaignId: 'mesa', characterId: 'mirna');
      final garrick = await api.createNpc(
        Npc(
          id: 'x',
          name: 'Garrick el Tuerto',
          sheetKind: NpcSheetKind.block,
          block: bandit,
          baseCreatureName: 'Bandido',
        ),
      );
      final ilse = await api.createNpc(
        Npc(id: 'x', name: 'Ilse', sheetKind: NpcSheetKind.none),
      );
      await api.linkCampaignNpc('mesa', garrick.npc.id);
      await api.linkCampaignNpc('mesa', ilse.npc.id);
      await api.saveEncounter(
        'mesa',
        Encounter(
          id: 'e',
          stage: EncounterStage.running,
          combatants: [
            const Combatant(
              id: 'p',
              kind: CombatantKind.player,
              name: 'Mirna',
              initiative: 12,
              memberId: 'm1',
            ),
            Combatant(
              id: 'g',
              kind: CombatantKind.npc,
              name: 'Garrick el Tuerto',
              initiative: 10,
              npcId: garrick.npc.id,
              maxHp: 11,
            ),
            Combatant(
              id: 'i',
              kind: CombatantKind.npc,
              name: 'Ilse',
              initiative: 9,
              npcId: ilse.npc.id,
            ),
          ],
        ),
      );

      await api.endEncounter('mesa', deadNpcIds: [garrick.npc.id]);

      expect(
        server.campaignNpcs[(campaignId: 'mesa', npcId: garrick.npc.id)],
        NpcStatus.dead,
      );
      final raw = await server.client.get(
        Uri.parse('/api/characters/mirna/campaigns'),
      );
      expect(raw.body, isNot(contains('Garrick')));
      expect(raw.body, isNot(contains('Ilse')));
      expect(raw.body, contains('Bandido'));
    });
  });
}
