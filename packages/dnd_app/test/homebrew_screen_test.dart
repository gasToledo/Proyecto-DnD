import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/homebrew/homebrew_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  testWidgets(
    'las siete categorías y el formulario de armas siguen accesibles',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomebrewScreen(repo: repo, store: HomebrewStore(ApiClient())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contenido homebrew'), findsOneWidget);
      expect(find.text('Agregar arma'), findsOneWidget);

      const categories = {
        'Armaduras': 'Agregar armadura',
        'Objetos': 'Agregar objeto',
        'Dotes': 'Agregar dote',
        'Razas': 'Agregar raza',
        'Trasfondos': 'Agregar trasfondo',
        'Conjuros': 'Agregar conjuro',
      };
      for (final entry in categories.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Armas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar arma'));
      await tester.pumpAndSettle();

      expect(find.text('Arma'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Dado de daño (p.ej. 1d8)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  /// Deja abierto el formulario de arma nueva.
  Future<void> openWeaponForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: HomebrewStore(ApiClient())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar arma'));
    await tester.pumpAndSettle();
  }

  // Antes, un dado ilegible se guardaba tal cual y una CA sin número se
  // reemplazaba por un 10 en silencio: la entrada inválida no puede
  // convertirse sola en otra cosa ni pasar de largo.
  testWidgets('un dado inválido frena el guardado y lo explica', (
    tester,
  ) async {
    await openWeaponForm(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Hoz');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dado de daño (p.ej. 1d8)'),
      'muchos',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Formato de dado inválido'), findsOneWidget);
    // No se guardó ni se navegó: seguimos en el formulario.
    expect(find.text('Arma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin nombre el guardado dice qué falta', (tester) async {
    await openWeaponForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribí el nombre del arma.'), findsOneWidget);
    expect(find.text('Arma'), findsOneWidget);
  });

  // Los ids internos (`simple`, `finesse`) son el contrato con el motor, pero
  // no tienen por qué estar a la vista de quien crea contenido.
  testWidgets('el formulario muestra etiquetas en español, no ids', (
    tester,
  ) async {
    await openWeaponForm(tester);

    expect(find.text('Marcial'), findsNothing, reason: 'está sin desplegar');
    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Sutil'), findsOneWidget);
    expect(find.text('finesse'), findsNothing);
    expect(find.text('two-handed'), findsNothing);
  });

  testWidgets('un objeto mundano no puede exigir sintonización', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: HomebrewStore(ApiClient())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Objetos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar objeto'));
    await tester.pumpAndSettle();

    final toggle = find.widgetWithText(
      SwitchListTile,
      'Requiere sintonización',
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    expect(
      find.text('Solo los objetos mágicos se sintonizan.'),
      findsOneWidget,
    );
  });

  testWidgets('borrar contenido homebrew pide confirmación', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = HomebrewStore(ApiClient())
      ..weapons['hb-hoz'] = const Weapon(
        id: 'hb-hoz',
        name: 'Hoz de guerra',
        source: ContentSource.homebrew,
        category: 'martial',
        damageDice: '1d8',
        damageType: 'slashing',
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar Hoz de guerra'));
    await tester.pumpAndSettle();

    // Sin deshacer y a un toque de distancia, borrar no puede ser inmediato.
    expect(find.text('¿Eliminar el arma «Hoz de guerra»?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.weapons.containsKey('hb-hoz'), isTrue);
    expect(find.text('Hoz de guerra'), findsOneWidget);
  });
}
