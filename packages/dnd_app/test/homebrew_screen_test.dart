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

  testWidgets('el panel abre las ocho categorías y el formulario de armas', (
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

    expect(find.text('Contenido homebrew'), findsOneWidget);
    // Se entra por la portada, no por Armas.
    expect(find.text('Tu taller está vacío'), findsOneWidget);

    const categories = {
      'Armas': 'Agregar arma',
      'Armaduras': 'Agregar armadura',
      'Objetos': 'Agregar objeto',
      'Dotes': 'Agregar dote',
      'Razas': 'Agregar raza',
      'Trasfondos': 'Agregar trasfondo',
      'Conjuros': 'Agregar conjuro',
      'Criaturas': 'Agregar criatura',
    };
    // En una ventana normal las ocho entran en el panel sin desplazarlo, que
    // es justamente lo que no pasaba con la barra de pestañas. La primera
    // aparición del rótulo es la del panel; la segunda, cuando está, el
    // título del contenido.
    for (final entry in categories.entries) {
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar arma'));
    await tester.pumpAndSettle();

    expect(find.text('Arma'), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Dado de daño (p.ej. 1d8)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // La portada existe para contestar «¿qué tengo?» sin recorrer categoría por
  // categoría, así que lo que se prueba es el conteo, no el dibujo.
  testWidgets('la portada cuenta lo que hay y la tarjeta abre su categoría', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
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
      )
      ..weapons['hb-maza'] = const Weapon(
        id: 'hb-maza',
        name: 'Maza corta',
        source: ContentSource.homebrew,
        category: 'simple',
        damageDice: '1d6',
        damageType: 'bludgeoning',
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu taller'), findsOneWidget);
    expect(find.textContaining('2 entradas propias'), findsOneWidget);
    // La muestra de la tarjeta sale ordenada por nombre, igual que la lista.
    expect(find.text('Hoz de guerra · Maza corta'), findsOneWidget);
    // El panel y la tarjeta cuentan lo mismo, que es de dónde sale la cifra:
    // las otras siete categorías están en cero.
    expect(find.text('2'), findsNWidgets(2));

    // La tarjeta es la segunda aparición de «Armas»; la primera es el panel.
    await tester.tap(find.text('Armas').last);
    await tester.pumpAndSettle();

    expect(find.text('Agregar arma'), findsOneWidget);
    expect(find.text('Hoz de guerra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Una grilla de ocho ceros no explica para qué sirve la pantalla.
  testWidgets('sin nada propio, la portada explica qué es el homebrew', (
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

    expect(find.text('Tu taller está vacío'), findsOneWidget);
    expect(find.text('Importar un pack'), findsOneWidget);
    expect(find.text('Tu taller'), findsNothing);

    await tester.tap(find.text('Empezar por un arma'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar arma'), findsOneWidget);
    expect(find.text('Todavía no agregaste nada en armas.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Una pantalla de homebrew con [store] y, si hace falta, las fichas que
  /// miran el borrado.
  Future<void> pumpHomebrew(
    WidgetTester tester,
    HomebrewStore store, {
    List<Character> characters = const [],
    Size size = const Size(1000, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store, characters: characters),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Un store que **guarda de verdad**: sin servidor falso, cualquier
  /// escritura falla y la copia nunca llega al store.
  HomebrewStore fakeStore() =>
      HomebrewStore(ApiClient(client: FakeApiServer().client));

  HomebrewStore storeWithHoz() => fakeStore()
    ..weapons['hb-hoz'] = const Weapon(
      id: 'hb-hoz',
      name: 'Hoz de guerra',
      source: ContentSource.homebrew,
      category: 'martial',
      damageDice: '1d8',
      damageType: 'slashing',
      properties: ['finesse'],
      weight: 3,
      costCp: 1500,
    );

  // Un peso, un precio o un dado existen para compararse con los de la fila de
  // al lado; en una línea de prosa gris eso no se puede hacer.
  testWidgets('la fila separa lo cualitativo de lo que se compara', (
    tester,
  ) async {
    await pumpHomebrew(tester, storeWithHoz());
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    // Pills.
    expect(find.text('Marcial'), findsOneWidget);
    expect(find.text('Sutil'), findsOneWidget);
    expect(find.text(DamageType.labelFor('slashing')), findsOneWidget);
    // Cifras, con su rótulo.
    expect(find.text('DAÑO'), findsOneWidget);
    expect(find.text('1d8'), findsOneWidget);
    expect(find.text('PESO'), findsOneWidget);
    expect(find.text('PRECIO'), findsOneWidget);
    expect(find.text(formatCost(1500)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicar una entrada propia abre una copia con id nuevo', (
    tester,
  ) async {
    final store = storeWithHoz();
    await pumpHomebrew(tester, store, size: const Size(1000, 1200));
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Duplicar Hoz de guerra'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Nombre'),
      findsOneWidget,
      reason: 'se abrió el formulario',
    );
    expect(find.text('Hoz de guerra (copia)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // El original sigue estando: duplicar no es renombrar.
    expect(store.weapons.length, 2);
    expect(store.weapons['hb-hoz']?.name, 'Hoz de guerra');
    final copy = store.weapons.values.firstWhere((w) => w.id != 'hb-hoz');
    expect(copy.name, 'Hoz de guerra (copia)');
    expect(copy.damageDice, '1d8');
    expect(copy.source, ContentSource.homebrew);
  });

  // Arrancar de la espada larga y cambiarle dos campos es como nace casi todo
  // el homebrew real; el formulario en blanco es el camino largo.
  testWidgets('duplicar del catálogo trae la entrada oficial completa', (
    tester,
  ) async {
    final store = fakeStore();
    final official = repo.weapons['dagger']!;
    await pumpHomebrew(tester, store, size: const Size(1000, 1200));
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duplicar del catálogo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, official.name);
    await tester.pumpAndSettle();
    await tester.tap(find.text(official.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final copy = store.weapons.values.single;
    expect(copy.name, '${official.name} (copia)');
    expect(copy.source, ContentSource.homebrew);
    expect(copy.id, isNot(official.id));
    // Lo que el formulario no muestra tiene que llegar igual: una copia a la
    // que le falten campos no es una copia.
    expect(copy.damageDice, official.damageDice);
    expect(copy.damageType, official.damageType);
    expect(copy.properties, official.properties);
    expect(copy.weight, official.weight);
    expect(copy.costCp, official.costCp);
  });

  // «Los personajes que ya lo estén usando» asusta sin informar: lo que hace
  // falta saber es cuáles.
  testWidgets('borrar nombra las fichas que usan la entrada', (tester) async {
    final store = storeWithHoz();
    final character = Character(
      id: 'grommash',
      name: 'Grommash',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 10},
      hpPerLevel: const [10],
      equippedWeaponIds: const ['hb-hoz'],
    );
    await pumpHomebrew(tester, store, characters: [character]);
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar Hoz de guerra'));
    await tester.pumpAndSettle();

    expect(find.text('Lo usa 1 ficha:'), findsOneWidget);
    expect(find.text('Grommash'), findsOneWidget);
    final klass = repo.characterClass('fighter')!.name;
    expect(find.text('$klass 1'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.weapons.containsKey('hb-hoz'), isTrue);
  });

  // Y el contrario informa igual: nadie la usa es permiso para borrar.
  testWidgets('borrar algo que nadie usa lo dice', (tester) async {
    await pumpHomebrew(tester, storeWithHoz());
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar Hoz de guerra'));
    await tester.pumpAndSettle();

    expect(find.text('Ninguna de tus fichas lo está usando.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // El buscador es global a propósito: con contenido propio uno se acuerda del
  // nombre, no de en qué categoría lo guardó.
  testWidgets('buscar cruza las categorías y agrupa lo que encuentra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = HomebrewStore(ApiClient())
      ..weapons['hb-hoz'] = const Weapon(
        id: 'hb-hoz',
        name: 'Hoz del faro',
        source: ContentSource.homebrew,
        category: 'martial',
        damageDice: '1d8',
        damageType: 'slashing',
      )
      ..weapons['hb-maza'] = const Weapon(
        id: 'hb-maza',
        name: 'Maza corta',
        source: ContentSource.homebrew,
        category: 'simple',
        damageDice: '1d6',
        damageType: 'bludgeoning',
      )
      ..items['hb-amuleto'] = const Item(
        id: 'hb-amuleto',
        name: 'Amuleto del Fáro',
        source: ContentSource.homebrew,
        category: 'gear',
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'faro');
    await tester.pumpAndSettle();

    expect(find.text('2 resultados'), findsOneWidget);
    // Los grupos llevan el rótulo de su categoría, en versalitas.
    expect(find.text('ARMAS'), findsOneWidget);
    expect(find.text('OBJETOS'), findsOneWidget);
    expect(find.text('Hoz del faro'), findsOneWidget);
    // La tilde no esconde una entrada: `foldForSearch` pliega acentos.
    expect(find.text('Amuleto del Fáro'), findsOneWidget);
    expect(find.text('Maza corta'), findsNothing);

    // El panel deja de contar lo que hay y pasa a contar lo que coincide.
    expect(find.text('Coincidencias'.toUpperCase()), findsOneWidget);

    // Elegir una categoría cancela la búsqueda: pedir Armas y seguir viendo
    // resultados mezclados sería contestar otra cosa.
    await tester.tap(find.text('Armas').first);
    await tester.pumpAndSettle();

    expect(find.text('Maza corta'), findsOneWidget);
    expect(find.text('2 resultados'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin coincidencias lo dice y ofrece limpiar la búsqueda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = HomebrewStore(ApiClient())
      ..weapons['hb-maza'] = const Weapon(
        id: 'hb-maza',
        name: 'Maza corta',
        source: ContentSource.homebrew,
        category: 'simple',
        damageDice: '1d6',
        damageType: 'bludgeoning',
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'grifo');
    await tester.pumpAndSettle();

    // «Nada coincide» pide corregir la búsqueda, no crear contenido: por eso
    // no es el mismo vacío que el de una categoría sin nada.
    expect(
      find.text('Nada de tu contenido coincide con «grifo».'),
      findsOneWidget,
    );

    await tester.tap(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();

    expect(find.text('Tu taller'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // En una ventana angosta el panel se pliega al Drawer, y navegar desde ahí
  // tiene que cerrarlo: si queda abierto, tapa el contenido que se acaba de
  // pedir.
  testWidgets('angosto, el panel va al Drawer y se cierra al navegar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: HomebrewStore(ApiClient())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criaturas'), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criaturas'));
    await tester.pumpAndSettle();

    // Angosto el botón se queda con el verbo: qué se agrega lo dice el título
    // que tiene al lado.
    expect(find.text('Criaturas'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Portada'), findsNothing, reason: 'el Drawer se cerró');
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra y permite borrar homebrew histórico inválido', (
    tester,
  ) async {
    final server = FakeApiServer();
    server.homebrew['weapons'] = {
      'broken': {'id': 'broken', 'name': 'Rota', 'source': 'homebrew'},
    };
    final store = HomebrewStore(ApiClient(client: server.client));
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomebrewScreen(repo: repo, store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 entrada no se pudo cargar'), findsOneWidget);
    await tester.tap(find.text('1 entrada no se pudo cargar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Borrar entrada inválida'));
    await tester.pumpAndSettle();

    expect(store.loadIssues, isEmpty);
    expect(server.homebrew['weapons'], isEmpty);
  });

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
    await tester.tap(find.text('Armas').first);
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
    // La maestría se elegía escribiendo el id en inglés («sap»), con el
    // glosario traducido ya en el motor y usado por la ficha.
    expect(find.text('Sin maestría'), findsOneWidget);
    expect(find.text('sap'), findsNothing);
  });

  // El glosario de maestrías es cerrado, pero `Weapon.mastery` acepta cualquier
  // cadena a propósito: un pack importado puede traer una propia. El
  // desplegable no puede borrarla por el solo hecho de abrir el formulario.
  testWidgets('la maestría se elige traducida y guarda el id en inglés', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Weapon? guardada;
    Weapon porra(String? mastery) => Weapon(
      id: 'hb-porra',
      name: 'Porra pesada',
      source: ContentSource.homebrew,
      category: 'simple',
      damageDice: '1d6',
      damageType: 'bludgeoning',
      weight: 2,
      costCp: 100,
      mastery: mastery,
    );

    Future<void> abrir(Weapon inicial) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async => guardada = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeaponForm(initial: inicial),
                  ),
                ),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
    }

    // Una maestría del glosario se muestra por su nombre del PHB, nunca por el
    // id, y vuelve a guardarse como id.
    await abrir(porra('sap'));
    expect(find.text(weaponMasteries['sap']!.name), findsOneWidget);
    expect(find.text('sap'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(guardada?.mastery, 'sap');

    // Una maestría ajena al glosario se conserva, marcada como desconocida.
    await abrir(porra('arrancar'));
    expect(find.text('arrancar (desconocido)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(guardada?.mastery, 'arrancar');

    // Sin maestría se guarda como null y no como cadena vacía.
    await abrir(porra(null));
    expect(find.text('Sin maestría'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(guardada?.mastery, isNull);
    expect(tester.takeException(), isNull);
  });

  // Las bases permitidas se escribían como una lista de ids del catálogo
  // separados por coma: el último campo del homebrew que pedía conocer la
  // estructura interna de los datos.
  testWidgets('las bases permitidas se eligen por nombre y según la familia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Item? guardado;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => guardado = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ItemForm(repo: repo)),
              ),
              child: const Text('Crear objeto'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Crear objeto'));
    await tester.pumpAndSettle();

    // El nombre se escribe ahora: el formulario scrollea y el campo se destruye
    // en cuanto se baja hasta los chips.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Daga rúnica',
    );
    await tester.pumpAndSettle();

    // Sin objeto base no hay nada que restringir: el bloque no está.
    expect(find.text('BASES PERMITIDAS'), findsNothing);

    Future<void> elegirFamilia(String label) async {
      final campo = find.ancestor(
        of: find.text('Objeto base'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      await tester.tap(campo);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await elegirFamilia('Arma');
    expect(find.text('BASES PERMITIDAS'), findsOneWidget);
    // Nombres del catálogo, no ids, y solo de la familia elegida.
    final daga = repo.weapon('dagger')!;
    expect(find.text(daga.name), findsWidgets);
    expect(find.text('dagger'), findsNothing);
    expect(find.text(repo.armorPiece('chain-mail')!.name), findsNothing);
    expect(
      find.textContaining('sirve cualquiera de la familia'),
      findsOneWidget,
    );

    final chip = find.widgetWithText(FilterChip, daga.name);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.textContaining('Solo se va a poder usar'), findsOneWidget);

    // Cambiar de familia no puede dejar guardada una base de la anterior: el
    // motor la rechazaría y nada en la pantalla la mostraría.
    await elegirFamilia('Armadura');
    expect(find.text(daga.name), findsNothing);

    await elegirFamilia('Arma');
    expect(tester.widget<FilterChip>(chip).selected, isFalse);

    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // Lo que se guarda sigue siendo el id, que es el contrato con el motor.
    expect(guardado?.eligibleBaseItemIds, ['dagger']);
    expect(guardado?.baseItemKind, 'weapon');
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('Armas').first);
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

  /// Abre un formulario de criatura y devuelve lo que se guardó.
  Future<Creature?> runCreatureForm(
    WidgetTester tester, {
    Creature? initial,
    Future<void> Function(WidgetTester tester)? edit,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Creature? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => saved = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatureForm(initial: initial),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    if (edit != null) await edit(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    return saved;
  }

  // El interruptor apagado es la frontera de la fase: un monstruo inventado
  // para la mesa no tiene por qué aparecer entre las formas que puede tomar el
  // druida de la partida.
  testWidgets('una criatura nueva no queda disponible para personajes', (
    tester,
  ) async {
    final saved = await runCreatureForm(
      tester,
      edit: (tester) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre').first,
          'Espanto del pantano',
        );
      },
    );

    expect(saved?.availableToCharacters, isFalse);
    expect(saved?.source, ContentSource.homebrew);
    expect(tester.takeException(), isNull);
  });

  // El tipo manda el género de la línea de perfil: «Bestia Mediana» pero
  // «Gigante Mediano». Compuesta mal se lee como un error de tipeo del catálogo.
  testWidgets('la línea de perfil concuerda con el tipo elegido', (
    tester,
  ) async {
    final saved = await runCreatureForm(
      tester,
      edit: (tester) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre').first,
          'Bruto',
        );
        await tester.tap(find.text('Monstruosidad').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gigante').last);
        await tester.pumpAndSettle();
      },
    );

    expect(saved?.kind, 'Gigante Mediano');
    expect(saved?.type, CreatureType.giant);
  });

  // El formulario no edita salvaciones ni habilidades (ver el `ponytail:` de
  // `creature_form.dart`): tocar el nombre de una criatura importada no puede
  // vaciárselas por la espalda.
  testWidgets('editar conserva lo que el formulario no muestra', (
    tester,
  ) async {
    const original = Creature(
      id: 'hb-quimera',
      name: 'Quimera del páramo',
      source: ContentSource.homebrew,
      type: CreatureType.monstrosity,
      size: CreatureSize.large,
      ac: '14',
      hp: '45',
      hitDice: '6d10 + 12',
      speed: '40 pies',
      cr: 0.25,
      savingThrows: {Ability.constitution: 5},
      skills: {Skill.perception: 4},
    );

    final saved = await runCreatureForm(tester, initial: original);

    expect(saved?.id, 'hb-quimera');
    expect(saved?.savingThrows, original.savingThrows);
    expect(saved?.skills, original.skills);
    expect(saved?.hitDice, '6d10 + 12');
    expect(saved?.cr, 0.25);
  });

  testWidgets('unos dados de golpe ilegibles frenan el guardado', (
    tester,
  ) async {
    final saved = await runCreatureForm(
      tester,
      edit: (tester) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre').first,
          'Cosa',
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Dados de golpe (opcional, p.ej. 2d6 + 2)',
          ),
          'un montón',
        );
      },
    );

    expect(saved, isNull);
    expect(find.textContaining('Formato inválido'), findsOneWidget);
  });
}
