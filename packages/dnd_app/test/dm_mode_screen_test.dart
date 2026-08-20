import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dm/dm_mode_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Monta el Modo DM contra un servidor falso ya sembrado: la pantalla lee sus
  /// campañas al montarse, así que lo que se agregue después no llega solo.
  Future<FakeApiServer> pumpDmMode(
    WidgetTester tester, {
    Size size = const Size(1400, 1000),
    void Function(FakeApiServer)? seed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = FakeApiServer();
    seed?.call(server);
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

  /// Una campaña creada y un jugador que ya compartió su ficha: el punto de
  /// partida real del DM cuando se sienta a la mesa.
  void seedTable(FakeApiServer server) {
    server.campaigns['tumba'] = const Campaign(id: 'tumba', name: 'La Tumba');
    server.characters['sagan'] = Character(
      id: 'sagan',
      name: 'Sagan',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final a in Ability.values) a: 12},
    );
    server.shareCodes['CODE-0001'] = 'sagan';
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.tap(find.text('Sumar personaje').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    // Sumar (y echar) reprograma un chequeo de avisos a los 3 segundos para no
    // taparle el cartel de confirmación a quien acaba de actuar: hay que
    // dejarlo correr, o el timer queda pendiente al desmontar el árbol.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  // Una cuenta que entra por primera vez tiene que entender qué hacer, no ver
  // un panel vacío.
  testWidgets('sin campañas ofrece crear la primera', (tester) async {
    await pumpDmMode(tester);

    expect(find.textContaining('Todavía no dirigís'), findsOneWidget);
    expect(find.text('Crear campaña'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear una campaña la deja abierta', (tester) async {
    final server = await pumpDmMode(tester);

    await tester.tap(find.text('Crear campaña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'La Tumba');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(server.campaigns.values.single.name, 'La Tumba');
    expect(find.text('La Tumba'), findsWidgets);
    expect(find.textContaining('Todavía nadie compartió'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear una campaña guarda su premisa y estado', (tester) async {
    final server = await pumpDmMode(tester);

    await tester.tap(find.text('Crear campaña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'La Tumba');
    await tester.enterText(
      find.byType(TextField).last,
      'Una maldición despierta bajo la ciudad.',
    );
    await tester.tap(find.text('En curso').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('En pausa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final campaign = server.campaigns.values.single;
    expect(campaign.premise, 'Una maldición despierta bajo la ciudad.');
    expect(campaign.state, CampaignState.paused);
    expect(find.text(campaign.premise), findsOneWidget);
    expect(find.text('En pausa'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar una campaña actualiza su identidad completa', (
    tester,
  ) async {
    final server = await pumpDmMode(
      tester,
      seed: (server) {
        server.campaigns['tumba'] = const Campaign(
          id: 'tumba',
          name: 'La Tumba',
          premise: 'Una expedición perdida.',
        );
      },
    );

    await tester.tap(find.byTooltip('Acciones de campaña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar campaña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'La Ciudad Hundida');
    await tester.enterText(
      find.byType(TextField).last,
      'El mar reclama las calles cada noche.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final campaign = server.campaigns['tumba']!;
    expect(campaign.name, 'La Ciudad Hundida');
    expect(campaign.premise, 'El mar reclama las calles cada noche.');
    expect(find.text(campaign.name), findsWidgets);
    expect(find.text(campaign.premise), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la acción principal acompaña la sección elegida', (
    tester,
  ) async {
    await pumpDmMode(tester, seed: seedTable);

    expect(
      find.widgetWithText(FilledButton, 'Sumar personaje'),
      findsOneWidget,
    );

    await tester.tap(find.text('Capítulos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Nuevo capítulo'), findsOneWidget);

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Empezar combate'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'las secciones viven en el lateral y el regreso dice Modo Jugador',
    (tester) async {
      await pumpDmMode(tester, seed: seedTable);

      expect(find.text('CAMPAÑA ACTUAL'), findsOneWidget);
      expect(find.text('Mesa'), findsOneWidget);
      expect(find.text('Capítulos'), findsOneWidget);
      expect(find.text('Combate'), findsOneWidget);
      expect(find.text('Cuaderno'), findsOneWidget);
      // El Bestiario va afuera del grupo de campaña: es de la app, no de la
      // mesa.
      expect(find.text('Bestiario'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is SegmentedButton),
        findsNothing,
      );
      expect(find.text('Modo Jugador'), findsOneWidget);
      expect(find.text('Volver a mis personajes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // Regresión: las campañas salían del panel recién después de tocar algo.
  //
  // Los tres grupos se calculaban en el cuerpo de `_sidebar`, fuera del
  // `ListenableBuilder`, así que el closure capturaba las listas del primer
  // build —vacías, porque todavía se estaban cargando— y notificar no las
  // actualizaba. Se veían al cambiar de sección, que es lo que fuerza un
  // `setState` y vuelve a correr `_sidebar`.
  testWidgets('al abrir el Modo DM el panel ya lista las campañas', (
    tester,
  ) async {
    await pumpDmMode(
      tester,
      seed: (server) {
        server.campaigns['activa'] = const Campaign(
          id: 'activa',
          name: 'Incendiando Phandalin',
        );
        server.campaigns['pausa'] = const Campaign(
          id: 'pausa',
          name: 'Rescatando al guerrero Bryan',
          state: CampaignState.paused,
        );
      },
    );

    // Sin tocar nada: los encabezados de grupo y las dos campañas están.
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('EN PAUSA'), findsOneWidget);
    expect(find.text('Incendiando Phandalin'), findsWidgets);
    expect(find.text('Rescatando al guerrero Bryan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al entrar prioriza una campaña en curso', (tester) async {
    await pumpDmMode(
      tester,
      seed: (server) {
        server.campaigns['pausa'] = const Campaign(
          id: 'pausa',
          name: 'Abadía',
          state: CampaignState.paused,
        );
        server.campaigns['activa'] = const Campaign(
          id: 'activa',
          name: 'Zafiro',
          premise: 'Esta es la campaña que se está jugando.',
        );
      },
    );

    expect(
      find.text('Esta es la campaña que se está jugando.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sumar un personaje con un código válido lo muestra', (
    tester,
  ) async {
    final server = await pumpDmMode(tester, seed: seedTable);

    await enterCode(tester, 'CODE-0001');

    expect(find.text('Sagan'), findsWidgets);
    expect(server.campaignMembers, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  // Un código gastado o inventado tiene que decirlo, no fallar en silencio.
  testWidgets('un código que no sirve muestra el mensaje del servidor', (
    tester,
  ) async {
    await pumpDmMode(tester, seed: seedTable);

    await enterCode(tester, 'ZZZZ-ZZZZ');

    expect(find.text('Código inválido o vencido.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Echar a alguien no puede ser un clic suelto: se va de la mesa de otro.
  testWidgets('echar a un personaje pide confirmación antes de cortar', (
    tester,
  ) async {
    final server = await pumpDmMode(tester, seed: seedTable);
    await enterCode(tester, 'CODE-0001');

    await tester.tap(find.byTooltip('Acciones de Sagan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Echar de la mesa'));
    await tester.pumpAndSettle();
    expect(find.text('Echar personaje'), findsWidgets);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(server.campaignMembers, hasLength(1));

    await tester.tap(find.byTooltip('Acciones de Sagan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Echar de la mesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Echar personaje'));
    await tester.pumpAndSettle();
    // Igual que sumar: reprograma un chequeo de avisos a los 3 segundos.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(server.campaignMembers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el panel entra en una ventana angosta sin desbordar', (
    tester,
  ) async {
    await pumpDmMode(tester, size: const Size(480, 800), seed: seedTable);

    expect(find.text('Modo DM'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en ventana angosta el drawer cambia de sección', (tester) async {
    await pumpDmMode(tester, size: const Size(480, 800), seed: seedTable);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Modo Jugador'), findsOneWidget);

    await tester.tap(find.text('Capítulos'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Nuevo capítulo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la mesa usa dos columnas cuando hay ancho suficiente', (
    tester,
  ) async {
    await pumpDmMode(
      tester,
      seed: (server) {
        seedTable(server);
        server.characters['lyra'] = Character(
          id: 'lyra',
          name: 'Lyra',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'soldier',
          assignedScores: {for (final a in Ability.values) a: 14},
        );
        server.shareCodes['CODE-0002'] = 'lyra';
      },
    );
    await enterCode(tester, 'CODE-0001');
    await enterCode(tester, 'CODE-0002');

    final saganTop = tester.getTopLeft(find.text('Sagan')).dy;
    final lyraTop = tester.getTopLeft(find.text('Lyra')).dy;
    expect(saganTop, lyraTop);
    expect(tester.takeException(), isNull);
  });

  group('Capítulos', () {
    Future<void> openCapitulos(WidgetTester tester) async {
      await tester.tap(find.text('Capítulos'));
      await tester.pumpAndSettle();
    }

    /// Crea un capítulo desde el diálogo. El primer campo es el nombre.
    Future<void> newChapter(
      WidgetTester tester,
      String name, {
      bool grantsLevel = false,
    }) async {
      await tester.tap(find.text('Nuevo capítulo').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, name);
      if (grantsLevel) {
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin capítulos explica para qué sirven', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);

      expect(find.textContaining('Todavía no dividiste'), findsOneWidget);
      expect(find.text('Nuevo capítulo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('crear un capítulo lo deja en Próximamente', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);

      await newChapter(tester, 'La Cripta');

      expect(find.text('La Cripta'), findsOneWidget);
      // `Eyebrow` pasa su texto a mayúsculas, así que el encabezado del grupo
      // no se busca por la etiqueta tal cual.
      expect(find.text('PRÓXIMAMENTE'), findsOneWidget);
      final chapter = server.chapters['tumba']!.single;
      expect(chapter.name, 'La Cripta');
      expect(chapter.state, ChapterState.planned);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empezar un capítulo lo pone en marcha', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');

      await tester.tap(find.widgetWithText(FilledButton, 'Empezar'));
      await tester.pumpAndSettle();

      expect(find.text('EN MARCHA'), findsOneWidget);
      expect(server.chapters['tumba']!.single.state, ChapterState.active);
      expect(tester.takeException(), isNull);
    });

    // La regla es del servidor; acá se comprueba que el DM vea el porqué en
    // vez de un fallo mudo.
    testWidgets('empezar un segundo capítulo muestra el mensaje del servidor', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');
      await newChapter(tester, 'El Regreso');

      await tester.tap(find.widgetWithText(FilledButton, 'Empezar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Empezar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ya hay un capítulo en marcha'),
        findsOneWidget,
      );
      expect(find.textContaining('La Cripta'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cerrar un capítulo pide confirmación y lo completa', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');
      await tester.tap(find.widgetWithText(FilledButton, 'Empezar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar capítulo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('le llega el aviso'), findsOneWidget);

      // El de la tarjeta y el del diálogo dicen lo mismo; el del diálogo es el
      // último en el árbol.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cerrar capítulo').last,
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPLETADO'), findsOneWidget);
      expect(server.chapters['tumba']!.single.state, ChapterState.completed);
      expect(tester.takeException(), isNull);
    });

    // El flag no reparte nada: solo cambia lo que dice el aviso, así que el
    // DM tiene que verlo marcado en la lista antes de cerrar.
    testWidgets('un capítulo que da nivel lo muestra en la lista', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);

      await newChapter(tester, 'La Cripta', grantsLevel: true);

      expect(find.text('Sube de nivel'), findsOneWidget);
      expect(server.chapters['tumba']!.single.grantsLevel, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('borrar un capítulo pide confirmación', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');

      await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(server.chapters['tumba']!, hasLength(1));

      await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar capítulo'));
      await tester.pumpAndSettle();

      expect(server.chapters['tumba']!, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Combate', () {
    Future<void> openCombate(WidgetTester tester) async {
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin combate abierto ofrece empezarlo', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);

      expect(find.text('No hay ningún combate en curso.'), findsOneWidget);
      expect(find.text('Empezar combate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'empezar combate ofrece sumar a la iniciativa al jugador de la mesa',
      (tester) async {
        final server = await pumpDmMode(tester, seed: seedTable);
        await enterCode(tester, 'CODE-0001');
        await openCombate(tester);

        await tester.tap(find.text('Empezar combate'));
        await tester.pumpAndSettle();

        expect(find.text('Todavía no tiraron iniciativa'), findsOneWidget);
        expect(find.text('Sumar a la iniciativa'), findsOneWidget);
        expect(server.encounters, contains('tumba'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sumar un jugador a la iniciativa lo deja en el orden', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar a la iniciativa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Todavía no tiraron iniciativa'), findsNothing);
      final combatants = server.encounters['tumba']!.combatants;
      expect(combatants, hasLength(1));
      expect(combatants.single.name, 'Sagan');
      expect(combatants.single.initiative, 15);
      expect(tester.takeException(), isNull);
    });

    // Sumar tres copias tira una iniciativa por cada una: nunca deben
    // terminar todas con el mismo número, a diferencia de lo que sugiere el
    // atajo de "tirar de una".
    testWidgets('sumar varios monstruos les tira una iniciativa a cada uno', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar monstruo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();

      final combatants = server.encounters['tumba']!.combatants;
      expect(combatants, hasLength(3));
      expect(
        combatants.map((c) => c.name),
        containsAll([
          'Guerrero goblin',
          'Guerrero goblin 2',
          'Guerrero goblin 3',
        ]),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avanzar turno y cerrar el combate lo borra del servidor', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar monstruo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siguiente turno'));
      await tester.pumpAndSettle();
      expect(server.encounters['tumba']!.round, 2);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Terminar y guardar'));
      await tester.pumpAndSettle();

      expect(server.encounters, isNot(contains('tumba')));
      expect(server.endedEncounters.single.discarded, isFalse);
      expect(find.text('No hay ningún combate en curso.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Un combate abierto por error se tiene que poder tirar sin que quede en
    // el registro de la campaña como si se hubiera jugado.
    testWidgets('descartar el combate lo cierra sin guardarlo', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Descartar sin guardar'),
      );
      await tester.pumpAndSettle();

      expect(server.encounters, isNot(contains('tumba')));
      expect(server.endedEncounters.single.discarded, isTrue);
      expect(find.text('No hay ningún combate en curso.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // "Cancelar" cierra el diálogo y nada más: no puede confundirse con
    // descartar el combate, que está al lado y es irreversible.
    testWidgets('cancelar el diálogo no termina el combate', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(server.encounters, contains('tumba'));
      expect(server.endedEncounters, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'un monstruo a 0 PG se marca caído y su turno se salta al avanzar',
      (tester) async {
        final server = await pumpDmMode(tester, seed: seedTable);
        await enterCode(tester, 'CODE-0001');
        await openCombate(tester);
        await tester.tap(find.text('Empezar combate'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sumar a la iniciativa'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '20');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sumar monstruo'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'goblin');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sumar'));
        await tester.pumpAndSettle();

        // El campo trae "1" por defecto: se sube antes de dañar para
        // liquidarlo de un solo golpe, sin importar sus PG máximos reales.
        await tester.enterText(find.byType(TextField).last, '999');
        await tester.tap(find.byTooltip('Dañar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('caído'), findsOneWidget);
        final goblin = server.encounters['tumba']!.combatants.firstWhere(
          (c) => c.kind == CombatantKind.monster,
        );
        expect(goblin.currentHp, 0);

        // Con Sagan (iniciativa 20) en pie y el goblin caído, avanzar no
        // tiene a quién más pasarle el turno: le toca otra ronda a Sagan.
        await tester.tap(find.text('Siguiente turno'));
        await tester.pumpAndSettle();

        expect(server.encounters['tumba']!.round, 2);
        expect(tester.takeException(), isNull);
      },
    );

    // Sin enemigos en pie el encuentro ya está resuelto, pero cerrarlo lo
    // decide el DM: se ofrece, no se hace solo.
    testWidgets('sin enemigos en pie ofrece terminar el encuentro', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar monstruo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No queda ningún enemigo'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '999');
      await tester.tap(find.byTooltip('Dañar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No queda ningún enemigo en pie'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // El orden de carga no puede decidir el turno: el jugador entra primero
    // pero con iniciativa baja, así que arranca el goblin.
    testWidgets('el primer turno es del de mayor iniciativa, no del que se '
        'cargó primero', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Empezar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar a la iniciativa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar monstruo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();

      // La iniciativa del goblin se tira sola, así que no se puede fijar
      // quién gana: lo que sí tiene que valer siempre es que el turno esté
      // en la iniciativa más alta de la mesa, y no en quien se cargó primero.
      final encounter = server.encounters['tumba']!;
      final highest = encounter.combatants
          .map((c) => c.initiative)
          .reduce((a, b) => a > b ? a : b);
      expect(encounter.current!.initiative, highest);
      expect(encounter.turnIndex, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cuaderno', () {
    /// Una mesa con un capítulo en marcha: el cuaderno cuelga de capítulos, así
    /// que sin uno no hay dónde escribir.
    void seedChapter(FakeApiServer server) {
      seedTable(server);
      server.chapters['tumba'] = [
        const Chapter(
          id: 'cripta',
          name: 'La cripta sellada',
          state: ChapterState.active,
        ),
      ];
    }

    Future<void> openCuaderno(WidgetTester tester) async {
      await tester.tap(find.text('Cuaderno'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin capítulos manda a crear uno primero', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCuaderno(tester);

      expect(find.textContaining('primero hay que crear uno'), findsOneWidget);
      // Y no se puede escribir: la nota no tendría dónde ir.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Escribir nota'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('escribir una nota la guarda en el capítulo', (tester) async {
      final server = await pumpDmMode(tester, seed: seedChapter);
      await openCuaderno(tester);

      await tester.tap(find.text('Escribir nota'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Los tres sellos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nota'),
        'El tercero está detrás del tapiz.',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(server.notes['tumba']!.single.title, 'Los tres sellos');
      expect(server.notes['tumba']!.single.chapterId, 'cripta');
      expect(find.text('Los tres sellos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('borrar una nota pide confirmación', (tester) async {
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedChapter(s);
          s.notes['tumba'] = [
            const Note(
              id: 'n1',
              chapterId: 'cripta',
              title: 'Los tres sellos',
              body: 'Detrás del tapiz.',
            ),
          ];
        },
      );
      await openCuaderno(tester);

      await tester.tap(find.byTooltip('Acciones de la nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      expect(find.text('Borrar nota'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Borrar nota'));
      await tester.pumpAndSettle();

      expect(server.notes['tumba'], isEmpty);
      expect(tester.takeException(), isNull);
    });

    // El cuaderno es el primer lector de los combates archivados: hasta ahora
    // se grababan y no los mostraba nadie.
    testWidgets('un combate cerrado aparece como entrada', (tester) async {
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedChapter(s);
          s.encounterLogs['tumba'] = [
            const EncounterLog(
              id: 'log-0',
              chapterId: 'cripta',
              rounds: 4,
              players: ['Sagan', 'Mirna'],
              monsters: [
                EncounterLogMonsters(name: 'Esqueleto', count: 2, defeated: 2),
              ],
            ),
          ];
        },
      );
      await openCuaderno(tester);

      expect(find.text('Combate contra Esqueleto'), findsOneWidget);
      expect(
        find.textContaining('Sagan, Mirna contra 2 Esqueleto'),
        findsOneWidget,
      );
      expect(find.textContaining('Cayeron todos'), findsOneWidget);
      // Un combate no se edita: no lleva menú, a diferencia de una nota.
      expect(find.byTooltip('Acciones de la nota'), findsNothing);
      expect(server.notes['tumba'] ?? const [], isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busca y abre el capítulo que coincide', (tester) async {
      await pumpDmMode(
        tester,
        seed: (s) {
          seedChapter(s);
          s.chapters['tumba']!.add(
            const Chapter(id: 'camino', name: 'El camino'),
          );
          s.notes['tumba'] = [
            const Note(
              id: 'n1',
              chapterId: 'camino',
              title: 'Deuda con el herrero',
              body: 'Cobrárselo más adelante.',
            ),
          ];
        },
      );
      await openCuaderno(tester);

      // «El camino» arranca plegado: solo se abre el capítulo en marcha.
      expect(find.text('Deuda con el herrero'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en el cuaderno'),
        'herrero',
      );
      await tester.pumpAndSettle();

      // Buscar abre el capítulo que coincide y esconde el que no. Se comprueba
      // por la tarjeta y no por el nombre: el encabezado de la campaña ya
      // muestra el capítulo en marcha, así que su texto está igual en pantalla.
      expect(find.text('Deuda con el herrero'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notebook-chapter-camino')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notebook-chapter-cripta')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un capítulo plegado resume lo que tiene', (tester) async {
      await pumpDmMode(
        tester,
        seed: (s) {
          seedChapter(s);
          s.chapters['tumba']!.add(
            const Chapter(id: 'camino', name: 'El camino'),
          );
          s.notes['tumba'] = [
            const Note(id: 'n1', chapterId: 'camino', title: 'Una'),
            const Note(id: 'n2', chapterId: 'camino', title: 'Otra'),
          ];
        },
      );
      await openCuaderno(tester);

      expect(find.text('2 notas'), findsOneWidget);
      expect(find.text('Una'), findsNothing);

      // Y al abrirlo aparecen.
      await tester.tap(find.text('El camino'));
      await tester.pumpAndSettle();
      expect(find.text('Una'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bestiario', () {
    Future<void> openBestiario(WidgetTester tester) async {
      await tester.tap(find.text('Bestiario'));
      await tester.pumpAndSettle();
    }

    /// La lista es alfabética y perezosa, así que una criatura del medio no
    /// está construida todavía. Se llega filtrando y no scrolleando, igual que
    /// en las pruebas de creación de personaje.
    Future<void> buscar(WidgetTester tester, String texto) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar criatura'),
        texto,
      );
      await tester.pumpAndSettle();
    }

    // Es la decisión de fondo de esta sección: el catálogo de criaturas no es
    // de ninguna campaña, así que se tiene que poder consultar sin tener una.
    // Sin campañas, el panel de contenido mostraría el estado de bienvenida.
    testWidgets('se abre sin tener ninguna campaña', (tester) async {
      await pumpDmMode(tester);
      expect(find.text('Prepará tu primera mesa'), findsOneWidget);

      await openBestiario(tester);

      expect(find.text(repo.creaturesSorted.first.name), findsOneWidget);
      expect(find.text('Prepará tu primera mesa'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('elegir una campaña sale del bestiario', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);
      expect(find.text('Sumar personaje'), findsNothing);

      await tester.tap(find.text('La Tumba'));
      await tester.pumpAndSettle();

      expect(find.text('Sumar personaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busca por nombre', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);
      await buscar(tester, 'goblin');

      expect(find.text(repo.creature('goblin-warrior')!.name), findsOneWidget);
      expect(find.text(repo.creature('ogre')!.name), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // El buscador viejo del combate compara con `toLowerCase().contains`, así
    // que tipear «aguila» no encuentra «Águila». Acá se pliega el acento, que
    // es como se escribe de verdad cuando uno busca rápido.
    testWidgets('busca sin acentos', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      await buscar(tester, 'aguila');

      expect(find.text(repo.creature('eagle')!.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra el perfil de una criatura', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      final ogre = repo.creature('ogre')!;
      await buscar(tester, 'ogro');
      await tester.tap(find.byKey(const ValueKey('bestiary-ogre')));
      await tester.pumpAndSettle();

      // Los números y la acción salen del catálogo, no de literales: si el
      // perfil cambia, el test sigue diciendo la verdad.
      expect(find.text(ogre.ac), findsWidgets);
      expect(find.text(ogre.actions.first.name), findsOneWidget);
      expect(find.text('ACCIONES'), findsOneWidget);
      // El tipo sale dos veces: como subtítulo en la lista y en el perfil.
      expect(find.text(ogre.kind), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin coincidencias lo dice y deja limpiar', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      await buscar(tester, 'no existe ninguna así');
      expect(
        find.text('Ninguna criatura coincide con lo que buscaste.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      // Vuelve el catálogo entero: se comprueba con la primera alfabética, que
      // es la única que se puede afirmar que está construida.
      expect(
        find.text('Ninguna criatura coincide con lo que buscaste.'),
        findsNothing,
      );
      expect(find.text(repo.creaturesSorted.first.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en pantalla angosta la lista deja lugar al perfil', (
      tester,
    ) async {
      await pumpDmMode(tester, size: const Size(480, 800), seed: seedTable);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await openBestiario(tester);
      await buscar(tester, 'ogro');

      // Angosto no hay lugar para las dos columnas: elegir una criatura
      // reemplaza el listado, y se vuelve con el botón.
      await tester.tap(find.byKey(const ValueKey('bestiary-ogre')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bestiary-ogre')), findsNothing);
      expect(find.text(repo.creature('ogre')!.kind), findsOneWidget);

      await tester.tap(find.text('Volver al listado'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bestiary-ogre')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
