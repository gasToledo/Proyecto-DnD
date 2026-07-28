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

    // Nivel 4 es ASI para el Guerrero: aparece la elección de mejora/dote.
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
    expect(find.text('Confirmar nivel 4'), findsOneWidget);
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
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // La dote ya tomada no debe ofrecerse de nuevo (no es repetible).
    expect(
      find.widgetWithText(ChoiceChip, 'Maestro de Armas Grandes'),
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
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
  }

  testWidgets('no ofrece una dote cuya característica mínima no se cumple', (
    tester,
  ) async {
    // Maestro de Armas Grandes exige Fuerza 13.
    await openFeatPicker(tester, fighterL5(strength: 8));

    expect(
      find.widgetWithText(ChoiceChip, 'Maestro de Armas Grandes'),
      findsNothing,
    );
    // Pero el selector no queda vacío: Cocinero no pide característica.
    expect(find.widgetWithText(ChoiceChip, 'Cocinero'), findsOneWidget);
  });

  testWidgets('no ofrece una marca mayor sin la marca base', (tester) async {
    // Marca Mayor de Manejo exige tener Marca de Manejo.
    await openFeatPicker(tester, fighterL5());

    expect(
      find.widgetWithText(ChoiceChip, 'Marca Mayor de Manejo'),
      findsNothing,
    );
  });

  testWidgets('ofrece la marca mayor cuando ya tiene la marca base', (
    tester,
  ) async {
    await openFeatPicker(
      tester,
      fighterL5(featIds: const ['mark-of-handling']),
    );

    expect(
      find.widgetWithText(ChoiceChip, 'Marca Mayor de Manejo'),
      findsOneWidget,
    );
  });

  testWidgets('el nivel del prerrequisito se mide en el nivel nuevo', (
    tester,
  ) async {
    // Las 57 dotes generales exigen nivel 4. Un personaje de nivel 3 subiendo
    // a 4 debe verlas: comprobar contra el nivel viejo vaciaría el selector
    // justo en el ASI más común.
    await openFeatPicker(tester, fighterL3());

    expect(
      find.widgetWithText(ChoiceChip, 'Maestro de Armas Grandes'),
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

    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // Sin dote elegida, se explica qué hacer para ver la descripción.
    expect(find.text('Elegí una dote para ver qué hace.'), findsOneWidget);

    // Cocinero y no Actor: Actor exige Carisma 13 y este guerrero tiene 8, así
    // que desde que el selector respeta los prerrequisitos no se ofrece.
    final chip = find.widgetWithText(ChoiceChip, 'Cocinero');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // El texto sale de los rasgos pasivos de la dote, no de un literal.
    final esperado = featSummary(repo.feat('chef')!);
    expect(esperado, isNotEmpty);
    expect(find.text(esperado), findsOneWidget);
    expect(find.text('Elegí una dote para ver qué hace.'), findsNothing);
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

    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ChoiceChip, 'Iniciado en la Magia (Mago)'),
      findsNothing,
    );
  });
}
