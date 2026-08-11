import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/demo/demo_characters.dart';
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

  Future<CharactersController> pumpSheet(
    WidgetTester tester,
    Character character, {
    Size size = const Size(900, 1400),
  }) async {
    // Alto de sobra a propósito. Con 700 la pestaña Personaje —que desde los
    // idiomas tiene cuatro tarjetas— dispara un fallo dentro de Flutter, en
    // `_RenderObjectSemantics._updateSemanticsNodeGeometry`: el binding de
    // test recorre el árbol de semántica en cada frame y ahí revienta un `!`
    // suyo. No es código nuestro y no se puede sortear desde acá.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = CharactersController(
      ApiClient(client: FakeApiServer().client),
    );
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

  testWidgets('plegar una tarjeta esconde su contenido y no el de las otras', (
    tester,
  ) async {
    // En el celular la tarjeta de Competencias es larguísima y empuja todo lo
    // demás fuera de la pantalla; plegarla tiene que sacar su contenido sin
    // llevarse puesto el de la tarjeta de al lado.
    final artificer = Character(
      id: 'collapse-sheet',
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

    expect(find.text('Armadura ligera'), findsOneWidget);
    expect(find.text('STR'), findsWidgets);

    await tester.tap(find.text('Competencias'));
    await tester.pumpAndSettle();

    expect(find.text('Armadura ligera'), findsNothing);
    // El título sigue, que es de lo que se trata: se pliega, no se esconde.
    expect(find.text('Competencias'), findsOneWidget);
    // Y plegar una no toca a las demás.
    expect(find.text('STR'), findsWidgets);

    await tester.tap(find.text('Competencias'));
    await tester.pumpAndSettle();

    expect(find.text('Armadura ligera'), findsOneWidget);
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

  group('Resolver advertencias sin recrear el personaje', () {
    // Un Humano/Guerrero/Soldado recién migrado deja pendientes las tres cosas
    // que la ficha sabe resolver —tamaño, estilo de combate y la herramienta
    // del trasfondo— más dos que no.
    Character legacySoldier() => Character(
      id: 'legacy-soldier',
      name: 'Veterano',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 12},
      hpPerLevel: const [10],
      // Con idiomas, aunque el personaje sea "viejo": estos tests son sobre
      // resolver otras advertencias, y sin ellos la tarjeta suma dos avisos
      // más que empujan los botones fuera de la vista.
      languages: const ['goblin', 'orc'],
    );

    /// El botón de la advertencia cuyo mensaje es [message]. Hay varias en
    /// pantalla, así que hay que anclar por su fila.
    Finder resolverDe(String message) => find.descendant(
      of: find.widgetWithText(ListTile, message),
      matching: find.widgetWithText(TextButton, 'Resolver'),
    );

    testWidgets('la herramienta del trasfondo', (tester) async {
      final character = legacySoldier();
      final controller = await pumpSheet(tester, character);

      final resolve = resolverDe('Soldado: elegiste 0 de 1.');
      await tester.ensureVisible(resolve);
      await tester.tap(resolve);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Juego de dados'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Soldado: elegiste 0 de 1.'), findsNothing);
      expect(controller.characters.single.id, character.id);
      expect(
        controller.characters.single.proficiencyChoices.values.single,
        contains('dice-set'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el tamaño, y la Identidad queda de acuerdo', (tester) async {
      final controller = await pumpSheet(tester, legacySoldier());

      final resolve = resolverDe(
        'Falta elegir el tamaño de Humano (Mediano, Pequeño).',
      );
      await tester.ensureVisible(resolve);
      await tester.tap(resolve);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pequeño'));
      await tester.pumpAndSettle();

      expect(controller.characters.single.chosenSize, 'Pequeño');
      expect(find.textContaining('Falta elegir el tamaño'), findsNothing);
      // La tarjeta Identidad leía el tamaño de la especie, no el elegido.
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Identidad'),
          matching: find.text('Pequeño'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el estilo de combate, conservando los grupos ajenos', (
      tester,
    ) async {
      // El grupo huérfano no se toca: el motor no lo limpia solo y borrarlo
      // sería perder una elección del jugador.
      final controller = await pumpSheet(
        tester,
        legacySoldier().copyWith(
          featureChoices: const {
            'grupo-viejo': ['algo'],
          },
        ),
      );

      final resolve = resolverDe('Estilo de Combate: elegiste 0 de 1.');
      await tester.ensureVisible(resolve);
      await tester.tap(resolve);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Defensa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final saved = controller.characters.single;
      expect(saved.featureChoices['fighting-style'], ['fs-defense']);
      expect(saved.featureChoices['grupo-viejo'], ['algo']);
      expect(find.text('Estilo de Combate: elegiste 0 de 1.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el linaje, y después la aptitud mágica que destapa', (
      tester,
    ) async {
      // Resolver el linaje puede hacer aparecer una advertencia nueva: el Elfo
      // Alto lanza conjuros y hay que elegirle la aptitud. Encadena solo.
      final controller = await pumpSheet(
        tester,
        Character(
          id: 'legacy-elf',
          name: 'Sin linaje',
          raceId: 'elf',
          classId: 'fighter',
          backgroundId: 'soldier',
          assignedScores: {for (final ability in Ability.values) ability: 12},
          hpPerLevel: const [10],
          languages: const ['goblin', 'orc'],
        ),
      );

      final resolveLinaje = resolverDe(
        'Falta elegir el linaje de Elfo '
        '(Alto Elfo, Elfo del Bosque, Elfo Oscuro (Drow)).',
      );
      await tester.ensureVisible(resolveLinaje);
      await tester.tap(resolveLinaje);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Alto Elfo'));
      await tester.pumpAndSettle();

      expect(controller.characters.single.lineageId, 'elf-high');

      final resolveAptitud = resolverDe(
        'Falta elegir la aptitud mágica del linaje (INT, SAB o CAR).',
      );
      await tester.ensureVisible(resolveAptitud);
      await tester.tap(resolveAptitud);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inteligencia'));
      await tester.pumpAndSettle();

      expect(
        controller.characters.single.speciesSpellcastingAbility,
        Ability.intelligence,
      );
      expect(find.textContaining('Falta elegir'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una advertencia sin editor no ofrece botón', (tester) async {
      await pumpSheet(tester, legacySoldier());

      expect(
        find.widgetWithText(ListTile, 'No hay arma equipada.'),
        findsOneWidget,
      );
      expect(resolverDe('No hay arma equipada.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lo pendiente se distingue de lo roto', (tester) async {
      await pumpSheet(tester, legacySoldier());

      // "No hay arma equipada" es info; "Elegiste 0 habilidades", advertencia.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'No hay arma equipada.'),
          matching: find.byIcon(Icons.info_outline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(
            ListTile,
            'Elegiste 0 habilidades pero corresponden 3.',
          ),
          matching: find.byIcon(Icons.warning_amber),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
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

  group('Compañeros invocados', () {
    /// La tarjeta de Compañeros va debajo de la de Ataques, así que sus
    /// controles caen fuera de la ventana del test. Se scrollea antes de tocar.
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Character artillerist({int level = 5}) => Character(
      id: 'artillero',
      name: 'Vex',
      raceId: 'human',
      classId: 'artificer',
      subclassId: 'artillerist',
      backgroundId: 'sage',
      level: level,
      assignedScores: const {
        Ability.strength: 10,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 18,
        Ability.wisdom: 10,
        Ability.charisma: 8,
      },
      hpPerLevel: List.filled(level, 5),
      combat: CombatState(currentHp: 30),
    );

    testWidgets('se invoca el cañón, se le pega y los PG quedan guardados', (
      tester,
    ) async {
      final character = artillerist();
      await pumpSheet(tester, character);
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.text('Compañeros'), findsOneWidget);
      expect(find.text('No hay ninguno invocado.'), findsOneWidget);

      await tapVisible(tester, find.text('Invocar'));
      await tester.pumpAndSettle();

      // PG 5 × nivel de Artífice, sin preguntar forma: el cañón es uno solo.
      expect(character.combat.companions, hasLength(1));
      expect(find.text('25 / 25 PG'), findsOneWidget);
      expect(find.text('CA 18'), findsOneWidget);

      final amounts = find.widgetWithText(TextField, 'Cantidad');
      await tester.enterText(amounts.last, '7');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Daño').last);
      await tester.pumpAndSettle();

      expect(character.combat.companions.single.currentHp, 18);
      expect(find.text('18 / 25 PG'), findsOneWidget);

      // El daño al compañero no toca los PG del personaje.
      expect(character.combat.currentHp, 30);
    });

    testWidgets('despedirlo lo saca de la ficha', (tester) async {
      final character = artillerist();
      await pumpSheet(tester, character);
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Invocar'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Despedir'));
      await tester.pumpAndSettle();

      expect(character.combat.companions, isEmpty);
      expect(find.text('No hay ninguno invocado.'), findsOneWidget);

      // Invocar deja un SnackBar con su temporizador; sin agotarlo el binding
      // falla al desmontar el árbol.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el descanso largo devuelve al cañón a sus PG máximos', (
      tester,
    ) async {
      final character = artillerist();
      await pumpSheet(tester, character);
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Invocar'));
      await tester.pumpAndSettle();

      final amounts = find.widgetWithText(TextField, 'Cantidad');
      await tester.enterText(amounts.last, '10');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Daño').last);
      await tester.pumpAndSettle();
      expect(character.combat.companions.single.currentHp, 15);

      await tapVisible(tester, find.text('Descanso largo'));
      await tester.pumpAndSettle();
      expect(character.combat.companions.single.currentHp, 25);
    });

    testWidgets('un Guerrero no ve la tarjeta', (tester) async {
      await pumpSheet(tester, demoSagan());
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.text('Compañeros'), findsNothing);
    });

    testWidgets('la pestaña Combate no desborda en un teléfono angosto', (
      tester,
    ) async {
      // La cabecera con el nombre y las filas de recursos se pasaban de ancho a
      // 360px. No es cosa de los compañeros, pero es la pantalla donde viven.
      await pumpSheet(tester, demoSagan(), size: const Size(360, 1600));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el selector de las 24 formas entra en un teléfono angosto', (
      tester,
    ) async {
      final wizard = Character(
        id: 'maga-familiar',
        name: 'Ilyra',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'scribe',
        assignedScores: {for (final a in Ability.values) a: 12},
        spellIds: const ['find-familiar'],
        hpPerLevel: const [6],
      );
      await pumpSheet(tester, wizard, size: const Size(360, 1600));

      // Por debajo de 900 la navegación de la ficha vive en un Drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      // La tarjeta de Conjuros se pasa de ancho a 360px por su cuenta, desde
      // antes de los compañeros. Se descarta acá para que este caso hable del
      // diálogo y no herede un desborde ajeno; el del guerrero, más arriba,
      // cubre la parte de la pantalla que sí arreglamos.
      tester.takeException();
      await tapVisible(tester, find.text('Invocar'));

      // El diálogo abre con las formas y sin desbordar: un RenderFlex que se
      // pasa de ancho deja la excepción acá.
      expect(find.text('Elegí la forma'), findsOneWidget);
      expect(find.text('Murciélago'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Murciélago'));
      await tester.pumpAndSettle();
      expect(wizard.combat.companions.single.creatureId, 'bat');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
