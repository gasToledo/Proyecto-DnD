import 'dart:async';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/dm/dm_mode_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialog_finders.dart';
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
    await tester.tap(dialogAction('Guardar'));
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
    await tester.tap(dialogAction('Guardar'));
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
    expect(find.widgetWithText(FilledButton, 'Armar combate'), findsOneWidget);
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
    await tester.tap(dialogAction('Echar personaje'));
    await tester.pumpAndSettle();
    // Igual que sumar: reprograma un chequeo de avisos a los 3 segundos.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(server.campaignMembers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // El DM no escribe la ficha de otra cuenta: conceder es dejar un aviso.
  testWidgets('conceder Inspiración Heroica avisa y no toca la ficha', (
    tester,
  ) async {
    final server = await pumpDmMode(tester, seed: seedTable);
    await enterCode(tester, 'CODE-0001');

    final antes = server.characters['sagan']!.toJson();

    await tester.tap(find.byTooltip('Acciones de Sagan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conceder Inspiración Heroica'));
    await tester.pumpAndSettle();

    expect(server.heroicInspirationGrants, hasLength(1));
    // Sigue en la mesa: el ítem nuevo no puede terminar echando a nadie.
    expect(server.campaignMembers, hasLength(1));
    // Y la ficha quedó intacta.
    expect(server.characters['sagan']!.toJson(), antes);
    expect(find.textContaining('La marca en su ficha'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  // Regresión del bug más fácil de cometer: el menú tenía
  // `onSelected: (_) => onRemove()`, que ignora cuál ítem se eligió.
  testWidgets('elegir conceder no echa al personaje de la mesa', (
    tester,
  ) async {
    final server = await pumpDmMode(tester, seed: seedTable);
    await enterCode(tester, 'CODE-0001');

    await tester.tap(find.byTooltip('Acciones de Sagan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conceder Inspiración Heroica'));
    await tester.pumpAndSettle();

    expect(find.text('Echar personaje'), findsNothing);
    expect(server.campaignMembers, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
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

    /// Crea un capítulo desde el diálogo. Los campos van en el orden en que se
    /// leen: nombre, objetivo, oro e ítems.
    Future<void> newChapter(
      WidgetTester tester,
      String name, {
      bool grantsLevel = false,
      String? gold,
      String? items,
    }) async {
      await tester.tap(find.text('Nuevo capítulo').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, name);
      if (grantsLevel) {
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
      }
      if (gold != null) {
        await tester.enterText(find.byType(TextField).at(2), gold);
      }
      if (items != null) {
        await tester.enterText(find.byType(TextField).at(3), items);
      }
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();
    }

    // Guardar sin nombre no guardaba nada y tampoco decía por qué: el diálogo
    // se quedaba quieto y se lee como que la app se colgó.
    testWidgets('guardar un capítulo sin nombre explica qué falta', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await tester.tap(find.text('Nuevo capítulo').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Poné un nombre para guardarlo.'), findsOneWidget);
      expect(server.chapters['tumba'] ?? const [], isEmpty);

      // Y se apaga al escribir, sin tener que reintentar para limpiarlo.
      await tester.enterText(find.byType(TextField).first, 'La Cripta');
      await tester.pumpAndSettle();
      expect(find.text('Poné un nombre para guardarlo.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

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

      // El de la tarjeta y el del diálogo dicen lo mismo: lo que los separa es
      // que uno es celda del pie del diálogo.
      await tester.tap(dialogAction('Cerrar capítulo'));
      await tester.pumpAndSettle();

      expect(find.text('COMPLETADO'), findsOneWidget);
      expect(server.chapters['tumba']!.single.state, ChapterState.completed);
      expect(tester.takeException(), isNull);
    });

    // Si el cierre no entró, el cartel de éxito no puede salir igual: tapa al
    // error (un aviso reemplaza al anterior) y deja al DM creyendo que a los
    // jugadores les llegó el aviso.
    testWidgets('cerrar un capítulo que falla no dice que se cerró', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');
      await tester.tap(find.widgetWithText(FilledButton, 'Empezar'));
      await tester.pumpAndSettle();

      // El capítulo desapareció del servidor entre medio: el cierre responde
      // 404, y ese es el mensaje que tiene que quedar en pantalla.
      server.chapters['tumba']!.clear();

      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar capítulo'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Cerrar capítulo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Capítulo no encontrado'), findsOneWidget);
      expect(find.textContaining('Se cerró'), findsNothing);
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

    // Mismo caso que el nivel: la app no reparte nada, así que lo único que
    // tiene que pasar es que el DM lea en la lista lo que va a anunciar.
    testWidgets('un capítulo con botín lo muestra en la lista', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);

      await newChapter(
        tester,
        'La Cripta',
        gold: '250',
        items: 'Espada larga +1\n\nPoción de curación\n',
      );

      expect(
        find.text('Se llevan 250 po, Espada larga +1 y Poción de curación'),
        findsOneWidget,
      );
      final chapter = server.chapters['tumba']!.single;
      expect(chapter.grantsGold, 250);
      // Las líneas en blanco del campo no son ítems.
      expect(chapter.grantsItems, ['Espada larga +1', 'Poción de curación']);
      expect(tester.takeException(), isNull);
    });

    // Cerrar es la única acción del Modo DM que le escribe a otra cuenta. Lo
    // que se le escribe es un aviso, y el diálogo lo dice antes de mandarlo.
    testWidgets(
      'el diálogo de cierre nombra el botín y aclara quién lo anota',
      (tester) async {
        await pumpDmMode(tester, seed: seedTable);
        await openCapitulos(tester);
        await newChapter(tester, 'La Cripta', grantsLevel: true, gold: '250');
        await tester.tap(find.widgetWithText(FilledButton, 'Empezar'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Cerrar capítulo'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('se llevan un nivel y 250 po'),
          findsOneWidget,
        );
        expect(
          find.textContaining('la app no se lo aplica a nadie'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('borrar un capítulo pide confirmación', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCapitulos(tester);
      await newChapter(tester, 'La Cripta');

      await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Cancelar'));
      await tester.pumpAndSettle();
      expect(server.chapters['tumba']!, hasLength(1));

      await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Borrar capítulo'));
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

    /// Pasa de armar la mesa a jugarla, aceptando la iniciativa propuesta.
    ///
    /// A los monstruos el diálogo se las trae ya tiradas; a los jugadores hay
    /// que escribírselas, así que quien necesite un número puntual lo pasa en
    /// [initiatives] por nombre de combatiente. El resto de los casilleros
    /// vacíos se completa con 0: el diálogo no arranca con ninguno en blanco.
    Future<void> tirarIniciativa(
      WidgetTester tester, {
      Map<String, int> initiatives = const {},
    }) async {
      await tester.tap(find.text('Tirar iniciativa'));
      await tester.pumpAndSettle();
      for (final entry in initiatives.entries) {
        // Cada fila del diálogo es un Row con el nombre y su campo. Se busca
        // **adentro del diálogo**: el mismo nombre está también en la fila del
        // combatiente que quedó atrás, y sin acotar se engancha esa.
        final nombre = find.descendant(
          of: find.byType(AppDialog),
          matching: find.text(entry.key),
        );
        await tester.enterText(
          find.descendant(
            of: find.ancestor(of: nombre, matching: find.byType(Row)).first,
            matching: find.byType(TextField),
          ),
          '${entry.value}',
        );
      }
      final fields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      );
      for (var i = 0; i < fields.evaluate().length; i++) {
        final field = fields.at(i);
        if (tester.widget<TextField>(field).controller!.text.isEmpty) {
          await tester.enterText(field, '0');
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Empezar'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin combate abierto ofrece empezarlo', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);

      expect(find.text('No hay ningún combate en curso.'), findsOneWidget);
      expect(find.text('Armar combate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('armar el combate ofrece sumar a la mesa a los jugadores', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);

      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      expect(find.text('Armando la mesa'), findsOneWidget);
      expect(find.text('Todavía no están en la mesa'), findsOneWidget);
      expect(find.text('Sumar a la mesa'), findsOneWidget);
      expect(server.encounters, contains('tumba'));
      expect(server.encounters['tumba']!.isPreparing, isTrue);
      expect(tester.takeException(), isNull);
    });

    // Mientras se arma, sumar un jugador es un solo toque: nadie tiró todavía.
    testWidgets('mientras se arma, el jugador entra sin iniciativa', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();

      final combatants = server.encounters['tumba']!.combatants;
      expect(combatants, hasLength(1));
      expect(combatants.single.name, 'Sagan');
      expect(combatants.single.initiative, 0);
      // Y el cero no se pinta: se leería como una tirada malísima en vez de
      // como «todavía no tiró».
      expect(find.text('—'), findsOneWidget);
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
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar al combate'));
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

    // El buscador del diálogo comparaba con `toLowerCase().contains` y cortaba
    // en 30. Ahora usa la regla del Bestiario y muestra el VD, que es lo que
    // se mira para elegir entre dos criaturas parecidas.
    testWidgets('el buscador del combate ignora acentos y muestra el VD', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'aguila');
      await tester.pumpAndSettle();

      final eagle = repo.creature('eagle')!;
      final tile = find.byKey(const ValueKey('add-bestiary-eagle'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text('VD ${challengeRatingLabel(eagle.cr!)}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    /// Suma [count] copias de un monstruo desde el diálogo, opcionalmente
    /// tirándoles los PG.
    Future<void> addMonsters(
      WidgetTester tester,
      String search,
      String name, {
      int count = 1,
      bool rollHp = false,
    }) async {
      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), search);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
      for (var i = 1; i < count; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      }
      await tester.pumpAndSettle();
      if (rollHp) {
        await tester.tap(find.text('Tirar los PG de cada uno'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
    }

    // Lo que pidieron los DM: seis minions con la misma vida se notan. Con la
    // tirada puesta, cada copia entra con la suya.
    testWidgets('con los PG tirados las copias no salen todas iguales', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await addMonsters(
        tester,
        'goblin',
        'Guerrero goblin',
        count: 8,
        rollHp: true,
      );

      final hps = server.encounters['tumba']!.combatants
          .map((c) => c.currentHp)
          .toList();
      expect(hps, hasLength(8));
      // Con 8 tiradas de 2d6 salir las ocho iguales tiene una probabilidad
      // despreciable; si pasa, es que no se está tirando.
      expect(hps.toSet().length, greaterThan(1));

      // Y los PG de cada uno arrancan llenos: el máximo es el tirado, no el
      // promedio del libro, así que ninguna barra empieza a media asta.
      for (final c in server.encounters['tumba']!.combatants) {
        expect(c.currentHp, c.maxHp, reason: c.name);
      }
      expect(tester.takeException(), isNull);
    });

    // El promedio del libro sigue siendo el comportamiento por defecto: es lo
    // que corresponde para un jefe, que tiene que aguantar lo que se planeó.
    testWidgets('sin tirar, todas las copias usan el promedio del libro', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await addMonsters(tester, 'goblin', 'Guerrero goblin', count: 4);

      final esperado = int.parse(repo.creature('goblin-warrior')!.hp);
      final hps = server.encounters['tumba']!.combatants.map((c) => c.maxHp);
      expect(hps, everyElement(esperado));
      expect(tester.takeException(), isNull);
    });

    // Sin dados en el perfil no hay nada que tirar, y ofrecerlo sería mentir.
    testWidgets('un perfil sin dados de golpe no ofrece tirarlos', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'defensor');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Defensor de Acero'));
      await tester.pumpAndSettle();

      expect(find.text('Tirar los PG de cada uno'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    /// Deja un goblin en la mesa, que es el sujeto de las pruebas de efectos.
    Future<FakeApiServer> withGoblin(WidgetTester tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await addMonsters(tester, 'goblin', 'Guerrero goblin');
      return server;
    }

    List<String> tagsOf(FakeApiServer server) =>
        server.encounters['tumba']!.combatants.single.tags;

    // El rótulo decía «Golpe rápido», pero el mismo número lo usa el botón de
    // curar: nombraba la mitad de lo que hace. Y que la cifra sea de toda la
    // mesa —y no de la fila que estás mirando— no lo decía nada.
    testWidgets('la cifra compartida dice que también cura', (tester) async {
      await withGoblin(tester);
      await tirarIniciativa(tester);

      expect(find.text('DAÑO O CURACIÓN'), findsOneWidget);
      expect(find.text('GOLPE RÁPIDO'), findsNothing);
      // Los dos botones que la gastan siguen teniendo su nombre.
      expect(find.byTooltip('Dañar'), findsOneWidget);
      expect(find.byTooltip('Curar'), findsOneWidget);
      // Y los atajos dejan de ser tres números sueltos.
      expect(find.byTooltip('Poner 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Lo que se olvida en la mesa no siempre es una condición del libro: hay
    // que poder escribir cualquier cosa.
    testWidgets('anotar un efecto a mano lo deja en la fila', (tester) async {
      final server = await withGoblin(tester);

      await tester.tap(find.byTooltip('Efectos'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Anotar un efecto'),
        'marcado por el pícaro',
      );
      await tester.tap(find.byTooltip('Anotar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      expect(tagsOf(server), ['marcado por el pícaro']);
      expect(find.text('marcado por el pícaro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las condiciones del libro están como atajo', (tester) async {
      final server = await withGoblin(tester);

      await tester.tap(find.byTooltip('Efectos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Envenenado'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      expect(tagsOf(server), ['Envenenado']);
      expect(tester.takeException(), isNull);
    });

    // En la ronda en que se termina un veneno, abrir el diálogo para
    // destildarlo sería un rodeo: se saca desde la propia fila.
    testWidgets('un efecto se saca desde la fila, sin abrir el diálogo', (
      tester,
    ) async {
      final server = await withGoblin(tester);

      await tester.tap(find.byTooltip('Efectos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Derribado'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();
      expect(tagsOf(server), ['Derribado']);

      await tester.tap(find.byTooltip('Sacar «Derribado»'));
      await tester.pumpAndSettle();

      expect(tagsOf(server), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar el diálogo no anota nada', (tester) async {
      final server = await withGoblin(tester);

      await tester.tap(find.byTooltip('Efectos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Aturdido'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Cancelar'));
      await tester.pumpAndSettle();

      expect(tagsOf(server), isEmpty);
      expect(tester.takeException(), isNull);
    });

    // Mientras se arma la mesa, la acción principal es tirar iniciativa; recién
    // después aparece «Siguiente turno».
    testWidgets('la acción principal sigue la etapa del combate', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      expect(find.text('Armar combate'), findsOneWidget);

      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      expect(find.text('Tirar iniciativa'), findsOneWidget);
      expect(find.text('Siguiente turno'), findsNothing);

      await addMonsters(tester, 'goblin', 'Guerrero goblin');
      await tirarIniciativa(tester);

      expect(find.text('Siguiente turno'), findsOneWidget);
      expect(find.text('Tirar iniciativa'), findsNothing);
      // La barra de la planilla separa el rótulo del número, como toda placa
      // de la app: la ronda se lee como cifra, no como frase.
      expect(find.text('RONDA'), findsOneWidget);
      expect(find.text('Turno 1 de 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Sin nadie en la mesa no hay iniciativa que tirar.
    testWidgets('con la mesa vacía no se puede tirar iniciativa', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Tirar iniciativa'),
      );
      expect(boton.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    // A los monstruos el diálogo les propone el número ya tirado; a los
    // jugadores les queda en blanco, porque ese número lo cantan ellos.
    testWidgets('el diálogo propone la tirada de los monstruos', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();
      await addMonsters(tester, 'goblin', 'Guerrero goblin');

      await tester.tap(find.text('Tirar iniciativa'));
      await tester.pumpAndSettle();

      String valorDe(String nombre) {
        final campo = find.descendant(
          of: find
              .ancestor(
                of: find.descendant(
                  of: find.byType(AppDialog),
                  matching: find.text(nombre),
                ),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byType(TextField),
        );
        return tester.widget<TextField>(campo).controller!.text;
      }

      expect(valorDe('Sagan'), isEmpty);
      expect(int.tryParse(valorDe('Guerrero goblin')), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar la tirada deja el combate armándose', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await addMonsters(tester, 'goblin', 'Guerrero goblin');

      await tester.tap(find.text('Tirar iniciativa'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Cancelar'));
      await tester.pumpAndSettle();

      expect(server.encounters['tumba']!.isPreparing, isTrue);
      expect(find.text('Armando la mesa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avanzar turno y cerrar el combate lo borra del servidor', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
      await tirarIniciativa(tester);

      await tester.tap(find.text('Siguiente turno'));
      await tester.pumpAndSettle();
      expect(server.encounters['tumba']!.round, 2);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar y guardar'));
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
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar sin guardar'));
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
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
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
        await tester.tap(find.text('Armar combate'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sumar a la mesa'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sumar al combate'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'goblin');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sumar'));
        await tester.pumpAndSettle();
        await tirarIniciativa(tester, initiatives: {'Sagan': 20});

        // El campo trae "1" por defecto: se sube antes de dañar para
        // liquidarlo de un solo golpe, sin importar sus PG máximos reales.
        await tester.enterText(find.byType(TextField).last, '999');
        await tester.tap(find.byTooltip('Dañar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Caído'), findsOneWidget);
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
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
      await tirarIniciativa(tester);

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

    /// Un combate ya jugándose, con un solo goblin a PG completos. Los números
    /// salen del bestiario, igual que cuando el DM lo suma desde la pantalla.
    Encounter combateConGoblin() {
      final goblin = repo.creatures.values.firstWhere(
        (c) => c.name == 'Guerrero goblin',
      );
      final pg = goblin.resolve(const CreatureVars({})).maxHp;
      return Encounter(
        id: 'en-curso',
        stage: EncounterStage.running,
        combatants: [
          Combatant(
            id: 'goblin-1',
            kind: CombatantKind.monster,
            name: goblin.name,
            initiative: 10,
            creatureId: goblin.id,
            currentHp: pg,
            maxHp: pg,
          ),
        ],
      );
    }

    // Con una docena larga de combatientes, «Siguiente turno» dejaba la marca
    // fuera de pantalla y el DM tenía que ir a buscar a quién le tocaba. Se
    // prueban los dos sentidos: bajar hasta el último y, al empezar la ronda
    // siguiente, volver a subir hasta el primero.
    testWidgets('el turno nuevo queda a la vista en una planilla larga', (
      tester,
    ) async {
      final goblin = combateConGoblin().combatants.single;
      final combate = Encounter(
        id: 'en-curso',
        stage: EncounterStage.running,
        turnIndex: 18,
        combatants: [
          for (var i = 1; i <= 20; i++)
            Combatant(
              id: 'g$i',
              kind: CombatantKind.monster,
              name: 'Goblin $i',
              initiative: 40 - i,
              creatureId: goblin.creatureId,
              currentHp: goblin.maxHp,
              maxHp: goblin.maxHp,
            ),
        ],
      );
      await pumpDmMode(
        tester,
        size: const Size(1400, 700),
        seed: (s) {
          seedTable(s);
          s.encounters['tumba'] = combate;
        },
      );
      await openCombate(tester);

      bool visible(String name) {
        final rect = tester.getRect(find.text(name));
        return rect.top >= 0 && rect.bottom <= 700;
      }

      expect(visible('Goblin 20'), isFalse, reason: 'la planilla no es larga');

      await tester.tap(find.text('Siguiente turno'));
      await tester.pumpAndSettle();
      expect(visible('Goblin 20'), isTrue);
      expect(visible('Goblin 1'), isFalse);

      await tester.tap(find.text('Siguiente turno'));
      await tester.pumpAndSettle();
      expect(visible('Goblin 1'), isTrue);
      expect(tester.takeException(), isNull);
    });

    // Cada golpe sale del combate que dejó guardado el anterior. Con el
    // servidor lento, los dos partían del mismo estado y el segundo pisaba al
    // primero: el goblin recibía un solo golpe.
    testWidgets('dos golpes seguidos se suman aunque el servidor tarde', (
      tester,
    ) async {
      final combate = combateConGoblin();
      final pg = combate.combatants.single.maxHp;
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedTable(s);
          s.encounters['tumba'] = combate;
        },
      );
      await openCombate(tester);

      final respuesta = Completer<void>();
      server.beforeHandle = (request) async {
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/encounter')) {
          await respuesta.future;
        }
      };
      // La cantidad trae «1»: dos toques antes de que conteste el primero.
      await tester.tap(find.byTooltip('Dañar'));
      await tester.pump();
      await tester.tap(find.byTooltip('Dañar'));
      await tester.pump();
      respuesta.complete();
      await tester.pumpAndSettle();

      expect(server.encounters['tumba']!.combatants.single.currentHp, pg - 2);
      // La fila y la columna del turno muestran los mismos PG, y ninguna se
      // queda con los de un solo golpe.
      expect(find.text('${pg - 2}/$pg'), findsWidgets);
      expect(find.text('${pg - 1}/$pg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Sin haber podido leer el combate no se sabe si hay uno: armar otro lo
    // reemplazaría entero en el servidor. La salida es reintentar.
    testWidgets('si no se pudo leer el combate no deja armar otro encima', (
      tester,
    ) async {
      final combate = combateConGoblin();
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedTable(s);
          s.encounters['tumba'] = combate;
          s.beforeHandle = (request) async {
            if (request.method == 'GET' &&
                request.url.path.endsWith('/encounter')) {
              throw Exception('Sin conexión');
            }
          };
        },
      );
      await openCombate(tester);

      expect(find.text('No se pudo leer el combate.'), findsOneWidget);
      final armar = find.widgetWithText(FilledButton, 'Armar combate');
      expect(tester.widget<FilledButton>(armar).onPressed, isNull);
      await tester.tap(armar);
      await tester.pumpAndSettle();
      expect(server.encounters['tumba'], same(combate));

      server.beforeHandle = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text(combate.combatants.single.name), findsWidgets);
      expect(find.text('Siguiente turno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // El sondeo de la mesa y una respuesta lenta se cruzan: la que llega tarde
    // no puede pisar a la que se pidió después.
    testWidgets('una lectura vieja de la mesa no pisa los PG más nuevos', (
      tester,
    ) async {
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedTable(s);
          // Con PG por nivel anotados, para que el valor viejo y el nuevo no
          // coincidan: sin ellos el máximo da 1.
          s.characters['sagan'] = s.characters['sagan']!.copyWith(
            hpPerLevel: const [10],
          );
        },
      );
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();

      final sagan = server.characters['sagan']!;
      final max = CharacterCompiler(repo).compile(sagan).maxHp;
      final lenta = Completer<void>();
      var lecturas = 0;
      server.beforeHandle = (request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/members') &&
            lecturas++ == 0) {
          await lenta.future;
        }
      };

      // La primera lectura del sondeo sale con los PG completos y se queda
      // esperando.
      sagan.combat.currentHp = max;
      await tester.pump(const Duration(seconds: 5));
      // El jugador se anota daño y la segunda lectura vuelve enseguida.
      sagan.combat.currentHp = 1;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('1/$max'), findsWidgets);

      // La primera contesta recién ahora, con lo que había cuando salió.
      sagan.combat.currentHp = max;
      lenta.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('1/$max'), findsWidgets);
      expect(find.text('$max/$max'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // La planilla tiene dos disposiciones —con columnas y partida en dos
    // líneas— y la columna derecha dos lugares. Ninguna combinación puede
    // desbordar: en la mesa se juega en la ventana que haya.
    // Los tres anchos son los tres cruces posibles de las dos decisiones:
    // 700 parte las filas y baja la columna; 1200 mantiene las columnas pero
    // todavía baja la columna derecha; 1336 la sube al costado y por eso vuelve
    // a partir las filas, que es la combinación menos obvia de todas.
    for (final width in const [700.0, 1200.0, 1336.0]) {
      testWidgets('la planilla entra en una ventana de $width', (tester) async {
        await pumpDmMode(tester, size: Size(width, 900), seed: seedTable);
        if (width < 900) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Combate'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Armar combate'));
        await tester.pumpAndSettle();
        await addMonsters(tester, 'goblin', 'Guerrero goblin', count: 3);
        await tirarIniciativa(tester);

        // Esté al costado o abajo, la columna del turno tiene que seguir ahí.
        expect(find.byKey(const ValueKey('combate-panel')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    // Lo que pidió el DM en la mesa: poder leer al monstruo que está jugando
    // sin salir de Combate a buscarlo al Bestiario.
    testWidgets('la columna del turno trae el perfil del monstruo', (
      tester,
    ) async {
      await withGoblin(tester);
      await tirarIniciativa(tester);

      final panel = find.byKey(const ValueKey('combate-panel'));
      Finder inPanel(Finder f) => find.descendant(of: panel, matching: f);

      // El nombre y el tipo salen del catálogo…
      expect(inPanel(find.text('Guerrero goblin')), findsOneWidget);
      expect(inPanel(find.textContaining('Feérico Pequeño')), findsOneWidget);
      // …y las acciones también, todas, con el bonificador ya firmado: el
      // goblin pega con cimitarra y con arco, y las dos a +4.
      expect(inPanel(find.text('Cimitarra')), findsOneWidget);
      expect(inPanel(find.text('Arco corto')), findsOneWidget);
      expect(inPanel(find.text('+4')), findsNWidgets(2));
      // Los PG, en cambio, son los del encuentro y no los del libro: son los
      // que bajan a golpes.
      expect(inPanel(find.text('10/10')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la columna del turno abre los conjuros de una criatura', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await addMonsters(tester, 'mago', 'Mago');
      await tirarIniciativa(tester);

      final spellKey = find.byKey(
        const ValueKey('creature-spell-mage-detect-magic'),
      );
      await tester.ensureVisible(spellKey);
      await tester.pumpAndSettle();
      expect(find.text('A voluntad'), findsOneWidget);
      expect(find.text('2/día cada uno'), findsOneWidget);

      await tester.tap(spellKey);
      await tester.pumpAndSettle();
      expect(find.text('CON MAGO'), findsOneWidget);
      expect(find.textContaining('Componentes:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // La frontera del Modo DM también rige acá: la columna no puede convertirse
    // en una forma de leer la ficha de otra cuenta.
    testWidgets('cuando le toca a un jugador la columna no muestra su ficha', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();
      await addMonsters(tester, 'goblin', 'Guerrero goblin');
      // Una iniciativa que ningún d20 alcanza: el turno es de Sagan seguro.
      await tirarIniciativa(tester, initiatives: {'Sagan': 40});

      final panel = find.byKey(const ValueKey('combate-panel'));
      expect(
        find.descendant(
          of: panel,
          matching: find.textContaining('su ficha la lleva quien lo juega'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Guerrero goblin')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    // Los efectos anotados están repartidos en filas que además se mueven de
    // lugar: juntarlos es lo que evita que se pase el veneno de turno.
    testWidgets('la solapa de efectos junta lo anotado de toda la mesa', (
      tester,
    ) async {
      await withGoblin(tester);
      await tirarIniciativa(tester);

      await tester.tap(find.byTooltip('Efectos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Envenenado'));
      await tester.pumpAndSettle();
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('combate-solapa-efectos')));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('combate-panel'));
      // El efecto queda listado con de quién es, que es el dato que la fila
      // no da cuando hay diez combatientes.
      expect(
        find.descendant(of: panel, matching: find.text('Envenenado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Guerrero goblin')),
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
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();

      // El jugador entra primero a propósito: es el orden que antes le daba
      // el primer turno aunque perdiera la iniciativa.
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
      await tirarIniciativa(tester, initiatives: {'Sagan': 8});

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

    // Un blanco entraba como cero: el jugador quedaba último sin aviso y ya no
    // había forma de corregirlo.
    testWidgets('no se empieza con una iniciativa en blanco', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tirar iniciativa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Falta la iniciativa de Sagan'), findsOne);
      await tester.tap(dialogAction('Empezar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      expect(server.encounters['tumba']!.isPreparing, isTrue);

      await tester.enterText(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextField),
        ),
        '12',
      );
      await tester.pumpAndSettle();
      expect(find.text('Al confirmar arranca la ronda 1.'), findsOneWidget);
      await tester.tap(dialogAction('Empezar'));
      await tester.pumpAndSettle();

      final encounter = server.encounters['tumba']!;
      expect(encounter.isPreparing, isFalse);
      expect(encounter.combatants.single.initiative, 12);
      expect(tester.takeException(), isNull);
    });

    // Un número mal cargado se corrige tocándolo, y el orden se rehace sin
    // quitarle el turno a quien lo tenía.
    testWidgets('corregir una iniciativa reordena y conserva el turno', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await enterCode(tester, 'CODE-0001');
      await openCombate(tester);
      await tester.tap(find.text('Armar combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar a la mesa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar al combate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goblin');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Guerrero goblin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
      // El goblin tira d20 + Destreza: con 40 Sagan arranca seguro.
      await tirarIniciativa(tester, initiatives: {'Sagan': 40});
      expect(server.encounters['tumba']!.current!.name, 'Sagan');

      await tester.tap(find.byTooltip('Corregir iniciativa').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextField),
        ),
        '-5',
      );
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      final encounter = server.encounters['tumba']!;
      final sagan = encounter.combatants.last;
      expect(sagan.name, 'Sagan');
      expect(sagan.initiative, -5);
      expect(encounter.current!.id, sagan.id);
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

    testWidgets('un capítulo abre directamente su bloque del Cuaderno', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedChapter);
      await tester.tap(find.text('Capítulos'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Ver en Cuaderno'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar en el cuaderno'), findsOneWidget);
      expect(find.text('La cripta sellada').last, findsOneWidget);
      expect(
        find.text('Todavía no hay nada anotado en este capítulo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

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

    // Antes «Guardar» se apagaba sin título: se veía que no se podía, pero no
    // por qué. Ahora dice qué falta, igual que campaña y capítulo.
    testWidgets('guardar una nota sin título explica qué falta', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedChapter);
      await openCuaderno(tester);

      await tester.tap(find.text('Escribir nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nota'), 'Algo');
      await tester.tap(dialogAction('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Poné un título para guardarla.'), findsOneWidget);
      expect(server.notes['tumba'] ?? const [], isEmpty);
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

      await tester.tap(dialogAction('Borrar nota'));
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

    // Lo repartido queda anotado en el cuaderno sin guardar nada: sale del
    // capítulo, que es donde el DM lo escribió.
    testWidgets('un capítulo cerrado deja anotado lo que repartió', (
      tester,
    ) async {
      final server = await pumpDmMode(
        tester,
        seed: (s) {
          seedTable(s);
          s.chapters['tumba'] = [
            const Chapter(
              id: 'cripta',
              name: 'La cripta sellada',
              state: ChapterState.completed,
              grantsLevel: true,
              grantsGold: 250,
              grantsItems: ['Espada larga +1'],
            ),
          ];
        },
      );
      await openCuaderno(tester);

      // Un capítulo cerrado arranca plegado.
      await tester.tap(find.text('La cripta sellada').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Se repartió un nivel, 250 po y Espada larga +1.'),
        findsOneWidget,
      );
      // Y no se guardó ninguna entrada por eso.
      expect(server.notes['tumba'] ?? const [], isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un capítulo sin recompensas no anota ninguna línea', (
      tester,
    ) async {
      await pumpDmMode(
        tester,
        seed: (s) {
          seedTable(s);
          s.chapters['tumba'] = [
            const Chapter(
              id: 'cripta',
              name: 'La cripta sellada',
              state: ChapterState.completed,
            ),
          ];
        },
      );
      await openCuaderno(tester);
      await tester.tap(find.text('La cripta sellada').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Se repartió'), findsNothing);
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

    testWidgets('el bestiario agrupa y abre conjuros de criatura', (
      tester,
    ) async {
      await pumpDmMode(tester, size: const Size(1100, 800), seed: seedTable);
      await openBestiario(tester);
      await buscar(tester, 'archimago');
      await tester.tap(find.byKey(const ValueKey('bestiary-archmage')));
      await tester.pumpAndSettle();

      final spellKey = find.byKey(
        const ValueKey('creature-spell-archmage-detect-magic'),
      );
      await tester.ensureVisible(spellKey);
      await tester.pumpAndSettle();
      expect(find.text('A voluntad'), findsOneWidget);
      expect(find.text('1/día cada uno'), findsOneWidget);

      await tester.tap(spellKey);
      await tester.pumpAndSettle();
      expect(find.text('CON ARCHIMAGO'), findsOneWidget);
      expect(find.textContaining('Inteligencia · CD 17'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // El perfil dejó de repetir dos datos y de meter dos puntos adentro de
    // otros dos puntos. Los tres cambios son fáciles de deshacer sin querer al
    // tocar `creatureProfileBody`, así que van fijados acá.
    testWidgets('el perfil no dice dos veces lo mismo', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      // El Diablo óseo trae las tres cosas a la vez: percepción pasiva metida
      // en los sentidos, salvaciones propias y defensas con punto y coma.
      final diablo = repo.creature('bone-devil')!;
      await buscar(tester, diablo.name);
      await tester.tap(find.byKey(const ValueKey('bestiary-bone-devil')));
      await tester.pumpAndSettle();

      // La percepción pasiva tiene su propia cifra arriba, así que se va del
      // renglón de sentidos en vez de leerse dos veces.
      expect(find.text('${diablo.passivePerceptionValue}'), findsWidgets);
      expect(find.textContaining('Percepción pasiva'), findsNothing);

      // La salvación vive adentro de su característica, y por eso ya no hay un
      // renglón «Salvaciones» que repita los mismos números.
      final salvFuerza = diablo.savingThrows[Ability.strength]!;
      expect(find.text('SALV +$salvFuerza'), findsOneWidget);
      expect(find.text('SALVACIONES'), findsNothing);

      // Cada fragmento de defensas es su propio chip.
      expect(find.text('Inmunidades: fuego, veneno'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    // La banda de cifras abrevia por ancho («CA», «Perc. pasiva»), y dicha así
    // en voz alta no se entiende. Es la misma celda en los dos layouts.
    testWidgets('la banda del perfil se anuncia con la palabra entera', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      final diablo = repo.creature('bone-devil')!;
      await buscar(tester, diablo.name);
      await tester.tap(find.byKey(const ValueKey('bestiary-bone-devil')));
      await tester.pumpAndSettle();

      Finder anuncio(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );

      // La cifra se ve abreviada y se escucha entera.
      expect(find.text('CA'), findsOneWidget);
      expect(anuncio('Clase de armadura: ${diablo.ac}'), findsOneWidget);
      expect(
        anuncio('Percepción pasiva: ${diablo.passivePerceptionValue}'),
        findsOneWidget,
      );
      // Los rótulos que ya vienen enteros componen solos.
      expect(
        anuncio('Iniciativa: +${diablo.initiativeModifier}'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    // El combate es de una campaña y el Bestiario no: el botón dice a cuál se
    // suma, para que no se sume a la equivocada.
    testWidgets('el perfil dice a qué combate se suma la criatura', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      final diablo = repo.creature('bone-devil')!;
      await buscar(tester, diablo.name);
      await tester.tap(find.byKey(const ValueKey('bestiary-bone-devil')));
      await tester.pumpAndSettle();

      expect(find.text('Sumar al combate de La Tumba'), findsOneWidget);
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

    /// Elige [opcion] en el desplegable rotulado [rotulo]. El menú abierto
    /// repite el texto del valor elegido, por eso se toca el último.
    Future<void> elegir(
      WidgetTester tester,
      String rotulo,
      String opcion,
    ) async {
      await tester.tap(find.widgetWithText(InputDecorator, rotulo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    String conteo(Iterable<Creature> criaturas) =>
        criaturas.length == 1 ? '1 criatura' : '${criaturas.length} criaturas';

    bool entre(Creature c, num min, num max) =>
        c.cr != null && c.cr! >= min && c.cr! <= max;

    testWidgets('filtra por rango de VD', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      await elegir(tester, 'VD desde', '1');
      await elegir(tester, 'VD hasta', '3');

      expect(
        find.text(conteo(repo.creaturesSorted.where((c) => entre(c, 1, 3)))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el rango de VD se combina con el tipo', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      final bestia = repo.creature('eagle')!.creatureType!;
      await elegir(tester, 'Tipo', bestia.label);
      await elegir(tester, 'VD desde', '1/4');
      await elegir(tester, 'VD hasta', '1/2');

      final esperadas = repo.creaturesSorted.where(
        (c) => c.creatureType?.id == bestia.id && entre(c, 0.25, 0.5),
      );
      expect(esperadas, isNotEmpty);
      expect(find.text(conteo(esperadas)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un rango invertido corre el otro extremo', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      await elegir(tester, 'VD hasta', '2');
      await elegir(tester, 'VD desde', '5');

      // En vez de una lista vacía, «hasta» acompaña a «desde».
      expect(
        find.text(conteo(repo.creaturesSorted.where((c) => entre(c, 5, 5)))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('limpiar filtros vacía también el rango de VD', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      // Ningún goblin es de VD 0; el valor va arriba del menú, que es lo que
      // se puede tocar sin scrollear.
      expect(repo.creature('goblin-warrior')!.cr, greaterThan(0));
      await elegir(tester, 'VD hasta', '0');
      await buscar(tester, 'goblin');
      expect(
        find.text('Ninguna criatura coincide con lo que buscaste.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.text(conteo(repo.creaturesSorted)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ordena por VD', (tester) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);

      final porVd = [...repo.creaturesSorted.where((c) => c.cr != null)]
        ..sort((a, b) {
          final byCr = a.cr!.compareTo(b.cr!);
          return byCr != 0 ? byCr : compareContentNames(a.name, b.name);
        });
      final primera = porVd.first;
      // Por nombre, la primera de VD más bajo no encabeza la lista.
      expect(primera, isNot(repo.creaturesSorted.first));

      await tester.tap(find.text('VD').last);
      await tester.pumpAndSettle();

      final filas = tester.widgetList<ListTile>(
        find.byWidgetPredicate(
          (w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('bestiary-'),
        ),
      );
      expect(filas.first.key, ValueKey('bestiary-${primera.id}'));
      expect(tester.takeException(), isNull);
    });

    /// Abre el perfil de [id] buscándolo por su nombre del catálogo.
    Future<Creature> abrirPerfil(WidgetTester tester, String id) async {
      final criatura = repo.creature(id)!;
      await buscar(tester, criatura.name);
      await tester.tap(find.byKey(ValueKey('bestiary-$id')));
      await tester.pumpAndSettle();
      return criatura;
    }

    /// Suma [copias] desde el perfil abierto, con el bando por defecto.
    Future<void> sumarDesdePerfil(WidgetTester tester, int copias) async {
      await tester.tap(find.text('Sumar al combate de La Tumba'));
      await tester.pumpAndSettle();
      for (var i = 1; i < copias; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();
    }

    testWidgets('sumar desde el perfil guarda y deja el bestiario igual', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);
      await elegir(tester, 'VD desde', '1/4');
      final goblin = await abrirPerfil(tester, 'goblin-warrior');

      await tester.tap(find.text('Sumar al combate de La Tumba'));
      await tester.pumpAndSettle();
      // El mismo paso que en Combate: dados en el perfil, tirar se ofrece.
      expect(find.text('Tirar los PG de cada uno'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sumar'));
      await tester.pumpAndSettle();

      final encounter = server.encounters['tumba']!;
      expect(encounter.isPreparing, isTrue);
      expect(encounter.combatants.map((c) => c.name), [
        goblin.name,
        '${goblin.name} 2',
        '${goblin.name} 3',
        '${goblin.name} 4',
      ]);
      // En preparación nadie tiene iniciativa, y un monstruo arranca enemigo.
      expect(encounter.combatants.map((c) => c.initiative), everyElement(0));
      expect(
        encounter.combatants.map((c) => c.side),
        everyElement(CombatantSide.enemy),
      );
      expect(
        find.text('Sumaste 4 × ${goblin.name} al combate de La Tumba.'),
        findsOneWidget,
      );

      // Sigue en el bestiario: el filtro, la búsqueda y el perfil abierto.
      final filtradas = repo.creaturesSorted.where(
        (c) =>
            c.cr != null &&
            c.cr! >= 0.25 &&
            foldForSearch(c.name).contains(foldForSearch(goblin.name)),
      );
      expect(find.text(conteo(filtradas)), findsOneWidget);
      expect(find.text('Sumar al combate de La Tumba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin dados en el perfil no se ofrece tirar los PG', (
      tester,
    ) async {
      await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);
      final sinDados = repo.creaturesSorted.firstWhere(
        (c) => c.hitDice == null,
      );
      await abrirPerfil(tester, sinDados.id);

      await tester.tap(find.text('Sumar al combate de La Tumba'));
      await tester.pumpAndSettle();

      expect(find.text('Tirar los PG de cada uno'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la numeración sigue la del combate guardado', (tester) async {
      final goblin = repo.creature('goblin-warrior')!;
      var n = 0;
      final server = await pumpDmMode(
        tester,
        seed: (server) {
          seedTable(server);
          server.encounters['tumba'] = const Encounter(
            id: 'e',
          ).withMonsters(goblin, 2, newId: () => 'viejo-${n++}');
        },
      );
      await openBestiario(tester);
      await abrirPerfil(tester, goblin.id);

      await sumarDesdePerfil(tester, 2);

      expect(
        server.encounters['tumba']!.combatants.map((c) => c.name).skip(2),
        ['${goblin.name} 3', '${goblin.name} 4'],
      );
      expect(tester.takeException(), isNull);
    });

    // El diálogo se cierra antes de que el servidor conteste. Sin la fila, la
    // segunda tanda leería el combate sin la primera y la pisaría.
    testWidgets('dos tandas seguidas no se pisan', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      server.beforeHandle = (request) async {
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/encounter')) {
          await Future<void>.delayed(const Duration(seconds: 10));
        }
      };
      await openBestiario(tester);
      final goblin = await abrirPerfil(tester, 'goblin-warrior');

      await sumarDesdePerfil(tester, 2);
      await sumarDesdePerfil(tester, 2);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(server.encounters['tumba']!.combatants.map((c) => c.name), [
        goblin.name,
        '${goblin.name} 2',
        '${goblin.name} 3',
        '${goblin.name} 4',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en un combate en curso cada copia tira su iniciativa', (
      tester,
    ) async {
      final server = await pumpDmMode(
        tester,
        seed: (server) {
          seedTable(server);
          server.encounters['tumba'] = const Encounter(
            id: 'e',
            stage: EncounterStage.running,
          );
        },
      );
      await openBestiario(tester);
      final lobo = await abrirPerfil(tester, 'wolf');

      await sumarDesdePerfil(tester, 2);

      final mod = lobo.initiativeModifier;
      final combatants = server.encounters['tumba']!.combatants;
      expect(combatants, hasLength(2));
      for (final c in combatants) {
        expect(c.initiative, inInclusiveRange(1 + mod, 20 + mod));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar no toca el combate', (tester) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      await openBestiario(tester);
      await abrirPerfil(tester, 'ogre');

      await tester.tap(find.text('Sumar al combate de La Tumba'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(server.encounters['tumba'], isNull);
      expect(find.textContaining('Sumaste'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin campañas el perfil explica que hace falta una', (
      tester,
    ) async {
      await pumpDmMode(tester);
      await openBestiario(tester);
      await abrirPerfil(tester, 'ogre');

      expect(find.textContaining('Sumar al combate'), findsNothing);
      expect(
        find.text('Para sumarla a un combate, primero creá una campaña.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un error al guardar lo dice y no pierde el bestiario', (
      tester,
    ) async {
      final server = await pumpDmMode(tester, seed: seedTable);
      server.beforeHandle = (request) async {
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/encounter')) {
          throw Exception('se cayó la conexión');
        }
      };
      await openBestiario(tester);
      await elegir(tester, 'VD desde', '1/4');
      final goblin = await abrirPerfil(tester, 'goblin-warrior');
      final antes = find.text(
        conteo(
          repo.creaturesSorted.where(
            (c) =>
                c.cr != null &&
                c.cr! >= 0.25 &&
                foldForSearch(c.name).contains(foldForSearch(goblin.name)),
          ),
        ),
      );
      expect(antes, findsOneWidget);

      await sumarDesdePerfil(tester, 1);

      expect(server.encounters['tumba'], isNull);
      expect(find.textContaining('Sumaste'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(antes, findsOneWidget);
      expect(find.text('Sumar al combate de La Tumba'), findsOneWidget);
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
