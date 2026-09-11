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

  /// Levanta el Modo DM con Ilvia ya vinculada y sentada a la mesa: es lo que
  /// hace falta para poder tocar su tarjeta y abrir la ficha reducida.
  Future<FakeApiServer> pumpTableWithIlvia(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = FakeApiServer();
    server.campaigns['tumba'] = const Campaign(id: 'tumba', name: 'La Tumba');
    server.characters['ilvia'] = Character(
      id: 'ilvia',
      name: 'Ilvia',
      raceId: 'elf',
      classId: 'cleric',
      backgroundId: 'acolyte',
      assignedScores: {for (final a in Ability.values) a: 14},
      combat: CombatState(currentHp: 20, conditions: {'poisoned'}),
    );
    server.shareCodes['CODE-0001'] = 'ilvia';

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

    await tester.tap(find.text('Sumar personaje').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'CODE-0001');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    // Reprograma un chequeo de avisos a los 3 segundos: hay que dejarlo
    // correr o el timer queda pendiente al desmontar el árbol.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    return server;
  }

  testWidgets('tocar la tarjeta abre la ficha reducida, sin nada editable', (
    tester,
  ) async {
    await pumpTableWithIlvia(tester);

    await tester.tap(find.text('Ilvia'));
    await tester.pumpAndSettle();

    // Lo que promete el diseño: defensas, salvaciones, ataques, conjuros y la
    // condición que el jugador ya se anotó.
    expect(find.text('SALVACIONES'), findsOneWidget);
    expect(find.text('Ataques'), findsOneWidget);
    expect(find.text('Condiciones activas'), findsOneWidget);
    expect(find.text('Envenenado'), findsOneWidget);
    expect(find.text('Espacios de conjuro'), findsOneWidget);

    // Solo lectura sin excepciones: ni el menú de acciones del DM ni ningún
    // campo editable cruzan a esta pantalla.
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'es una foto al abrir: lo que cambia después en el servidor no se refleja sin reabrir',
    (tester) async {
      final server = await pumpTableWithIlvia(tester);

      await tester.tap(find.text('Ilvia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('20'), findsWidgets);

      // El jugador se anota daño mientras el DM sigue mirando esta pantalla.
      server.characters['ilvia'] = server.characters['ilvia']!.copyWith(
        combat: CombatState(currentHp: 5, conditions: {'poisoned'}),
      );
      // Tiempo de sobra para que un sondeo (si existiera) ya hubiera llegado.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.textContaining('20'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
