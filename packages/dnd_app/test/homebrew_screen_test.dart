import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/homebrew/homebrew_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/sheet_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

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
    tester.view.physicalSize = const Size(1000, 1100);
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

  testWidgets('editar arma y armadura conserva peso, precio y bono mágico', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Weapon? savedWeapon;
    Armor? savedArmor;
    const weapon = Weapon(
      id: 'hb-arma-completa',
      name: 'Espada completa',
      source: ContentSource.homebrew,
      category: 'martial',
      damageDice: '1d8',
      damageType: 'slashing',
      weight: 3.5,
      costCp: 2750,
      magicBonus: 2,
    );
    const armor = Armor(
      id: 'hb-armadura-completa',
      name: 'Armadura completa',
      source: ContentSource.homebrew,
      category: 'medium',
      baseAc: 15,
      weight: 22.5,
      costCp: 4800,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                FilledButton(
                  onPressed: () async => savedWeapon = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WeaponForm(initial: weapon),
                    ),
                  ),
                  child: const Text('Editar arma'),
                ),
                FilledButton(
                  onPressed: () async => savedArmor = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArmorForm(initial: armor),
                    ),
                  ),
                  child: const Text('Editar armadura'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editar arma'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(savedWeapon?.weight, 3.5);
    expect(savedWeapon?.costCp, 2750);
    expect(savedWeapon?.magicBonus, 2);

    await tester.tap(find.text('Editar armadura'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(savedArmor?.weight, 22.5);
    expect(savedArmor?.costCp, 4800);
  });

  testWidgets(
    'un objeto homebrew guardado aparece en el buscador de la ficha',
    (tester) async {
      Future<void> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final localRepo = ContentRepository()..addAll(repo);
      final server = FakeApiServer();
      final api = ApiClient(client: server.client);
      final store = HomebrewStore(api);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomebrewScreen(repo: localRepo, store: store),
        ),
      );
      await settle();
      await tester.tap(find.text('Objetos'));
      await settle();
      await tester.tap(find.text('Agregar objeto'));
      await settle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Broche protector',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Bonificador a la Clase de Armadura',
        ),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await settle();

      final item = store.items.values.single;
      expect(localRepo.item(item.id), same(item));
      expect(item.effects, [isA<ArmorClassBonusEffect>()]);
      expect(server.homebrew['items']?[item.id], isNotNull);

      final controller = CharactersController(api);
      addTearDown(controller.dispose);
      final character = Character(
        id: 'buscadora',
        name: 'Buscadora',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {for (final ability in Ability.values) ability: 10},
        hpPerLevel: const [10],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: SheetScreen(
            character: character,
            repo: localRepo,
            controller: controller,
            theme: AppThemeController(),
          ),
        ),
      );
      await settle();
      await tester.tap(find.text('Inventario'));
      await settle();
      await tester.tap(find.text('Agregar objeto'));
      await settle();
      await tester.enterText(find.byType(TextField).last, 'Broche protector');
      await settle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Broche protector',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
