import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

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

    await tapOption(tester, 'Humano');
    await next();
    await tapOption(tester, 'Mago');
    await next();
    await tapOption(tester, 'Soldado');
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

  testWidgets('no ofrece la dote de origen que ya concede el trasfondo', (
    tester,
  ) async {
    // El Soldado concede Atacante Salvaje. Si el Humano podía elegirla otra vez
    // quedaba con la dote por dos vías y el rasgo aparecía duplicado en la
    // ficha. El PHB solo permite repetir las dotes que lo declaran.
    await gotoAptitudes(tester);

    // La sección existe y ofrece alternativas, así que la ausencia es del
    // filtro y no de un paso que no llegó a construirse.
    expect(find.text('Dote de origen'.toUpperCase()), findsOneWidget);
    final otra = find.text('Duro');
    await tester.scrollUntilVisible(otra, 200);
    await tester.pumpAndSettle();
    expect(otra, findsOneWidget);

    expect(find.text('Atacante Salvaje'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Habilidoso abre la elección de tres competencias', (
    tester,
  ) async {
    await gotoAptitudes(tester);

    // Antes de tomarla, la sección no existe: la declara la dote, no el paso.
    expect(find.text('Competencias por dote'.toUpperCase()), findsNothing);

    final card = find.text('Habilidoso');
    await tester.scrollUntilVisible(card, 200);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Competencias por dote'.toUpperCase()), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);

    // Ofrece herramientas además de habilidades, que es lo que la distingue de
    // las competencias de clase y especie.
    final tool = find.text('Herramientas de ladrón');
    await tester.scrollUntilVisible(tool, 200);
    await tester.pumpAndSettle();
    await tester.tap(tool);
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Habilidoso no ofrece las herramientas genéricas', (
    tester,
  ) async {
    // "Herramientas de artesano" es "una de esta familia a tu elección", no
    // una competencia: elegirla dejaría al personaje sin nada concreto.
    await gotoAptitudes(tester);

    final card = find.text('Habilidoso');
    await tester.scrollUntilVisible(card, 200);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Herramientas de artesano'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
