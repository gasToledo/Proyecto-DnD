import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
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

  Widget harness(
    CharactersController ctrl,
    FakeApiServer server, {
    String? appVersion,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: DashboardScreen(
      repo: repo,
      controller: ctrl,
      homebrew: HomebrewStore(ApiClient(client: server.client)),
      appVersion: appVersion,
      onToggleTheme: () {},
    ),
  );

  /// Monta el dashboard con un roster de prueba en un viewport dado y deja
  /// vencer el debounce de guardado (400 ms) para no dejar timers pendientes.
  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await tester.pumpWidget(harness(ctrl, server));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('el panel lateral muestra la versión instalada', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await tester.pumpWidget(harness(ctrl, server, appVersion: '1.2.3'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final version = find.byKey(const ValueKey('app-version'));
    expect(version, findsOneWidget);
    expect(tester.widget<Text>(version).data, 'v1.2.3');
    expect(tester.widget<Text>(version).style?.color, AppPalette.dark.gold);
    // Va debajo del cambio de tema, no encima.
    expect(
      tester.getTopLeft(version).dy,
      greaterThan(tester.getTopLeft(find.text('Cambiar tema')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin versión resuelta no se muestra el rótulo', (tester) async {
    await pumpDashboard(tester, const Size(1400, 900));
    expect(find.byKey(const ValueKey('app-version')), findsNothing);
  });

  testWidgets('layout ancho: panel lateral + tarjeta con datos de combate', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1280, 800));

    // Panel lateral presente con sus secciones.
    expect(find.text('Personajes'), findsOneWidget);
    expect(find.text('Homebrew'), findsOneWidget);
    expect(find.text('Importar / Exportar'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);

    // La tarjeta muestra los datos que antes obligaban a abrir la ficha.
    expect(find.text('Sagan "The Red"'), findsOneWidget);
    expect(find.text('PG'), findsOneWidget);
    expect(find.text('VEL'), findsOneWidget);
    expect(find.text('INIC'), findsOneWidget);
    // Sin overflow: un RenderFlex desbordado dispararía una excepción acá.
    expect(tester.takeException(), isNull);
  });

  testWidgets('el buscador filtra el roster', (tester) async {
    await pumpDashboard(tester, const Size(1280, 800));

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Sagan "The Red"'), findsNothing);
    expect(
      find.text('Ningún personaje coincide con la búsqueda.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'sagan');
    await tester.pumpAndSettle();
    expect(find.text('Sagan "The Red"'), findsOneWidget);
  });

  testWidgets('muestra el estado real del guardado', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());

    await tester.pumpWidget(harness(ctrl, server));
    expect(find.text('Guardando…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Guardado'), findsOneWidget);
  });

  testWidgets('layout angosto: el panel se colapsa a Drawer', (tester) async {
    await pumpDashboard(tester, const Size(700, 800));

    // El panel no está fijo, pero sí accesible por el Drawer del AppBar.
    expect(find.text('Homebrew'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Homebrew'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard sigue usable en una ventana mínima', (tester) async {
    await pumpDashboard(tester, const Size(480, 520));

    expect(find.text('Fichas D&D 5e'), findsOneWidget);
    expect(find.text('Sagan "The Red"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
