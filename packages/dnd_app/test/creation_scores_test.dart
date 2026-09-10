import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

/// Cubre el paso de Puntuaciones ya rediseñado: se llega navegando el wizard
/// real (lo que además ejercita el gating y el stepper).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Avanza hasta Puntuaciones. Usa Mago a propósito: no pide estilo de combate
  /// ni maestrías, así el paso de Clase se completa con solo elegirlo.
  Future<void> gotoScores(WidgetTester tester) async {
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

    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
    }

    // Raza
    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await next();

    // Clase
    await tapOption(tester, 'Mago');
    await next();

    // Trasfondo (+1/+1/+1 no necesita elegir características). El reparto vive
    // debajo de la grilla, que ya tiene 33 trasfondos: hay que scrollear.
    await tapOption(tester, 'Soldado');
    await tester.ensureVisible(find.text('+1 / +1 / +1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 / +1 / +1'));
    await tester.pumpAndSettle();
    await next();
  }

  testWidgets('la grilla arranca con el pool entero y asignar mueve todo', (
    tester,
  ) async {
    // Un recorrido y no dos: llegar al paso cuesta tres pantallas del
    // asistente, y la segunda mitad solo tiene sentido después de la primera.
    await gotoScores(tester);

    // --- Una tarjeta por característica y el pool sin tocar.
    expect(find.text('Valores sin asignar'), findsOneWidget);
    for (final a in Ability.values) {
      expect(find.text(a.abbr), findsOneWidget, reason: 'falta ${a.abbr}');
    }
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(6));
    // Array estándar: 6 valores del pool sin asignar todavía.
    expect(find.text('sin asignar'), findsNWidgets(6));

    // --- Asignar el 15 a la primera característica (FUE).
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();

    // Soldado con +1/+1/+1 suma +1 a FUE: 15 + 1 = 16, modificador +3.
    expect(find.text('base 15'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('MOD +3'), findsOneWidget);
    // Y el 15 ya no figura entre los valores sin asignar.
    expect(find.text('sin asignar'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  // Los cuatro métodos no se explican solos, y la ayuda del modo manual es la
  // única que aparece y desaparece: sirve para comprobar que sigue atada al
  // método después de pasar a `AppHelpCallout`.
  testWidgets(
    'la ayuda del método está siempre y la del manual solo en manual',
    (tester) async {
      await gotoScores(tester);

      expect(find.text('¿Qué método conviene?'), findsOneWidget);
      expect(find.textContaining('Escribí la puntuación base'), findsNothing);

      await tester.tap(find.text('Escribir a mano'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué método conviene?'), findsOneWidget);
      expect(find.textContaining('Escribí la puntuación base'), findsOneWidget);

      await tester.tap(find.text('Array estándar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escribí la puntuación base'), findsNothing);

      // La ayuda es texto largo arriba de una grilla que ya se apila a una
      // columna: tiene que entrar en el ancho compacto del asistente, el mismo
      // que fija `creation_wizard_test`.
      //
      // Ojo con bajar este número: el paso ya desbordaba por su cuenta abajo de
      // ~420 px antes de que existiera esta ayuda, y eso es otro arreglo.
      tester.view.physicalSize = const Size(480, 900);
      await tester.pumpAndSettle();
      expect(find.text('¿Qué método conviene?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
