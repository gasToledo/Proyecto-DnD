import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/sheet_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

/// Cambio del truco innato desde la ficha (Alto Elfo).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Character highElf({Map<String, String> choices = const {}}) => Character(
    id: 'alto-elfo',
    name: 'Iriel',
    raceId: 'elf',
    lineageId: 'elf-high',
    speciesSpellcastingAbility: Ability.intelligence,
    classId: 'fighter',
    backgroundId: 'soldier',
    innateCantripChoices: choices,
    assignedScores: const {
      Ability.strength: 15,
      Ability.dexterity: 14,
      Ability.constitution: 13,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 8,
    },
    hpPerLevel: const [10],
  );

  /// Deja la ficha abierta en la sección de conjuros y devuelve el controlador.
  ///
  /// Se lee de ahí y no de la instancia que se pasó: guardar una elección hace
  /// `copyWith`, así que el `Character` original queda intacto y comprobar
  /// sobre él daría un falso negativo.
  Future<CharactersController> pumpSpells(
    WidgetTester tester,
    Character character,
  ) async {
    // Mismo viewport que el resto de las pruebas de ficha: a otros anchos la
    // barra de navegación desborda, y eso es anterior a esta pantalla.
    tester.view.physicalSize = const Size(900, 700);
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

    // La tarjeta de Conjuros vive dentro de la pestaña de Combate; no hay una
    // pestaña propia.
    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();

    // La tarjeta de Conjuros cae debajo del pliegue. El último `Scrollable` es
    // el del contenido; el primero es la barra de navegación lateral. Se ancla
    // en el encabezado de la sección y no en el botón de cambio, que es
    // justamente lo que algunas de estas pruebas esperan no encontrar.
    await tester.scrollUntilVisible(
      find.text('Conjuros de rasgos'.toUpperCase()),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Elecciones guardadas del personaje, leídas del controlador.
  Map<String, String> choicesOf(CharactersController controller, String id) =>
      controller.characters.firstWhere((c) => c.id == id).innateCantripChoices;

  /// Toca una opción del diálogo, scrolleando su lista si hace falta: tiene más
  /// de treinta trucos y es perezosa.
  Future<void> pickInDialog(WidgetTester tester, String name) async {
    final option = find.descendant(
      of: find.byType(RadioListTile<String>),
      matching: find.text(name),
    );
    if (option.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        option,
        120,
        scrollable: find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(option.first);
    await tester.pumpAndSettle();
  }

  testWidgets('el truco del rasgo aparece con su botón de cambio', (
    tester,
  ) async {
    await pumpSpells(tester, highElf());

    expect(find.text('Conjuros de rasgos'.toUpperCase()), findsOneWidget);
    expect(find.text('Prestidigitación'), findsWidgets);
    // Solo el truco lo lleva: el Alto Elfo de nivel 1 no tiene otros innatos.
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el diálogo ofrece los trucos de Mago y marca el del rasgo', (
    tester,
  ) async {
    await pumpSpells(tester, highElf());

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Cambiar Prestidigitación'), findsOneWidget);
    expect(find.textContaining('la lista de Mago'), findsOneWidget);

    // El del rasgo va primero, así que está a la vista sin scrollear.
    expect(find.text('El del rasgo'), findsOneWidget);

    // Un truco de Mago está; uno que solo es de Clérigo no.
    await pickInDialog(tester, 'Descarga de Fuego');
    expect(find.text('Llama Sagrada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('elegir otro truco lo cambia en la ficha', (tester) async {
    final controller = await pumpSpells(tester, highElf());

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    await pickInDialog(tester, 'Descarga de Fuego');

    expect(choicesOf(controller, 'alto-elfo'), {
      'prestidigitation': 'fire-bolt',
    });
    // La fila ahora muestra el reemplazo, no el original.
    expect(find.text('Descarga de Fuego'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volver al truco del rasgo borra la elección', (tester) async {
    // Escribirla apuntando a sí misma dejaría ruido en el mapa guardado.
    final controller = await pumpSpells(
      tester,
      highElf(choices: {'prestidigitation': 'fire-bolt'}),
    );

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    await pickInDialog(tester, 'Prestidigitación');

    expect(choicesOf(controller, 'alto-elfo'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un innato fijo no ofrece el cambio', (tester) async {
    // El Drow concede Luces Danzantes y no lo puede cambiar.
    final drow = Character(
      id: 'drow',
      name: 'Nym',
      raceId: 'elf',
      lineageId: 'elf-drow',
      speciesSpellcastingAbility: Ability.charisma,
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: const {
        Ability.strength: 15,
        Ability.dexterity: 14,
        Ability.constitution: 13,
        Ability.intelligence: 12,
        Ability.wisdom: 10,
        Ability.charisma: 8,
      },
      hpPerLevel: const [10],
    );
    await pumpSpells(tester, drow);

    expect(find.text('Conjuros de rasgos'.toUpperCase()), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
