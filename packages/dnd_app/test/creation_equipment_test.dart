import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paso de Equipo y Conjuros.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Navega hasta Equipo con la clase indicada.
  Future<void> gotoEquipo(WidgetTester tester, String className) async {
    tester.view.physicalSize = const Size(1500, 2400);
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

    await tester.tap(find.text('Humano'));
    await tester.pumpAndSettle();
    await next();

    // El nombre puede figurar en la tarjeta y en el panel de detalle (si ya
    // está seleccionada): la tarjeta es la primera.
    await tester.tap(find.text(className).first);
    await tester.pumpAndSettle();
    // El Guerrero exige estilo de combate y 3 maestrías.
    if (className == 'Guerrero') {
      await tester.tap(find.text('Estilo de Combate: Defensa'));
      await tester.pumpAndSettle();
      for (final w in ['Garrote', 'Daga', 'Clava']) {
        final tile = find.widgetWithText(CheckboxListTile, w);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
    }
    await next();

    await tester.tap(find.text('Soldado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 / +1 / +1'));
    await tester.pumpAndSettle();
    await next();

    const order = [15, 14, 13, 12, 10, 8];
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(i));
      await tester.pumpAndSettle();
      final item = find.descendant(
        of: find.byType(ListView),
        matching: find.text('${order[i]}'),
      );
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }
    await next();

    // Aptitudes: completar lo que pida para poder avanzar.
    for (final s in ['Arcanos', 'Historia', 'Acrobacias']) {
      final f = find.text(s);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await tester.pumpAndSettle();
      }
    }
    final feat = find.text('Hábil');
    if (feat.evaluate().isNotEmpty) {
      await tester.ensureVisible(feat);
      await tester.pumpAndSettle();
      await tester.tap(feat);
      await tester.pumpAndSettle();
    }
    await next();
  }

  testWidgets('lanzador: muestra trucos y conjuros con sus contadores', (
    tester,
  ) async {
    await gotoEquipo(tester, 'Mago');

    expect(find.text('ARMADURA'), findsOneWidget);
    expect(find.text('Sin armadura'), findsOneWidget);
    expect(find.text('Escudo (+2 CA)'), findsOneWidget);
    expect(find.text('CONJUROS'), findsOneWidget);
    expect(find.text('Trucos'), findsOneWidget);
    expect(find.text('Tu clase no lanza conjuros'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no lanzador: muestra el cartel en vez de la lista', (
    tester,
  ) async {
    await gotoEquipo(tester, 'Guerrero');

    expect(find.text('CONJUROS'), findsOneWidget);
    expect(find.text('Tu clase no lanza conjuros'), findsOneWidget);
    expect(find.text('Trucos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el selector de arma scrollea solo', (tester) async {
    await gotoEquipo(tester, 'Mago');

    // Hay dos listas acotadas posibles en el wizard; en Equipo, la del arma.
    final list = find.descendant(
      of: find.byType(Scrollbar),
      matching: find.byType(ListView),
    );
    expect(list, findsOneWidget);
    expect(tester.getSize(list).height, lessThanOrEqualTo(300.0));
    expect(tester.takeException(), isNull);
  });
}
