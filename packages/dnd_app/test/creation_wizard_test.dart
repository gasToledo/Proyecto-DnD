import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Regresión: el Bardo es la única clase con `skillChoiceFrom` vacío (2024:
  /// elige libremente entre las 18). Antes eso se leía como "ninguna opción" y
  /// el picker salía vacío. La regla vive ahora en un solo lugar.
  group('skillOptions', () {
    test('lista vacía significa las 18 habilidades, no ninguna', () {
      expect(skillOptions(const []), hasLength(18));
      expect(skillOptions(const []), same(allSkills2024));
    });

    test('el Bardo puede elegir entre las 18', () {
      final bard = repo.characterClass('bard')!;
      expect(bard.skillChoiceFrom, isEmpty, reason: 'premisa del caso');
      expect(skillOptions(bard.skillChoiceFrom), hasLength(18));
    });

    test('una lista acotada se respeta tal cual', () {
      final fighter = repo.characterClass('fighter')!;
      expect(fighter.skillChoiceFrom, isNotEmpty);
      expect(skillOptions(fighter.skillChoiceFrom), fighter.skillChoiceFrom);
    });
  });

  testWidgets('el wizard abre en Raza con el stepper de 8 pasos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Crear personaje'), findsOneWidget);
    // Los 8 rótulos del stepper.
    for (final s in CreationStep.values) {
      expect(
        find.text(s.label.toUpperCase()),
        findsOneWidget,
        reason: 'falta el paso ${s.label}',
      );
    }
    // Arranca bloqueado: hay que elegir especie antes de avanzar.
    final next = find.widgetWithText(FilledButton, 'Siguiente');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
  });

  testWidgets('el stepper sigue usable en una ventana compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crear personaje'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text(CreationStep.raza.label.toUpperCase()), findsOneWidget);
    expect(find.text(CreationStep.resumen.label.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la lista de maestrías scrollea sola, no estira el paso', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Raza -> Clase (Guerrero es la clase por defecto y pide 3 maestrías).
    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // (ver también la prueba del modo dividido más abajo)
    // El paso de Clase tiene dos listas con scroll propio: la de clases (panel
    // izquierdo del modo dividido) y el checklist de maestrías. Esta prueba
    // mira la segunda, así que se ancla en un CheckboxListTile.
    final list = find.ancestor(
      of: find.byType(CheckboxListTile).first,
      matching: find.byType(ListView),
    );
    expect(
      list,
      findsOneWidget,
      reason: 'el checklist debe tener scroll propio',
    );
    expect(tester.getSize(list).height, lessThanOrEqualTo(300.0));

    // Y hay más contenido del que entra: la lista realmente scrollea.
    final position = tester.widget<ListView>(list).controller!.position;
    expect(position.maxScrollExtent, greaterThan(0.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pide confirmación al cerrar después de elegir opciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar este personaje?'), findsOneWidget);
    expect(
      find.text('Las elecciones realizadas en el asistente se perderán.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Seguir creando'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar este personaje?'), findsNothing);
    expect(find.text('Crear personaje'), findsOneWidget);
  });

  // --- Modo dividido de Especie / Clase / Trasfondo -------------------------
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  const emptyHint = 'Elegí una especie para ver su detalle.';

  testWidgets('con ancho de sobra la especie se muestra en dos columnas', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1500, 1400));

    // Sin selección, el panel derecho existe igual y dice qué falta hacer.
    expect(find.text(emptyHint), findsOneWidget);

    await tapOption(tester, 'Humano');
    await pickSize(tester);

    // Al elegir, el panel pasa a ser el detalle: la lista sigue a la izquierda.
    expect(find.text(emptyHint), findsNothing);

    final list = tester.getRect(find.text('Humano').first);
    final detail = tester.getRect(find.text('TAMAÑO  '));
    expect(
      list.right,
      lessThan(detail.left),
      reason: 'la lista tiene que quedar a la izquierda del detalle',
    );
  });

  testWidgets('la lista de especies sigue al alto de la ventana', (
    tester,
  ) async {
    Future<double> listHeight(double windowHeight) async {
      await pumpAt(tester, Size(1500, windowHeight));
      // Se ancla en la primera especie: la lista es perezosa y una del medio
      // puede no estar construida todavía, que es lo que se quiere medir acá.
      final list = find.ancestor(
        of: find.text(primeraEspecie),
        matching: find.byType(ListView),
      );
      return tester.getSize(list).height;
    }

    final short = await listHeight(900);
    final tall = await listHeight(1500);

    // Con una ventana más alta la lista tiene que crecer: un tope fijo dejaba
    // media pantalla vacía.
    expect(tall, greaterThan(short));
    expect(tall, greaterThan(900));
    // Y no puede desbordar la ventana que la contiene.
    expect(tall, lessThan(1500));
  });

  testWidgets('en una ventana muy baja la lista no colapsa', (tester) async {
    await pumpAt(tester, const Size(1500, 500));
    final list = find.ancestor(
      of: find.text(primeraEspecie),
      matching: find.byType(ListView),
    );
    expect(tester.getSize(list).height, greaterThanOrEqualTo(320.0));
  });

  testWidgets('la línea de sabor del trasfondo vive en el detalle', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1500, 1400));

    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
    }

    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await next();

    // El Guerrero es la clase por defecto y no deja avanzar sin estilo de
    // combate ni las 3 maestrías.
    await tester.tap(find.text('Defensa'));
    await tester.pumpAndSettle();
    for (final w in ['Garrote', 'Daga', 'Clava']) {
      await checkWeapon(tester, w);
    }
    await next();

    // Soldado es el primero de la lista, así que no hace falta scrollear.
    const tagline = 'Disciplina forjada en el campo de batalla';
    // En la lista solo van nombres: el sabor no se repite 33 veces.
    expect(find.text(tagline), findsNothing);

    await tapOption(tester, 'Soldado');

    expect(find.text(tagline), findsOneWidget);
    final name = tester.getRect(find.text('Soldado').first);
    expect(
      name.right,
      lessThan(tester.getRect(find.text(tagline)).left),
      reason: 'el sabor tiene que quedar en el panel derecho',
    );
  });

  testWidgets('en una ventana angosta vuelve al apilado', (tester) async {
    await pumpAt(tester, const Size(700, 1400));

    // Apilado: sin selección no hay panel derecho que llenar, así que tampoco
    // hay marca de agua.
    expect(find.text(emptyHint), findsNothing);

    await tapOption(tester, 'Humano');
    await pickSize(tester);

    final card = tester.getRect(find.text('Humano').first);
    final detail = tester.getRect(find.text('TAMAÑO  '));
    expect(
      card.bottom,
      lessThan(detail.top),
      reason: 'el detalle tiene que quedar debajo de la grilla',
    );
    expect(tester.takeException(), isNull);
  });
}
