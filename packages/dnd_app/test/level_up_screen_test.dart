import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresión: en la subida de nivel, la sección de conjuros previsualiza el
/// personaje llamando a `_buildUpdated()` en cada build. Cambiar a "Tomar dote"
/// antes de elegir una dote no debe romper (antes: `_featId!` sobre null).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Character fighterL3() => Character(
    id: 't-fighter',
    name: 'Prueba',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    subclassId: 'champion',
    level: 3,
    assignedScores: {
      Ability.strength: 16,
      Ability.dexterity: 14,
      Ability.constitution: 14,
      Ability.intelligence: 10,
      Ability.wisdom: 12,
      Ability.charisma: 8,
    },
    hpPerLevel: [10, 6, 6],
  );

  Future<void> goToAsi(WidgetTester tester) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Mejora tu personaje'), findsOneWidget);
  }

  Future<void> searchFeat(WidgetTester tester, String query) async {
    final search = find.widgetWithText(TextField, 'Buscar dote');
    expect(search, findsOneWidget);
    await tester.enterText(search, query);
    await tester.pumpAndSettle();
  }

  testWidgets('cambiar a "Tomar dote" sin elegir dote no crashea', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Nivel 4 es ASI para el Guerrero: el wizard llega a mejora/dote tras
    // resolver el resumen y los PG.
    await goToAsi(tester);
    expect(find.text('Tomar dote'), findsOneWidget);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // No debe haberse lanzado ninguna excepción durante el rebuild.
    expect(tester.takeException(), isNull);
  });

  testWidgets('la subida de nivel cabe en una ventana compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subir a nivel 4'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('Paso 1 de'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tirar PG bloquea el avance hasta obtener un resultado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar'));
    await tester.pumpAndSettle();

    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Tirá el dado o elegí el promedio para continuar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Tirar el dado'));
    await tester.tap(find.text('Tirar el dado'));
    await tester.pumpAndSettle();
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('la revisión confirma recién al final y abre la celebración', (
    tester,
  ) async {
    Character? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(
          character: fighterL3(),
          repo: repo,
          onDone: (updated) => saved = updated,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.widgetWithText(InkWell, 'Fuerza'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Así queda Prueba'), findsOneWidget);
    expect(find.text('Confirmar nivel 4'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.text('Confirmar nivel 4'));
    await tester.pumpAndSettle();

    expect(saved?.level, 4);
    expect(saved?.asiChoices.last.abilityIncreases[Ability.strength], 2);
    expect(find.text('¡Subiste a nivel 4!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no ofrece una dote general ya tomada', (tester) async {
    final c = Character(
      id: 't-fighter-6',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      subclassId: 'champion',
      level: 5,
      assignedScores: {
        Ability.strength: 16,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      hpPerLevel: [10, 6, 6, 6, 6],
      // Ya tomó esta dote general en un nivel de ASI anterior.
      featIds: const ['great-weapon-master'],
      asiChoices: const [AsiChoice(level: 4, featId: 'great-weapon-master')],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Nivel 6 es ASI para el Guerrero.
    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
    await searchFeat(tester, 'Maestro de Armas Grandes');

    // La dote ya tomada no debe ofrecerse de nuevo (no es repetible).
    expect(
      find.widgetWithText(InkWell, 'Maestro de Armas Grandes'),
      findsNothing,
    );
  });

  // Regresión: el selector no miraba `Feat.prerequisite`, así que ofrecía
  // dotes que el personaje no podía tomar. Ahora las oculta, delegando la
  // comprobación en `CharacterValidator.unmetFeatPrerequisite`.
  Character fighterL5({int strength = 16, List<String> featIds = const []}) =>
      Character(
        id: 't-fighter-prereq',
        name: 'Prueba',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        subclassId: 'champion',
        level: 5,
        assignedScores: {
          Ability.strength: strength,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 12,
          Ability.charisma: 8,
        },
        hpPerLevel: [10, 6, 6, 6, 6],
        featIds: featIds,
      );

  Future<void> openFeatPicker(WidgetTester tester, Character c) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
  }

  testWidgets('no ofrece una dote cuya característica mínima no se cumple', (
    tester,
  ) async {
    // Maestro de Armas Grandes exige Fuerza 13.
    await openFeatPicker(tester, fighterL5(strength: 8));
    await searchFeat(tester, 'Maestro de Armas Grandes');

    expect(
      find.widgetWithText(InkWell, 'Maestro de Armas Grandes'),
      findsNothing,
    );
    // Pero el selector no queda vacío: Cocinero no pide característica.
    await searchFeat(tester, 'Cocinero (Sabiduría)');
    expect(
      find.widgetWithText(InkWell, 'Cocinero (Sabiduría)'),
      findsOneWidget,
    );
  });

  testWidgets('no ofrece una marca mayor sin la marca base', (tester) async {
    // Marca Mayor de Manejo exige tener Marca de Manejo.
    await openFeatPicker(tester, fighterL5());
    await searchFeat(tester, 'Marca Mayor de Manejo');

    expect(find.widgetWithText(InkWell, 'Marca Mayor de Manejo'), findsNothing);
  });

  testWidgets('ofrece la marca mayor cuando ya tiene la marca base', (
    tester,
  ) async {
    await openFeatPicker(
      tester,
      fighterL5(featIds: const ['mark-of-handling']),
    );
    await searchFeat(tester, 'Marca Mayor de Manejo');

    expect(
      find.widgetWithText(InkWell, 'Marca Mayor de Manejo'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Mejora de Característica no se duplica en el selector de dotes',
    (tester) async {
      await openFeatPicker(tester, fighterL5());
      await searchFeat(tester, 'Mejora de Característica');

      expect(
        find.widgetWithText(InkWell, 'Mejora de Característica'),
        findsNothing,
      );
    },
  );

  testWidgets('no ofrece otra variante de Resiliente', (tester) async {
    await openFeatPicker(
      tester,
      fighterL5(featIds: const ['resilient-wisdom']),
    );
    await searchFeat(tester, 'Resiliente (Constitución)');

    expect(
      find.widgetWithText(InkWell, 'Resiliente (Constitución)'),
      findsNothing,
    );
  });

  testWidgets('el nivel del prerrequisito se mide en el nivel nuevo', (
    tester,
  ) async {
    // Las 57 dotes generales exigen nivel 4. Un personaje de nivel 3 subiendo
    // a 4 debe verlas: comprobar contra el nivel viejo vaciaría el selector
    // justo en el ASI más común.
    await openFeatPicker(tester, fighterL3());
    await searchFeat(tester, 'Maestro de Armas Grandes');

    expect(
      find.widgetWithText(InkWell, 'Maestro de Armas Grandes'),
      findsOneWidget,
    );
  });

  testWidgets('elegir una dote muestra qué hace', (tester) async {
    // La grilla son decenas de chips con solo el nombre: sin este panel había
    // que elegir a ciegas.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // Sin dote elegida, se explica qué hacer para ver la descripción.
    expect(find.text('Elegí una dote'), findsOneWidget);

    // Cocinero y no Actor: Actor exige Carisma 13 y este guerrero tiene 8, así
    // que desde que el selector respeta los prerrequisitos no se ofrece.
    await searchFeat(tester, 'Cocinero (Sabiduría)');
    final chip = find.widgetWithText(InkWell, 'Cocinero (Sabiduría)');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // El texto sale de los rasgos pasivos de la dote, no de un literal.
    final esperado = featSummary(repo.feat('chef-wisdom')!);
    expect(esperado, isNotEmpty);
    // La tarjeta y el panel de detalle comparten el resumen.
    expect(find.text(esperado), findsWidgets);
    expect(find.text('Elegí una dote'), findsNothing);
  });

  testWidgets('no ofrece Iniciado en la Magia: es dote de origen', (
    tester,
  ) async {
    // En 2024 los ASI solo admiten dotes generales, e Iniciado en la Magia es
    // de origen. Antes figuraba como general y aparecía acá.
    expect(repo.feat('magic-initiate-wizard')!.category, 'origin');

    final c = Character(
      id: 't-fighter-4',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      subclassId: 'champion',
      level: 3,
      assignedScores: {
        Ability.strength: 16,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      hpPerLevel: [10, 6, 6],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
    await searchFeat(tester, 'Iniciado en la Magia');

    expect(
      find.widgetWithText(InkWell, 'Iniciado en la Magia (Mago)'),
      findsNothing,
    );
  });
}
