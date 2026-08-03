import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/backup_bundle.dart';
import 'package:dnd_app/data/data_recovery.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:dnd_app/data/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Almacén en memoria: evita tocar el sistema de archivos en tests.
class _FakeStore implements CharacterStore {
  final Map<String, Character> saved = {};
  @override
  final List<DataRecoveryIssue> recoveryIssues = [];
  @override
  final List<DataMigrationBackup> migrationBackups = [];
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

  Widget harness(CharactersController ctrl, {UpdateService? updates}) =>
      MaterialApp(
        theme: AppTheme.dark,
        home: DashboardScreen(
          repo: repo,
          controller: ctrl,
          homebrew: HomebrewStore(),
          updateService: updates,
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

  testWidgets('el panel lateral muestra la versión instalada', (tester) async {
    // Sale del mismo servicio que compara contra el último Release, así que el
    // rótulo no puede quedar desfasado del aviso de actualización.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ctrl = CharactersController(_FakeStore())..add(demoSagan());
    await tester.pumpWidget(
      harness(
        ctrl,
        updates: UpdateService(
          currentVersion: '1.2.3',
          // Sin red: la comprobación de actualizaciones falla y se ignora.
          client: MockClient((_) async => http.Response('', 500)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final version = find.byKey(const ValueKey('app-version'));
    expect(version, findsOneWidget);
    expect(tester.widget<Text>(version).data, 'v1.2.3');
    expect(tester.widget<Text>(version).style?.color, AppPalette.dark.gold);
    // Va debajo del cambio de tema, no encima.
    expect(
      tester.getTopLeft(version).dy,
      greaterThan(tester.getTopLeft(find.text('Cambiar tema')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin servicio de actualizaciones no se muestra versión', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1400, 900));
    expect(find.byKey(const ValueKey('app-version')), findsNothing);
  });

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

  testWidgets('muestra el estado real del guardado', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ctrl = CharactersController(_FakeStore())..add(demoSagan());

    await tester.pumpWidget(harness(ctrl));
    expect(find.text('Guardando…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Guardado'), findsOneWidget);
  });

  testWidgets('la vista previa explica colisiones y contenido completo', (
    tester,
  ) async {
    final bundle = BackupBundle(
      formatVersion: 2,
      scope: BackupScope.full,
      characters: [BundleCharacter(character: demoSagan())],
      homebrew: {
        'weapons': [
          {'id': 'hb-uno'},
          {'id': 'hb-dos'},
        ],
      },
      preferences: const {'imageProvider': 'pollinations'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ImportPreviewDialog(
            bundle: bundle,
            characterCollisions: 1,
            homebrewTotal: 2,
            homebrewCollisions: 1,
          ),
        ),
      ),
    );

    expect(find.text('Revisar importación'), findsOneWidget);
    expect(find.textContaining('Sagan "The Red"'), findsOneWidget);
    expect(find.textContaining('copias nuevas'), findsOneWidget);
    expect(find.text('Homebrew: 2 elemento(s).'), findsOneWidget);
    expect(find.textContaining('credenciales locales'), findsOneWidget);
    expect(find.text('Solo personajes'), findsOneWidget);
    expect(find.text('Restaurar todo'), findsOneWidget);
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

  testWidgets('dashboard sigue usable en una ventana mínima', (tester) async {
    await pumpDashboard(tester, const Size(480, 520));

    expect(find.text('Fichas D&D 5e'), findsOneWidget);
    expect(find.text('Sagan "The Red"'), findsOneWidget);
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

  testWidgets('una versión futura se informa sin afirmar que fue movida', (
    tester,
  ) async {
    final store = _FakeStore()
      ..recoveryIssues.add(
        const DataRecoveryIssue(
          originalPath: r'C:\datos\futuro.json',
          recoveryPath: r'C:\datos\futuro.json',
          error: 'La versión 3 es más nueva.',
        ),
      );

    await tester.pumpWidget(harness(CharactersController(store)));
    await tester.pumpAndSettle();

    expect(find.text('Datos que requieren atención'), findsOneWidget);
    expect(find.textContaining('No se modificaron'), findsOneWidget);
    expect(find.textContaining(r'C:\datos\futuro.json'), findsOneWidget);
  });

  testWidgets('confirma las migraciones automáticas y sus copias', (
    tester,
  ) async {
    final store = _FakeStore()
      ..migrationBackups.add(
        const DataMigrationBackup(
          originalPath: r'C:\datos\sagan.json',
          backupPath: r'C:\datos\recovery\migrations\sagan-v1.json',
          fromVersion: 1,
          toVersion: 2,
        ),
      );

    await tester.pumpWidget(harness(CharactersController(store)));
    await tester.pump();

    expect(find.textContaining('Se actualizaron 1 archivo'), findsOneWidget);
    expect(find.textContaining('recovery/migrations'), findsOneWidget);
  });
}
