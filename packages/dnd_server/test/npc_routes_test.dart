import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:dnd_server/src/import/npc_bundle.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_settings_repository.dart';

/// Rutas de PNJ del Modo DM y las fronteras que las rodean: que la ficha de un
/// PNJ nunca se comporte como la de un jugador y que ningún jugador vea un
/// dato de un PNJ.
void main() {
  late FakeAuthDependencies fakeAuth;
  late InMemoryPortraitBlobStore portraits;
  late InMemoryCharacterRepository characters;
  late InMemoryCampaignRepository campaigns;
  late InMemoryEncounterRepository encounters;
  late InMemoryNpcRepository npcs;
  late InMemoryHomebrewRepository homebrew;
  late Handler handler;

  setUp(() {
    fakeAuth = FakeAuthDependencies();
    portraits = InMemoryPortraitBlobStore();
    characters = InMemoryCharacterRepository();
    campaigns = InMemoryCampaignRepository(characters);
    final chapters = InMemoryChapterRepository(campaigns);
    final notes = InMemoryNoteRepository(campaigns, chapters);
    encounters = InMemoryEncounterRepository(campaigns);
    campaigns
      ..playerChaptersFor = chapters.listFor
      ..playerBattlesFor = encounters.logsFor;
    final events = InMemoryEventRepository();
    npcs = InMemoryNpcRepository(campaigns, characters);
    homebrew = InMemoryHomebrewRepository();
    handler = buildHandler(
      auth: fakeAuth.dependencies,
      portraits: portraits,
      generation: PortraitGenerationService([
        FakePortraitProvider(id: 'pollinations', name: 'Pollinations'),
      ]),
      importBackup: ({required userId, required bundle}) async =>
          const ImportResult(charactersImported: 0, portraitsImported: 0),
      importHomebrew: ({required userId, required content}) async => 0,
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      notes: notes,
      encounters: encounters,
      events: events,
      npcs: npcs,
      transactions: InMemoryRepositoryTransactionRunner(
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        events: events,
        npcs: npcs,
        encounters: encounters,
        homebrew: homebrew,
      ),
      homebrew: homebrew,
      settings: InMemorySettingsRepository(),
    );
  });

  Future<String> login(String subject) async {
    fakeAuth.nextVerifiedSubject = subject;
    final callback = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/auth/callback?code=c&state=x'),
      ),
    );
    return RegExp(
      r'dnd_session=([^;]+)',
    ).firstMatch(callback.headers['set-cookie']!)!.group(1)!;
  }

  String userIdOf(String subject) => fakeAuth.accountsBySubject[subject]!;

  Future<({int status, String body})> send(
    String method,
    String path, {
    required String token,
    Object? body,
  }) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'cookie': 'dnd_session=$token'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    // Tolerante porque algunas respuestas son imágenes, no texto.
    final bytes = await response.read().expand((chunk) => chunk).toList();
    return (
      status: response.statusCode,
      body: utf8.decode(bytes, allowMalformed: true),
    );
  }

  Map<String, dynamic> decode(String body) =>
      (jsonDecode(body) as Map).cast<String, dynamic>();

  Map<String, dynamic> characterJson(String id, {String name = 'Sagan'}) => {
    'id': id,
    'name': name,
    'raceId': 'human',
    'classId': 'fighter',
    'backgroundId': 'soldier',
    'assignedScores': <String, dynamic>{},
  };

  const bandit = Creature(
    id: 'bandit',
    name: 'Bandido',
    source: ContentSource.srd2024,
    kind: 'Humanoide Mediano o Pequeño, neutral',
    ac: '12',
    hp: '11',
  );

  Map<String, dynamic> npcJson(
    String name, {
    NpcSheetKind kind = NpcSheetKind.none,
    Creature? block,
    String id = 'lo-que-mande-el-cliente',
  }) => Npc(
    id: id,
    name: name,
    sheetKind: kind,
    block: block,
    baseCreatureId: block?.id,
    baseCreatureName: block?.name,
    background: 'TRASFONDO-SECRETO',
  ).toJson();

  Future<Map<String, dynamic>> createNpc(
    String token,
    String name, {
    NpcSheetKind kind = NpcSheetKind.none,
    Creature? block,
  }) async {
    final response = await send(
      'POST',
      '/api/npcs',
      token: token,
      body: {
        'npc': npcJson(name, kind: kind, block: block),
        if (kind == NpcSheetKind.character)
          'character': characterJson('villano', name: name),
      },
    );
    expect(response.status, 200, reason: response.body);
    return decode(response.body);
  }

  Future<void> createCampaign(String token, String id) async {
    final response = await send(
      'POST',
      '/api/campaigns',
      token: token,
      body: {
        'campaign': {'id': id, 'name': 'Campaña $id'},
      },
    );
    expect(response.status, 200, reason: response.body);
  }

  Uint8List png() =>
      Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

  group('la ficha de un PNJ no es un personaje', () {
    test('no aparece en el listado de personajes', () async {
      final token = await login('dm');
      await send(
        'POST',
        '/api/characters',
        token: token,
        body: {'character': characterJson('sagan')},
      );
      await createNpc(token, 'Maerith', kind: NpcSheetKind.character);

      final listed = decode(
        (await send('GET', '/api/characters', token: token)).body,
      );
      expect(
        [for (final c in listed['characters']) c['character']['name']],
        ['Sagan'],
      );
    });

    test('borrarla por la ruta de personajes no la toca', () async {
      final token = await login('dm');
      final created = await createNpc(
        token,
        'Maerith',
        kind: NpcSheetKind.character,
      );
      final sheetId = created['npc']['characterId'] as String;
      final key = await portraits.save(
        userId: userIdOf('dm'),
        characterId: sheetId,
        bytes: png(),
      );

      final deleted = await send(
        'DELETE',
        '/api/characters/$sheetId',
        token: token,
      );

      expect(deleted.status, 200);
      expect(await characters.findNpcSheet(userIdOf('dm'), sheetId), isNotNull);
      expect(
        await portraits.read(userId: userIdOf('dm'), portraitKey: key),
        isNotNull,
      );
    });

    test('no se le puede pedir un código para compartir', () async {
      final token = await login('dm');
      final created = await createNpc(
        token,
        'Maerith',
        kind: NpcSheetKind.character,
      );
      final sheetId = created['npc']['characterId'] as String;

      final shared = await send(
        'POST',
        '/api/characters/$sheetId/share',
        token: token,
      );

      expect(shared.status, 404);
    });

    test(
      'un código que apunta a una ficha de PNJ no la sienta a la mesa',
      () async {
        final token = await login('dm');
        await createCampaign(token, 'mesa');
        final created = await createNpc(
          token,
          'Maerith',
          kind: NpcSheetKind.character,
        );
        final code = campaigns.plantShareCode(
          ownerUserId: userIdOf('dm'),
          characterId: created['npc']['characterId'] as String,
        );

        final redeemed = await send(
          'POST',
          '/api/campaigns/mesa/members',
          token: token,
          body: {'code': code},
        );

        expect(redeemed.status, 404);
        final members = decode(
          (await send('GET', '/api/campaigns/mesa/members', token: token)).body,
        );
        expect(members['members'], isEmpty);
      },
    );
  });

  group('/api/npcs', () {
    test('crea los tres tipos con id del servidor', () async {
      final token = await login('dm');
      final none = await createNpc(token, 'Toblen');
      final block = await createNpc(
        token,
        'Garrick',
        kind: NpcSheetKind.block,
        block: bandit,
      );
      final sheet = await createNpc(
        token,
        'Maerith',
        kind: NpcSheetKind.character,
      );

      expect(none['npc']['id'], startsWith('npc-'));
      expect(none['npc'], isNot(contains('block')));
      expect(block['npc']['block']['hp'], '11');
      expect(block['npc']['baseCreatureName'], 'Bandido');
      expect(sheet['character']['name'], 'Maerith');
      expect(sheet['npc']['characterId'], sheet['character']['id']);

      final listed = decode(
        (await send('GET', '/api/npcs', token: token)).body,
      );
      expect([
        for (final n in listed['npcs']) n['npc']['name'],
      ], containsAll(['Toblen', 'Garrick', 'Maerith']));
    });

    test('sin nombre no se crea', () async {
      final token = await login('dm');
      final response = await send(
        'POST',
        '/api/npcs',
        token: token,
        body: {'npc': npcJson('  ')},
      );
      expect(response.status, 400);
    });

    test('un PNJ ajeno responde igual que uno inexistente', () async {
      final tokenA = await login('dm-a');
      final created = await createNpc(tokenA, 'Toblen');
      final id = created['npc']['id'] as String;
      final tokenB = await login('dm-b');

      final ajeno = await send('GET', '/api/npcs/$id', token: tokenB);
      final inexistente = await send(
        'GET',
        '/api/npcs/npc-no-existe',
        token: tokenB,
      );
      expect(ajeno.status, 404);
      expect(ajeno.body, inexistente.body);

      final edited = await send(
        'PUT',
        '/api/npcs/$id',
        token: tokenB,
        body: {'npc': npcJson('Robado', id: id)},
      );
      expect(edited.status, 404);

      await send('DELETE', '/api/npcs/$id', token: tokenB);
      expect(await npcs.find(userIdOf('dm-a'), id), isNotNull);
      expect((await npcs.find(userIdOf('dm-a'), id))!.npc.name, 'Toblen');
    });

    test('el tipo no se puede cambiar', () async {
      final token = await login('dm');
      final created = await createNpc(token, 'Toblen');
      final id = created['npc']['id'] as String;

      final response = await send(
        'PUT',
        '/api/npcs/$id',
        token: token,
        body: {
          'npc': npcJson(
            'Toblen',
            id: id,
            kind: NpcSheetKind.block,
            block: bandit,
          ),
        },
      );

      expect(response.status, 400);
      expect(
        (await npcs.find(userIdOf('dm'), id))!.npc.sheetKind,
        NpcSheetKind.none,
      );
    });

    test('borrar se lleva ficha, vínculos y retratos', () async {
      final token = await login('dm');
      await createCampaign(token, 'mesa');
      final created = await createNpc(
        token,
        'Maerith',
        kind: NpcSheetKind.character,
      );
      final id = created['npc']['id'] as String;
      final sheetId = created['npc']['characterId'] as String;
      await send('PUT', '/api/campaigns/mesa/npcs/$id', token: token);
      final key = await portraits.save(
        userId: userIdOf('dm'),
        characterId: sheetId,
        bytes: png(),
      );

      final deleted = await send('DELETE', '/api/npcs/$id', token: token);

      expect(deleted.status, 200);
      expect(await npcs.find(userIdOf('dm'), id), isNull);
      expect(await characters.findNpcSheet(userIdOf('dm'), sheetId), isNull);
      expect(npcs.statusOf(userIdOf('dm'), 'mesa', id), isNull);
      final read = await send('GET', '/api/portraits/$key', token: token);
      expect(read.status, 404);
    });
  });

  group('/api/campaigns/<id>/npcs', () {
    test('vincular nace vivo y repetir no cambia el estado', () async {
      final token = await login('dm');
      await createCampaign(token, 'mesa');
      final id = (await createNpc(token, 'Toblen'))['npc']['id'] as String;

      final first = await send(
        'PUT',
        '/api/campaigns/mesa/npcs/$id',
        token: token,
      );
      expect(decode(first.body)['status'], 'alive');

      await send(
        'PUT',
        '/api/campaigns/mesa/npcs/$id',
        token: token,
        body: {'status': 'unknown'},
      );
      final again = await send(
        'PUT',
        '/api/campaigns/mesa/npcs/$id',
        token: token,
      );
      expect(decode(again.body)['status'], 'unknown');

      final listed = decode(
        (await send('GET', '/api/campaigns/mesa/npcs', token: token)).body,
      );
      expect(listed['npcs'], hasLength(1));
      expect(listed['npcs'][0]['status'], 'unknown');
    });

    test('el estado es de cada campaña', () async {
      final token = await login('dm');
      await createCampaign(token, 'a');
      await createCampaign(token, 'b');
      final id = (await createNpc(token, 'Ilse'))['npc']['id'] as String;
      await send('PUT', '/api/campaigns/a/npcs/$id', token: token);
      await send('PUT', '/api/campaigns/b/npcs/$id', token: token);

      await send(
        'PUT',
        '/api/campaigns/a/npcs/$id',
        token: token,
        body: {'status': 'dead'},
      );

      expect(npcs.statusOf(userIdOf('dm'), 'a', id), NpcStatus.dead);
      expect(npcs.statusOf(userIdOf('dm'), 'b', id), NpcStatus.alive);
    });

    test('no se puede vincular a una campaña ajena', () async {
      final tokenA = await login('dm-a');
      await createCampaign(tokenA, 'ajena');
      final tokenB = await login('dm-b');
      final id = (await createNpc(tokenB, 'Toblen'))['npc']['id'] as String;

      final response = await send(
        'PUT',
        '/api/campaigns/ajena/npcs/$id',
        token: tokenB,
      );

      expect(response.status, 404);
      expect(npcs.statusOf(userIdOf('dm-a'), 'ajena', id), isNull);
      expect(npcs.statusOf(userIdOf('dm-b'), 'ajena', id), isNull);
    });

    test('quitar de la campaña o borrarla conserva el PNJ', () async {
      final token = await login('dm');
      await createCampaign(token, 'a');
      await createCampaign(token, 'b');
      final id = (await createNpc(token, 'Toblen'))['npc']['id'] as String;
      await send('PUT', '/api/campaigns/a/npcs/$id', token: token);
      await send('PUT', '/api/campaigns/b/npcs/$id', token: token);

      await send('DELETE', '/api/campaigns/a/npcs/$id', token: token);
      await send('DELETE', '/api/campaigns/b', token: token);

      final listed = decode(
        (await send('GET', '/api/npcs', token: token)).body,
      );
      expect(listed['npcs'], hasLength(1));
      expect(listed['npcs'][0]['campaigns'], isEmpty);
    });
  });

  group('retratos de PNJ', () {
    test('se guardan con el PNJ y otra cuenta no los lee', () async {
      final token = await login('dm');
      final id = (await createNpc(token, 'Toblen'))['npc']['id'] as String;

      final saved = await send(
        'POST',
        '/api/npcs/$id/portraits',
        token: token,
        body: {'bytes': base64Encode(png())},
      );
      expect(saved.status, 200);
      final key = decode(saved.body)['key'] as String;
      expect(key, startsWith('$id/'));

      expect(
        (await send('GET', '/api/portraits/$key', token: token)).status,
        200,
      );
      final otherToken = await login('otro');
      expect(
        (await send('GET', '/api/portraits/$key', token: otherToken)).status,
        404,
      );
    });

    test('un PNJ con ficha los guarda por la ruta de su ficha', () async {
      final token = await login('dm');
      final id =
          (await createNpc(
                token,
                'Maerith',
                kind: NpcSheetKind.character,
              ))['npc']['id']
              as String;

      final response = await send(
        'POST',
        '/api/npcs/$id/portraits',
        token: token,
        body: {'bytes': base64Encode(png())},
      );

      expect(response.status, 404);
    });
  });

  group('combate con PNJ', () {
    /// Una mesa con un jugador vinculado y un combate en curso contra Garrick
    /// (PNJ con bloque de Bandido) y un goblin, con Ilse aliada y Toblen
    /// neutral. Garrick y el goblin quedaron a 0 PG.
    Future<({String dm, String player, Map<String, String> ids})> mesa() async {
      final player = await login('jugador');
      await send(
        'POST',
        '/api/characters',
        token: player,
        body: {'character': characterJson('mirna', name: 'Mirna')},
      );
      final code = decode(
        (await send('POST', '/api/characters/mirna/share', token: player)).body,
      )['code'];

      final dm = await login('dm');
      await createCampaign(dm, 'mesa');
      final memberId =
          decode(
                (await send(
                  'POST',
                  '/api/campaigns/mesa/members',
                  token: dm,
                  body: {'code': code},
                )).body,
              )['member']['memberId']
              as String;

      final garrick =
          (await createNpc(
                dm,
                'Garrick el Tuerto',
                kind: NpcSheetKind.block,
                block: bandit,
              ))['npc']['id']
              as String;
      final ilse =
          (await createNpc(
                dm,
                'Capitana Ilse Varn',
                kind: NpcSheetKind.block,
                block: bandit,
              ))['npc']['id']
              as String;
      final toblen = (await createNpc(dm, 'Toblen'))['npc']['id'] as String;
      for (final id in [garrick, ilse, toblen]) {
        await send('PUT', '/api/campaigns/mesa/npcs/$id', token: dm);
      }

      final encounter = Encounter(
        id: 'e',
        stage: EncounterStage.running,
        round: 3,
        combatants: [
          Combatant(
            id: 'p',
            kind: CombatantKind.player,
            name: 'Mirna',
            initiative: 20,
            memberId: memberId,
          ),
          Combatant(
            id: 'g',
            kind: CombatantKind.npc,
            name: 'Garrick el Tuerto',
            initiative: 15,
            npcId: garrick,
            maxHp: 11,
          ),
          Combatant(
            id: 'i',
            kind: CombatantKind.npc,
            name: 'Capitana Ilse Varn',
            initiative: 12,
            npcId: ilse,
            currentHp: 11,
            maxHp: 11,
            side: CombatantSide.ally,
          ),
          Combatant(
            id: 't',
            kind: CombatantKind.npc,
            name: 'Toblen',
            initiative: 10,
            npcId: toblen,
          ),
          const Combatant(
            id: 'm',
            kind: CombatantKind.monster,
            name: 'Guerrero goblin 1',
            initiative: 8,
            creatureId: 'goblin-warrior',
            maxHp: 10,
          ),
        ],
      );
      final saved = await send(
        'PUT',
        '/api/campaigns/mesa/encounter',
        token: dm,
        body: {'encounter': encounter.toJson()},
      );
      expect(saved.status, 200, reason: saved.body);
      return (
        dm: dm,
        player: player,
        ids: {'garrick': garrick, 'ilse': ilse, 'toblen': toblen},
      );
    }

    test(
      'terminar marca muertos solo a los pedidos que pelearon ahí',
      () async {
        final m = await mesa();
        final token = await login('dm');
        final ajeno = (await createNpc(token, 'Otro'))['npc']['id'] as String;
        await send('PUT', '/api/campaigns/mesa/npcs/$ajeno', token: token);

        final closed = await send(
          'DELETE',
          '/api/campaigns/mesa/encounter',
          token: m.dm,
          body: {
            'deadNpcIds': [m.ids['garrick'], ajeno],
          },
        );

        expect(closed.status, 200);
        final dm = userIdOf('dm');
        expect(npcs.statusOf(dm, 'mesa', m.ids['garrick']!), NpcStatus.dead);
        expect(npcs.statusOf(dm, 'mesa', m.ids['ilse']!), NpcStatus.alive);
        expect(npcs.statusOf(dm, 'mesa', ajeno), NpcStatus.alive);
      },
    );

    test('descartar no cambia ningún estado', () async {
      final m = await mesa();

      await send(
        'DELETE',
        '/api/campaigns/mesa/encounter?discard=true',
        token: m.dm,
        body: {
          'deadNpcIds': [m.ids['garrick']],
        },
      );

      expect(
        npcs.statusOf(userIdOf('dm'), 'mesa', m.ids['garrick']!),
        NpcStatus.alive,
      );
      expect(encounters.logs, isEmpty);
    });

    test('el registro guarda bandos y el nombre público de cada PNJ', () async {
      final m = await mesa();
      await send('DELETE', '/api/campaigns/mesa/encounter', token: m.dm);

      final log = EncounterLog.fromJson(encounters.logs.single.document);
      final garrick = log.enemies.firstWhere((e) => e.npc);
      expect(garrick.name, 'Garrick el Tuerto');
      expect(garrick.publicName, 'Bandido');
      expect(garrick.defeated, 1);
      expect(log.allies.single.name, 'Capitana Ilse Varn');
      expect(log.neutrals.single.name, 'Toblen');
      expect(log.totalMonsters, 2);
      expect(log.totalDefeated, 2);
    });

    test('la campaña vista por el jugador no nombra a ningún PNJ', () async {
      final m = await mesa();
      await send('DELETE', '/api/campaigns/mesa/encounter', token: m.dm);

      final response = await send(
        'GET',
        '/api/characters/mirna/campaigns',
        token: m.player,
      );

      expect(response.status, 200);
      for (final secreto in [
        'Garrick',
        'Ilse',
        'Toblen',
        'TRASFONDO-SECRETO',
      ]) {
        expect(response.body, isNot(contains(secreto)), reason: secreto);
      }
      final battle = decode(response.body)['campaigns'][0]['battles'][0];
      expect([
        for (final m in battle['monsters']) m['name'],
      ], containsAll(['Bandido', 'Guerrero goblin']));
    });
  });

  group('/api/npcs/import', () {
    Map<String, dynamic> spell(String id, String name) => {
      'id': id,
      'name': name,
      'source': 'homebrew',
      'level': 1,
      'school': 'Evocación',
      'castingTime': '1 acción',
      'range': '60 pies',
      'components': 'V, S',
      'duration': 'Instantánea',
      'description': 'Hace algo.',
    };

    String bundle({
      Map<String, dynamic>? homebrew,
      int formatVersion = 1,
      bool withPortrait = false,
    }) {
      final npc = Npc(
        id: 'npc-origen',
        name: 'Garrick el Tuerto',
        sheetKind: NpcSheetKind.block,
        block: bandit,
        baseCreatureId: 'bandit',
        baseCreatureName: 'Bandido',
        portraitPaths: withPortrait ? const ['npc-origen/0.png'] : const [],
        portraitPrompts: withPortrait
            ? const {'npc-origen/0.png': 'un bandido'}
            : const {},
      );
      final manifest = {
        'type': NpcBundleCodec.type,
        'formatVersion': formatVersion,
        'npc': npc.toJson(),
        'homebrew': ?homebrew,
        'portraits': [
          if (withPortrait)
            {
              'file': 'portraits/0.png',
              'owner': 'npc',
              'key': 'npc-origen/0.png',
            },
        ],
      };
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes(
            NpcBundleCodec.manifestName,
            utf8.encode(jsonEncode(manifest)),
          ),
        );
      if (withPortrait) {
        archive.addFile(ArchiveFile.bytes('portraits/0.png', png()));
      }
      return base64Encode(ZipEncoder().encode(archive));
    }

    test('crea una copia nueva cada vez, con retrato y campaña', () async {
      final token = await login('dm');
      await createCampaign(token, 'mesa');

      final first = await send(
        'POST',
        '/api/npcs/import',
        token: token,
        body: {'bytes': bundle(withPortrait: true), 'campaignId': 'mesa'},
      );
      final second = await send(
        'POST',
        '/api/npcs/import',
        token: token,
        body: {'bytes': bundle()},
      );

      expect(first.status, 200, reason: first.body);
      expect(second.status, 200, reason: second.body);
      final a = decode(first.body);
      final b = decode(second.body);
      expect(a['npc']['id'], isNot(b['npc']['id']));
      expect(a['npc']['id'], isNot('npc-origen'));
      expect(a['campaigns'][0]['campaignId'], 'mesa');
      final key = (a['npc']['portraitPaths'] as List).single as String;
      expect(key, startsWith('${a['npc']['id']}/'));
      expect(a['npc']['portraitPrompts'][key], 'un bandido');
      expect(
        decode((await send('GET', '/api/npcs', token: token)).body)['npcs'],
        hasLength(2),
      );
    });

    test('homebrew nuevo se crea e idéntico se reusa', () async {
      final token = await login('dm');
      await homebrew.upsert(
        userIdOf('dm'),
        'spells',
        'rayo-casero',
        spell('rayo-casero', 'Rayo casero'),
      );

      final response = await send(
        'POST',
        '/api/npcs/import',
        token: token,
        body: {
          'bytes': bundle(
            homebrew: {
              'spells': [
                spell('rayo-casero', 'Rayo casero'),
                spell('niebla-casera', 'Niebla casera'),
              ],
            },
          ),
        },
      );

      expect(response.status, 200, reason: response.body);
      final spells = (await homebrew.listForUser(userIdOf('dm')))['spells']!;
      expect(
        spells.map((s) => s['id']),
        containsAll(['rayo-casero', 'niebla-casera']),
      );
      expect(spells, hasLength(2));
    });

    test('un homebrew distinto con el mismo id rechaza todo', () async {
      final token = await login('dm');
      await homebrew.upsert(
        userIdOf('dm'),
        'spells',
        'rayo-casero',
        spell('rayo-casero', 'Rayo casero'),
      );

      final response = await send(
        'POST',
        '/api/npcs/import',
        token: token,
        body: {
          'bytes': bundle(
            homebrew: {
              'spells': [spell('rayo-casero', 'Otro rayo')],
            },
            withPortrait: true,
          ),
        },
      );

      expect(response.status, 400);
      expect(response.body, contains('Otro rayo'));
      expect(
        decode((await send('GET', '/api/npcs', token: token)).body)['npcs'],
        isEmpty,
      );
      final spells = (await homebrew.listForUser(userIdOf('dm')))['spells']!;
      expect(spells.single['name'], 'Rayo casero');
    });

    test('una versión futura se rechaza sin escribir nada', () async {
      final token = await login('dm');
      final response = await send(
        'POST',
        '/api/npcs/import',
        token: token,
        body: {'bytes': bundle(formatVersion: 99)},
      );
      expect(response.status, 400);
      expect(
        decode((await send('GET', '/api/npcs', token: token)).body)['npcs'],
        isEmpty,
      );
    });

    test('importar un respaldo no crea PNJ', () async {
      final token = await login('dm');
      await send(
        'POST',
        '/api/import',
        token: token,
        body: {'bytes': base64Encode(ZipEncoder().encode(Archive()))},
      );
      expect(
        decode((await send('GET', '/api/npcs', token: token)).body)['npcs'],
        isEmpty,
      );
    });
  });
}
