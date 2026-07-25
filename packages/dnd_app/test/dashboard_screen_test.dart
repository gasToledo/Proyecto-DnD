import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/data_recovery.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén en memoria: evita tocar el sistema de archivos en tests.
class _FakeStore implements CharacterStore {
  final Map<String, Character> saved = {};
  @override
  final List<DataRecoveryIssue> recoveryIssues = [];
  @override
  Future<List<Character>> loadAll() async => saved.values.toList();
  @override
  Future<void> save(Character c) async => saved[c.id] = c;
  @override
  Future<void> saveAll(Iterable<Character> characters) async {
    for (final character in characters) {
      saved[character.id] = character;
    }
  }

  @override
  Future<void> delete(String id) async => saved.remove(id);
  @override
  Future<String> directoryPath() async => '/fake';
}

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Widget harness(CharactersController ctrl) => MaterialApp(
    theme: AppTheme.dark,
    home: DashboardScreen(
      repo: repo,
      controller: ctrl,
      homebrew: HomebrewStore(),
      onToggleTheme: () {},
    ),
  );

  /// Monta el dashboard con un roster de prueba en un viewport dado y deja
  /// vencer el debounce de guardado (400 ms) para no dejar timers pendientes.
  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ctrl = CharactersController(_FakeStore())..add(demoSagan());
    await tester.pumpWidget(harness(ctrl));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('layout ancho: panel lateral + tarjeta con datos de combate', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1280, 800));

    // Panel lateral presente con sus secciones.
    expect(find.text('Personajes'), findsOneWidget);
    expect(find.text('Homebrew'), findsOneWidget);
    expect(find.text('Importar / Exportar'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);

    // La tarjeta muestra los datos que antes obligaban a abrir la ficha.
    expect(find.text('Sagan "The Red"'), findsOneWidget);
    expect(find.text('PG'), findsOneWidget);
    expect(find.text('VEL'), findsOneWidget);
    expect(find.text('INIC'), findsOneWidget);
    // Sin overflow: un RenderFlex desbordado dispararía una excepción acá.
    expect(tester.takeException(), isNull);
  });

  testWidgets('el buscador filtra el roster', (tester) async {
    await pumpDashboard(tester, const Size(1280, 800));

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Sagan "The Red"'), findsNothing);
    expect(
      find.text('Ningún personaje coincide con la búsqueda.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'sagan');
    await tester.pumpAndSettle();
    expect(find.text('Sagan "The Red"'), findsOneWidget);
  });

  testWidgets('layout angosto: el panel se colapsa a Drawer', (tester) async {
    await pumpDashboard(tester, const Size(700, 800));

    // El panel no está fijo, pero sí accesible por el Drawer del AppBar.
    expect(find.text('Homebrew'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Homebrew'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa dónde quedó un archivo apartado para recuperación', (
    tester,
  ) async {
    final store = _FakeStore()
      ..recoveryIssues.add(
        const DataRecoveryIssue(
          originalPath: r'C:\datos\roto.json',
          recoveryPath: r'C:\datos\recovery\roto.json',
          error: 'JSON inválido',
        ),
      );
    final ctrl = CharactersController(store);

    await tester.pumpWidget(harness(ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Archivos apartados para recuperación'), findsOneWidget);
    expect(find.textContaining(r'C:\datos\recovery\roto.json'), findsOneWidget);
  });
}
