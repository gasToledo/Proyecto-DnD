import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_models.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/class_visuals.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
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

  Widget harness(
    CharactersController ctrl,
    FakeApiServer server, {
    String? appVersion,
    AccountInfo? account,
    AppSettings? settings,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: DashboardScreen(
      repo: repo,
      controller: ctrl,
      homebrew: HomebrewStore(ApiClient(client: server.client)),
      account: account,
      settings: settings,
      appVersion: appVersion,
      onToggleTheme: () {},
    ),
  );

  /// Monta el dashboard con un roster de prueba en un viewport dado y deja
  /// vencer el debounce de guardado (400 ms) para no dejar timers pendientes.
  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await tester.pumpWidget(harness(ctrl, server));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('el panel lateral muestra la versión instalada', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await tester.pumpWidget(harness(ctrl, server, appVersion: '1.2.3'));
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

  /// Monta el dashboard con una cuenta dada, para las pruebas del pie.
  Future<FakeApiServer> pumpWithAccount(
    WidgetTester tester,
    AccountInfo? account, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await tester.pumpWidget(harness(ctrl, server, account: account));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    return server;
  }

  // Sin esto no hay forma de saber con qué cuenta estás entrando, que es
  // justo lo que importa cuando el navegador tiene más de una sesión abierta.
  testWidgets('el pie del panel muestra la cuenta de la sesión', (
    tester,
  ) async {
    await pumpWithAccount(
      tester,
      const AccountInfo(
        userId: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@example.org',
      ),
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.org'), findsOneWidget);
    // Carmesí, no el gris del resto del pie: es la única acción destructiva
    // del panel y tiene que distinguirse de «Cambiar tema».
    final logout = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('logout-button')),
    );
    expect(logout.style?.foregroundColor?.resolve({}), AppPalette.dark.crimson);
    expect(tester.takeException(), isNull);
  });

  // Una cuenta del proveedor sin nombre ni correo no puede dejar al usuario
  // sin poder salir.
  testWidgets('sin nombre ni correo queda el botón de salir', (tester) async {
    await pumpWithAccount(tester, const AccountInfo(userId: 'u1'));

    expect(find.byKey(const ValueKey('account-name')), findsNothing);
    expect(find.byKey(const ValueKey('account-email')), findsNothing);
    expect(find.byKey(const ValueKey('logout-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cerrar sesión llama al servidor y navega a donde este indique', (
    tester,
  ) async {
    final server = await pumpWithAccount(
      tester,
      const AccountInfo(userId: 'u1', name: 'Ada Lovelace'),
    );

    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pumpAndSettle();

    expect(server.logoutCalls, 1);
    // En la VM `redirectTo` es el stub que lanza `UnsupportedError`, así que
    // el aviso de error es la señal de que se llegó a navegar. En el build web
    // esa navegación es la que cierra también la sesión del proveedor.
    expect(
      find.textContaining('No se pudo cerrar la sesión'),
      findsOneWidget,
      reason: 'no se llegó a navegar al cierre de sesión del proveedor',
    );
  });

  testWidgets('sin cuenta el pie no aparece', (tester) async {
    await pumpWithAccount(tester, null);

    expect(find.byKey(const ValueKey('logout-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // La grilla reparte el ancho en columnas de a lo sumo `_kCardMaxExtent`, así
  // que subir ese máximo por sí solo no ensancha nada: si entra una columna
  // más, la tarjeta queda igual de chica. Lo que importa es que en una ventana
  // ancha la tarjeta —y con ella el retrato y los rótulos— crezca de verdad.
  testWidgets('la tarjeta crece en una ventana ancha', (tester) async {
    double medallionSize(WidgetTester t) =>
        t.widgetList<ClassMedallion>(find.byType(ClassMedallion)).first.size;

    await pumpDashboard(tester, const Size(700, 800));
    final narrow = medallionSize(tester);

    await pumpDashboard(tester, const Size(1920, 1080));
    final wide = medallionSize(tester);

    expect(
      wide,
      greaterThan(narrow),
      reason: 'la tarjeta no aprovecha el ancho de la ventana',
    );
    expect(tester.takeException(), isNull);
  });

  group('favorito y orden del roster', () {
    /// Monta el dashboard con dos personajes de nombre conocido y unos ajustes
    /// dados, y devuelve el servidor falso para poder mirar qué se guardó.
    Future<FakeApiServer> pumpRoster(
      WidgetTester tester,
      AppSettings settings,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = FakeApiServer();
      final ctrl = CharactersController(ApiClient(client: server.client))
        ..add(demoSagan())
        ..add(
          Character.fromJson(
            demoSagan().toJson()
              ..['id'] = 'zzz'
              ..['name'] = 'Zzz Ultimo',
          ),
        );
      await tester.pumpWidget(harness(ctrl, server, settings: settings));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      return server;
    }

    /// Nombres en el orden en que aparecen en la grilla, de arriba a abajo.
    List<String> rosterOrder(WidgetTester tester) {
      final names = ['Sagan "The Red"', 'Zzz Ultimo'];
      final found = [
        for (final n in names)
          if (find.text(n).evaluate().isNotEmpty)
            (n, tester.getTopLeft(find.text(n)).dx),
      ];
      found.sort((a, b) => a.$2.compareTo(b.$2));
      return [for (final f in found) f.$1];
    }

    testWidgets('el favorito encabeza el roster y se distingue', (
      tester,
    ) async {
      await pumpRoster(
        tester,
        AppSettings(favoriteCharacterId: 'zzz', sortMode: 'name'),
      );

      // Por nombre, "Zzz Ultimo" iría último; marcado como favorito va primero.
      expect(rosterOrder(tester).first, 'Zzz Ultimo');
      expect(find.byKey(const ValueKey('favorite-star')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('marcar un favorito lo guarda en los ajustes', (tester) async {
      final server = await pumpRoster(tester, AppSettings(sortMode: 'name'));

      await tester.tap(find.byTooltip('Acciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como favorito'));
      await tester.pumpAndSettle();

      expect(server.settings?['favoriteCharacterId'], isNotNull);
      expect(find.byKey(const ValueKey('favorite-star')), findsOneWidget);
    });

    // Sin persistir el modo, el orden manual se vería una sola vez y al
    // recargar volvería a ordenarse por nombre: el arrastre sería trabajo
    // perdido.
    testWidgets('el orden manual guardado se respeta al abrir', (tester) async {
      await pumpRoster(
        tester,
        AppSettings(characterOrder: ['zzz', 'sagan'], sortMode: 'manual'),
      );

      expect(rosterOrder(tester), ['Zzz Ultimo', 'Sagan "The Red"']);
      expect(tester.takeException(), isNull);
    });

    // Un personaje que nunca se arrastró (recién creado, o importado) no
    // aparece en el orden guardado: tiene que ir al final, no desaparecer.
    testWidgets('un personaje fuera del orden guardado va al final', (
      tester,
    ) async {
      await pumpRoster(
        tester,
        AppSettings(characterOrder: ['zzz'], sortMode: 'manual'),
      );

      expect(rosterOrder(tester), ['Zzz Ultimo', 'Sagan "The Red"']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ordenar por más recientes pone el último creado primero', (
      tester,
    ) async {
      await pumpRoster(tester, AppSettings(sortMode: 'dateAdded'));

      // "Zzz Ultimo" se agrega después de Sagan en `pumpRoster`.
      expect(rosterOrder(tester).first, 'Zzz Ultimo');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('sin versión resuelta no se muestra el rótulo', (tester) async {
    await pumpDashboard(tester, const Size(1400, 900));
    expect(find.byKey(const ValueKey('app-version')), findsNothing);
  });

  // En ancho, la marca la lleva la cabecera del panel lateral, que tiene 236
  // de ancho fijo: el subtítulo es largo y ahí es donde puede desbordar.
  testWidgets('el panel lateral muestra el nombre y el subtítulo', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1400, 900));

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('Milantus') &&
            w.text.toPlainText().contains('Asistente de Aventuras'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());

    await tester.pumpWidget(harness(ctrl, server));
    expect(find.text('Guardando…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Guardado'), findsOneWidget);
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

    // En este ancho el panel lateral se esconde en el Drawer, así que la marca
    // la lleva la barra superior: el nombre y el subtítulo tienen que estar los
    // dos, no solo el nombre.
    expect(find.text('Milantus'), findsOneWidget);
    expect(find.text('Asistente de Aventuras'), findsOneWidget);
    expect(find.text('Sagan "The Red"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
