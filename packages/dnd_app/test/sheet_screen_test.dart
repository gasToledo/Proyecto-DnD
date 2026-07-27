import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/data_recovery.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/sheet_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements CharacterStore {
  final Map<String, Character> saved = {};

  @override
  final List<DataRecoveryIssue> recoveryIssues = [];
  @override
  final List<DataMigrationBackup> migrationBackups = [];

  @override
  Future<void> delete(String id) async => saved.remove(id);

  @override
  Future<String> directoryPath() async => '/memory';

  @override
  Future<List<Character>> loadAll() async => saved.values.toList();

  @override
  Future<void> save(Character character) async {
    saved[character.id] = character;
  }

  @override
  Future<void> saveAll(Iterable<Character> characters) async {
    for (final character in characters) {
      saved[character.id] = character;
    }
  }
}

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Future<CharactersController> pumpSheet(
    WidgetTester tester,
    Character character,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = CharactersController(_MemoryStore());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SheetScreen(
          character: character,
          repo: repo,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('las pestañas marciales conservan sus flujos principales', (
    tester,
  ) async {
    final character = demoSagan();
    final initialHp = character.combat.currentHp;
    await pumpSheet(tester, character);

    expect(find.text(character.name), findsOneWidget);
    expect(find.text('CARACTERÍSTICAS'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Combate'));
    await tester.pumpAndSettle();
    expect(find.text('Descanso corto'), findsOneWidget);
    expect(find.text('Descanso largo'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '2');
    await tester.tap(find.text('Daño'));
    await tester.pump();
    expect(character.combat.currentHp, initialHp - 2);

    await tester.tap(find.widgetWithText(Tab, 'Inventario'));
    await tester.pumpAndSettle();
    expect(find.text('ARMADURA EQUIPADA'), findsOneWidget);
    expect(find.text('ARMA EQUIPADA'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Notas'));
    await tester.pumpAndSettle();
    expect(find.text('NOTAS DEL PERSONAJE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un lanzador conserva la pestaña y datos de conjuros', (
    tester,
  ) async {
    final wizard = Character(
      id: 'wizard-sheet',
      name: 'Ilyra',
      raceId: 'human',
      classId: 'wizard',
      backgroundId: 'scribe',
      assignedScores: const {
        Ability.strength: 8,
        Ability.dexterity: 14,
        Ability.constitution: 13,
        Ability.intelligence: 16,
        Ability.wisdom: 12,
        Ability.charisma: 10,
      },
      cantripIds: const ['shocking-grasp'],
      spellIds: const ['detect-magic'],
      hpPerLevel: const [6],
    );
    await pumpSheet(tester, wizard);

    await tester.tap(find.widgetWithText(Tab, 'Conjuros'));
    await tester.pumpAndSettle();

    expect(find.text('LANZAMIENTO DE CONJUROS'), findsOneWidget);
    expect(find.text('ESPACIOS DE CONJURO'), findsOneWidget);
    expect(find.text('Agarre Electrizante'), findsOneWidget);
    expect(find.text('Detectar Magia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un personaje marcial muestra sus conjuros de linaje', (
    tester,
  ) async {
    final elf = Character(
      id: 'elf-sheet',
      name: 'Lethariel',
      raceId: 'elf',
      lineageId: 'elf-high',
      speciesSpellcastingAbility: Ability.wisdom,
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 12},
      hpPerLevel: const [10],
    );
    await pumpSheet(tester, elf);

    await tester.tap(find.widgetWithText(Tab, 'Conjuros'));
    await tester.pumpAndSettle();

    expect(find.text('CONJUROS DE ESPECIE Y LINAJE'), findsOneWidget);
    expect(find.text('Prestidigitación'), findsOneWidget);
    expect(find.textContaining('WIS'), findsOneWidget);
    expect(find.text('LANZAMIENTO DE CONJUROS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
