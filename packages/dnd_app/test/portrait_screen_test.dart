import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/portrait_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

/// La pantalla arma dos caminos —generar y subir— y antes convivían apilados en
/// el mismo formulario. Lo que se prueba acá es el ruteo entre ambos, que es lo
/// único con ramas: el prompt ya lo cubre `portrait_test.dart`.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Map<String, dynamic>> providers,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeApiServer()..providers = providers;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PortraitScreen(
          character: demoSagan(),
          repo: repo,
          api: ApiClient(client: server.client),
          onUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const pollinations = {
    'id': 'pollinations',
    'name': 'Pollinations',
    'supportsReference': false,
  };
  const azure = {'id': 'azure', 'name': 'Azure', 'supportsReference': true};

  testWidgets('con proveedores abre en generar y deja pasar a subir', (
    tester,
  ) async {
    await pumpScreen(tester, providers: [pollinations, azure]);

    // Arranca en IA: se ven los dos motores y el selector de estilo.
    expect(find.text('Pollinations'), findsOneWidget);
    expect(find.text('Azure'), findsOneWidget);
    expect(find.text('Arte digital de fantasía'), findsOneWidget);
    expect(find.text('Importar imagen desde archivo'), findsNothing);

    await tester.tap(find.text('Subir imagen'));
    await tester.pumpAndSettle();

    expect(find.text('Importar imagen desde archivo'), findsOneWidget);
    // Y los controles de generación se fueron con la pestaña, en vez de
    // seguir apilados debajo como antes.
    expect(find.text('Arte digital de fantasía'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin proveedores arranca en subir y no ofrece generar', (
    tester,
  ) async {
    await pumpScreen(tester, providers: const []);

    expect(find.text('Importar imagen desde archivo'), findsOneWidget);
    // La pestaña de IA ni siquiera aparece: no hay con qué generar.
    expect(find.text('Generar con IA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la referencia solo se ofrece si el proveedor la admite', (
    tester,
  ) async {
    await pumpScreen(tester, providers: [pollinations, azure]);

    expect(find.text('Elegir imagen…'), findsNothing);

    await tester.tap(find.text('Azure'));
    await tester.pumpAndSettle();

    expect(find.text('Elegir imagen…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
