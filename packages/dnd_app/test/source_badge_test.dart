import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Procedencia visible: solo el contenido del SRD 5.2.1 está cubierto por la
/// atribución CC BY 4.0, así que el jugador tiene que poder distinguirlo.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  test('cada procedencia tiene una etiqueta legible', () {
    expect(sourceLabel(ContentSource.srd2024), 'SRD');
    expect(sourceLabel(ContentSource.phb2024), 'PHB 2024');
    expect(sourceLabel(ContentSource.srd2014), 'SRD 2014');
    expect(sourceLabel(ContentSource.homebrew), 'Propio');
  });

  testWidgets('el selector de subclase distingue SRD de PHB 2024', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Mago de nivel 2 a 3: elige entre 4 escuelas, de las cuales solo Evocación
    // pertenece al SRD.
    final c = Character(
      id: 't-wizard-3',
      name: 'Prueba',
      raceId: 'human',
      classId: 'wizard',
      backgroundId: 'soldier',
      level: 2,
      assignedScores: {
        Ability.strength: 8,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 16,
        Ability.wisdom: 12,
        Ability.charisma: 10,
      },
      hpPerLevel: [6, 4],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Escuela de Evocación'), findsOneWidget);
    // Una sola opción del SRD y tres del PHB.
    expect(find.text('SRD'), findsOneWidget);
    expect(find.text('PHB 2024'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
