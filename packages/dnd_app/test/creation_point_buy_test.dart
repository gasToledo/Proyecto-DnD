import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

/// Paso de Puntuaciones con el tercer método oficial: compra de puntos.
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

  testWidgets('arranca con las seis en 8 y los 27 puntos intactos', (
    tester,
  ) async {
    await gotoPointBuy(tester);

    expect(find.text('27 de 27'), findsOneWidget);
    // Seis steppers, uno por característica.
    expect(find.widgetWithIcon(IconButton, Icons.add), findsNWidgets(6));
    expect(find.text('subir cuesta 1 · gastados 0'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el paso no bloquea: las seis en el mínimo ya son válidas', (
    tester,
  ) async {
    // A diferencia del array estándar, acá no hay nada "sin asignar": el
    // reparto de partida es legal aunque desperdicie el presupuesto.
    await gotoPointBuy(tester);

    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Siguiente'),
    );
    expect(next.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subir descuenta según la tabla y el coste sube en 14', (
    tester,
  ) async {
    await gotoPointBuy(tester);

    // Cinco escalones: 8 → 13, un punto cada uno.
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('al llegar a 15 el botón de subir se apaga', (tester) async {
    await gotoPointBuy(tester);

    for (var i = 0; i < 7; i++) {
      await tester.tap(raiseAt(0));
      await tester.pumpAndSettle();
    }
    expect(find.text('18 de 27'), findsOneWidget);
    expect(find.text('al máximo · gastados 9'), findsOneWidget);

    final button = tester.widget<IconButton>(raiseAt(0));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin presupuesto no se puede subir ninguna otra', (tester) async {
    await gotoPointBuy(tester);

    // 15/15/15 gasta los 27 exactos.
    for (var ability = 0; ability < 3; ability++) {
      for (var i = 0; i < 7; i++) {
        await tester.tap(raiseAt(ability));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('0 de 27'), findsOneWidget);
    expect(find.text('Presupuesto completo.'), findsOneWidget);

    // Las tres restantes quedan bloqueadas aunque estén en el mínimo.
    for (var ability = 3; ability < 6; ability++) {
      expect(tester.widget<IconButton>(raiseAt(ability)).onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('limpiar devuelve el presupuesto entero', (tester) async {
    await gotoPointBuy(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(raiseAt(0));
      await tester.pumpAndSettle();
    }
    expect(find.text('22 de 27'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpiar'));
    await tester.pumpAndSettle();

    expect(find.text('27 de 27'), findsOneWidget);
    expect(find.text('subir cuesta 1 · gastados 0'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('volver al array estándar deja de mostrar el presupuesto', (
    tester,
  ) async {
    await gotoPointBuy(tester);
    expect(find.text('27 de 27'), findsOneWidget);

    await tester.tap(find.text('Array estándar'));
    await tester.pumpAndSettle();

    expect(find.text('27 de 27'), findsNothing);
    expect(find.text('Valores sin asignar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
