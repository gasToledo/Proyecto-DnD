import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';

/// Paso de Aptitudes: competencias de clase/especie y dote de origen.
///
/// Dos recorridos y no ocho tests, uno por trasfondo: llegar hasta acá cuesta
/// cuatro pantallas del asistente —incluido asignar las seis puntuaciones— y
/// esa navegación tardaba 4,5 s en cada uno. Las reglas de fondo (cupos, podas,
/// bloqueos) ya están en `creation_draft_test.dart` a 10 ms el caso; acá queda
/// lo que solo se ve en la pantalla.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Navega hasta Aptitudes con Humano + Mago + el trasfondo indicado.
  Future<void> gotoAptitudes(
    WidgetTester tester, {
    String background = 'Soldado',
  }) async {
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
    await pickSize(tester);
    await next();
    await tapOption(tester, 'Mago');
    await next();
    await tapOption(tester, background);
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

  /// Toca una tarjeta que puede estar fuera del viewport.
  Future<void> tapCard(WidgetTester tester, Finder card) async {
    await tester.scrollUntilVisible(card, 200);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  testWidgets('competencias de clase, dote de origen y lo que abre Habilidoso', (
    tester,
  ) async {
    await gotoAptitudes(tester);

    // --- Los nombres son los del catálogo, no ids en inglés, y lo que ya da el
    // trasfondo aparece bloqueado.
    expect(find.text('Competencias de clase'.toUpperCase()), findsOneWidget);
    expect(find.text('Juego de Manos'), findsOneWidget);
    expect(find.text('sleight-of-hand'), findsNothing);
    expect(find.text('Atletismo'), findsWidgets);
    expect(find.byIcon(Icons.lock), findsWidgets);

    // --- El tope de la clase. El Mago elige 2, y llegado al tope una no
    // elegida deja de responder. Varias habilidades figuran en las dos listas
    // (clase y especie); la de clase es la primera en el árbol.
    expect(find.text('0 / 2 elegidas'), findsOneWidget);
    await tester.tap(find.text('Arcanos').first);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 elegidas'), findsOneWidget);
    await tester.tap(find.text('Historia').first);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 elegidas'), findsOneWidget);
    await tester.tap(find.text('Medicina').first);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 elegidas'), findsOneWidget);

    // --- Dote de origen. Iniciado en la Magia se ofrece acá desde que pasó de
    // general a origin (contraparte de la regresión en la subida de nivel), y
    // Atacante Salvaje no, porque ya la concede el Soldado: con las dos vías el
    // rasgo salía duplicado en la ficha.
    expect(find.text('Dote de origen'.toUpperCase()), findsOneWidget);
    final iniciado = find.text('Iniciado en la Magia (Mago)');
    await tester.scrollUntilVisible(iniciado, 200);
    await tester.pumpAndSettle();
    expect(iniciado, findsOneWidget);
    expect(find.text('Atacante Salvaje'), findsNothing);

    // --- Habilidoso suma tres competencias a la elección que ya traía el
    // Soldado (su set de juego).
    expect(find.text('Competencias a elección'.toUpperCase()), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    await tapCard(tester, find.text('Habilidoso'));
    expect(find.text('0/4'), findsOneWidget);

    // Ofrece herramientas además de habilidades, que es lo que la distingue de
    // las competencias de clase y especie...
    await tapCard(tester, find.text('Herramientas de ladrón'));
    expect(find.text('1/4'), findsOneWidget);
    // ...pero no las genéricas: "Herramientas de artesano" es "una de esta
    // familia a tu elección", así que elegirla dejaría al personaje sin nada
    // concreto.
    expect(find.text('Herramientas de artesano'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('una competencia no se puede tomar dos veces, en los dos '
      'sentidos', (tester) async {
    // El Noble ya concede Habilidoso, así que la elección de tres competencias
    // convive con la de habilidades de clase desde que se abre el paso. Sin
    // cruzar las dos listas se podía tomar Arcanos por clase y otra vez por la
    // dote: la segunda no agregaba nada y la ficha terminada avisaba de la
    // repetición, pero la creación la seguía ofreciendo.
    await gotoAptitudes(tester, background: 'Noble');
    // Habilidoso (3) más el set de juego del Noble (1).
    expect(find.text('0/4'), findsOneWidget);

    /// La tarjeta de la lista de la dote es la última del árbol; la de clase,
    /// la primera. Las dos habilidades son de la lista del Mago y ninguna la
    /// concede el Noble (que ya trae Historia y Persuasión, y por eso aparecen
    /// bloqueadas arriba y no se pueden usar para probar el cruce).
    Future<void> tapDote(String label) =>
        tapCard(tester, find.text(label).last);

    // --- Elegida por clase, bloqueada en la dote.
    await tester.tap(find.text('Arcanos').first);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 elegidas'), findsOneWidget);
    await tapDote('Arcanos');
    // La tarjeta de la dote no responde: sigue sin gastarse ninguna.
    expect(find.text('0/4'), findsOneWidget);

    // --- Y al revés: elegida por la dote, bloqueada en la clase.
    await tapDote('Medicina');
    expect(find.text('1/4'), findsOneWidget);
    await tester.tap(find.text('Medicina').first);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 elegidas'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
