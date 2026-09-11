import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/portrait_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

/// La pantalla arma dos caminos —generar y subir— y antes convivían apilados en
/// el mismo formulario. Lo que se prueba acá es el ruteo entre ambos, que es lo
/// único con ramas: el prompt ya lo cubre `portrait_test.dart`.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Future<FakeApiServer> pumpScreen(
    WidgetTester tester, {
    required List<Map<String, dynamic>> providers,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeApiServer()..providers = providers;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PortraitScreen(
          character: demoSagan(),
          repo: repo,
          api: ApiClient(client: server.client),
          onUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  const pollinations = {
    'id': 'pollinations',
    'name': 'Pollinations',
    'supportsReference': false,
  };
  const azure = {'id': 'azure', 'name': 'Azure', 'supportsReference': true};

  testWidgets('con proveedores abre en generar y deja pasar a subir', (
    tester,
  ) async {
    await pumpScreen(tester, providers: [pollinations, azure]);

    // Arranca en IA: se ven los dos motores y el selector de estilo.
    expect(find.text('Pollinations'), findsOneWidget);
    expect(find.text('Azure'), findsOneWidget);
    expect(find.text('Arte digital de fantasía'), findsOneWidget);
    expect(find.text('Importar imagen desde archivo'), findsNothing);

    await tester.tap(find.text('Subir imagen'));
    await tester.pumpAndSettle();

    expect(find.text('Importar imagen desde archivo'), findsOneWidget);
    // Y los controles de generación se fueron con la pestaña, en vez de
    // seguir apilados debajo como antes.
    expect(find.text('Arte digital de fantasía'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin proveedores arranca en subir y no ofrece generar', (
    tester,
  ) async {
    await pumpScreen(tester, providers: const []);

    expect(find.text('Importar imagen desde archivo'), findsOneWidget);
    // La pestaña de IA ni siquiera aparece: no hay con qué generar.
    expect(find.text('Generar con IA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('elegir un proveedor lo deja fijado como predeterminado', (
    tester,
  ) async {
    // Lo hacía el diálogo de ajustes, que se sacó de esta pantalla por
    // redundante: si la tarjeta no lo guarda, la elección se pierde al salir.
    final server = await pumpScreen(tester, providers: [pollinations, azure]);
    expect(server.settings?['imageProvider'], isNot('azure'));

    await tester.tap(find.text('Azure'));
    await tester.pumpAndSettle();

    expect(server.settings?['imageProvider'], 'azure');
    expect(tester.takeException(), isNull);
  });

  // El rótulo vivía solo en el placeholder, que se borra con la primera letra:
  // a mitad de escribir, el campo quedaba sin decir para qué era.
  testWidgets('el campo de detalles conserva su rótulo al escribir', (
    tester,
  ) async {
    await pumpScreen(tester, providers: [pollinations]);

    final campo = find.widgetWithText(TextField, 'Detalles adicionales');
    expect(campo, findsOneWidget);

    await tester.enterText(campo, 'una cicatriz en la ceja');
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Detalles adicionales'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la referencia solo se ofrece si el proveedor la admite', (
    tester,
  ) async {
    await pumpScreen(tester, providers: [pollinations, azure]);

    expect(find.text('Elegir imagen…'), findsNothing);

    await tester.tap(find.text('Azure'));
    await tester.pumpAndSettle();

    expect(find.text('Elegir imagen…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Guardar un retrato nuevo nunca borró los anteriores: `_use` los antepone en
  // `portraitPaths` y el almacén no tiene `delete`. Lo que faltaba era poder
  // verlos, así que quien probaba otro aspecto creía perder el de antes.
  group('retratos anteriores', () {
    /// Abre la pantalla desde otra ruta —igual que la ficha— para que el `pop`
    /// de confirmar tenga adónde volver.
    Future<void> abrir(
      WidgetTester tester,
      Character personaje,
      ValueChanged<Character> onUpdated,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = FakeApiServer()..providers = const [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PortraitScreen(
                      character: personaje,
                      repo: repo,
                      api: ApiClient(client: server.client),
                      onUpdated: onUpdated,
                    ),
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
    }

    testWidgets('se puede volver a uno anterior sin subir nada', (
      tester,
    ) async {
      // El primero es el que se muestra; los otros dos son los que antes no
      // se veían en ningún lado.
      const actual = 'sagan/2.png';
      const anterior = 'sagan/1.png';
      const primero = 'sagan/0.png';
      Character? guardado;
      await abrir(
        tester,
        demoSagan().copyWith(portraitPaths: [actual, anterior, primero]),
        (c) => guardado = c,
      );

      expect(find.text('RETRATOS GUARDADOS'), findsOneWidget);
      for (final clave in [actual, anterior, primero]) {
        expect(find.byKey(ValueKey('portrait-history-$clave')), findsOneWidget);
      }
      // Mirar no compromete nada: no hay botón hasta elegir uno distinto.
      expect(find.text('Volver a este retrato'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('portrait-history-$anterior')),
      );
      await tester.pumpAndSettle();
      expect(guardado, isNull, reason: 'tocar la miniatura solo lo muestra');

      await tester.tap(find.text('Volver a este retrato'));
      await tester.pumpAndSettle();

      // Pasa adelante sin duplicarse ni perder a nadie: sigue siendo historial.
      expect(guardado?.portraitPaths, [anterior, actual, primero]);
      expect(
        find.text('Abrir'),
        findsOneWidget,
        reason: 'la pantalla se cerró',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin retratos guardados no hay tira', (tester) async {
      await abrir(tester, demoSagan(), (_) {});

      expect(find.text('RETRATOS GUARDADOS'), findsNothing);
      expect(find.text('Borrar este retrato'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Guardar nunca borraba, así que cada retrato que no gustaba quedaba
    // ocupando el disco para siempre.
    testWidgets('borrar pide confirmación y saca el retrato y su prompt', (
      tester,
    ) async {
      const actual = 'sagan/1.png';
      const otro = 'sagan/0.png';
      Character? guardado;
      // El almacén falso no tiene estos archivos, así que el borrado responde
      // 404: sirve también para ver que eso no traba soltar la clave.
      await abrir(
        tester,
        demoSagan().copyWith(
          portraitPaths: const [actual, otro],
          portraitPrompts: const {
            actual: 'prompt del actual',
            otro: 'prompt del otro',
          },
        ),
        (c) => guardado = c,
      );

      await tester.tap(find.text('Borrar este retrato'));
      await tester.pumpAndSettle();
      expect(find.text('Borrar retrato'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(guardado, isNull, reason: 'cancelar no toca nada');

      await tester.tap(find.text('Borrar este retrato'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      // Sin nada en vista previa, lo que se borra es el actual.
      expect(guardado?.portraitPaths, [otro]);
      expect(guardado?.portraitPrompts, {otro: 'prompt del otro'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('el prompt usado se lee en la misma tarjeta', (tester) async {
      const generado = 'sagan/1.png';
      const subido = 'sagan/0.png';
      await abrir(
        tester,
        demoSagan().copyWith(
          portraitPaths: const [generado, subido],
          portraitPrompts: const {generado: 'una guerrera de armadura roja'},
        ),
        (_) {},
      );

      expect(find.text('PROMPT USADO'), findsOneWidget);
      expect(find.text('una guerrera de armadura roja'), findsOneWidget);

      // Un retrato subido desde un archivo no tiene prompt que mostrar.
      await tester.tap(find.byKey(const ValueKey('portrait-history-$subido')));
      await tester.pumpAndSettle();
      expect(find.text('PROMPT USADO'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar el retrato actual no ofrece volver a él', (
      tester,
    ) async {
      const actual = 'sagan/1.png';
      await abrir(
        tester,
        demoSagan().copyWith(portraitPaths: [actual, 'sagan/0.png']),
        (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('portrait-history-$actual')));
      await tester.pumpAndSettle();
      expect(find.text('Volver a este retrato'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con un solo retrato la tira aparece para poder borrarlo', (
      tester,
    ) async {
      await abrir(
        tester,
        demoSagan().copyWith(portraitPaths: const ['sagan/0.png']),
        (_) {},
      );

      // No hay adónde volver, pero sí qué borrar.
      expect(find.text('RETRATOS GUARDADOS'), findsOneWidget);
      expect(find.text('Volver a este retrato'), findsNothing);
      expect(find.text('Borrar este retrato'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
