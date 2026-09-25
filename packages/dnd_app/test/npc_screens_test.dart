import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_models.dart';
import 'package:dnd_app/data/backup_bundle.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/data/npc_bundle.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/dm/dm_mode_screen.dart';
import 'package:dnd_app/ui/dm/npcs/npc_detail_screen.dart';
import 'package:dnd_app/ui/dm/npcs/npc_transfer.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialog_finders.dart';
import 'fakes/fake_api_server.dart';

/// Las pantallas de PNJ fuera del combate: la biblioteca, la ficha, la
/// sección de la campaña, el visor para la mesa y el pase entre DM.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Creature creature(String name) =>
      repo.creatures.values.firstWhere((c) => c.name == name);

  Npc blockNpc(String id, String name, String base, {List<String>? tags}) {
    final c = creature(base);
    return Npc(
      id: id,
      name: name,
      sheetKind: NpcSheetKind.block,
      block: Creature.fromJson(c.toJson()),
      baseCreatureId: c.id,
      baseCreatureName: c.name,
      tags: tags ?? const [],
    );
  }

  const tumba = Campaign(id: 'tumba', name: 'La Tumba');
  const costa = Campaign(id: 'costa', name: 'La Costa');

  /// Mirra y Garrick en La Tumba (Garrick también en La Costa), Bruno sin
  /// campaña. Phandalin lo llevan Mirra y Bruno.
  void seedLibrary(FakeApiServer s) {
    s.campaigns['tumba'] = tumba;
    s.campaigns['costa'] = costa;
    s.npcs['mirra'] = blockNpc(
      'mirra',
      'Mirra',
      'Bandido',
      tags: ['Phandalin'],
    );
    s.npcs['garrick'] = blockNpc(
      'garrick',
      'Garrick',
      'Bandido',
      tags: ['Enemigos'],
    );
    s.npcs['bruno'] = Npc(
      id: 'bruno',
      name: 'Bruno',
      sheetKind: NpcSheetKind.none,
      tags: const ['Phandalin'],
    );
    s.campaignNpcs[(campaignId: 'tumba', npcId: 'mirra')] = NpcStatus.alive;
    s.campaignNpcs[(campaignId: 'tumba', npcId: 'garrick')] = NpcStatus.dead;
    s.campaignNpcs[(campaignId: 'costa', npcId: 'garrick')] = NpcStatus.alive;
  }

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<FakeApiServer> pumpDm(
    WidgetTester tester,
    void Function(FakeApiServer) seed,
  ) async {
    bigView(tester);
    final server = FakeApiServer();
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
    return server;
  }

  Future<FakeApiServer> pumpDetail(
    WidgetTester tester,
    String npcId,
    void Function(FakeApiServer) seed,
  ) async {
    bigView(tester);
    final server = FakeApiServer();
    seed(server);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NpcDetailScreen(
          api: ApiClient(client: server.client),
          repo: repo,
          npcId: npcId,
          campaigns: [for (final c in server.campaigns.values) c],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AppDialog), matching: matching);

  /// El selector de estado, por la etiqueta con que lo anuncia el lector de
  /// pantalla: el mismo «Desconocido» se repite en cada campaña.
  Finder selector(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  Finder card(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(InkWell));

  group('Biblioteca', () {
    Future<void> openLibrary(WidgetTester tester) async {
      await tester.tap(find.text('Biblioteca de PNJ'));
      await tester.pumpAndSettle();
    }

    // El filtro de campaña manda y el tag afina: combinados con el buscador
    // son tres cortes distintos sobre la misma lista.
    testWidgets('los filtros de campaña, tag y nombre se combinan', (
      tester,
    ) async {
      await pumpDm(tester, seedLibrary);
      await openLibrary(tester);

      expect(find.text('Mirra'), findsOneWidget);
      expect(find.text('La Tumba · La Costa'), findsOneWidget);
      expect(find.text('Sin campaña todavía'), findsOneWidget);

      await tester.tap(find.text('La Tumba  2'));
      await tester.pumpAndSettle();
      expect(card('Mirra'), findsOneWidget);
      expect(card('Garrick'), findsOneWidget);
      expect(card('Bruno'), findsNothing);

      await tester.tap(find.text('Phandalin  2'));
      await tester.pumpAndSettle();
      expect(card('Mirra'), findsOneWidget);
      expect(card('Garrick'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por nombre'),
        'gar',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ningún PNJ coincide con los filtros.'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(card('Bruno'), findsOneWidget);

      await tester.tap(find.text('Sin campaña  1'));
      await tester.pumpAndSettle();
      expect(card('Bruno'), findsOneWidget);
      expect(card('Mirra'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la biblioteca vacía invita a crear, no a limpiar filtros', (
      tester,
    ) async {
      await pumpDm(tester, (s) => s.campaigns['tumba'] = tumba);
      await openLibrary(tester);

      expect(find.textContaining('Tu biblioteca de PNJ está vacía'), findsOne);
      expect(find.text('Limpiar filtros'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('crear un PNJ con bloque copia la criatura y abre su ficha', (
      tester,
    ) async {
      final server = await pumpDm(tester, (s) => s.campaigns['tumba'] = tumba);
      await openLibrary(tester);

      await tester.tap(find.text('Nuevo PNJ').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        inDialog(find.widgetWithText(TextField, 'Nombre')),
        'Pipo',
      );
      await tester.tap(inDialog(find.text('PNJ con bloque')));
      await tester.pumpAndSettle();
      await tester.enterText(
        inDialog(
          find.widgetWithText(TextField, 'Partir de una criatura (opcional)'),
        ),
        'goblin',
      );
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('Guerrero goblin')));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Crear'));
      await tester.pumpAndSettle();

      final pipo = server.npcs.values.single;
      final goblin = creature('Guerrero goblin');
      expect(pipo.sheetKind, NpcSheetKind.block);
      expect(pipo.baseCreatureId, goblin.id);
      expect(pipo.block!.hp, goblin.hp);
      // La ficha abierta no ofrece cambiar el tipo: define con qué se edita.
      expect(find.byType(NpcDetailScreen), findsOneWidget);
      expect(find.text('PNJ sin estadísticas'), findsNothing);
      expect(find.byType(RadioListTile<NpcSheetKind>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ficha del PNJ', () {
    testWidgets('cómo habla, notas y tags se guardan en el PNJ', (
      tester,
    ) async {
      final server = await pumpDetail(tester, 'mirra', seedLibrary);

      await tester.tap(find.byTooltip('Editar cómo habla'));
      await tester.pumpAndSettle();
      await tester.enterText(
        inDialog(find.byType(TextField)),
        'Arrastra las erres.',
      );
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();
      expect(server.npcs['mirra']!.speech, 'Arrastra las erres.');

      await tester.tap(find.text('Agregar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(
        inDialog(find.byType(TextField)),
        'Le debe plata al herrero.',
      );
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();
      final note = server.npcs['mirra']!.notes.single;
      expect(note.text, 'Le debe plata al herrero.');
      expect(find.text('Le debe plata al herrero.'), findsOneWidget);

      // Sugiere los tags que ya usa la biblioteca y no los que ya tiene.
      await tester.tap(find.widgetWithText(TextButton, 'Tag'));
      await tester.pumpAndSettle();
      expect(inDialog(find.widgetWithText(ActionChip, 'Enemigos')), findsOne);
      expect(
        inDialog(find.widgetWithText(ActionChip, 'Phandalin')),
        findsNothing,
      );
      await tester.tap(inDialog(find.widgetWithText(ActionChip, 'Enemigos')));
      await tester.pumpAndSettle();
      expect(server.npcs['mirra']!.tags, ['Phandalin', 'Enemigos']);
      expect(tester.takeException(), isNull);
    });

    // El bloque es una copia: retocarlo no puede tocar al Bandido del
    // bestiario, que usan los demás combates.
    testWidgets('editar el bloque no cambia la criatura de origen', (
      tester,
    ) async {
      final bandido = creature('Bandido');
      final hpBefore = bandido.hp;
      final server = await pumpDetail(tester, 'mirra', seedLibrary);

      await tester.tap(find.text('Editar bloque'));
      await tester.pumpAndSettle();
      final hp = find.widgetWithText(TextFormField, 'PG').first;
      await tester.ensureVisible(hp);
      await tester.enterText(hp, '99');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(server.npcs['mirra']!.block!.hp, '99');
      expect(server.npcs['mirra']!.baseCreatureId, bandido.id);
      expect(repo.creature(bandido.id)!.hp, hpBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el estado se cambia por campaña desde la ficha', (
      tester,
    ) async {
      final server = await pumpDetail(tester, 'garrick', seedLibrary);

      await tester.tap(
        find.descendant(
          of: selector('Estado en La Costa'),
          matching: find.text('Desconocido'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        server.campaignNpcs[(campaignId: 'costa', npcId: 'garrick')],
        NpcStatus.unknown,
      );
      expect(
        server.campaignNpcs[(campaignId: 'tumba', npcId: 'garrick')],
        NpcStatus.dead,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('borrar confirma nombrando las campañas y lo saca de todo', (
      tester,
    ) async {
      final server = await pumpDetail(tester, 'garrick', seedLibrary);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar PNJ'));
      await tester.pumpAndSettle();
      expect(
        inDialog(
          find.textContaining('de tu biblioteca y de La Tumba, La Costa'),
        ),
        findsOneWidget,
      );
      await tester.tap(dialogAction('Borrar PNJ'));
      await tester.pumpAndSettle();

      expect(server.npcs.containsKey('garrick'), isFalse);
      expect(
        server.campaignNpcs.keys.where((k) => k.npcId == 'garrick'),
        isEmpty,
      );
      expect(server.npcs.containsKey('mirra'), isTrue);
      expect(tester.takeException(), isNull);
    });

    // Lo que se proyecta a la mesa es la cara y, si el DM quiere, el nombre:
    // ni el trasfondo ni los tags ni el bloque.
    testWidgets('mostrar a la mesa solo enseña retrato y nombre', (
      tester,
    ) async {
      await pumpDetail(tester, 'mirra', (s) {
        seedLibrary(s);
        s.npcs['mirra'] = s.npcs['mirra']!.copyWith(
          background: 'Espía de los Zhentarim.',
          speech: 'Susurra.',
        );
      });

      await tester.tap(find.byTooltip('Mostrar a la mesa'));
      await tester.pumpAndSettle();

      expect(find.text('Mirra'), findsOneWidget);
      expect(find.textContaining('Zhentarim'), findsNothing);
      expect(find.text('Susurra.'), findsNothing);
      expect(find.text('Phandalin'), findsNothing);
      expect(find.textContaining('Bandido'), findsNothing);
      expect(find.textContaining('La Tumba'), findsNothing);

      await tester.tap(find.byTooltip('Ocultar el nombre'));
      await tester.pumpAndSettle();
      expect(find.text('Mirra'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    Character fighterSheet(String id) => Character(
      id: id,
      name: 'Vadrik',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {
        Ability.strength: 16,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      hpPerLevel: const [10],
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
    );

    void seedCharacterNpc(FakeApiServer s) {
      s.campaigns['tumba'] = tumba;
      s.characters['ficha-vadrik'] = fighterSheet('ficha-vadrik');
      s.npcSheets.add('ficha-vadrik');
      s.npcs['vadrik'] = Npc(
        id: 'vadrik',
        name: 'Vadrik',
        sheetKind: NpcSheetKind.character,
        characterId: 'ficha-vadrik',
      );
    }

    // Si el nombre del PNJ y el de su ficha se editaran por separado, la
    // biblioteca mostraría uno y la ficha otro.
    testWidgets('renombrar un PNJ con ficha renombra también la ficha', (
      tester,
    ) async {
      final server = await pumpDetail(tester, 'vadrik', seedCharacterNpc);

      await tester.tap(find.byTooltip('Editar nombre'));
      await tester.pumpAndSettle();
      await tester.enterText(
        inDialog(find.byType(TextField)),
        'Vadrik el Gris',
      );
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      expect(server.npcs['vadrik']!.name, 'Vadrik el Gris');
      expect(server.characters['ficha-vadrik']!.name, 'Vadrik el Gris');
      expect(tester.takeException(), isNull);
    });

    // La ficha de un PNJ es la del jugador sin lo que supone un jugador: no se
    // comparte ni tiene una campaña que mirar desde adentro.
    testWidgets('la ficha completa de un PNJ no se comparte y sube de nivel', (
      tester,
    ) async {
      final server = await pumpDetail(tester, 'vadrik', seedCharacterNpc);

      await tester.tap(find.text('Abrir ficha completa'));
      await tester.pumpAndSettle();

      expect(find.text('Volver al PNJ'), findsWidgets);
      expect(find.text('Compartir'), findsNothing);
      expect(find.text('Campaña'), findsNothing);
      // Nombre, retrato, trasfondo y notas tienen una sola casa: la pantalla
      // del PNJ. La ficha no ofrece una segunda.
      expect(find.text('Diario'), findsNothing);
      expect(find.text('Retrato'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.text('Subir nivel'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 8 && find.textContaining('Confirmar').evaluate().isEmpty;
        i++
      ) {
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Confirmar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(server.characters['ficha-vadrik']!.totalLevel, 2);
      // Sigue siendo la ficha de un PNJ: no aparece entre los personajes.
      expect(server.npcSheets, contains('ficha-vadrik'));
      expect(tester.takeException(), isNull);
    });
  });

  group('PNJ de la campaña', () {
    Future<void> openCampaignNpcs(WidgetTester tester) async {
      await tester.tap(find.text('PNJ'));
      await tester.pumpAndSettle();
    }

    testWidgets('el estado cambia desde la fila y quitar no borra', (
      tester,
    ) async {
      final server = await pumpDm(tester, (s) {
        seedLibrary(s);
        s.campaigns.remove('costa');
        s.campaignNpcs.remove((campaignId: 'costa', npcId: 'garrick'));
      });
      await openCampaignNpcs(tester);

      expect(
        find.text('2 PNJ · 1 vivo · 1 muerto · 0 desconocidos'),
        findsOneWidget,
      );
      // El muerto se lee tachado, no solo en otro color.
      final garrick = tester.widget<Text>(find.text('Garrick'));
      expect(garrick.style?.decoration, TextDecoration.lineThrough);

      await tester.tap(
        find.descendant(
          of: selector('Estado de Mirra'),
          matching: find.text('Desconocido'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        server.campaignNpcs[(campaignId: 'tumba', npcId: 'mirra')],
        NpcStatus.unknown,
      );

      await tester.tap(find.byTooltip('Acciones de Garrick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar de esta campaña'));
      await tester.pumpAndSettle();

      expect(
        server.campaignNpcs.containsKey((
          campaignId: 'tumba',
          npcId: 'garrick',
        )),
        isFalse,
      );
      expect(server.npcs.containsKey('garrick'), isTrue);
      expect(find.text('Garrick'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Exportar e importar', () {
    Map<String, dynamic> manifestOf(Uint8List bytes) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final file = archive.files.firstWhere(
        (f) => f.name == NpcBundleCodec.manifestName,
      );
      return (jsonDecode(utf8.decode(file.readBytes()!)) as Map)
          .cast<String, dynamic>();
    }

    final full = Npc(
      id: 'mirra',
      name: 'Mirra',
      sheetKind: NpcSheetKind.none,
      speech: 'Susurra.',
      background: 'Espía.',
      tags: const ['Phandalin'],
      notes: [
        NpcNote(id: 'n1', date: DateTime.utc(2026, 9, 1), text: 'Debe plata.'),
      ],
    );

    Future<NpcExportOptions?> pickOptions(
      WidgetTester tester, {
      List<String> toggle = const [],
    }) async {
      NpcExportOptions? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showDialog(
                context: context,
                builder: (_) => ExportNpcDialog(
                  entry: NpcEntry(npc: full, campaigns: const []),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      for (final label in toggle) {
        await tester.tap(inDialog(find.text(label)));
        await tester.pumpAndSettle();
      }
      await tester.tap(dialogAction('Descargar .zip'));
      await tester.pumpAndSettle();
      return picked;
    }

    // Por defecto viajan trasfondo y tags, y las notas —que son de las mesas
    // de quien exporta— no. Nunca viajan las campañas.
    for (final (toggle, background, tags, notes) in [
      (const <String>[], true, true, false),
      (const ['Notas'], true, true, true),
      (const ['Trasfondo', 'Tags'], false, false, false),
    ]) {
      testWidgets(
        'exportar con ${toggle.isEmpty ? 'las opciones de fábrica' : 'cambios en ${toggle.join(' y ')}'}',
        (tester) async {
          final options = await pickOptions(tester, toggle: toggle);
          expect(options, isNotNull);

          final manifest = manifestOf(
            NpcBundleCodec.encode(npc: npcForExport(full, options!)),
          );
          expect(manifest['type'], 'dnd_npc');
          final npc = Npc.fromJson(
            (manifest['npc'] as Map).cast<String, dynamic>(),
          );
          expect(npc.name, 'Mirra');
          expect(npc.speech, 'Susurra.');
          expect(npc.background, background ? 'Espía.' : '');
          expect(npc.tags, tags ? ['Phandalin'] : isEmpty);
          expect(npc.notes, hasLength(notes ? 1 : 0));
          expect(jsonEncode(manifest), isNot(contains('campaign')));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('la ficha viaja con el homebrew que usa', (tester) async {
      final sheet = Character(
        id: 'ficha',
        name: 'Vadrik',
        raceId: 'mi-especie',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: const {},
      );
      final homebrew = homebrewUsedBy(sheet, {
        'races': [
          {'id': 'mi-especie', 'name': 'Mi especie'},
          {'id': 'otra', 'name': 'Otra'},
        ],
      });
      final manifest = manifestOf(
        NpcBundleCodec.encode(
          npc: Npc(id: 'v', name: 'Vadrik', sheetKind: NpcSheetKind.character),
          sheet: sheet,
          homebrew: homebrew,
        ),
      );
      final races = (manifest['homebrew'] as Map)['races'] as List;
      expect(races.map((r) => (r as Map)['id']), ['mi-especie']);
    });

    // Sin la clase del lado de quien importa, la ficha no abriría: se dice
    // antes de subir nada.
    testWidgets('una ficha con una clase ausente no llega al servidor', (
      tester,
    ) async {
      bigView(tester);
      final server = FakeApiServer();
      final bytes = NpcBundleCodec.encode(
        npc: Npc(id: 'v', name: 'Vadrik', sheetKind: NpcSheetKind.character),
        sheet: Character(
          id: 'ficha',
          name: 'Vadrik',
          raceId: 'human',
          classId: 'clase-que-no-existe',
          backgroundId: 'soldier',
          assignedScores: const {},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImportNpcDialog(
                  api: ApiClient(client: server.client),
                  repo: repo,
                  bytes: bytes,
                  preview: NpcBundleCodec.preview(bytes),
                  campaigns: const [tumba],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se puede importar'), findsOneWidget);
      expect(
        find.textContaining('clase «clase-que-no-existe»'),
        findsOneWidget,
      );
      await tester.tap(dialogAction('Importar'));
      await tester.pumpAndSettle();
      expect(server.importNpcCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    // El personaje retirado de un jugador vuelve como PNJ con ficha: el
    // archivo de «Mis personajes» se rearma como el de un PNJ y entra por la
    // misma importación, sin una segunda ruta en el servidor.
    test('un personaje exportado se rearma como PNJ con ficha', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      final exported = await BackupBundleCodec.encode(
        scope: BackupScope.character,
        characters: [
          Character(
            id: 'pj-vadrik',
            name: 'Vadrik',
            raceId: 'human',
            classId: 'fighter',
            backgroundId: 'soldier',
            assignedScores: const {},
            background: 'Desertor del ejército.',
            portraitPaths: const ['ajeno/1.png', 'ajeno/2.png'],
            diary: [
              DiaryEntry(entryId: 'e1', title: 'Deudas', body: 'Al herrero.'),
              DiaryEntry(
                entryId: 'e2',
                kind: DiaryEntryKind.image,
                imageKey: 'ajeno/mapa.png',
              ),
            ],
          ),
        ],
        // El primer retrato no se pudo leer al exportar: el segundo tiene que
        // seguir atado a su propia clave, no correrse un lugar.
        readPortrait: (key) async => key == 'ajeno/2.png' ? png : null,
      );

      final bytes = NpcBundleCodec.adoptCharacterExport(exported);
      final preview = NpcBundleCodec.preview(bytes);
      expect(preview.npc.name, 'Vadrik');
      expect(preview.npc.sheetKind, NpcSheetKind.character);
      expect(preview.npc.background, 'Desertor del ejército.');
      expect(preview.npc.notes.map((n) => n.text), ['Deudas\nAl herrero.']);
      expect(preview.sheet!.background, isEmpty);
      expect(preview.sheet!.diary, isEmpty);
      final portraits = manifestOf(bytes)['portraits'] as List;
      expect(portraits.map((p) => (p as Map)['key']), ['ajeno/2.png']);
      expect(portraits.map((p) => (p as Map)['owner']), ['character']);
    });

    test('un respaldo con varios personajes pide exportar uno solo', () async {
      Character pj(String id) => Character(
        id: id,
        name: id,
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: const {},
      );
      final backup = await BackupBundleCodec.encode(
        scope: BackupScope.full,
        characters: [pj('a'), pj('b')],
        readPortrait: (_) async => null,
      );
      expect(
        () => NpcBundleCodec.adoptCharacterExport(backup),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('2 personajes'),
          ),
        ),
      );
      // Un archivo de PNJ pasa tal cual.
      final npcFile = NpcBundleCodec.encode(npc: full);
      expect(NpcBundleCodec.adoptCharacterExport(npcFile), same(npcFile));
    });
    testWidgets('importar con campaña la suma a esa campaña', (tester) async {
      bigView(tester);
      final server = FakeApiServer()
        ..campaigns['tumba'] = tumba
        ..importNpcResult = full;
      final bytes = NpcBundleCodec.encode(npc: full);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImportNpcDialog(
                  api: ApiClient(client: server.client),
                  repo: repo,
                  bytes: bytes,
                  preview: NpcBundleCodec.preview(bytes),
                  campaigns: const [tumba],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ninguna: queda sin campaña'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('La Tumba').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Importar'));
      await tester.pumpAndSettle();

      expect(server.importNpcCalls, hasLength(1));
      final id = server.npcs.keys.single;
      expect(
        server.campaignNpcs[(campaignId: 'tumba', npcId: id)],
        NpcStatus.alive,
      );
      expect(tester.takeException(), isNull);
    });

    // La observación con un PNJ que llevaba un arma homebrew: el servidor la
    // guardaba en la cuenta del DM, pero el catálogo en memoria se arma al
    // abrir la app, y la ficha la mostraba como «No está en el catálogo»
    // hasta recargar la página.
    testWidgets('el homebrew que trae la ficha entra al catálogo al importar', (
      tester,
    ) async {
      bigView(tester);
      const arma = Weapon(
        id: 'hb-bracamante-de-prueba',
        name: 'Bracamante de prueba',
        source: ContentSource.homebrew,
        category: 'martial',
        damageDice: '1d8',
        damageType: 'slashing',
      );
      addTearDown(() => repo.weapons.remove(arma.id));
      final sheet = Character(
        id: 'ficha',
        name: 'Mirra',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: const {},
        inventory: [InventoryEntry(itemId: arma.id)],
      );
      final conFicha = Npc(
        id: 'mirra',
        name: 'Mirra',
        sheetKind: NpcSheetKind.character,
      );
      final server = FakeApiServer()..importNpcResult = conFicha;
      final api = ApiClient(client: server.client);
      final store = HomebrewStore(api);
      final bytes = NpcBundleCodec.encode(
        npc: conFicha,
        sheet: sheet,
        homebrew: {
          'weapons': [arma.toJson()],
        },
      );
      expect(repo.weapon(arma.id), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImportNpcDialog(
                  api: api,
                  repo: repo,
                  bytes: bytes,
                  preview: NpcBundleCodec.preview(bytes),
                  campaigns: const [],
                  homebrew: store,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Importar'));
      await tester.pumpAndSettle();

      // En el catálogo, que es donde la busca la ficha, y en el store, que es
      // lo que lista la sección Homebrew.
      expect(repo.weapon(arma.id)?.name, arma.name);
      expect(store.weapons.keys, contains(arma.id));
      expect(tester.takeException(), isNull);
    });
  });
}
