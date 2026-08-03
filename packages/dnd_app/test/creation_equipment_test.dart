import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

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

    await tapOption(tester, 'Humano');
    await next();

    // El nombre puede figurar en la tarjeta y en el panel de detalle (si ya
    // está seleccionada): la tarjeta es la primera.
    await tapOption(tester, className);
    // El Guerrero exige estilo de combate y 3 maestrías.
    if (className == 'Guerrero') {
      await tester.tap(find.text('Defensa'));
      await tester.pumpAndSettle();
      for (final w in ['Garrote', 'Daga', 'Clava']) {
        await checkWeapon(tester, w);
      }
    }
    await next();

    await tapOption(tester, 'Soldado');
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
    final feat = find.text('Habilidoso');
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

  testWidgets('se pueden equipar dos armas y elegir la mano secundaria', (
    tester,
  ) async {
    await gotoEquipo(tester, 'Mago');

    Future<void> tapWeapon(String name) async {
      final chip = find.ancestor(
        of: find.textContaining('$name ('),
        matching: find.byType(FilterChip),
      );
      await tester.ensureVisible(chip.first);
      await tester.pumpAndSettle();
      await tester.tap(chip.first);
      await tester.pumpAndSettle();
    }

    // El aviso de que la regla no se aplicaba sola ya no corresponde: ahora la
    // aplica el motor y lo que hay que decidir es la mano.
    expect(find.textContaining('todavía no aplica'), findsNothing);
    expect(find.text('Cómo las empuñás'), findsNothing);

    await tapWeapon('Daga');
    await tapWeapon('Bastón');

    // La daga es Ligera, el bastón es versátil: cada una ofrece lo suyo.
    expect(find.text('Cómo las empuñás'), findsOneWidget);
    final offHand = find.byKey(const ValueKey('off-hand-dagger'));
    expect(offHand, findsOneWidget);
    expect(
      find.byKey(const ValueKey('two-handed-quarterstaff')),
      findsOneWidget,
    );
    // El bastón no es Ligero, así que no se puede mandar a la secundaria.
    expect(find.byKey(const ValueKey('off-hand-quarterstaff')), findsNothing);

    expect(tester.widget<FilterChip>(offHand).selected, isFalse);
    await tester.ensureVisible(offHand);
    await tester.pumpAndSettle();
    await tester.tap(offHand);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(offHand).selected, isTrue);

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
