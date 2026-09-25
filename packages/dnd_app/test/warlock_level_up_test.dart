import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'level_up_helpers.dart';

/// La subida del Brujo gnomo de la observación del 24/09/2026: el nivel 4 se
/// confirmaba sin el truco ni el conjuro nuevos, y las invocaciones con
/// elección (Pacto del Grimorio, Descarga Agónica) no pedían nada.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Character brujo({
    required int level,
    List<String> invocations = const [
      'armor-of-shadows',
      'eldritch-mind',
      'devils-sight',
    ],
    List<String> cantrips = const ['eldritch-blast', 'mind-sliver'],
    List<String> spells = const [
      'hex',
      'armor-of-agathys',
      'charm-person',
      'invisibility',
    ],
  }) => Character(
    id: 't-brujo',
    name: 'Nimble Fizzwick',
    raceId: 'human',
    classId: 'warlock',
    subclassId: level >= 3 ? 'archfey-patron' : null,
    backgroundId: 'soldier',
    level: level,
    assignedScores: {
      Ability.strength: 8,
      Ability.dexterity: 14,
      Ability.constitution: 13,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 17,
    },
    hpPerLevel: [8, for (var i = 1; i < level; i++) 5],
    featureChoices: {'warlock-invocation': invocations},
    cantripIds: cantrips,
    spellIds: spells,
  );

  Future<void> pump(
    WidgetTester tester,
    Character c, {
    void Function(Character)? onDone,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: onDone ?? (_) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continuar(WidgetTester tester) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('de 3 a 4 no confirma sin el truco y el conjuro nuevos', (
    tester,
  ) async {
    final antes = brujo(level: 3);
    final sheetAntes = CharacterCompiler(repo).compile(antes);
    final despues = CharacterCompiler(
      repo,
    ).compile(antes.copyWith(level: 4, hpPerLevel: [...antes.hpPerLevel, 5]));
    // El caso tiene sentido solo si el nivel 4 trae cupo nuevo de los dos.
    expect(
      despues.spellcasting!.cantripsKnown,
      sheetAntes.spellcasting!.cantripsKnown + 1,
    );
    expect(
      despues.spellcasting!.preparedCount,
      sheetAntes.spellcasting!.preparedCount + 1,
    );

    Character? saved;
    await pump(tester, antes, onDone: (c) => saved = c);

    // El resumen ya no dice que revisar conjuros es opcional.
    expect(find.text('ELEGÍS VOS'), findsWidgets);
    expect(find.text('OPCIONAL'), findsNothing);

    for (
      var i = 0;
      i < 10 && find.text('Preparar conjuros').evaluate().isEmpty;
      i++
    ) {
      // La mejora de característica del nivel 4.
      final carisma = find.widgetWithText(InkWell, 'Carisma');
      if (find.text('Mejora tu personaje').evaluate().isNotEmpty &&
          carisma.evaluate().isNotEmpty) {
        await tester.ensureVisible(carisma.first);
        await tester.pumpAndSettle();
        await tester.tap(carisma.first);
        await tester.pumpAndSettle();
      }
      await continuar(tester);
    }

    expect(
      find.text('Te falta elegir un truco y un conjuro para continuar.'),
      findsOneWidget,
    );
    // El cuerpo del paso dice lo mismo que el pie, no solo el cupo de
    // preparados.
    expect(
      find.text(
        'Trucos: ${antes.cantripIds.length} de '
        '${despues.spellcasting!.cantripsKnown}',
      ),
      findsOneWidget,
    );
    expect(find.text('Te falta elegir un truco.'), findsOneWidget);
    expect(find.text('Te falta preparar un conjuro.'), findsOneWidget);
    // Continuar no avanza.
    await continuar(tester);
    expect(find.text('Preparar conjuros'), findsOneWidget);

    await completarConjurosDeClase(tester);
    expect(find.textContaining('Te falta elegir'), findsNothing);
    expect(find.text('Conjuros actualizados'), findsOneWidget);

    await avanzarHastaConfirmar(tester, 'Confirmar nivel 4');
    // La revisión cuenta lo elegido para la clase. Leía las listas planas,
    // que el editor vacía al pasarlas al mapa por clase, y decía «6 → 0».
    final fila = find.ancestor(
      of: find.text('Trucos y conjuros elegidos'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
        of: fila.first,
        matching: find.text(
          '${antes.cantripIds.length + antes.spellIds.length}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: fila.first,
        matching: find.text(
          '${despues.spellcasting!.cantripsKnown + despues.spellcasting!.preparedCount}',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar nivel 4'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final sheet = CharacterCompiler(repo).compile(saved!);
    expect(
      saved!.cantripIdsFor('warlock'),
      hasLength(sheet.spellcasting!.cantripsKnown),
    );
    expect(
      saved!.spellIdsFor('warlock'),
      hasLength(sheet.spellcasting!.preparedCount),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el conjuro listo y el truco pendiente no se da por hecho', (
    tester,
  ) async {
    // El estado de la observación en producción: los preparados completos y
    // el truco nuevo sin elegir. La pantalla decía «Conjuros actualizados»
    // con tilde y el truco pendiente solo aparecía en el pie.
    final antes = brujo(
      level: 3,
      spells: const [
        'hex',
        'armor-of-agathys',
        'charm-person',
        'invisibility',
        'mirror-image',
      ],
    );
    await pump(tester, antes);

    for (
      var i = 0;
      i < 10 && find.text('Preparar conjuros').evaluate().isEmpty;
      i++
    ) {
      final carisma = find.widgetWithText(InkWell, 'Carisma');
      if (find.text('Mejora tu personaje').evaluate().isNotEmpty &&
          carisma.evaluate().isNotEmpty) {
        await tester.ensureVisible(carisma.first);
        await tester.pumpAndSettle();
        await tester.tap(carisma.first);
        await tester.pumpAndSettle();
      }
      await continuar(tester);
    }
    expect(find.text('Te falta preparar un conjuro.'), findsNothing);
    expect(find.text('Te falta elegir un truco.'), findsOneWidget);

    // Pasar por el editor y guardar sin tocar el truco.
    await tester.tap(find.text('Preparar conjuros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Conjuros actualizados'), findsNothing);
    expect(find.text('Preparar conjuros'), findsOneWidget);
    expect(find.text('Te falta elegir un truco.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pacto del Grimorio tomado al subir pide sus conjuros', (
    tester,
  ) async {
    // A nivel 1 conoce una invocación; a nivel 2, tres.
    await pump(
      tester,
      brujo(
        level: 1,
        invocations: const ['armor-of-shadows'],
        spells: const ['hex', 'armor-of-agathys'],
      ),
    );
    await continuar(tester);
    await continuar(tester);
    expect(find.text('Tus elecciones de este nivel'), findsOneWidget);

    for (final nombre in ['Pacto del Grimorio', 'Mente Sobrenatural']) {
      final chip = find.widgetWithText(InkWell, nombre);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    await continuar(tester);
    for (
      var i = 0;
      i < 4 &&
          find
              .text('Conjuros que quedan siempre preparados')
              .evaluate()
              .isEmpty;
      i++
    ) {
      await continuar(tester);
    }

    expect(find.textContaining('LIBRO DE LAS SOMBRAS: TRUCOS'), findsOneWidget);
    expect(
      find.textContaining('LIBRO DE LAS SOMBRAS: RITUALES'),
      findsOneWidget,
    );
    expect(find.text('Te faltan 5 conjuros para continuar.'), findsOneWidget);
    await continuar(tester);
    expect(find.textContaining('LIBRO DE LAS SOMBRAS: TRUCOS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Descarga Agónica tomada al subir pide su truco', (tester) async {
    await pump(
      tester,
      brujo(
        level: 1,
        invocations: const ['armor-of-shadows'],
        spells: const ['hex', 'armor-of-agathys'],
      ),
    );
    await continuar(tester);
    await continuar(tester);

    for (final nombre in ['Descarga Agónica', 'Mente Sobrenatural']) {
      final chip = find.widgetWithText(InkWell, nombre);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    await continuar(tester);
    for (
      var i = 0;
      i < 4 &&
          find.textContaining('DESCARGA AGÓNICA: TRUCO').evaluate().isEmpty;
      i++
    ) {
      await continuar(tester);
    }

    expect(find.textContaining('DESCARGA AGÓNICA: TRUCO'), findsOneWidget);
    expect(find.textContaining('Elegí uno que ya conocés'), findsOneWidget);
    expect(
      find.text('Te falta elegir un conjuro para continuar.'),
      findsOneWidget,
    );
    // Las opciones son los trucos de Brujo que conoce.
    expect(find.textContaining('Descarga Sobrenatural'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
