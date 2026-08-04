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
          onToggleTheme: () {},
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

    expect(find.text(character.name), findsWidgets);
    expect(find.text('Características'), findsOneWidget);

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();
    expect(find.text('Descanso corto'), findsOneWidget);
    expect(find.text('Descanso largo'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '2');
    await tester.tap(find.text('Daño'));
    await tester.pump();
    expect(character.combat.currentHp, initialHp - 2);

    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    expect(find.text('ARMADURA EQUIPADA'), findsOneWidget);
    expect(find.text('ARMAS EQUIPADAS'), findsOneWidget);

    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();
    expect(find.text('Notas del personaje'), findsOneWidget);
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

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    expect(find.text('Conjuros'), findsOneWidget);
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

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    // El rótulo dejó de nombrar a la especie: desde las invocaciones del Brujo
    // también los concede una elección abierta.
    expect(find.text('CONJUROS DE RASGOS'), findsOneWidget);
    expect(find.text('Prestidigitación'), findsOneWidget);
    expect(find.textContaining('WIS'), findsOneWidget);
    expect(find.text('ESPACIOS DE CONJURO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las competencias se muestran en español', (tester) async {
    // La tarjeta se armaba capitalizando el id en inglés, así que un Alquimista
    // leía "Alchemists Supplies", "Light" y "Simple".
    final artificer = Character(
      id: 'artificer-sheet',
      name: 'Merrix',
      raceId: 'warforged',
      classId: 'artificer',
      subclassId: 'alchemist',
      backgroundId: 'artisan',
      level: 3,
      assignedScores: {for (final ability in Ability.values) ability: 12},
      hpPerLevel: const [8, 5, 5],
    );
    await pumpSheet(tester, artificer);

    expect(find.text('Competencias'), findsOneWidget);
    expect(find.text('Suministros de alquimista'), findsOneWidget);
    expect(find.text('Herramientas de ladrón'), findsOneWidget);
    expect(find.text('Herramientas de manitas'), findsOneWidget);
    expect(find.text('Armadura ligera'), findsOneWidget);
    expect(find.text('Armas simples'), findsOneWidget);
    expect(find.textContaining('Supplies'), findsNothing);
    expect(find.text('Light'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los conjuros siempre preparados de subclase llegan a la ficha', (
    tester,
  ) async {
    // Antes vivían solo como texto en la descripción del rasgo: el jugador los
    // tenía por regla y la ficha no los mostraba ni los dejaba lanzar.
    final artillerist = Character(
      id: 'artillerist-sheet',
      name: 'Zil',
      raceId: 'gnome',
      lineageId: 'gnome-rock',
      classId: 'artificer',
      subclassId: 'artillerist',
      backgroundId: 'artisan',
      level: 5,
      spellIds: const ['cure-wounds'],
      assignedScores: {for (final ability in Ability.values) ability: 14},
      hpPerLevel: const [8, 5, 5, 5, 5],
    );
    await pumpSheet(tester, artillerist);

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    expect(find.text('SIEMPRE PREPARADOS'), findsOneWidget);
    // Nivel 3 de la tabla del Artillero, más los de nivel 5.
    expect(find.text('Escudo'), findsOneWidget);
    expect(find.text('Ola Atronadora'), findsOneWidget);
    expect(find.text('Rayo Abrasador'), findsOneWidget);
    // Y el elegido a mano sigue en su propia sección.
    expect(find.text('CONJUROS PREPARADOS'), findsOneWidget);
    expect(find.text('Curar Heridas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un Paladín de Entrega ve sus Conjuros de Juramento', (
    tester,
  ) async {
    // El caso que más gente juega de las 19 subclases del PHB que ganaron su
    // tabla: hasta ahora los dos conjuros de nivel 3 eran texto en el rasgo.
    final paladin = Character(
      id: 'paladin-sheet',
      name: 'Aurelia',
      raceId: 'human',
      classId: 'paladin',
      subclassId: 'oath-devotion',
      backgroundId: 'soldier',
      level: 5,
      assignedScores: {for (final ability in Ability.values) ability: 14},
      hpPerLevel: const [10, 6, 6, 6, 6],
    );
    await pumpSheet(tester, paladin);

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    expect(find.text('SIEMPRE PREPARADOS'), findsOneWidget);
    expect(find.text('Escudo de Fe'), findsOneWidget);
    expect(find.text('Protección contra el Bien y el Mal'), findsOneWidget);
    // Nivel 5 del juramento.
    expect(find.text('Zona de la Verdad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resistencias y daño se muestran en español', (tester) async {
    // Un Dracónido rojo: la resistencia sale de su linaje dracónico y antes
    // se imprimía con la clave interna en inglés ("Fire").
    final dragonborn = Character(
      id: 'dragonborn-sheet',
      name: 'Vharax',
      raceId: 'dragonborn',
      lineageId: 'dragonborn-red',
      classId: 'fighter',
      backgroundId: 'soldier',
      equippedWeaponIds: const ['longsword'],
      assignedScores: {for (final ability in Ability.values) ability: 12},
      hpPerLevel: const [10],
    );
    await pumpSheet(tester, dragonborn);

    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    expect(find.text('Resistencias: Fuego'), findsOneWidget);
    expect(find.textContaining('Fire'), findsNothing);
    // Y el tipo de daño del arma, que compartía el mismo defecto.
    expect(find.textContaining('Cortante'), findsWidgets);
    expect(find.textContaining('Slashing'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resuelve herramientas pendientes sin recrear el personaje', (
    tester,
  ) async {
    final character = Character(
      id: 'legacy-soldier',
      name: 'Veterano',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 12},
      hpPerLevel: const [10],
    );
    final controller = await pumpSheet(tester, character);

    expect(find.text('Elecciones de competencia pendientes'), findsOneWidget);
    final resolve = find.widgetWithText(FilledButton, 'Resolver');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Juego de dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Elecciones de competencia pendientes'), findsNothing);
    expect(controller.characters.single.id, character.id);
    expect(
      controller.characters.single.proficiencyChoices.values.single,
      contains('dice-set'),
    );
    expect(tester.takeException(), isNull);
  });

  group('Combate con dos armas desde la ficha', () {
    Character dualWielder() => Character(
      id: 'dual-sheet',
      name: 'Ambidiestra',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      equippedWeaponIds: const ['dagger', 'shortsword'],
      assignedScores: {for (final ability in Ability.values) ability: 14},
      hpPerLevel: const [10],
    );

    testWidgets('marcar la mano secundaria cambia el ataque de la ficha', (
      tester,
    ) async {
      await pumpSheet(tester, dualWielder());

      // Antes de marcar nada, las dos armas suman el modificador al daño.
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1d4 + 2'), findsOneWidget);
      expect(find.text('Mano secundaria'), findsNothing);
      expect(find.text('Acción adicional'), findsNothing);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      final offHand = find.byKey(const ValueKey('off-hand-dagger'));
      await tester.ensureVisible(offHand);
      await tester.pumpAndSettle();
      await tester.tap(offHand);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(offHand).selected, isTrue);

      // La ficha refleja la regla sin que la UI la calcule: el daño pierde el
      // modificador y el ataque pasa a ser acción adicional.
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1d4 + 2'), findsNothing);
      expect(find.text('Mano secundaria'), findsOneWidget);
      expect(find.text('Acción adicional'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el arma versátil por fin se puede empuñar a dos manos', (
      tester,
    ) async {
      // El daño versátil estaba implementado en el motor desde siempre, pero
      // no había ninguna UI que activara `weaponTwoHanded`.
      final character = Character(
        id: 'versatile-sheet',
        name: 'Versátil',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        equippedWeaponIds: const ['longsword'],
        assignedScores: {for (final ability in Ability.values) ability: 14},
        hpPerLevel: const [10],
      );
      await pumpSheet(tester, character);

      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1d8 + 2'), findsOneWidget);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      final twoHanded = find.byKey(const ValueKey('two-handed-longsword'));
      await tester.ensureVisible(twoHanded);
      await tester.pumpAndSettle();
      await tester.tap(twoHanded);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1d10 + 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el arma no Ligera no ofrece mandarla a la secundaria', (
      tester,
    ) async {
      await pumpSheet(tester, dualWielder());
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('off-hand-dagger')), findsOneWidget);
      expect(find.byKey(const ValueKey('off-hand-longsword')), findsNothing);
      // Y el aviso viejo de que la regla no se aplicaba sola ya no está.
      expect(find.textContaining('todavía no se aplica'), findsNothing);
    });
  });
}
