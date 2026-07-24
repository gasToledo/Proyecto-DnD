import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/theme/class_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El emblema de clase reemplaza a la inicial cuando no hay retrato.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024');
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)));

  testWidgets('sin retrato muestra el ícono de la clase, no la inicial',
      (tester) async {
    final wizard = repo.characterClass('wizard')!;
    await pump(tester, ClassMedallion(klass: wizard, fallback: 'S'));

    expect(find.byIcon(classIcon(wizard)), findsOneWidget);
    expect(find.text('S'), findsNothing);
  });

  testWidgets('cada clase da un emblema con su propio color', (tester) async {
    final wizard = repo.characterClass('wizard')!;
    final barbarian = repo.characterClass('barbarian')!;
    const fb = Color(0xFF000001);
    expect(classAccent(wizard, fb), isNot(classAccent(barbarian, fb)));
    expect(classIcon(wizard), isNot(classIcon(barbarian)));
  });

  testWidgets('sin clase conocida cae a la inicial', (tester) async {
    await pump(tester, const ClassMedallion(klass: null, fallback: 'S'));
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('Medallion sin emblema sigue mostrando la inicial',
      (tester) async {
    await pump(tester, const Medallion(fallback: 'B', size: 40));
    expect(find.text('B'), findsOneWidget);
  });
}
