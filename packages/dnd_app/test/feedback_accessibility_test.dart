import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  testWidgets('los avisos se anuncian como región viva', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showAppMessage(
                context,
                'Cambios guardados.',
                tone: AppMessageTone.success,
              ),
              child: const Text('Avisar'),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    await tester.tap(find.text('Avisar'));
    await tester.pump();

    expect(find.text('Cambios guardados.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Cambios guardados.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('las estadísticas exponen una etiqueta completa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: StatPlaque(label: 'Velocidad', value: '30'),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('Velocidad: 30'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('ajustes cabe en una ventana baja y permite recorrido por foco', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeApiServer()
      ..providers = [
        {
          'id': 'pollinations',
          'name': 'Pollinations',
          'supportsReference': false,
        },
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsDialog(api: ApiClient(client: server.client)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proveedor de retratos:'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
