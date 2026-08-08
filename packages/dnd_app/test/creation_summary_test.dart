import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

/// Recorrido completo del wizard: del primer paso al personaje creado.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  testWidgets('crea un Mago Alto Elfo de punta a punta y lo resume bien', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Character? created;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (c) => created = c),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(String t) async {
      await tester.tap(find.text(t).first);
      await tester.pumpAndSettle();
    }

    // Raza / Clase / Trasfondo
    await tapOption(tester, 'Elfo');
    final nextButton = find.widgetWithText(FilledButton, 'Siguiente');
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    expect(
      find.text('Esta especie requiere elegir un linaje.'),
      findsOneWidget,
    );
    await tapText('Alto Elfo');
    await tester.tap(find.byType(DropdownButton<Ability>));
    await tester.pumpAndSettle();
    await tapText('INT');
    await next();
    await tapOption(tester, 'Mago');
    await next();
    await tapOption(tester, 'Soldado');
    await tapText('+1 / +1 / +1');
    await next();

    // Puntuaciones
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

    // Aptitudes: 2 de clase y 1 de especie.
    await tapText('Arcanos');
    await tapText('Historia');
    await tester.tap(find.text('Supervivencia').last);
    await tapText('Juego de dados');
    await tester.pumpAndSettle();
    await pickLanguages(tester);
    await next();

    // Equipo: dejamos el equipo por defecto y llenamos los cupos de conjuros,
    // guiándonos por lo que el propio footer dice que falta.
    var cantrip = 0, spell = 0;
    for (var guard = 0; guard < 40; guard++) {
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Siguiente'),
      );
      if (btn.onPressed != null) break;
      final pending =
          tester.widget<Text>(find.textContaining('Falta:')).data ?? '';
      final target = pending.contains('Trucos')
          ? find.byIcon(Icons.auto_fix_high).at(cantrip++)
          : find.byIcon(Icons.auto_stories).at(spell++);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
    await next();

    // Detalles
    await tester.enterText(find.byType(TextField).first, 'Elminster');
    await tester.pumpAndSettle();
    await tapText('Neutral Bueno');
    await next();

    // Resumen
    expect(find.text('REVISÁ Y CONFIRMÁ'), findsOneWidget);
    expect(find.text('Elminster'), findsWidgets);
    expect(
      find.text('Elfo (Alto Elfo) · Mago · Soldado · Nivel 1'),
      findsOneWidget,
    );
    // "Puntuaciones" y "Equipo" también son rótulos del stepper: se asienta
    // sobre los bloques que solo existen en el resumen.
    expect(find.text('EN COMBATE'), findsOneWidget);
    expect(find.text('COMPETENCIAS'), findsOneWidget);
    expect(find.text('DOTES'), findsOneWidget);
    expect(find.text('CONJUROS'), findsWidgets);
    expect(find.text('Prestidigitación'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Confirmar
    await tester.tap(find.widgetWithText(FilledButton, 'Crear personaje'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.name, 'Elminster');
    expect(created!.classId, 'wizard');
    expect(created!.raceId, 'elf');
    expect(created!.lineageId, 'elf-high');
    expect(created!.speciesSpellcastingAbility, Ability.intelligence);
    expect(created!.backgroundId, 'soldier');
    expect(created!.alignment, CharacterAlignment.neutralGood);
    expect(created!.chosenSkills, containsAll(['arcana', 'history']));
    // Los PG arrancan al máximo.
    final sheet = CharacterCompiler(repo).compile(created!);
    expect(created!.combat.currentHp, sheet.maxHp);
  });
}
