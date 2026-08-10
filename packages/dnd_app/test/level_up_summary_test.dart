import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_summary_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La pantalla de resumen abre con una animación (medallón con "pop" + estallido
/// dibujado por CustomPainter). Verifica que monta y asienta sin excepciones.
void main() {
  SheetDiff diff() => const SheetDiff(
    hpGained: 7,
    proficiencyBonusFrom: 2,
    proficiencyBonusTo: 3,
    abilityChanges: {},
    extraAttacksGained: 1,
    weaponMasterySlotsGained: 0,
    newPassives: [],
    newResources: [],
    newCompanions: [],
    newSkillProficiencies: [],
    newSaveProficiencies: [],
    speedGained: 0,
    newDarkvision: null,
  );

  testWidgets('el resumen de subida de nivel anima y renderiza sin errores', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpSummaryScreen(
          level: 5,
          diff: diff(),
          newFeatures: const [
            ClassFeature(
              level: 5,
              name: 'Ataque Adicional',
              description: 'Atacás dos veces.',
            ),
          ],
        ),
      ),
    );
    // Un pump para el primer frame + settle para que termine la animación.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('¡Subiste a nivel 5!'), findsOneWidget);
    expect(find.text('Ataque Adicional'), findsOneWidget);
  });

  testWidgets('el resumen cabe en una ventana compacta', (tester) async {
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpSummaryScreen(
          level: 5,
          diff: diff(),
          newFeatures: const [],
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('+7 PG máximos'), findsOneWidget);
    expect(find.text('¡Listo!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
