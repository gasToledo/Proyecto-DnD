import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.tap(find.text('Humano'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    final list = find.descendant(
      of: find.byType(Scrollbar),
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

    await tester.tap(find.text('Humano'));
    await tester.pumpAndSettle();
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
}
