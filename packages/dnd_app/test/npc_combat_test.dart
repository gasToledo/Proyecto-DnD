import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/dm/dm_mode_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialog_finders.dart';
import 'fakes/fake_api_server.dart';

/// Los PNJ en el combate del DM: bandos, el diálogo «Sumar al combate», la
/// conversión desde el tracker y el cierre que marca muertos.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Creature creature(String name) =>
      repo.creatures.values.firstWhere((c) => c.name == name);

  int maxHp(Creature c) => c.resolve(const CreatureVars({})).maxHp;

  Npc blockNpc(
    String id,
    String name,
    String base, {
    String speech = '',
    String background = '',
  }) {
    final c = creature(base);
    return Npc(
      id: id,
      name: name,
      sheetKind: NpcSheetKind.block,
      block: Creature.fromJson(c.toJson()),
      baseCreatureId: c.id,
      baseCreatureName: c.name,
      speech: speech,
      background: background,
    );
  }

  void seedCampaign(FakeApiServer server) {
    server.campaigns['tumba'] = const Campaign(id: 'tumba', name: 'La Tumba');
  }

  void addNpc(
    FakeApiServer server,
    Npc npc, {
    NpcStatus? status = NpcStatus.alive,
  }) {
    server.npcs[npc.id] = npc;
    if (status != null) {
      server.campaignNpcs[(campaignId: 'tumba', npcId: npc.id)] = status;
    }
  }

  Future<FakeApiServer> pumpCombate(
    WidgetTester tester, {
    required void Function(FakeApiServer) seed,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = FakeApiServer();
    seedCampaign(server);
    seed(server);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: DmModeScreen(
          api: ApiClient(client: server.client),
          repo: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();
    return server;
  }

  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AppDialog), matching: matching);

  bool enabled(WidgetTester tester, Finder action) =>
      tester.widget<InkWell>(action).onTap != null;

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.text('Sumar al combate'));
    await tester.pumpAndSettle();
  }

  Future<void> startEmpty(WidgetTester tester) async {
    await tester.tap(find.text('Armar combate'));
    await tester.pumpAndSettle();
  }

  Combatant combatant(FakeApiServer server, String name) =>
      server.encounters['tumba']!.combatants.firstWhere((c) => c.name == name);

  group('Sumar al combate', () {
    // El mismo PNJ puede ser aliado hoy y enemigo mañana: un bando por
    // defecto sería una decisión que el DM no tomó.
    testWidgets('un PNJ no se suma hasta elegirle bando', (tester) async {
      final mirra = blockNpc('mirra', 'Mirra', 'Bandido');
      final server = await pumpCombate(tester, seed: (s) => addNpc(s, mirra));
      await startEmpty(tester);
      await openAdd(tester);

      await tester.tap(inDialog(find.widgetWithText(ListTile, 'Mirra')));
      await tester.pumpAndSettle();
      expect(enabled(tester, dialogAction('Sumar')), isFalse);

      await tester.tap(inDialog(find.text('Aliado')));
      await tester.pumpAndSettle();
      expect(enabled(tester, dialogAction('Sumar')), isTrue);
      await tester.tap(dialogAction('Sumar'));
      await tester.pumpAndSettle();

      final added = combatant(server, 'Mirra');
      expect(added.kind, CombatantKind.npc);
      expect(added.npcId, 'mirra');
      expect(added.side, CombatantSide.ally);
      expect(added.maxHp, maxHp(mirra.block!));
      expect(added.currentHp, added.maxHp);
      expect(find.text('Aliado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un monstruo del bestiario puede entrar como aliado', (
      tester,
    ) async {
      final server = await pumpCombate(tester, seed: (_) {});
      await startEmpty(tester);
      await openAdd(tester);

      await tester.enterText(inDialog(find.byType(TextField)), 'lobo');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lobo'));
      await tester.pumpAndSettle();
      // El bestiario sí arranca en enemigo: es lo esperable de un monstruo.
      expect(enabled(tester, dialogAction('Sumar')), isTrue);
      await tester.tap(inDialog(find.text('Aliado')));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Sumar'));
      await tester.pumpAndSettle();

      expect(combatant(server, 'Lobo').side, CombatantSide.ally);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el PNJ sin estadísticas entra neutral, sin PG ni daño', (
      tester,
    ) async {
      final server = await pumpCombate(
        tester,
        seed: (s) => addNpc(
          s,
          Npc(id: 'bruno', name: 'Bruno', sheetKind: NpcSheetKind.none),
        ),
      );
      await startEmpty(tester);
      await openAdd(tester);

      await tester.tap(inDialog(find.widgetWithText(ListTile, 'Bruno')));
      await tester.pumpAndSettle();
      expect(
        inDialog(find.textContaining('Sin estadísticas no tiene PG')),
        findsOneWidget,
      );
      expect(enabled(tester, dialogAction('Sumar')), isTrue);
      await tester.tap(dialogAction('Sumar'));
      await tester.pumpAndSettle();

      final bruno = combatant(server, 'Bruno');
      expect(bruno.side, CombatantSide.neutral);
      expect(bruno.maxHp, 0);
      expect(find.byTooltip('Dañar'), findsNothing);
      expect(find.byTooltip('Curar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un PNJ que ya está en la mesa no se puede elegir', (
      tester,
    ) async {
      final mirra = blockNpc('mirra', 'Mirra', 'Bandido');
      final server = await pumpCombate(
        tester,
        seed: (s) {
          addNpc(s, mirra);
          s.encounters['tumba'] = Encounter(
            id: 'e',
            combatants: [
              Combatant(
                id: 'c-mirra',
                kind: CombatantKind.npc,
                name: 'Mirra',
                initiative: 0,
                npcId: 'mirra',
                currentHp: 11,
                maxHp: 11,
                side: CombatantSide.ally,
              ),
            ],
          );
        },
      );
      await openAdd(tester);

      expect(inDialog(find.text('Ya está en la mesa')), findsOneWidget);
      await tester.tap(inDialog(find.widgetWithText(ListTile, 'Mirra')));
      await tester.pumpAndSettle();
      expect(dialogAction('Sumar'), findsNothing);
      expect(server.encounters['tumba']!.combatants, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sumar uno de la biblioteca lo trae a la campaña vivo', (
      tester,
    ) async {
      final server = await pumpCombate(
        tester,
        seed: (s) =>
            addNpc(s, blockNpc('garrick', 'Garrick', 'Bandido'), status: null),
      );
      await startEmpty(tester);
      await openAdd(tester);
      // Sin PNJ en la campaña abre en el bestiario.
      await tester.tap(inDialog(find.text('PNJ')));
      await tester.pumpAndSettle();

      expect(
        inDialog(find.textContaining('entra también a la campaña')),
        findsOneWidget,
      );
      await tester.tap(inDialog(find.widgetWithText(ListTile, 'Garrick')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('Enemigo')));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Sumar'));
      await tester.pumpAndSettle();

      expect(
        server.campaignNpcs[(campaignId: 'tumba', npcId: 'garrick')],
        NpcStatus.alive,
      );
      expect(combatant(server, 'Garrick').side, CombatantSide.enemy);
      expect(tester.takeException(), isNull);
    });

    for (final revive in [true, false]) {
      testWidgets(
        revive
            ? 'un muerto que vuelve pasa a vivo'
            : 'sumar a un muerto sin revivirlo lo deja muerto',
        (tester) async {
          final server = await pumpCombate(
            tester,
            seed: (s) => addNpc(
              s,
              blockNpc('mirra', 'Mirra', 'Bandido'),
              status: NpcStatus.dead,
            ),
          );
          await startEmpty(tester);
          await openAdd(tester);

          expect(inDialog(find.textContaining('Muerto en esta')), findsOne);
          await tester.tap(inDialog(find.widgetWithText(ListTile, 'Mirra')));
          await tester.pumpAndSettle();
          expect(inDialog(find.textContaining('está muerto')), findsOneWidget);
          if (revive) {
            await tester.tap(
              inDialog(find.text('Volvió: marcarlo vivo otra vez')),
            );
          }
          await tester.tap(inDialog(find.text('Enemigo')));
          await tester.pumpAndSettle();
          await tester.tap(dialogAction('Sumar'));
          await tester.pumpAndSettle();

          expect(combatant(server, 'Mirra').npcId, 'mirra');
          expect(
            server.campaignNpcs[(campaignId: 'tumba', npcId: 'mirra')],
            revive ? NpcStatus.alive : NpcStatus.dead,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Bandos en la planilla', () {
    Encounter running(List<Combatant> combatants, {int round = 1}) => Encounter(
      id: 'e',
      round: round,
      stage: EncounterStage.running,
      combatants: combatants,
    );

    Combatant goblin({String id = 'g1', int? hp}) {
      final c = creature('Guerrero goblin');
      final max = maxHp(c);
      return Combatant(
        id: id,
        kind: CombatantKind.monster,
        name: c.name,
        initiative: 12,
        creatureId: c.id,
        currentHp: hp ?? max,
        maxHp: max,
      );
    }

    Combatant npcCombatant(
      String npcId,
      String name, {
      required CombatantSide side,
      int hp = 11,
      int maxHp = 11,
      int initiative = 15,
    }) => Combatant(
      id: 'c-$npcId',
      kind: CombatantKind.npc,
      name: name,
      initiative: initiative,
      npcId: npcId,
      currentHp: hp,
      maxHp: maxHp,
      side: side,
    );

    // El aviso de bando vencido es de los enemigos: un aliado caído baja el
    // conteo de la mesa y nada más.
    testWidgets('un aliado caído no dispara el aviso de enemigos', (
      tester,
    ) async {
      await pumpCombate(
        tester,
        seed: (s) {
          addNpc(s, blockNpc('mirra', 'Mirra', 'Bandido'));
          s.encounters['tumba'] = running([
            const Combatant(
              id: 'p1',
              kind: CombatantKind.player,
              name: 'Sagan',
              initiative: 18,
            ),
            npcCombatant('mirra', 'Mirra', side: CombatantSide.ally, hp: 0),
            goblin(),
          ]);
        },
      );

      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.textContaining('No queda ningún'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con solo un neutral en pie avisa que no quedan enemigos', (
      tester,
    ) async {
      await pumpCombate(
        tester,
        seed: (s) {
          addNpc(s, blockNpc('mirra', 'Mirra', 'Bandido'));
          s.encounters['tumba'] = running([
            npcCombatant('mirra', 'Mirra', side: CombatantSide.neutral),
            goblin(hp: 0),
          ]);
        },
      );

      expect(find.text('1 neutral'), findsOneWidget);
      expect(
        find.textContaining('No queda ningún enemigo en pie'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cambiar el bando a mitad de combate recalcula los conteos', (
      tester,
    ) async {
      final server = await pumpCombate(
        tester,
        seed: (s) {
          addNpc(s, blockNpc('mirra', 'Mirra', 'Bandido'));
          s.encounters['tumba'] = running([
            npcCombatant('mirra', 'Mirra', side: CombatantSide.ally),
            goblin(),
          ], round: 3);
        },
      );
      expect(find.text('1/1'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Bando de Mirra'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<Object>, 'Enemigo'),
      );
      await tester.pumpAndSettle();

      expect(combatant(server, 'Mirra').side, CombatantSide.enemy);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el turno de un PNJ muestra cómo habla y su trasfondo', (
      tester,
    ) async {
      await pumpCombate(
        tester,
        seed: (s) {
          addNpc(
            s,
            blockNpc(
              'mirra',
              'Mirra',
              'Bandido',
              speech: 'Susurra y nunca mira a los ojos.',
              background: 'Hija del prestamista de Phandalin.',
            ),
          );
          s.encounters['tumba'] = running([
            npcCombatant('mirra', 'Mirra', side: CombatantSide.ally),
            goblin(),
          ]);
        },
      );
      final panel = find.byKey(const ValueKey('combate-panel'));

      expect(
        find.descendant(
          of: panel,
          matching: find.text('Susurra y nunca mira a los ojos.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Aliado')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: panel, matching: find.text('Trasfondo')),
      );
      await tester.pumpAndSettle();
      expect(
        inDialog(find.text('Hija del prestamista de Phandalin.')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // En la columna «Monstruos y PNJ», que solo la mitad trajera número se
    // leía como un olvido. Los dos los maneja el DM y los dos vienen tirados.
    testWidgets('la tirada automática también le propone número al PNJ', (
      tester,
    ) async {
      final sheet = Character(
        id: 'sheet-v',
        name: 'Vadrik',
        raceId: 'human',
        classId: 'rogue',
        backgroundId: 'criminal',
        assignedScores: const {Ability.dexterity: 16},
      );
      await pumpCombate(
        tester,
        seed: (s) {
          addNpc(s, blockNpc('mirra', 'Mirra', 'Bandido'));
          addNpc(
            s,
            Npc(id: 'bruno', name: 'Bruno', sheetKind: NpcSheetKind.none),
          );
          s.characters[sheet.id] = sheet;
          s.npcSheets.add(sheet.id);
          addNpc(
            s,
            Npc(
              id: 'vadrik',
              name: 'Vadrik',
              sheetKind: NpcSheetKind.character,
              characterId: sheet.id,
            ),
          );
          s.encounters['tumba'] = Encounter(
            id: 'e',
            combatants: [
              goblin(id: 'g1'),
              npcCombatant('mirra', 'Mirra', side: CombatantSide.enemy),
              npcCombatant('bruno', 'Bruno', side: CombatantSide.neutral),
              npcCombatant('vadrik', 'Vadrik', side: CombatantSide.ally),
            ],
          );
        },
      );
      await tester.tap(find.text('Tirar iniciativa'));
      await tester.pumpAndSettle();

      int field(String id) => int.parse(
        tester
            .widget<TextField>(find.byKey(ValueKey('initiative-$id')))
            .controller!
            .text,
      );
      // Mirra tira con su bloque, copiado del bandido.
      final mod = creature('Bandido').initiativeModifier;
      expect(field('c-mirra'), inInclusiveRange(1 + mod, 20 + mod));
      // Bruno no tiene Destreza: el d20 solo.
      expect(field('c-bruno'), inInclusiveRange(1, 20));
      // Vadrik, con la iniciativa de su ficha compilada.
      final vadrik = CharacterCompiler(repo).compile(sheet).initiative;
      expect(vadrik, isNonZero);
      expect(field('c-vadrik'), inInclusiveRange(1 + vadrik, 20 + vadrik));
      expect(find.text('Al confirmar arranca la ronda 1.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // El goblin que se rinde y pasa a tener nombre no vuelve a empezar la
    // pelea: conserva lugar, PG, bando y efectos.
    testWidgets('convertir un monstruo en PNJ conserva su lugar y sus PG', (
      tester,
    ) async {
      final base = creature('Guerrero goblin');
      final hurt = maxHp(base) - 3;
      final server = await pumpCombate(
        tester,
        seed: (s) {
          s.encounters['tumba'] = running([
            npcCombatant('otro', 'Alguien', side: CombatantSide.ally),
            goblin(hp: hurt).copyWith(tags: ['Asustado']),
            goblin(id: 'g2'),
          ]);
        },
      );

      await tester.tap(find.byTooltip('Bando de ${base.name}').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convertir en PNJ…'));
      await tester.pumpAndSettle();
      await tester.enterText(inDialog(find.byType(TextField)), 'Pipo');
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      final pipo = server.npcs.values.singleWhere((n) => n.name == 'Pipo');
      expect(pipo.sheetKind, NpcSheetKind.block);
      expect(pipo.baseCreatureId, base.id);
      expect(pipo.block!.name, base.name);
      expect(
        server.campaignNpcs[(campaignId: 'tumba', npcId: pipo.id)],
        NpcStatus.alive,
      );

      final combatants = server.encounters['tumba']!.combatants;
      final converted = combatants[1];
      expect(converted.id, 'g1');
      expect(converted.name, 'Pipo');
      expect(converted.kind, CombatantKind.npc);
      expect(converted.npcId, pipo.id);
      expect(converted.currentHp, hurt);
      expect(converted.side, CombatantSide.enemy);
      expect(converted.tags, ['Asustado']);
      expect(tester.takeException(), isNull);
    });

    group('Terminar', () {
      void seedFallen(FakeApiServer s) {
        addNpc(s, blockNpc('mirra', 'Mirra', 'Bandido'));
        addNpc(s, blockNpc('garrick', 'Garrick', 'Bandido'));
        s.encounters['tumba'] = running([
          npcCombatant('mirra', 'Mirra', side: CombatantSide.ally, hp: 0),
          npcCombatant('garrick', 'Garrick', side: CombatantSide.enemy, hp: 0),
          goblin(),
        ]);
      }

      testWidgets('solo el PNJ marcado queda muerto en la campaña', (
        tester,
      ) async {
        final server = await pumpCombate(tester, seed: seedFallen);
        await tester.tap(find.text('Terminar combate').first);
        await tester.pumpAndSettle();

        final boxes = tester.widgetList<CheckboxListTile>(
          inDialog(find.byType(CheckboxListTile)),
        );
        expect(boxes, hasLength(2));
        expect(boxes.every((b) => b.value == false), isTrue);

        await tester.tap(inDialog(find.text('Garrick')));
        await tester.pumpAndSettle();
        await tester.tap(dialogAction('Terminar y guardar'));
        await tester.pumpAndSettle();

        NpcStatus? status(String id) =>
            server.campaignNpcs[(campaignId: 'tumba', npcId: id)];
        expect(status('garrick'), NpcStatus.dead);
        expect(status('mirra'), NpcStatus.alive);
        expect(server.encounters['tumba'], isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('descartar no cambia ningún estado', (tester) async {
        final server = await pumpCombate(tester, seed: seedFallen);
        await tester.tap(find.text('Terminar combate').first);
        await tester.pumpAndSettle();
        await tester.tap(inDialog(find.text('Garrick')));
        await tester.pumpAndSettle();
        await tester.tap(dialogAction('Descartar sin guardar'));
        await tester.pumpAndSettle();

        expect(server.campaignNpcs.values, everyElement(NpcStatus.alive));
        expect(server.encounterLogs['tumba'] ?? const [], isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  });

  // El cuaderno es del DM: ve los nombres propios y los bandos, pero
  // «cayeron N de M» sigue siendo de los enemigos.
  testWidgets('el cuaderno muestra aliados y neutrales en líneas propias', (
    tester,
  ) async {
    await pumpCombate(
      tester,
      seed: (s) {
        s.chapters['tumba'] = [
          const Chapter(
            id: 'cripta',
            name: 'La cripta',
            state: ChapterState.active,
          ),
        ];
        s.encounterLogs['tumba'] = [
          const EncounterLog(
            id: 'log-0',
            chapterId: 'cripta',
            rounds: 3,
            players: ['Sagan'],
            monsters: [
              EncounterLogMonsters(
                name: 'Guerrero goblin',
                count: 3,
                defeated: 3,
              ),
              EncounterLogMonsters(
                name: 'Garrick',
                npc: true,
                publicName: 'Bandido',
              ),
              EncounterLogMonsters(
                name: 'Mirra',
                side: CombatantSide.ally,
                npc: true,
              ),
              EncounterLogMonsters(
                name: 'Bruno',
                side: CombatantSide.neutral,
                npc: true,
              ),
            ],
          ),
        ];
      },
    );
    await tester.tap(find.text('Cuaderno'));
    await tester.pumpAndSettle();

    expect(
      find.text('Combate contra Guerrero goblin, Garrick'),
      findsOneWidget,
    );
    expect(find.textContaining('Cayeron 3 de 4 enemigos.'), findsOneWidget);
    expect(find.textContaining('Aliados: Mirra.'), findsOneWidget);
    expect(find.textContaining('Neutrales: Bruno.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
