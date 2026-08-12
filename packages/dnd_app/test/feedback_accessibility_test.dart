import 'dart:math';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

/// Contraste WCAG entre dos colores opacos.
double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  // La paleta se elige a mano; sin esto, ajustar un tono para que "quede
  // lindo" puede dejar los rótulos por debajo de AA sin que nadie se entere
  // hasta que alguien no los pueda leer.
  group('contraste de la paleta', () {
    void checkTheme(ThemeData theme, String name) {
      final palette = theme.extension<AppPalette>()!;
      final surface = theme.colorScheme.surface;
      final backgrounds = {
        'surface': surface,
        'plaque': palette.plaque,
        'scaffold': theme.scaffoldBackgroundColor,
      };

      for (final bg in backgrounds.entries) {
        // Texto normal: 4.5:1. `textMuted` lleva rótulos y hints, y el carmesí
        // los PG de la tarjeta, que son chicos.
        for (final fg in {
          'textMuted': palette.textMuted,
          'crimson': palette.crimson,
          'onSurfaceVariant': theme.colorScheme.onSurfaceVariant,
        }.entries) {
          expect(
            _contrast(fg.value, bg.value),
            greaterThanOrEqualTo(4.5),
            reason: '$name: ${fg.key} sobre ${bg.key} no llega a AA',
          );
        }
        // El oro solo lleva números grandes (24 px en `StatPlaque`) y bordes:
        // ahí el umbral de AA es 3:1. Sobre `surface` igual llega a 4.5, que
        // es donde aparece como texto corriente.
        expect(
          _contrast(palette.gold, bg.value),
          greaterThanOrEqualTo(3.0),
          reason: '$name: el oro sobre ${bg.key} no llega a 3:1',
        );
      }
      expect(_contrast(palette.gold, surface), greaterThanOrEqualTo(4.5));
      // El verde marca el tipo de acción en íconos: 3:1 alcanza.
      expect(_contrast(palette.verdant, surface), greaterThanOrEqualTo(3.0));
    }

    test(
      'el tema oscuro llega a AA',
      () => checkTheme(AppTheme.dark, 'oscuro'),
    );
    test('el tema claro llega a AA', () => checkTheme(AppTheme.light, 'claro'));

    // Lo que va encima del carmesí (texto de un botón de error, de un chip
    // secundario) también tiene que leerse: al aclarar el carmesí para los PG,
    // el blanco de antes dejó de servir en el tema oscuro.
    test('lo que va sobre carmesí se lee en los dos temas', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        expect(
          _contrast(theme.colorScheme.onError, theme.colorScheme.error),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });
  testWidgets('los avisos se anuncian como región viva', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showAppMessage(
                context,
                'Cambios guardados.',
                tone: AppMessageTone.success,
              ),
              child: const Text('Avisar'),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    await tester.tap(find.text('Avisar'));
    await tester.pump();

    expect(find.text('Cambios guardados.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Cambios guardados.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('las estadísticas exponen una etiqueta completa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: StatPlaque(label: 'Velocidad', value: '30'),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('Velocidad: 30'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('ajustes cabe en una ventana baja y permite recorrido por foco', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeApiServer()
      ..providers = [
        {
          'id': 'pollinations',
          'name': 'Pollinations',
          'supportsReference': false,
        },
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsDialog(api: ApiClient(client: server.client)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proveedor de retratos:'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });

  // Toda animación tiene que poder desactivarse: quien pide menos movimiento
  // suele hacerlo por mareo, no por gusto.
  testWidgets('las animaciones duran cero con movimiento reducido', (
    tester,
  ) async {
    late Duration reduced;
    late Duration normal;

    Widget probe(bool disableAnimations, void Function(Duration) sink) =>
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              sink(context.motion(const Duration(milliseconds: 220)));
              return const SizedBox.shrink();
            },
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Column(
          children: [
            probe(true, (d) => reduced = d),
            probe(false, (d) => normal = d),
          ],
        ),
      ),
    );

    expect(reduced, Duration.zero);
    expect(normal, const Duration(milliseconds: 220));
  });

  // La barra de PG interpola, así que con movimiento reducido tiene que
  // mostrar el valor final de una vez, no quedarse a medio camino.
  testWidgets('la barra de PG llega a su valor sin animación', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ThinBar(
              ratio: 0.4,
              color: AppPalette.dark.crimson,
              track: AppPalette.dark.plaque,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.4, 0.001));
    expect(tester.takeException(), isNull);
  });

  // El pie del panel lateral mide 208 (236 menos 14 de padding a cada lado):
  // los tres segmentos y el idioma tienen que entrar ahí sin desbordar, y cada
  // segmento tiene que ser un objetivo táctil de 48 px.
  group('preferencias de presentación', () {
    const contentWidth = 236.0 - 14 * 2;

    Future<AppThemeController> pump(WidgetTester tester) async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: contentWidth,
                child: DisplayPreferences(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('entran en el ancho del panel', (tester) async {
      await pump(tester);

      final group = tester.getSize(find.byType(SegmentedButton<ThemeMode>));
      expect(group.width, lessThanOrEqualTo(contentWidth));
      expect(
        group.height,
        greaterThanOrEqualTo(40),
        reason: 'los segmentos quedaron por debajo de un objetivo táctil',
      );
      expect(
        tester.getSize(find.text('Español')).width,
        lessThan(contentWidth),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar un segmento cambia el tema y marca cuál está activo', (
      tester,
    ) async {
      final controller = await pump(tester);
      expect(controller.value, ThemeMode.dark);

      await tester.tap(find.byTooltip('Seguir el tema del sistema'));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.system);
      expect(
        tester
            .widget<SegmentedButton<ThemeMode>>(
              find.byType(SegmentedButton<ThemeMode>),
            )
            .selected,
        {ThemeMode.system},
      );
    });

    // El idioma se muestra aunque no se pueda cambiar; lo que no puede pasar es
    // que parezca interactivo sin decir por qué no lo es.
    testWidgets('el idioma se anuncia como no disponible todavía', (
      tester,
    ) async {
      await pump(tester);
      final semantics = tester.ensureSemantics();

      expect(find.text('Español'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Idioma: Español. Todavía no hay otros idiomas disponibles.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  // Un botón que solo es un ícono no tiene nombre para un lector de pantalla
  // si nadie se lo pone: el tooltip es lo que se lo da.
  testWidgets('los botones de solo ícono tienen nombre accesible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SpendRecoverButtons(
            onSpend: () {},
            onRecover: () {},
            spendTooltip: 'Gastar un uso',
            recoverTooltip: 'Recuperar un uso',
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    // El tooltip llega al árbol de semántica como `tooltip`: es lo que anuncia
    // un lector de pantalla al posarse sobre un botón que solo tiene ícono.
    for (final label in ['Gastar un uso', 'Recuperar un uso']) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSemantics(find.byTooltip(label)).tooltip, label);
    }
    semantics.dispose();
  });

  testWidgets('un fallo explica qué pasó y deja el detalle a un toque', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppErrorView(
            message: 'No se pudo conectar con el servidor.',
            hint: 'Revisá la conexión y reintentá.',
            details: 'SocketException: connection refused (errno = 111)',
            onRetry: () => retried++,
          ),
        ),
      ),
    );

    // El detalle técnico no es el mensaje principal: está, pero plegado.
    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);

    await tester.tap(find.text('Ver detalles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SocketException'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    expect(retried, 1);
  });
}
