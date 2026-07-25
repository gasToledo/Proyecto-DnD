import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
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
}
