import 'package:dnd_app/codex/codex_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El Códice: todo el catálogo para leer, sin crear ni editar nada.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Future<void> pumpCodex(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CodexScreen(repo: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('codex-search')), text);
    await tester.pumpAndSettle();
  }

  testWidgets('la portada cuenta lo que hay en cada categoría', (tester) async {
    await pumpCodex(tester);

    // Los conteos salen del catálogo, no de literales: tocar el contenido no
    // puede dejar la portada mintiendo.
    final magicos = repo.items.values.where((i) => i.isMagic).length;
    expect(find.text('${repo.spells.length}'), findsWidgets);
    expect(find.text('$magicos'), findsWidgets);
    expect(find.text('${repo.creaturesSorted.length}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // Construir los detalles sin dibujarlos: lo que puede romper (un dato que
  // falta, una rareza desconocida) está en armarlos, y dibujar 1500 fichas
  // sería lento sin atrapar más.
  testWidgets('el detalle de cada entrada del catálogo se arma', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    var total = 0;
    for (final category in CodexCategory.values) {
      for (final e in codexEntries(category, repo)) {
        expect(e.name, isNotEmpty, reason: '${category.name}/${e.id}');
        e.body(context);
        total++;
      }
    }
    expect(total, greaterThan(1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un objeto mágico se lee con sus datos y su texto', (
    tester,
  ) async {
    await pumpCodex(tester);
    final bolsa = repo.item('bolsa-de-contencion')!;

    await tester.tap(find.text('Objetos mágicos').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, bolsa.name);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('codex-magicItems-bolsa-de-contencion')),
    );
    await tester.pumpAndSettle();

    expect(find.text('${formatPounds(bolsa.weight)} lb'), findsOneWidget);
    expect(find.text(formatCost(bolsa.costCp)), findsOneWidget);
    // La línea de tipo y rareza va arriba como dato, no repetida en el texto.
    final texto = bolsa.description.substring(
      bolsa.description.indexOf('\n') + 1,
    );
    expect(find.text(texto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el filtro por nivel deja solo los conjuros de ese nivel', (
    tester,
  ) async {
    await pumpCodex(tester);
    await tester.tap(find.text('Conjuros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Nivel 3'));
    await tester.pumpAndSettle();

    final nivel3 = repo.spells.values.where((s) => s.level == 3).length;
    expect(find.text('$nivel3 entradas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la búsqueda general agrupa y abre la entrada tocada', (
    tester,
  ) async {
    await pumpCodex(tester);
    final bola = repo.spell('fireball')!;

    await search(tester, 'fuego');
    expect(find.textContaining('CONJUROS ·'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('codex-result-spells-fireball')),
    );
    await tester.pumpAndSettle();
    expect(find.text(bola.description), findsOneWidget);
    expect(find.text(bola.range), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Criaturas es el Bestiario del Modo DM, pero sin nada de combate: el Códice
  // no tiene campaña a la que sumar.
  testWidgets('una criatura muestra el perfil del Modo DM y nada de combate', (
    tester,
  ) async {
    await pumpCodex(tester);
    final elemental = repo.creature('fire-elemental')!;

    await search(tester, elemental.name);
    await tester.tap(
      find.byKey(const ValueKey('codex-result-creatures-fire-elemental')),
    );
    await tester.pumpAndSettle();

    expect(find.text(elemental.traits.first.name), findsWidgets);
    expect(find.textContaining('Sumar al combate'), findsNothing);
    expect(find.textContaining('creá una campaña'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en un teléfono el detalle ocupa la pantalla y se vuelve', (
    tester,
  ) async {
    await pumpCodex(tester, size: const Size(390, 844));
    final duelo = repo.feat('fs-dueling')!;

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Dotes')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, duelo.name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex-feats-fs-dueling')));
    await tester.pumpAndSettle();

    expect(find.text('Volver al listado'), findsOneWidget);
    await tester.tap(find.text('Volver al listado'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codex-feats-fs-dueling')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
