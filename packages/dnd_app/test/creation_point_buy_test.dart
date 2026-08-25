import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

/// Paso de Puntuaciones con el tercer método oficial: compra de puntos.
///
/// Es **un solo recorrido** y no un test por regla a propósito. Llegar hasta
/// este paso cuesta tres pantallas del asistente, y esa navegación tardaba 4,8
/// s: con siete tests el archivo se iba a 37 s para probar una tabla de costes
/// que `creation_draft_test.dart` ya cubre en 11 ms por caso. Acá queda lo que
/// solo se puede ver en la pantalla —el presupuesto, el rótulo del próximo
/// escalón, los botones que se apagan— y se ve todo en una pasada.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Navega hasta Puntuaciones y elige compra de puntos.
  Future<void> gotoPointBuy(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
    }

    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await next();
    await tapOption(tester, 'Mago');
    await next();
    await tapOption(tester, 'Soldado');
    await tester.tap(find.text('+1 / +1 / +1'));
    await tester.pumpAndSettle();
    await next();

    await tester.tap(find.text('Compra de puntos'));
    await tester.pumpAndSettle();
  }

  /// El botón de subir de la característica en la posición [index].
  Finder raiseAt(int index) =>
      find.widgetWithIcon(IconButton, Icons.add).at(index);

  testWidgets('la compra de puntos se gasta, se topa y se limpia', (
    tester,
  ) async {
    await gotoPointBuy(tester);

    // --- Arranque: las seis en 8 y los 27 puntos intactos.
    expect(find.text('27 de 27'), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.add), findsNWidgets(6));
    expect(find.text('subir cuesta 1 · gastados 0'), findsNWidgets(6));

    // A diferencia del array estándar, acá no hay nada "sin asignar": el
    // reparto de partida es legal aunque desperdicie el presupuesto.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Siguiente'))
          .onPressed,
      isNotNull,
    );

    // --- Subir descuenta según la tabla, y el coste sube en 14.
    for (var i = 0; i < 5; i++) {
      await tester.tap(raiseAt(0));
      await tester.pumpAndSettle();
    }
    expect(find.text('22 de 27'), findsOneWidget);
    // El próximo escalón ya no cuesta 1: es la parte no lineal de la tabla.
    expect(find.text('subir cuesta 2 · gastados 5'), findsOneWidget);

    await tester.tap(raiseAt(0));
    await tester.pumpAndSettle();
    expect(find.text('20 de 27'), findsOneWidget);

    // --- Al llegar a 15 el botón de subir se apaga.
    await tester.tap(raiseAt(0));
    await tester.pumpAndSettle();
    expect(find.text('18 de 27'), findsOneWidget);
    expect(find.text('al máximo · gastados 9'), findsOneWidget);
    expect(tester.widget<IconButton>(raiseAt(0)).onPressed, isNull);

    // --- Sin presupuesto no se puede subir ninguna otra: 15/15/15 gasta los 27
    // exactos y las tres restantes quedan bloqueadas aunque estén en el mínimo.
    for (var ability = 1; ability < 3; ability++) {
      for (var i = 0; i < 7; i++) {
        await tester.tap(raiseAt(ability));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('0 de 27'), findsOneWidget);
    expect(find.text('Presupuesto completo.'), findsOneWidget);
    for (var ability = 3; ability < 6; ability++) {
      expect(tester.widget<IconButton>(raiseAt(ability)).onPressed, isNull);
    }

    // --- Limpiar devuelve el presupuesto entero.
    await tester.tap(find.widgetWithText(TextButton, 'Limpiar'));
    await tester.pumpAndSettle();
    expect(find.text('27 de 27'), findsOneWidget);
    expect(find.text('subir cuesta 1 · gastados 0'), findsNWidgets(6));

    // --- Volver al array estándar deja de mostrar el presupuesto.
    await tester.tap(find.text('Array estándar'));
    await tester.pumpAndSettle();
    expect(find.text('27 de 27'), findsNothing);
    expect(find.text('Valores sin asignar'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
