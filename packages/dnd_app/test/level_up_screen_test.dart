import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/levelup/level_up_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresión: en la subida de nivel, la sección de conjuros previsualiza el
/// personaje llamando a `_buildUpdated()` en cada build. Cambiar a "Tomar dote"
/// antes de elegir una dote no debe romper (antes: `_featId!` sobre null).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Character fighterL3() => Character(
    id: 't-fighter',
    name: 'Prueba',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    subclassId: 'champion',
    level: 3,
    assignedScores: {
      Ability.strength: 16,
      Ability.dexterity: 14,
      Ability.constitution: 14,
      Ability.intelligence: 10,
      Ability.wisdom: 12,
      Ability.charisma: 8,
    },
    hpPerLevel: [10, 6, 6],
    // El Guerrero elige su Estilo de Combate a nivel 1: sin esto el asistente
    // lo trata (con razón) como una elección pendiente y agrega un paso.
    featureChoices: const {
      'fighting-style': ['fs-defense'],
    },
  );

  Future<void> goToAsi(WidgetTester tester) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Mejora tu personaje'), findsOneWidget);
  }

  Future<void> searchFeat(WidgetTester tester, String query) async {
    final search = find.widgetWithText(TextField, 'Buscar dote');
    expect(search, findsOneWidget);
    await tester.enterText(search, query);
    await tester.pumpAndSettle();
  }

  testWidgets('cambiar a "Tomar dote" sin elegir dote no crashea', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Nivel 4 es ASI para el Guerrero: el wizard llega a mejora/dote tras
    // resolver el resumen y los PG.
    await goToAsi(tester);
    expect(find.text('Tomar dote'), findsOneWidget);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // No debe haberse lanzado ninguna excepción durante el rebuild.
    expect(tester.takeException(), isNull);
  });

  testWidgets('la subida de nivel cabe en una ventana compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subir a nivel 4'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('Paso 1 de'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tirar PG bloquea el avance hasta obtener un resultado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar'));
    await tester.pumpAndSettle();

    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Tirá el dado o elegí el promedio para continuar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Tirar el dado'));
    await tester.tap(find.text('Tirar el dado'));
    await tester.pumpAndSettle();
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('la revisión confirma recién al final y abre la celebración', (
    tester,
  ) async {
    Character? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(
          character: fighterL3(),
          repo: repo,
          onDone: (updated) => saved = updated,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.widgetWithText(InkWell, 'Fuerza'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Así queda Prueba'), findsOneWidget);
    expect(find.text('Confirmar nivel 4'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.text('Confirmar nivel 4'));
    await tester.pumpAndSettle();

    expect(saved?.level, 4);
    expect(saved?.asiChoices.last.abilityIncreases[Ability.strength], 2);
    expect(find.text('¡Subiste a nivel 4!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no ofrece una dote general ya tomada', (tester) async {
    final c = Character(
      id: 't-fighter-6',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      subclassId: 'champion',
      level: 5,
      assignedScores: {
        Ability.strength: 16,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      hpPerLevel: [10, 6, 6, 6, 6],
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
      // Ya tomó esta dote general en un nivel de ASI anterior.
      featIds: const ['great-weapon-master'],
      asiChoices: const [AsiChoice(level: 4, featId: 'great-weapon-master')],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Nivel 6 es ASI para el Guerrero.
    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
    await searchFeat(tester, 'Maestro en Armas Pesadas');

    // La dote ya tomada no debe ofrecerse de nuevo (no es repetible).
    expect(
      find.widgetWithText(InkWell, 'Maestro en Armas Pesadas'),
      findsNothing,
    );
  });

  // Regresión: el selector no miraba `Feat.prerequisite`, así que ofrecía
  // dotes que el personaje no podía tomar. Ahora las oculta, delegando la
  // comprobación en `CharacterValidator.unmetFeatPrerequisite`.
  Character fighterL5({int strength = 16, List<String> featIds = const []}) =>
      Character(
        id: 't-fighter-prereq',
        name: 'Prueba',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        subclassId: 'champion',
        level: 5,
        assignedScores: {
          Ability.strength: strength,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 12,
          Ability.charisma: 8,
        },
        hpPerLevel: [10, 6, 6, 6, 6],
        featureChoices: const {
          'fighting-style': ['fs-defense'],
        },
        featIds: featIds,
      );

  Future<void> openFeatPicker(WidgetTester tester, Character c) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
  }

  testWidgets('no ofrece una dote cuya característica mínima no se cumple', (
    tester,
  ) async {
    // Maestro en Armas Pesadas exige Fuerza 13.
    await openFeatPicker(tester, fighterL5(strength: 8));
    await searchFeat(tester, 'Maestro en Armas Pesadas');

    expect(
      find.widgetWithText(InkWell, 'Maestro en Armas Pesadas'),
      findsNothing,
    );
    // Pero el selector no queda vacío: Cocinero no pide característica.
    await searchFeat(tester, 'Chef (Sabiduría)');
    expect(find.widgetWithText(InkWell, 'Chef (Sabiduría)'), findsOneWidget);
  });

  testWidgets('no ofrece una marca mayor sin la marca base', (tester) async {
    // Marca Mayor de Manejo exige tener Marca de Manejo.
    await openFeatPicker(tester, fighterL5());
    await searchFeat(tester, 'Marca Mayor de Manejo');

    expect(find.widgetWithText(InkWell, 'Marca Mayor de Manejo'), findsNothing);
  });

  testWidgets('ofrece la marca mayor cuando ya tiene la marca base', (
    tester,
  ) async {
    await openFeatPicker(
      tester,
      fighterL5(featIds: const ['mark-of-handling']),
    );
    await searchFeat(tester, 'Marca Mayor de Manejo');

    expect(
      find.widgetWithText(InkWell, 'Marca Mayor de Manejo'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Mejora de Característica no se duplica en el selector de dotes',
    (tester) async {
      await openFeatPicker(tester, fighterL5());
      await searchFeat(tester, 'Mejora de Característica');

      expect(
        find.widgetWithText(InkWell, 'Mejora de Característica'),
        findsNothing,
      );
    },
  );

  testWidgets('no ofrece otra variante de Resiliente', (tester) async {
    await openFeatPicker(
      tester,
      fighterL5(featIds: const ['resilient-wisdom']),
    );
    await searchFeat(tester, 'Resiliente (Constitución)');

    expect(
      find.widgetWithText(InkWell, 'Resiliente (Constitución)'),
      findsNothing,
    );
  });

  testWidgets('el nivel del prerrequisito se mide en el nivel nuevo', (
    tester,
  ) async {
    // Las 57 dotes generales exigen nivel 4. Un personaje de nivel 3 subiendo
    // a 4 debe verlas: comprobar contra el nivel viejo vaciaría el selector
    // justo en el ASI más común.
    await openFeatPicker(tester, fighterL3());
    await searchFeat(tester, 'Maestro en Armas Pesadas');

    expect(
      find.widgetWithText(InkWell, 'Maestro en Armas Pesadas'),
      findsOneWidget,
    );
  });

  testWidgets('elegir una dote muestra qué hace', (tester) async {
    // La grilla son decenas de chips con solo el nombre: sin este panel había
    // que elegir a ciegas.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: fighterL3(), repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();

    // Sin dote elegida, se explica qué hacer para ver la descripción.
    expect(find.text('Elegí una dote'), findsOneWidget);

    // Chef y no Actor: Actor exige Carisma 13 y este guerrero tiene 8, así
    // que desde que el selector respeta los prerrequisitos no se ofrece.
    await searchFeat(tester, 'Chef (Sabiduría)');
    final chip = find.widgetWithText(InkWell, 'Chef (Sabiduría)');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // El texto sale de los rasgos pasivos de la dote, no de un literal.
    final esperado = featSummary(repo.feat('chef-wisdom')!);
    expect(esperado, isNotEmpty);
    // La tarjeta y el panel de detalle comparten el resumen.
    expect(find.text(esperado), findsWidgets);
    expect(find.text('Elegí una dote'), findsNothing);
  });

  testWidgets('no ofrece Iniciado en la Magia: es dote de origen', (
    tester,
  ) async {
    // En 2024 los ASI solo admiten dotes generales, e Iniciado en la Magia es
    // de origen. Antes figuraba como general y aparecía acá.
    expect(repo.feat('magic-initiate-wizard')!.category, 'origin');

    final c = Character(
      id: 't-fighter-4',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      subclassId: 'champion',
      level: 3,
      assignedScores: {
        Ability.strength: 16,
        Ability.dexterity: 14,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      hpPerLevel: [10, 6, 6],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await goToAsi(tester);
    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
    await searchFeat(tester, 'Iniciado en la Magia');

    expect(
      find.widgetWithText(InkWell, 'Iniciado en la Magia (Mago)'),
      findsNothing,
    );
  });

  // --- Elecciones abiertas: Estilo de Combate de Paladín/Explorador --------

  Character paladin({
    int level = 1,
    Map<String, List<String>> choices = const {},
  }) => Character(
    id: 't-paladin',
    name: 'Prueba',
    raceId: 'human',
    classId: 'paladin',
    backgroundId: 'soldier',
    level: level,
    assignedScores: {
      Ability.strength: 16,
      Ability.dexterity: 12,
      Ability.constitution: 14,
      Ability.intelligence: 10,
      Ability.wisdom: 10,
      Ability.charisma: 14,
    },
    hpPerLevel: List.filled(level, 10),
    featureChoices: choices,
  );

  Future<void> pumpLevelUp(
    WidgetTester tester,
    Character c, {
    void Function(Character)? onDone,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LevelUpScreen(character: c, repo: repo, onDone: onDone ?? (_) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('un Paladín de 1 a 2 tiene que elegir su Estilo de Combate', (
    tester,
  ) async {
    Character? saved;
    await pumpLevelUp(tester, paladin(), onDone: (c) => saved = c);

    expect(find.text('Elecciones'), findsWidgets);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Tus elecciones de este nivel'), findsOneWidget);
    // Bloquea hasta elegir, y dice por qué.
    expect(find.text('Te falta una elección para continuar.'), findsOneWidget);

    final chip = find.widgetWithText(InkWell, 'Defensa');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Te falta una elección para continuar.'), findsNothing);

    while (find.text('Confirmar nivel 2').evaluate().isEmpty) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 2'));
    await tester.pumpAndSettle();

    expect(saved?.featureChoices['fighting-style'], ['fs-defense']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un Guerrero que ya eligió no vuelve a ver el paso', (
    tester,
  ) async {
    // Su estilo no es revisable, así que subir a 4 no vuelve a preguntárselo.
    await pumpLevelUp(tester, fighterL3());

    expect(find.text('Elecciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un Brujo de 1 a 2 gana dos invocaciones y puede cambiarlas', (
    tester,
  ) async {
    // A nivel 1 conoce 1 invocación y a nivel 2 pasa a 3: el paso tiene que
    // pedir las dos que faltan.
    Character? saved;
    final brujo = Character(
      id: 't-warlock',
      name: 'Prueba',
      raceId: 'human',
      classId: 'warlock',
      backgroundId: 'soldier',
      level: 1,
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: const [8],
      featureChoices: const {
        'warlock-invocation': ['pact-of-the-tome'],
      },
    );
    await pumpLevelUp(tester, brujo, onDone: (c) => saved = c);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Tus elecciones de este nivel'), findsOneWidget);
    expect(find.text('INVOCACIONES SOBRENATURALES (1/3)'), findsOneWidget);
    expect(find.text('Te faltan 2 elecciones para continuar.'), findsOneWidget);

    for (final nombre in ['Pacto de la Cadena', 'Pacto del Filo']) {
      final chip = find.widgetWithText(InkWell, nombre);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(find.text('INVOCACIONES SOBRENATURALES (3/3)'), findsOneWidget);

    while (find.text('Confirmar nivel 2').evaluate().isEmpty) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 2'));
    await tester.pumpAndSettle();

    expect(saved?.featureChoices['warlock-invocation'], hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('una invocación repetible se puede tomar dos veces', (
    tester,
  ) async {
    // Descarga Agónica dice "Repetible: cada vez elegís un truco distinto", así
    // que gastar en ella las dos invocaciones del nivel 2 es legal. Antes el
    // chip era un interruptor y el brujo perdía una invocación.
    Character? saved;
    final brujo = Character(
      id: 't-warlock-rep',
      name: 'Prueba',
      raceId: 'human',
      classId: 'warlock',
      backgroundId: 'soldier',
      level: 1,
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: const [8],
      featureChoices: const {
        'warlock-invocation': ['pact-of-the-tome'],
      },
    );
    await pumpLevelUp(tester, brujo, onDone: (c) => saved = c);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(InkWell, 'Descarga Agónica');
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(chip.first);
      await tester.pumpAndSettle();
      await tester.tap(chip.first);
      await tester.pumpAndSettle();
    }

    expect(find.text('INVOCACIONES SOBRENATURALES (3/3)'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    // La descripción sale una sola vez aunque haya dos copias.
    expect(
      find.textContaining('sumás tu modificador por Carisma'),
      findsOneWidget,
    );

    while (find.text('Confirmar nivel 2').evaluate().isEmpty) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 2'));
    await tester.pumpAndSettle();

    expect(saved?.featureChoices['warlock-invocation'], [
      'pact-of-the-tome',
      'agonizing-blast',
      'agonizing-blast',
    ]);
    // Repetible: el duplicado no es un error.
    expect(
      CharacterValidator(repo).validate(saved!).map((w) => w.code),
      isNot(contains('feat_duplicate')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un Paladín legado de nivel alto recupera la elección pendiente',
    (tester) async {
      // Guardado antes de que la clase concediera el estilo: nunca eligió. El
      // asistente se lo pide en la próxima subida en vez de dejarlo incompleto.
      await pumpLevelUp(tester, paladin(level: 7));

      expect(find.text('Elecciones'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  // --- Dones épicos ---------------------------------------------------------

  testWidgets('un don épico pide además a qué característica va su +1', (
    tester,
  ) async {
    // Los trece dones épicos conceden la dote y "+1 a una característica a tu
    // elección, hasta un máximo de 30". El aumento no tiene mapa propio: viaja
    // en el mismo AsiChoice que la dote, porque un don solo se puede tomar en
    // un nivel de Mejora.
    // El don agrega la grilla de características debajo del selector de dotes,
    // así que la página se hace larga: sin esto no entra nada.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Character? saved;
    await pumpLevelUp(
      tester,
      Character(
        id: 't-epic',
        name: 'Prueba',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        subclassId: 'champion',
        level: 18,
        assignedScores: {
          Ability.strength: 20,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 12,
          Ability.charisma: 8,
        },
        hpPerLevel: List.filled(18, 6),
        featureChoices: const {
          'fighting-style': ['fs-defense'],
        },
      ),
      onDone: (c) => saved = c,
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Mejora tu personaje'), findsOneWidget);

    await tester.tap(find.text('Tomar dote'));
    await tester.pumpAndSettle();
    await searchFeat(tester, 'Don de la Habilidad');
    final don = find.widgetWithText(InkWell, 'Don de la Habilidad');
    await tester.ensureVisible(don);
    await tester.tap(don);
    await tester.pumpAndSettle();

    // La dote sola no alcanza: falta decir adónde va el punto.
    expect(
      find.text('Elegí a qué característica va el +1 del don épico.'),
      findsOneWidget,
    );

    final fuerza = find.widgetWithText(InkWell, 'Fuerza');
    await tester.ensureVisible(fuerza);
    await tester.tap(fuerza);
    await tester.pumpAndSettle();
    expect(find.textContaining('Elegí a qué característica'), findsNothing);

    // El don también concede las 18 competencias y un cupo de Pericia, así que
    // el paso aparece y hay que resolverlo antes de poder confirmar.
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final atletismo = find.widgetWithText(FilterChip, 'Atletismo');
    await tester.ensureVisible(atletismo);
    await tester.tap(atletismo);
    await tester.pumpAndSettle();

    // Con cota: un paso que bloquea tiene que fallar el test y no colgarlo,
    // que es lo que pasa con un `while` pelado.
    for (var i = 0; find.text('Confirmar nivel 19').evaluate().isEmpty; i++) {
      expect(i, lessThan(10), reason: 'el asistente dejó de avanzar');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 19'));
    await tester.pumpAndSettle();

    // Un AsiChoice con dote *y* aumento, que es la excepción que habilita esto.
    final asi = saved!.asiChoices.last;
    expect(asi.featId, 'boon-of-skill');
    expect(asi.abilityIncreases, {Ability.strength: 1});
    // Y el 20 pasa a 21, que con el don es legal.
    expect(
      CharacterCompiler(repo).compile(saved!).abilityScores[Ability.strength],
      21,
    );
    expect(tester.takeException(), isNull);
  });

  // --- Competencias ---------------------------------------------------------

  Character barbarian({int level = 2}) => Character(
    id: 't-barbarian',
    name: 'Prueba',
    raceId: 'human',
    classId: 'barbarian',
    backgroundId: 'soldier',
    // El Bárbaro elige subclase justo a nivel 3: fijarla acá deja el paso de
    // competencias como el único que el test tiene que atravesar, igual que
    // `fighterL3` hace con el Estilo de Combate.
    subclassId: 'berserker',
    level: level,
    assignedScores: {
      Ability.strength: 16,
      Ability.dexterity: 14,
      Ability.constitution: 15,
      Ability.intelligence: 8,
      Ability.wisdom: 12,
      Ability.charisma: 10,
    },
    hpPerLevel: List.filled(level, 8),
    chosenSkills: const ['athletics', 'survival'],
  );

  testWidgets('subir un Bárbaro a nivel 3 pide Conocimiento Primigenio', (
    tester,
  ) async {
    // El rasgo concede "competencia en otra habilidad de la lista del Bárbaro".
    // Hasta que el paso cubrió las competencias y no solo la Pericia, el
    // asistente se lo saltaba y había que ir a buscarlo al aviso de la ficha.
    Character? saved;
    await pumpLevelUp(tester, barbarian(), onDone: (c) => saved = c);

    expect(find.text('Competencias'), findsWidgets);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Te falta una competencia para continuar.'),
      findsOneWidget,
    );

    // El pozo son las seis de la lista del Bárbaro, no las dieciocho...
    expect(find.widgetWithText(FilterChip, 'Naturaleza'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Arcanos'), findsNothing);
    // ...y las dos que ya tiene quedan bloqueadas, para no gastar el cupo en
    // algo que ya sabe hacer.
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Atletismo'))
          .onSelected,
      isNull,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Naturaleza'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Te falta'), findsNothing);

    while (find.text('Confirmar nivel 3').evaluate().isEmpty) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 3'));
    await tester.pumpAndSettle();

    expect(saved?.proficiencyChoices['class:barbarian:primal-knowledge'], [
      'nature',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una competencia vieja sin resolver no bloquea la subida', (
    tester,
  ) async {
    // El Humano/Soldado tiene dos cupos de nivel 1 —Habilidoso y la herramienta
    // del trasfondo— que este fixture nunca resolvió. Esa deuda la reclama el
    // aviso de la ficha, que deja seguir; el asistente solo pregunta por lo que
    // concede el nivel al que se está subiendo. Si esto se rompe, el `while` de
    // los tests de acá arriba gira para siempre en vez de fallar.
    await pumpLevelUp(tester, barbarian(level: 3));

    expect(find.text('Competencias'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // --- Pericia -------------------------------------------------------------

  Character bard({
    int level = 1,
    Map<String, List<String>> expertise = const {},
  }) => Character(
    id: 't-bard',
    name: 'Prueba',
    raceId: 'human',
    classId: 'bard',
    backgroundId: 'wayfarer',
    level: level,
    assignedScores: {
      Ability.strength: 10,
      Ability.dexterity: 14,
      Ability.constitution: 12,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 16,
    },
    hpPerLevel: List.filled(level, 8),
    chosenSkills: const ['perception', 'stealth', 'performance'],
    proficiencyChoices: expertise,
  );

  testWidgets('subir un Bardo a nivel 2 pide la Pericia', (tester) async {
    // La queja que originó todo esto: "los bardos tienen pericia con el nivel 2
    // que duplica el bonificador, pero nunca me lo hizo elegir".
    Character? saved;
    await pumpLevelUp(tester, bard(), onDone: (c) => saved = c);

    expect(find.text('Pericia'), findsWidgets);

    // El paso bloquea el avance mientras falten elecciones.
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegí 2 habilidades para tu Pericia.'), findsOneWidget);

    // Solo se ofrecen las competencias que tiene, no las 18 habilidades.
    expect(find.widgetWithText(FilterChip, 'Percepción'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Atletismo'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Percepción'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Sigilo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Elegí'),
      findsNothing,
      reason: 'ya no debería bloquear',
    );
    expect(saved, isNull, reason: 'todavía no se confirmó');
    expect(tester.takeException(), isNull);
  });

  testWidgets('la Pericia elegida se guarda y duplica el bonificador', (
    tester,
  ) async {
    Character? saved;
    await pumpLevelUp(tester, bard(), onDone: (c) => saved = c);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Percepción'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Sigilo'));
    await tester.pumpAndSettle();

    // Avanzar hasta el final y confirmar.
    while (find.text('Confirmar nivel 2').evaluate().isEmpty) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirmar nivel 2'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(
      saved!.proficiencyChoices['class:bard:expertise-2'],
      containsAll(['perception', 'stealth']),
    );

    final sheet = CharacterCompiler(repo).compile(saved!);
    expect(sheet.expertiseSkills, {'perception', 'stealth'});
    expect(
      sheet.skillModifier('perception'),
      sheet.abilityModifiers[Ability.wisdom]! + sheet.proficiencyBonus * 2,
    );
  });

  testWidgets('un Bardo que ya eligió su Pericia no vuelve a que se la pidan', (
    tester,
  ) async {
    await pumpLevelUp(
      tester,
      bard(
        level: 2,
        expertise: const {
          'class:bard:expertise-2': ['perception', 'stealth'],
        },
      ),
    );

    // Sube a 3: la Pericia del nivel 2 ya está resuelta y no hay otra hasta 9.
    expect(find.text('Pericia'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // --- Conjuros a elección --------------------------------------------------

  Character wizard({
    required int level,
    Map<String, List<String>> spellChoices = const {},
  }) => Character(
    id: 't-wizard',
    name: 'Prueba',
    raceId: 'human',
    classId: 'wizard',
    backgroundId: 'farmer',
    subclassId: 'evoker',
    level: level,
    assignedScores: {
      Ability.strength: 8,
      Ability.dexterity: 14,
      Ability.constitution: 12,
      Ability.intelligence: 16,
      Ability.wisdom: 10,
      Ability.charisma: 10,
    },
    hpPerLevel: List.filled(level, 6),
    chosenSkills: const ['arcana', 'history'],
    // Académico (nivel 2) es un cupo de Pericia: sin resolverlo el asistente
    // agrega —con razón— un paso que bloquea, y los bucles de abajo no
    // avanzarían.
    proficiencyChoices: const {
      'class:wizard:expertise-2': ['arcana'],
    },
    spellChoices: spellChoices,
  );

  /// Avanza tocando "Continuar" hasta que aparezca [target], con tope: un paso
  /// que bloquea haría girar el bucle para siempre y el fallo saldría como un
  /// timeout sin decir dónde se trabó.
  Future<void> advanceUntil(WidgetTester tester, String target) async {
    for (var i = 0; i < 12; i++) {
      if (find.text(target).evaluate().isNotEmpty) return;
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    final visto = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(40)
        .join(' | ');
    fail('no se llegó a "$target": algún paso previo está bloqueando.\n$visto');
  }

  /// Un Mago de 19 ya tiene resueltos los dos cupos de Maestría sobre Conjuros
  /// (nivel 18), así que lo único pendiente al subir a 20 son los Característicos.
  /// Paso Brumoso no sirve para el de nivel 2: es de acción adicional y la
  /// regla pide acción.
  Character wizard19() => wizard(
    level: 19,
    spellChoices: const {
      'class:wizard:spell-mastery-1': ['magic-missile'],
      'class:wizard:spell-mastery-2': ['invisibility'],
    },
  );

  testWidgets('subir un Mago a nivel 20 pide los Conjuros Característicos', (
    tester,
  ) async {
    await pumpLevelUp(tester, wizard19());

    expect(find.text('Conjuros a elección'), findsWidgets);

    // Avanza hasta el paso y comprueba que bloquea.
    await advanceUntil(tester, 'Conjuros que quedan siempre preparados');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Te faltan 2 conjuros para continuar.'), findsOneWidget);

    // Los Característicos ofrecen nivel 3. Los de nivel 1 y 2 que también se
    // ven son los pozos de Maestría sobre Conjuros, que comparten el paso.
    expect(
      find.widgetWithText(FilterChip, 'Bola de Fuego (Nv 3)'),
      findsOneWidget,
    );
    // Ningún cupo del Mago llega a nivel 4, así que no puede aparecer en
    // ninguno de los tres.
    expect(
      find.widgetWithText(FilterChip, 'Muro de Fuego (Nv 4)'),
      findsNothing,
    );
    // Paso Brumoso es de acción adicional: la regla de Maestría pide acción.
    expect(
      find.widgetWithText(FilterChip, 'Paso Brumoso (Nv 2)'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lo elegido se guarda y queda siempre preparado sin gastar cupo',
    (tester) async {
      Character? saved;
      await pumpLevelUp(tester, wizard19(), onDone: (c) => saved = c);

      await advanceUntil(tester, 'Conjuros que quedan siempre preparados');
      // Los tres cupos del Mago comparten el paso y el de nivel 3 queda abajo
      // del todo, fuera de la vista: sin `ensureVisible` el toque cae al vacío.
      for (final etiqueta in ['Bola de Fuego (Nv 3)', 'Volar (Nv 3)']) {
        final chip = find.widgetWithText(FilterChip, etiqueta);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await advanceUntil(tester, 'Confirmar nivel 20');
      await tester.tap(find.text('Confirmar nivel 20'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(
        saved!.spellChoices['class:wizard:signature-spells'],
        containsAll(['fireball', 'fly']),
      );

      final sheet = CharacterCompiler(repo).compile(saved!);
      expect(sheet.alwaysPreparedSpellIds, containsAll(['fireball', 'fly']));
      // No entran en `spellIds`: no gastan cupo de preparados.
      expect(saved!.spellIds, isNot(contains('fireball')));
      // Y traen su uso gratis por descanso corto.
      expect(
        sheet.resources.map((r) => r.id),
        containsAll(['innate-fireball', 'innate-fly']),
      );
    },
  );

  testWidgets('una clase sin conjuros a elección no ve el paso', (
    tester,
  ) async {
    // El paso tiene que aparecer solo donde hay algo que elegir: es genérico y
    // se cuela en cada subida si el gating está mal.
    await pumpLevelUp(tester, fighterL3());
    expect(find.text('Conjuros a elección'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los Conjuros Característicos no se re-preguntan una vez hechos', (
    tester,
  ) async {
    // Signature Spells no es reemplazable —la regla no da forma de cambiarlos—,
    // así que el cupo tiene que quedar completo y no bloquear.
    await pumpLevelUp(
      tester,
      wizard(
        level: 19,
        spellChoices: const {
          'class:wizard:signature-spells': ['fireball', 'fly'],
          'class:wizard:spell-mastery-1': ['magic-missile'],
          'class:wizard:spell-mastery-2': ['invisibility'],
        },
      ),
    );

    // Llega hasta el final sin que ningún paso pida conjuros: si bloqueara,
    // `advanceUntil` agota su tope y falla diciendo dónde se trabó.
    await advanceUntil(tester, 'Confirmar nivel 20');
    expect(find.textContaining('Te falta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Descubrimientos Mágicos se puede rehacer en cada nivel', (
    tester,
  ) async {
    // `replaceable: true`, así que el paso aparece aunque ya esté completo.
    final bardo = Character(
      id: 't-lore',
      name: 'Prueba',
      raceId: 'human',
      classId: 'bard',
      backgroundId: 'wayfarer',
      subclassId: 'college-lore',
      level: 6,
      assignedScores: {
        Ability.strength: 10,
        Ability.dexterity: 14,
        Ability.constitution: 12,
        Ability.intelligence: 12,
        Ability.wisdom: 10,
        Ability.charisma: 16,
      },
      hpPerLevel: List.filled(6, 8),
      chosenSkills: const ['perception', 'stealth', 'performance'],
      spellChoices: const {
        'subclass:college-lore:magical-discoveries': ['fireball', 'fly'],
      },
    );

    await pumpLevelUp(tester, bardo);
    expect(find.text('Conjuros a elección'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
