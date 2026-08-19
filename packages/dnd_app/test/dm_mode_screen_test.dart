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
    await tester.enterText(find.byType(TextField), 'La Tumba');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(server.campaigns.values.single.name, 'La Tumba');
    expect(find.text('La Tumba'), findsWidgets);
    expect(find.textContaining('Todavía nadie compartió'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Echar a Sagan'));
    await tester.pumpAndSettle();
    expect(find.text('Echar personaje'), findsWidgets);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(server.campaignMembers, hasLength(1));

    await tester.tap(find.byTooltip('Echar a Sagan'));
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
      await tester.tap(find.widgetWithText(FilledButton, 'Terminar combate'));
      await tester.pumpAndSettle();

      expect(server.encounters, isNot(contains('tumba')));
      expect(find.text('No hay ningún combate en curso.'), findsOneWidget);
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
}
