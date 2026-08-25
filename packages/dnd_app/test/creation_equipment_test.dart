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
    await pickSize(tester);
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
    // Habilidoso concede tres competencias a elegir y el paso no deja avanzar
    // sin ellas. Se eligen herramientas y no habilidades a propósito: sus
    // nombres solo aparecen en este selector, así que no chocan con los de
    // clase y especie de más arriba.
    for (final t in [
      'Juego de dados',
      'Herramientas de ladrón',
      'Suministros de alquimista',
      'Suministros de cervecero',
    ]) {
      final f = find.text(t);
      if (f.evaluate().isEmpty) continue;
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }
    await pickLanguages(tester);
    await next();

    Future<void> pickStartingOption(String key, String label) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pickStartingOption('starting-equipment-clase', 'Opción A');
    // La opción monetaria evita elecciones internas del trasfondo: estos tests
    // verifican el equipo de clase y no necesitan resolver el juego de Soldado.
    await pickStartingOption('starting-equipment-trasfondo', 'Opción B');
  }

  testWidgets('Mago: recibe su equipo, lo equipa y elige la mano', (
    tester,
  ) async {
    // Un solo recorrido para las tres cosas que se ven en esta pantalla con un
    // lanzador. Llegar hasta acá cuesta cinco pasos del asistente —12 s por
    // test—, y las tres miran el mismo estado.
    await gotoEquipo(tester, 'Mago');

    // --- Lo que trajo: equipo, conjuros y sus contadores.
    expect(find.text('EQUIPO INICIAL'), findsOneWidget);
    expect(find.text('EQUIPO PUESTO'), findsOneWidget);
    expect(find.text('Daga'), findsWidgets);
    expect(find.text('Bastón'), findsWidgets);
    expect(find.text('CONJUROS'), findsOneWidget);
    expect(find.text('Trucos'), findsOneWidget);
    expect(find.text('Tu clase no lanza conjuros'), findsNothing);

    // --- Solo se puede equipar lo recibido: la espada larga no está.
    expect(
      find.ancestor(of: find.text('Daga'), matching: find.byType(FilterChip)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Bastón'), matching: find.byType(FilterChip)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Espada larga'),
        matching: find.byType(FilterChip),
      ),
      findsNothing,
    );

    // --- Equipar las dos abre la elección de mano.
    Future<void> tapWeapon(String name) async {
      final chip = find.ancestor(
        of: find.text(name),
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

  testWidgets('no lanzador: muestra el cartel en vez de la lista', (
    tester,
  ) async {
    // Este va aparte porque el camino es otro: el Guerrero exige estilo de
    // combate y tres maestrías antes de llegar.
    await gotoEquipo(tester, 'Guerrero');

    expect(find.text('CONJUROS'), findsOneWidget);
    expect(find.text('Tu clase no lanza conjuros'), findsOneWidget);
    expect(find.text('Trucos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
