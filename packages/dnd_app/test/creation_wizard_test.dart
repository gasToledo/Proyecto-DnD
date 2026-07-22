import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresión: al elegir Bardo, el paso de Clase debía mostrar sus opciones de
/// habilidad. El Bardo es la única clase con `skillChoiceFrom` vacío (2024:
/// elige libremente entre todas), y el picker de habilidades de clase no tenía
/// el fallback "vacío = cualquiera" que sí tiene el de especie.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024');
  });

  testWidgets('elegir Bardo muestra opciones de habilidad de clase', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: CreationWizard(repo: repo, onCreate: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bardo'), findsOneWidget);
    await tester.tap(find.text('Bardo'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate(
        (w) => w is Eyebrow && w.text == 'Habilidades de clase (elige 3)'),
        findsOneWidget);
    // Las 18 habilidades del juego deben estar disponibles (antes: ninguna).
    expect(find.byType(FilterChip), findsNWidgets(18));
  });
}
