import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/sheet_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

/// Si el `IconButton` con ese tooltip está deshabilitado.
///
/// Por predicado y no con `find.byTooltip`: eso encuentra el `Tooltip` que el
/// propio IconButton arma por dentro, y lo que hay que mirar es el `onPressed`
/// del botón.
bool _botonDeshabilitado(WidgetTester tester, String tooltip) {
  final boton = tester.widget<IconButton>(
    find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip),
  );
  return boton.onPressed == null;
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
    Character character, {
    Size size = const Size(900, 1400),
    // Solo lo pasa la pestaña Campaña, que es lo único de la ficha que lee del
    // servidor además del turno. El resto se conforma con un doble vacío.
    FakeApiServer? server,
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
      ApiClient(client: (server ?? FakeApiServer()).client),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SheetScreen(
          character: character,
          repo: repo,
          controller: controller,
          theme: AppThemeController(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Abre el menú contextual de una fila del inventario.
  Future<void> openItemMenu(WidgetTester tester, String itemId) async {
    final menu = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('menu-') &&
          (widget.key! as ValueKey<String>).value.endsWith('-$itemId'),
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  Future<void> closeItemMenu(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  /// Abre el menú de una fila y elige una acción por su etiqueta.
  Future<void> tapItemAction(
    WidgetTester tester,
    String itemId,
    String action,
  ) async {
    await openItemMenu(tester, itemId);
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('Lanzamiento de la Marca se ve y vuelve con el descanso corto', (
    tester,
  ) async {
    // Es el primer recurso del catálogo que declara una **dote** y no una
    // clase, así que lo que se comprueba acá no es el rasgo sino que la ficha
    // no filtre los recursos por su origen.
    final marcado = Character(
      id: 'marcado',
      name: 'Sivis',
      raceId: 'human',
      classId: 'wizard',
      backgroundId: 'sage',
      level: 8,
      assignedScores: {for (final a in Ability.values) a: 14},
      hpPerLevel: List.filled(8, 4),
      featIds: const ['mark-of-scribing', 'potent-dragonmark'],
      combat: CombatState(
        currentHp: 40,
        // Sin `const`: `CombatState` se queda con este mapa y el descanso lo
        // muta, así que un literal constante revienta.
        resourceUsage: {'potent_dragonmark_slot': 1},
      ),
    );
    await pumpSheet(tester, marcado, size: const Size(900, 6000));
    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    expect(find.text('Lanzamiento de la Marca'), findsWidgets);

    await tester.tap(find.text('Descanso corto'));
    await tester.pumpAndSettle();

    // Recarga corta: el descanso corto lo devuelve entero, que es la mitad de
    // la regla que un `passiveTrait` no podía hacer cumplir.
    expect(marcado.combat.resourceUsage['potent_dragonmark_slot'], 0);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('MONEDAS'), findsOneWidget);
    expect(find.text('CARGA'), findsOneWidget);
    expect(find.text('SINTONIZACIÓN'), findsOneWidget);
    // Los cupos libres se ven vacíos, no contados: «0 / 3» no decía con qué.
    expect(find.text('Cupo libre'), findsNWidgets(attunementSlots));
    // La ficha de demostración se arma en código y no toca `inventory`, así
    // que su arma y su armadura equipadas llegan a la lista por derivación.
    final sword = character.inventory.firstWhere(
      (entry) => entry.itemId == 'longsword',
    );
    final leather = character.inventory.firstWhere(
      (entry) => entry.itemId == 'leather',
    );
    expect(find.byKey(ValueKey('inv-${sword.entryId}')), findsOneWidget);
    expect(find.byKey(ValueKey('inv-${leather.entryId}')), findsOneWidget);

    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();
    expect(find.text('Notas del personaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Inventario', () {
    Character mochilera() => Character(
      id: 'mochilera',
      name: 'Mochilera',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 10},
      hpPerLevel: const [10],
    );

    // Editar el inventario produce un `Character` nuevo vía `copyWith`, así
    // que lo guardado hay que leerlo del controlador y no del objeto original.
    Character saved(CharactersController controller) =>
        controller.characters.firstWhere((c) => c.id == 'mochilera');

    testWidgets('un cupo de arma contextual se gestiona sin lógica de clase', (
      tester,
    ) async {
      final warlock = Character(
        id: 'mochilera',
        name: 'Bruja del Filo',
        raceId: 'human',
        classId: 'warlock',
        backgroundId: 'sage',
        assignedScores: const {
          Ability.strength: 8,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 10,
          Ability.charisma: 18,
        },
        hpPerLevel: const [8],
        featureChoices: const {
          'warlock-invocation': ['pact-of-the-blade'],
        },
      );
      final controller = await pumpSheet(tester, warlock);
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(find.text('Arma de pacto (0/1)'), findsOneWidget);
      await tester.tap(find.text('Arma de pacto (0/1)'));
      await tester.pumpAndSettle();

      final rapier = find.byKey(
        const ValueKey('target-create-pact-weapon-rapier'),
      );
      await tester.ensureVisible(rapier);
      await tester.tap(rapier);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      final stored = saved(controller);
      final generated = stored.inventory.singleWhere(
        (entry) => entry.origin == 'effect-target:pact-weapon',
      );
      expect(generated.itemId, 'rapier');
      expect(generated.equipped, isTrue);
      expect(stored.effectTargets['pact-weapon'], [generated.entryId]);
      expect(find.text('Arma de pacto (1/1)'), findsOneWidget);
      expect(find.text('Arma de pacto'), findsOneWidget);

      final attack = CharacterCompiler(repo).compile(stored).attacks.single;
      expect(attack.proficient, isTrue);
      expect(attack.abilityUsed, Ability.charisma);
    });

    testWidgets('agregar y equipar una armadura mueve la CA y la carga', (
      tester,
    ) async {
      final controller = await pumpSheet(tester, mochilera());
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(find.text('La mochila está vacía.'), findsOneWidget);
      expect(find.text('0 / 150 lb'), findsOneWidget);

      await tester.tap(find.text('Agregar objeto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Armadura de placas');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-plate')));
      await tester.pumpAndSettle();

      // El diálogo no se cierra al agregar: se cargan varias compras seguidas.
      expect(find.text('1 objeto agregado a la mochila.'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      // Aparece una sola vez: la línea guardada no se duplica con la derivada.
      expect(find.text('Armadura de placas'), findsOneWidget);
      expect(find.text('65 / 150 lb'), findsOneWidget);
      expect(saved(controller).inventory.single.itemId, 'plate');

      final equip = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('equip-') &&
            (widget.key! as ValueKey<String>).value.endsWith('-plate'),
      );
      await tester.ensureVisible(equip);
      await tester.tap(equip);
      await tester.pumpAndSettle();

      expect(saved(controller).equippedArmorId, 'plate');
      expect(CharacterCompiler(repo).compile(saved(controller)).armorClass, 18);
    });

    testWidgets('cargar monedas suma a la carga: 50 hacen una libra', (
      tester,
    ) async {
      final controller = await pumpSheet(tester, mochilera());
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('coin-gp')), '100');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // El guardado va con rebote de 400 ms; sin dejarlo correr, el temporizador
      // sigue vivo cuando el árbol se desmonta y el binding lo marca como error.
      await tester.pump(const Duration(milliseconds: 500));

      expect(saved(controller).coins, {'gp': 100});
      expect(find.text('2 / 150 lb'), findsOneWidget);
    });

    testWidgets('la nota queda escrita en la línea del objeto', (tester) async {
      final controller = await pumpSheet(
        tester,
        mochilera().copyWith(inventory: const [InventoryEntry(itemId: 'book')]),
      );
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      await tapItemAction(tester, 'book', 'Nota…');
      await tester.enterText(
        find.byType(TextField).last,
        'La carta del alcalde va entre las páginas.',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        saved(controller).inventory.single.note,
        'La carta del alcalde va entre las páginas.',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('note-') &&
              (widget.key! as ValueKey<String>).value.endsWith('-book'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la munición aclara el tamaño del paquete', (tester) async {
      await pumpSheet(
        tester,
        mochilera().copyWith(
          inventory: const [InventoryEntry(itemId: 'arrows')],
        ),
      );
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(find.text('Munición · paquete de 20'), findsOneWidget);
      await tapItemAction(tester, 'arrows', 'Cantidad exacta…');
      expect(find.widgetWithText(TextField, 'Paquetes de 20'), findsOneWidget);
    });

    testWidgets('el − y el + de la fila cambian la cantidad sin abrir nada', (
      tester,
    ) async {
      final controller = await pumpSheet(
        tester,
        mochilera().copyWith(
          inventory: const [InventoryEntry(itemId: 'arrows')],
        ),
      );
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      // Por la fila y no por el ícono suelto: «Agregar objeto» también es un +.
      final row = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('inv-') &&
            (widget.key! as ValueKey<String>).value.endsWith('-arrows'),
      );
      Finder step(IconData icon) =>
          find.descendant(of: row, matching: find.byIcon(icon));

      await tester.tap(step(Icons.add));
      await tester.pumpAndSettle();
      expect(saved(controller).inventory.single.quantity, 2);

      await tester.tap(step(Icons.remove));
      await tester.pumpAndSettle();
      expect(saved(controller).inventory.single.quantity, 1);

      // En 1 el − se apaga: bajar a cero es quitar la línea, y eso está en el
      // menú.
      final minus = tester.widget<OutlinedButton>(
        find.ancestor(
          of: step(Icons.remove),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('el buscador y los filtros achican el listado', (tester) async {
      await pumpSheet(
        tester,
        mochilera().copyWith(
          inventory: const [
            InventoryEntry(itemId: 'plate'),
            InventoryEntry(itemId: 'arrows'),
          ],
        ),
      );
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      // Las familias se agrupan con el mismo nombre que calcula el catálogo.
      expect(find.text('ARMADURAS'), findsOneWidget);
      expect(find.text('MUNICIÓN'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en la mochila…'),
        'flech',
      );
      await tester.pumpAndSettle();
      expect(find.text('Armadura de placas'), findsNothing);
      expect(find.text('ARMADURAS'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en la mochila…'),
        'nada de esto existe',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Ningún objeto coincide con ese filtro.'),
        findsOneWidget,
      );
    });

    testWidgets('en un teléfono angosto las filas no fuerzan scroll lateral', (
      tester,
    ) async {
      final character = mochilera().copyWith(
        inventory: const [
          InventoryEntry(itemId: 'dungeoneers-pack'),
          InventoryEntry(itemId: 'case-map-or-scroll'),
          InventoryEntry(itemId: 'plate'),
        ],
      );
      await pumpSheet(tester, character, size: const Size(360, 1400));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      // En compacto no hay encabezados de tabla: cada fila es una tarjeta.
      expect(find.text('OBJETO'), findsNothing);
      expect(find.text('Paquete de explorador de mazmorras'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

  // Lo que la pestaña Personaje decidió mostrar y dónde. Son decisiones de
  // presentación, pero cada una nació de un malentendido concreto en la mesa:
  // la puntuación leída como el número que se tira, la percepción pasiva
  // confundida con una cifra de combate, la Pericia invisible.
  group('Personaje · jerarquía de la pestaña', () {
    /// Pícaro enano: enano trae visión en la oscuridad y el Pícaro concede
    /// Pericia a nivel 1, que son las dos cosas que esta tanda mira.
    Character rogue() => Character(
      id: 'rogue-sheet',
      name: 'Dain',
      raceId: 'dwarf',
      classId: 'rogue',
      backgroundId: 'criminal',
      level: 1,
      assignedScores: const {
        Ability.strength: 8,
        Ability.dexterity: 15,
        Ability.constitution: 14,
        Ability.intelligence: 13,
        Ability.wisdom: 12,
        Ability.charisma: 10,
      },
      chosenSkills: const ['stealth', 'perception', 'acrobatics', 'insight'],
      proficiencyChoices: const {
        'class:rogue:expertise-1': ['stealth', 'perception'],
      },
      hpPerLevel: const [8],
    );

    testWidgets('la banda táctica se queda con las cinco cifras de combate', (
      tester,
    ) async {
      await pumpSheet(tester, rogue());

      for (final label in [
        'ARMADURA',
        'PUNTOS DE GOLPE',
        'INICIATIVA',
        'VELOCIDAD',
        'COMPETENCIA',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'falta $label');
      }
      // Tamaño ya vive en Identidad, y los sentidos en su propia tarjeta:
      // repetirlos acá era lo que empujaba la banda a un segundo renglón.
      expect(find.text('TAMAÑO'), findsNothing);
      expect(find.text('PERC. PASIVA'), findsNothing);
      expect(find.text('VISIÓN OSC.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los sentidos tienen tarjeta propia', (tester) async {
      final character = rogue();
      final s = CharacterCompiler(repo).compile(character);
      expect(
        s.darkvision,
        isNotNull,
        reason: 'el enano tiene que traer visión en la oscuridad',
      );
      await pumpSheet(tester, character);

      expect(find.text('Sentidos'), findsOneWidget);
      expect(find.text('Percepción pasiva'), findsOneWidget);
      expect(find.text('Visión en la oscuridad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la plaqueta pone grande el modificador, no la puntuación', (
      tester,
    ) async {
      await pumpSheet(tester, rogue());

      // DEX 15 → +2. El +2 es el número que se tira; la puntuación queda como
      // dato de apoyo y por eso viaja rotulada.
      expect(find.text('Punt. 15'), findsOneWidget);
      // El Pícaro es competente en salvaciones de Destreza e Inteligencia, y
      // ahora eso se nombra en vez de insinuarse con un punto sin rótulo.
      expect(find.text('SALV'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la Pericia se nombra y no queda solo en el anillo', (
      tester,
    ) async {
      final character = rogue();
      expect(
        CharacterCompiler(repo).compile(character).expertiseSkills,
        containsAll(<String>['stealth', 'perception']),
      );
      await pumpSheet(tester, character);

      expect(find.text('PERICIA'), findsNWidgets(2));
      expect(find.text('Competente'), findsOneWidget);
      expect(find.text('Pericia · bonificador duplicado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

    // La cabecera de Competencias queda por debajo del pliegue: hay que
    // traerla a la vista antes de tocarla o el toque no le llega.
    Future<void> toggleCompetencias() async {
      await tester.ensureVisible(find.text('Competencias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();
    }

    await toggleCompetencias();

    expect(find.text('Armadura ligera'), findsNothing);
    // El título sigue, que es de lo que se trata: se pliega, no se esconde.
    expect(find.text('Competencias'), findsOneWidget);
    // Y plegar una no toca a las demás.
    expect(find.text('STR'), findsWidgets);

    await toggleCompetencias();

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

    testWidgets('la habilidad de Conocimiento Primigenio', (tester) async {
      // Un Bárbaro de nivel 3 guardado **antes** de que el rasgo declarara su
      // elección: nunca eligió, y el asistente de subida de nivel no se la va a
      // volver a ofrecer. La ficha es su único camino, igual que para los otros
      // nueve cupos de competencia lisa que el catálogo concede a nivel 3.
      final controller = await pumpSheet(
        tester,
        Character(
          id: 'legacy-barbarian',
          name: 'Furiosa',
          raceId: 'human',
          classId: 'barbarian',
          backgroundId: 'soldier',
          level: 3,
          assignedScores: {for (final ability in Ability.values) ability: 12},
          hpPerLevel: const [12, 7, 7],
          languages: const ['goblin', 'orc'],
        ),
      );

      final resolve = resolverDe('Conocimiento Primigenio: elegiste 0 de 1.');
      await tester.ensureVisible(resolve);
      await tester.tap(resolve);
      await tester.pumpAndSettle();

      // El pozo son las seis de la lista del Bárbaro, no las dieciocho.
      expect(find.widgetWithText(FilterChip, 'Naturaleza'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Arcanos'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Naturaleza'));
      await tester.pumpAndSettle();
      // El diálogo resuelve todos los cupos de una y «Guardar» exige tenerlos
      // completos, así que la herramienta del Soldado va en el mismo viaje.
      await tester.tap(find.widgetWithText(FilterChip, 'Juego de dados'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Conocimiento Primigenio: elegiste 0 de 1.'),
        findsNothing,
      );
      expect(
        controller
            .characters
            .single
            .proficiencyChoices['class:barbarian:primal-knowledge'],
        contains('nature'),
      );
      expect(tester.takeException(), isNull);
    });

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
      await tapItemAction(tester, 'dagger', 'Mano secundaria');

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
      await tapItemAction(tester, 'longsword', 'A dos manos');

      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1d10 + 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el arma no Ligera no ofrece mandarla a la secundaria', (
      tester,
    ) async {
      // La daga es Ligera y el espadón no; el espadón tampoco es versátil, así
      // que su menú no tiene que ofrecer ninguna de las dos empuñaduras.
      await pumpSheet(
        tester,
        dualWielder().copyWith(
          equippedWeaponIds: const ['dagger', 'greatsword'],
        ),
      );
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      await openItemMenu(tester, 'dagger');
      expect(find.text('Mano secundaria'), findsOneWidget);
      await closeItemMenu(tester);

      await openItemMenu(tester, 'greatsword');
      expect(find.text('Mano secundaria'), findsNothing);
      expect(find.text('A dos manos'), findsNothing);
      await closeItemMenu(tester);
    });

    testWidgets('la Lanza de caballería avisa que montado no exige dos manos', (
      tester,
    ) async {
      final character = Character(
        id: 'lancero',
        name: 'Lancero',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        equippedWeaponIds: const ['lance', 'greatsword'],
        assignedScores: {for (final ability in Ability.values) ability: 14},
        hpPerLevel: const [10],
      );
      await pumpSheet(tester, character);
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('exige dos manos salvo montado'),
        findsOneWidget,
      );
      // El espadón sigue siendo incondicional.
      expect(find.text('Arma · exige dos manos'), findsOneWidget);
    });
  });

  group('Orden Divina', () {
    Character clerigo({Map<String, List<String>> choices = const {}}) =>
        Character(
          id: 'clerigo',
          name: 'Sacerdote',
          raceId: 'human',
          classId: 'cleric',
          backgroundId: 'acolyte',
          level: 1,
          assignedScores: const {
            Ability.strength: 10,
            Ability.dexterity: 12,
            Ability.constitution: 14,
            Ability.intelligence: 10,
            Ability.wisdom: 16,
            Ability.charisma: 10,
          },
          hpPerLevel: const [8],
          featureChoices: choices,
        );

    testWidgets('una ficha vieja sin elegir avisa, no inventa una opción', (
      tester,
    ) async {
      await pumpSheet(tester, clerigo());
      expect(find.textContaining('Orden Divina'), findsWidgets);
      // Sin elegir, no se regaló ninguna de las dos opciones.
      final sheet = CharacterCompiler(repo).compile(clerigo());
      expect(sheet.armorProficiencies, isNot(contains('heavy')));
      expect(sheet.skillBonuses, isEmpty);
    });

    testWidgets('Taumaturgo muestra el aporte en el desglose de Inteligencia', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        clerigo(
          choices: const {
            'divine-order': ['divine-order-thaumaturge'],
          },
        ),
      );
      await tester.tap(find.text('Personaje'));
      await tester.pumpAndSettle();

      final int = find.text('INT');
      await tester.ensureVisible(int.first);
      await tester.tap(int.first);
      await tester.pumpAndSettle();

      // El total no alcanza: el desglose tiene que decir de dónde salen los +3.
      expect(
        find.textContaining('incluye +3 de Orden Divina: Taumaturgo'),
        findsWidgets,
      );
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
      // Sin nada invocado el campo no manda a nada, así que no está.
      expect(find.widgetWithText(TextField, 'Cantidad de PG'), findsNothing);

      await tapVisible(tester, find.text('Invocar'));
      await tester.pumpAndSettle();

      // PG 5 × nivel de Artífice, sin preguntar forma: el cañón es uno solo.
      expect(character.combat.companions, hasLength(1));
      expect(find.widgetWithText(TextField, 'Cantidad de PG'), findsOneWidget);
      expect(find.text('25 / 25 PG'), findsOneWidget);
      expect(find.text('CA 18'), findsOneWidget);

      final amount = find.widgetWithText(TextField, 'Cantidad de PG');
      await tester.enterText(amount, '7');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Daño').last);
      await tester.pumpAndSettle();

      expect(character.combat.companions.single.currentHp, 18);
      expect(find.text('18 / 25 PG'), findsOneWidget);

      // El daño al compañero no toca los PG del personaje.
      expect(character.combat.currentHp, 30);
    });

    testWidgets('a 0 PG el cañón se destruye y sale de la ficha', (
      tester,
    ) async {
      final character = artillerist();
      await pumpSheet(tester, character);
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Invocar'));
      await tester.pumpAndSettle();

      final amount = find.widgetWithText(TextField, 'Cantidad de PG');
      await tester.enterText(amount, '25');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Daño').last);
      await tester.pumpAndSettle();

      expect(character.combat.companions, isEmpty);
      expect(find.text('No hay ninguno invocado.'), findsOneWidget);
      // Sin instancia no queda nada que curar: se fueron los controles del
      // compañero y con ellos el campo. Los del personaje siguen, en su tarjeta.
      expect(find.text('Despedir'), findsNothing);
      expect(find.widgetWithText(TextField, 'Cantidad de PG'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
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

      final amount = find.widgetWithText(TextField, 'Cantidad de PG');
      await tester.enterText(amount, '10');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Daño').last);
      await tester.pumpAndSettle();
      expect(character.combat.companions.single.currentHp, 15);

      await tapVisible(tester, find.text('Descanso largo'));
      await tester.pumpAndSettle();
      expect(character.combat.companions.single.currentHp, 25);
    });

    testWidgets('invocar un espíritu gasta el espacio y concentra', (
      tester,
    ) async {
      final wizard = Character(
        id: 'maga-dragon',
        name: 'Ilyra',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'scribe',
        level: 9,
        assignedScores: {for (final a in Ability.values) a: 14},
        spellIds: const ['summon-dragon'],
        hpPerLevel: List.filled(9, 4),
        combat: CombatState(currentHp: 40),
      );
      // Mucho más alto que el resto de los casos: el bloque del dragón trae
      // cuatro acciones con sus descripciones, y si la pestaña no entra entera
      // salta el fallo de semántica de Flutter que explica `pumpSheet`.
      await pumpSheet(tester, wizard, size: const Size(900, 6000));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Invocar'));
      // Un mago de nivel 9 tiene espacios de 1 a 5; el conjuro es de nivel 5,
      // así que el único nivel ofrecido es el 5. Se busca dentro del diálogo:
      // la tarjeta de Conjuros también rotula sus filas "Nivel N".
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );
      expect(inDialog('Nivel 5'), findsOneWidget);
      expect(inDialog('Nivel 4'), findsNothing);
      await tester.tap(inDialog('Nivel 5'));
      await tester.pumpAndSettle();

      expect(wizard.combat.companions.single.spellLevel, 5);
      expect(wizard.combat.spellSlotsUsed[5], 1);
      expect(wizard.combat.concentratingOn, 'Invocar Dragón');
      expect(wizard.combat.companions.single.concentration, isTrue);

      // Cortar la concentración se lleva al espíritu.
      await tapVisible(tester, find.text('Terminar'));
      expect(wizard.combat.companions, isEmpty);
      expect(wizard.combat.concentratingOn, isNull);
      // El espacio gastado no vuelve solo: eso se recupera aparte.
      expect(wizard.combat.spellSlotsUsed[5], 1);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el Paladín puede invocar el corcel sin gastar espacio', (
      tester,
    ) async {
      final paladin = Character(
        id: 'paladin-corcel',
        name: 'Aurel',
        raceId: 'human',
        classId: 'paladin',
        backgroundId: 'soldier',
        level: 5,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(5, 6),
        combat: CombatState(currentHp: 40),
      );
      await pumpSheet(tester, paladin, size: const Size(900, 6000));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Invocar'));
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

      // El uso gratis del Corcel Fiel va primero, antes de los espacios.
      expect(inDialog('Sin gastar espacio'), findsOneWidget);
      expect(inDialog('Nivel 2'), findsOneWidget);

      await tester.tap(inDialog('Sin gastar espacio'));
      await tester.pumpAndSettle();

      expect(paladin.combat.companions.single.spellLevel, 2);
      // Se consumió el uso del rasgo y ningún espacio de conjuro.
      expect(
        paladin.combat.resourceUsage[innateSpellResourceId('find-steed')],
        1,
      );
      expect(paladin.combat.spellSlotsUsed, isEmpty);
      // Hallar Corcel no es de concentración, así que no la toca.
      expect(paladin.combat.concentratingOn, isNull);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sin espacios ni usos gratis no se puede invocar', (
      tester,
    ) async {
      final paladin = Character(
        id: 'paladin-sin-espacios',
        name: 'Aurel',
        raceId: 'human',
        classId: 'paladin',
        backgroundId: 'soldier',
        level: 5,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(5, 6),
        combat: CombatState(
          currentHp: 40,
          // Todo gastado: 4 espacios de nivel 1, 2 de nivel 2, y el uso gratis
          // del Corcel Fiel.
          spellSlotsUsed: {1: 4, 2: 2},
          resourceUsage: {innateSpellResourceId('find-steed'): 1},
        ),
      );
      await pumpSheet(tester, paladin, size: const Size(900, 6000));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Invocar'));

      // No abre el selector: avisa y no invoca nada.
      expect(find.byType(AlertDialog), findsNothing);
      expect(paladin.combat.companions, isEmpty);
      expect(find.textContaining('No te quedan espacios'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('reemplazar un compañero avisa antes de gastar nada', (
      tester,
    ) async {
      final paladin = Character(
        id: 'paladin-reemplazo',
        name: 'Aurel',
        raceId: 'human',
        classId: 'paladin',
        backgroundId: 'soldier',
        level: 5,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(5, 6),
        combat: CombatState(currentHp: 40),
      );
      await pumpSheet(tester, paladin, size: const Size(900, 6000));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

      await tapVisible(tester, find.text('Invocar'));
      await tester.tap(inDialog('Sin gastar espacio'));
      await tester.pumpAndSettle();
      expect(paladin.combat.companions, hasLength(1));

      // Con uno en juego, invocar otro avisa primero.
      await tapVisible(tester, find.text('Invocar otro'));
      expect(find.text('Ya tenés uno en juego'), findsOneWidget);
      expect(
        find.textContaining('hace desaparecer a Corcel sobrenatural'),
        findsOneWidget,
      );

      // Cancelar no toca nada: ni el compañero ni los espacios.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(paladin.combat.companions, hasLength(1));
      expect(paladin.combat.spellSlotsUsed, isEmpty);

      await tester.pump(const Duration(seconds: 5));
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

    testWidgets('las salvaciones de muerte entran en un teléfono angosto', (
      tester,
    ) async {
      // A 0 PG aparece la fila de salvaciones, con seis círculos y dos
      // botones: en un teléfono no entraban en una línea. Es justo la pantalla
      // que se mira cuando el personaje está cayendo.
      final dying = demoSagan();
      dying.combat.currentHp = 0;
      await pumpSheet(tester, dying, size: const Size(360, 1600));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.text('+Éxito'), findsOneWidget);
      expect(find.text('+Fallo'), findsOneWidget);
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
        combat: CombatState(currentHp: 6),
      );
      await pumpSheet(tester, wizard, size: const Size(360, 1600));

      // Por debajo de 900 la navegación de la ficha vive en un Drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
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

  group('Forma Salvaje', () {
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Character druid({int level = 4, List<String> forms = const ['wolf']}) =>
        Character(
          id: 'druida',
          name: 'Sagan',
          raceId: 'human',
          classId: 'druid',
          backgroundId: 'sage',
          level: level,
          wildShapeForms: forms,
          assignedScores: const {
            Ability.strength: 8,
            Ability.dexterity: 12,
            Ability.constitution: 14,
            Ability.intelligence: 13,
            Ability.wisdom: 16,
            Ability.charisma: 10,
          },
          hpPerLevel: List.filled(level, 5),
          combat: CombatState(currentHp: 26),
        );

    testWidgets('transformarse cambia los números de la ficha y volver los '
        'devuelve', (tester) async {
      final character = druid();
      await pumpSheet(tester, character, size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.text('Forma Salvaje'), findsWidgets);
      // La CA del druida sin armadura: 10 + DES.
      expect(find.text('11'), findsWidgets);

      await tapVisible(tester, find.text('Transformarse'));

      expect(character.combat.wildShapeCreatureId, 'wolf');
      expect(find.text('Transformado en Lobo'), findsWidgets);
      // La CA pasa a ser la del lobo y el mordisco aparece entre los ataques.
      expect(find.text('12'), findsWidgets);
      expect(find.text('Mordisco'), findsWidgets);
      // Los PG no se tocan; los temporales son el nivel de druida.
      expect(character.combat.currentHp, 26);
      expect(character.combat.tempHp, 4);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('Volver'));
      expect(character.combat.wildShapeCreatureId, isNull);
      expect(find.text('Mordisco'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('transformado avisa que no podés lanzar conjuros', (
      tester,
    ) async {
      final character = druid();
      await pumpSheet(tester, character, size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Transformarse'));

      expect(
        find.text('En forma de Lobo no podés lanzar conjuros.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('anotar formas guarda la elección en el personaje', (
      tester,
    ) async {
      final character = druid(forms: const []);
      final controller = await pumpSheet(
        tester,
        character,
        size: const Size(900, 2400),
      );
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no anotaste ninguna forma.'), findsOneWidget);

      await tapVisible(tester, find.text('Anotar'));
      expect(find.text('Formas conocidas (0/6)'), findsOneWidget);

      // El pozo son decenas de bestias en un ListView perezoso: el Lobo no
      // está construido hasta que se scrollea hasta él.
      await tester.scrollUntilVisible(
        find.text('Lobo'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Lobo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(controller.characters.single.wildShapeForms, ['wolf']);
      expect(find.text('Transformarse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un Guerrero no ve la tarjeta', (tester) async {
      await pumpSheet(tester, demoSagan());
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.text('Forma Salvaje'), findsNothing);
    });

    testWidgets('la tarjeta y el selector entran en un teléfono angosto', (
      tester,
    ) async {
      await pumpSheet(tester, druid(), size: const Size(360, 2400));
      // Por debajo de 900 la navegación de la ficha vive en un Drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      // Sin `takeException` a propósito: un desborde llega igual como fallo, y
      // recogerlo se lleva puesto el widget que lo causó, que es el único dato
      // que sirve para arreglarlo.
      await tapVisible(tester, find.text('Transformarse'));
      await tapVisible(tester, find.text('Anotar'));
      expect(find.text('Formas conocidas (1/6)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
  // La vuelta del vínculo: hasta acá el jugador compartía su ficha y no veía
  // nada a cambio.
  group('Campaña', () {
    /// Un servidor con una mesa armada alrededor de Sagan.
    FakeApiServer tableFor(Character c, {bool withChapter = true}) {
      final server = FakeApiServer();
      server.characters[c.id] = c;
      server.campaigns['tumba'] = const Campaign(
        id: 'tumba',
        name: 'La Tumba',
        premise: 'Una maldición despierta bajo la ciudad.',
      );
      server.campaignMembers['m1'] = (campaignId: 'tumba', characterId: c.id);
      if (withChapter) {
        server.chapters['tumba'] = [
          const Chapter(
            id: 'cripta',
            name: 'La cripta sellada',
            summary: 'Detrás del tercer sello duerme algo.',
            state: ChapterState.completed,
            grantsLevel: true,
            grantsGold: 250,
            grantsItems: ['Espada larga +1'],
          ),
        ];
      }
      return server;
    }

    Future<void> openCampana(WidgetTester tester) async {
      await tester.tap(find.text('Campaña'));
      await tester.pumpAndSettle();
    }

    testWidgets('la pestaña va entre Inventario y Notas', (tester) async {
      await pumpSheet(tester, demoSagan());

      // El panel las pinta en el orden del enum, así que comparar posiciones
      // verticales prueba el orden real y no solo que existan.
      double y(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(y('Inventario'), lessThan(y('Campaña')));
      expect(y('Campaña'), lessThan(y('Notas')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra la campaña, sus batallas y lo que se repartió', (
      tester,
    ) async {
      final sagan = demoSagan();
      final server = tableFor(sagan);
      server.encounterLogs['tumba'] = [
        const EncounterLog(
          id: 'log-1',
          chapterId: 'cripta',
          rounds: 4,
          players: ['Sagan "The Red"', 'Mirna'],
          monsters: [
            EncounterLogMonsters(name: 'Esqueleto', count: 2, defeated: 2),
          ],
        ),
      ];
      await pumpSheet(tester, sagan, server: server);
      await openCampana(tester);

      expect(find.text('La Tumba'), findsOneWidget);
      expect(
        find.text('Una maldición despierta bajo la ciudad.'),
        findsOneWidget,
      );
      expect(find.text('Contra 2 Esqueleto'), findsOneWidget);
      expect(find.textContaining('Con Mirna'), findsOneWidget);
      expect(find.textContaining('cayeron todos'), findsOneWidget);
      expect(find.text('La cripta sellada'), findsOneWidget);
      expect(
        find.text('Te llevaste un nivel, 250 po y Espada larga +1'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // La misma frontera que el servidor ya defiende, comprobada del lado de la
    // pantalla: si algún día el endpoint dejara de podarlo, esto lo agarra.
    testWidgets('no muestra la descripción que escribió el DM', (tester) async {
      final sagan = demoSagan();
      await pumpSheet(tester, sagan, server: tableFor(sagan));
      await openCampana(tester);

      expect(find.textContaining('duerme algo'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin campañas ofrece compartir el personaje', (tester) async {
      final sagan = demoSagan();
      final server = FakeApiServer();
      server.characters[sagan.id] = sagan;
      await pumpSheet(tester, sagan, server: server);
      await openCampana(tester);

      expect(
        find.textContaining('todavía no está en ninguna campaña'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Compartir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Regresión: `sheetCard` plegaba por título, así que dos campañas apiladas
    // tenían dos tarjetas «Batallas» que se plegaban juntas.
    testWidgets('dos campañas se apilan y se pliegan por separado', (
      tester,
    ) async {
      final sagan = demoSagan();
      final server = tableFor(sagan);
      server.campaigns['bosque'] = const Campaign(
        id: 'bosque',
        name: 'El Bosque Callado',
      );
      server.campaignMembers['m2'] = (
        campaignId: 'bosque',
        characterId: sagan.id,
      );
      server.chapters['bosque'] = [
        const Chapter(
          id: 'raiz',
          name: 'La raíz partida',
          state: ChapterState.completed,
        ),
      ];
      await pumpSheet(tester, sagan, server: server);
      await openCampana(tester);

      expect(find.text('Batallas'), findsNWidgets(2));
      expect(find.text('La cripta sellada'), findsOneWidget);
      expect(find.text('La raíz partida'), findsOneWidget);

      // Plegar los capítulos de la primera no puede llevarse los de la segunda.
      await tester.tap(find.text('Capítulos cerrados').first);
      await tester.pumpAndSettle();
      expect(find.text('La cripta sellada'), findsNothing);
      expect(find.text('La raíz partida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Las batallas de un capítulo que el DM borró —o del que sigue en marcha,
    // que no se muestra— no pueden desaparecer sin dejar rastro.
    testWidgets('una batalla sin capítulo a la vista se muestra igual', (
      tester,
    ) async {
      final sagan = demoSagan();
      final server = tableFor(sagan);
      server.encounterLogs['tumba'] = [
        const EncounterLog(
          id: 'log-1',
          chapterId: 'un-capitulo-que-ya-no-esta',
          rounds: 3,
          players: ['Sagan "The Red"'],
          monsters: [EncounterLogMonsters(name: 'Bandido', count: 4)],
        ),
      ];
      await pumpSheet(tester, sagan, server: server);
      await openCampana(tester);

      expect(find.text('SIN CAPÍTULO'), findsOneWidget);
      expect(find.text('Contra 4 Bandido'), findsOneWidget);
      expect(find.textContaining('Solo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un error de red se puede reintentar', (tester) async {
      final sagan = demoSagan();
      final server = tableFor(sagan);
      server.failWith = Exception('sin conexión');
      await pumpSheet(tester, sagan, server: server);
      await openCampana(tester);

      expect(
        find.textContaining('No se pudieron leer tus campañas'),
        findsOneWidget,
      );

      server.failWith = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('La Tumba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cansancio e Inspiración Heroica', () {
    Character guerrero({int exhaustion = 0, bool inspiracion = false}) =>
        Character(
          id: 'cansado',
          name: 'Bruno',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'soldier',
          level: 3,
          assignedScores: const {
            Ability.strength: 16,
            Ability.dexterity: 12,
            Ability.constitution: 14,
            Ability.intelligence: 10,
            Ability.wisdom: 12,
            Ability.charisma: 8,
          },
          hpPerLevel: const [10, 6, 6],
          combat: CombatState(
            currentHp: 22,
            exhaustion: exhaustion,
            heroicInspiration: inspiracion,
          ),
        );

    testWidgets('sin cansancio la ficha no habla del tema', (tester) async {
      await pumpSheet(tester, guerrero(), size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.text('Estado'), findsOneWidget);
      expect(find.textContaining('No lo restes otra vez'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el cansancio baja la plaqueta y marca la velocidad', (
      tester,
    ) async {
      // FUE 16 son +3; con cansancio 2 la prueba es +3 − 4 = −1. La plaqueta
      // muestra la prueba, no el modificador: es el número que se tira.
      await pumpSheet(
        tester,
        guerrero(exhaustion: 2),
        size: const Size(900, 2400),
      );

      expect(find.text('-1'), findsWidgets);
      expect(find.text('Cansancio −10 pies'), findsOneWidget);
      // La velocidad ya viene bajada: 30 − 5 × 2. Por predicado y no por texto:
      // StatTile compone la cifra con su sufijo y `find.text` no la ve entera.
      expect(
        find.byWidgetPredicate(
          (w) => w is StatTile && w.label == 'Velocidad' && w.value == '20',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el aviso dice que los números ya vienen restados', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        guerrero(exhaustion: 2),
        size: const Size(900, 2400),
      );
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya vienen con −4'), findsOneWidget);
      expect(find.textContaining('No lo restes otra vez'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en nivel 6 avisa la muerte y no deja subir más', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        guerrero(exhaustion: maxExhaustionLevel),
        size: const Size(900, 2400),
      );
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tu personaje muere'), findsOneWidget);
      // Avisa, pero no le toca los PG: esa decisión es de la mesa.
      expect(find.textContaining('esa decisión es de la mesa'), findsOneWidget);

      // Por predicado: `byTooltip` encuentra el `Tooltip` que arma el
      // IconButton, no el botón, y lo que hay que mirar es su `onPressed`.
      expect(
        _botonDeshabilitado(tester, 'Subir un nivel de cansancio'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('subir y bajar el cansancio se guarda en el personaje', (
      tester,
    ) async {
      final character = guerrero();
      await pumpSheet(tester, character, size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Subir un nivel de cansancio'));
      await tester.pumpAndSettle();
      expect(character.combat.exhaustion, 1);

      await tester.tap(find.byTooltip('Bajar un nivel de cansancio'));
      await tester.pumpAndSettle();
      expect(character.combat.exhaustion, 0);

      // En 0 no se puede bajar más.
      expect(
        _botonDeshabilitado(tester, 'Bajar un nivel de cansancio'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('la Inspiración Heroica se marca y se gasta', (tester) async {
      final character = guerrero();
      await pumpSheet(tester, character, size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Marcar que la tenés'));
      await tester.pumpAndSettle();
      expect(character.combat.heroicInspiration, isTrue);

      await tester.tap(find.byTooltip('Gastar la Inspiración Heroica'));
      await tester.pumpAndSettle();
      expect(character.combat.heroicInspiration, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un humano la gana al terminar un descanso largo', (
      tester,
    ) async {
      // El rasgo Ingenioso dejó de ser solo texto.
      final character = guerrero(exhaustion: 2);
      await pumpSheet(tester, character, size: const Size(900, 2400));
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();

      expect(find.text('La ganás al descansar'), findsOneWidget);

      await tester.tap(find.text('Descanso largo'));
      await tester.pumpAndSettle();

      expect(character.combat.heroicInspiration, isTrue);
      expect(character.combat.exhaustion, 1);
      // El aviso cuenta lo que efectivamente cambió.
      expect(find.textContaining('cansancio a nivel 1'), findsOneWidget);
      expect(
        find.textContaining('ganaste Inspiración Heroica'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
