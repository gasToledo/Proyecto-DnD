import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paso de Aptitudes: competencias de clase/especie y dote de origen.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Navega hasta Aptitudes con Humano + Mago + Soldado.
  Future<void> gotoAptitudes(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 2200);
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

    await tester.tap(find.text('Humano'));
    await tester.pumpAndSettle();
    await next();
    await tester.tap(find.text('Mago'));
    await tester.pumpAndSettle();
    await next();
    await tester.tap(find.text('Soldado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 / +1 / +1'));
    await tester.pumpAndSettle();
    await next();
    // Puntuaciones: asignar las 6 del array estándar para poder avanzar. El
    // ítem del menú abierto es la última coincidencia (está en el overlay).
    const order = [15, 14, 13, 12, 10, 8];
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(i));
      await tester.pumpAndSettle();
      // El ítem vive dentro del menú desplegable (el único ListView en este
      // paso), no en las pills del pool que muestran el mismo número.
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
  }

  testWidgets('muestra las habilidades en español con su característica', (
    tester,
  ) async {
    await gotoAptitudes(tester);

    expect(find.text('Competencias de clase'.toUpperCase()), findsOneWidget);
    // Nombres del catálogo, no ids en inglés.
    expect(find.text('Juego de Manos'), findsOneWidget);
    expect(find.text('sleight-of-hand'), findsNothing);
    // Las que ya da el trasfondo aparecen bloqueadas.
    expect(find.text('Atletismo'), findsWidgets);
    expect(find.byIcon(Icons.lock), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('respeta el tope de competencias de clase', (tester) async {
    await gotoAptitudes(tester);

    // Varias habilidades figuran en las dos listas (clase y especie); la de
    // clase es la primera en el árbol.
    Future<void> tapClassSkill(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    // El Mago elige 2. El contador arranca en 0.
    expect(find.text('0 / 2 elegidas'), findsOneWidget);
    await tapClassSkill('Arcanos');
    expect(find.text('1 / 2 elegidas'), findsOneWidget);
    await tapClassSkill('Historia');
    expect(find.text('2 / 2 elegidas'), findsOneWidget);
    // Llegado al tope, una no elegida deja de responder.
    await tapClassSkill('Medicina');
    expect(find.text('2 / 2 elegidas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ofrece Iniciado en la Magia como dote de origen del Humano', (
    tester,
  ) async {
    // Contraparte de la regresión en la subida de nivel: al pasar de general a
    // origin, la dote sale del picker de ASI y entra en el del Humano.
    await gotoAptitudes(tester);

    final card = find.text('Iniciado en la Magia (Mago)');
    await tester.scrollUntilVisible(card, 200);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
