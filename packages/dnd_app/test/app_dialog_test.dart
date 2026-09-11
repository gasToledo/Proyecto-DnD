import 'dart:io';

import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre un [AppDialog] sobre un andamio con el tema real.
///
/// Lo que devuelva la ruta se anota en [salida] cuando el diálogo se cierre,
/// que es después de que esta función haya vuelto: por eso una caja y no un
/// valor de retorno.
Future<void> _abrir(
  WidgetTester tester, {
  required List<DialogAction> Function(BuildContext ctx) actions,
  List<String?>? salida,
  double width = 480,
  Widget content = const Text('Cuerpo del diálogo.'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final elegido = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AppDialog(
                    title: 'Terminar combate',
                    width: width,
                    content: content,
                    actions: actions(ctx),
                  ),
                );
                salida?.add(elegido);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

List<DialogAction> _tresAcciones(BuildContext ctx) => [
  DialogAction(
    'Cancelar',
    keyHint: 'Esc',
    onPressed: () => Navigator.of(ctx).pop(),
  ),
  DialogAction(
    'Descartar sin guardar',
    onPressed: () => Navigator.of(ctx).pop('descartar'),
  ),
  DialogAction(
    'Terminar y guardar',
    primary: true,
    onPressed: () => Navigator.of(ctx).pop('guardar'),
  ),
];

/// La placa del diálogo: el `Material` que le pone el `Dialog`, que mide lo que
/// mide el contenido. `AppDialog` en cambio ocupa la pantalla entera, porque
/// abarca también el margen del velo.
final _placa = find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

void main() {
  testWidgets('el molde muestra el título, el cuerpo y una celda por acción', (
    tester,
  ) async {
    await _abrir(tester, actions: _tresAcciones);

    expect(find.text('Terminar combate'), findsOneWidget);
    expect(find.text('Cuerpo del diálogo.'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Descartar sin guardar'), findsOneWidget);
    expect(find.text('Terminar y guardar'), findsOneWidget);
    // La tecla se dibuja solo donde se la declaró.
    expect(find.text('Esc'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('cada celda devuelve lo suyo', (tester) async {
    final salida = <String?>[];

    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Descartar sin guardar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar']);

    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Terminar y guardar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar', 'guardar']);

    // Cancelar cierra sin resultado, que es lo que distingue «no hice nada» de
    // «elegí una de las dos salidas».
    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar', 'guardar', null]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra de acciones llega a los 48 px de blanco táctil', (
    tester,
  ) async {
    await _abrir(tester, actions: _tresAcciones);

    // §11.3: los objetivos táctiles siguen los mínimos de Material.
    for (final rotulo in [
      'Cancelar',
      'Descartar sin guardar',
      'Terminar y guardar',
    ]) {
      final celda = find.ancestor(
        of: find.text(rotulo),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(celda).height, 48, reason: rotulo);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('el ancho se topea en la medida de lectura', (tester) async {
    await _abrir(tester, actions: _tresAcciones);

    // Sin tope, el párrafo estiraba el diálogo hasta el ancho de la ventana:
    // ese era el defecto que el molde vino a arreglar.
    final ancho = tester.getSize(_placa).width;
    expect(ancho, 480);
    expect(ancho, lessThan(tester.view.physicalSize.width));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'en una ventana angosta el diálogo se achica en vez de desbordar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _abrir(tester, actions: _tresAcciones);

      expect(tester.getSize(_placa).width, lessThan(400));
      expect(tester.takeException(), isNull);
    },
  );

  // Los diálogos pasaron al molde propio en un solo commit y tres se escaparon,
  // porque nada lo verificaba: siguieron con la placa de Material hasta que
  // alguien los vio. Recorre el código y no la pantalla a propósito: un diálogo
  // que ningún test abre es justo el que se escapa.
  test('ningún diálogo de la aplicación usa el molde de Material', () {
    final crudo = RegExp(r'\b(SimpleDialog|AlertDialog)\(');
    final encontrados = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (crudo.hasMatch(line)) '${file.path}:${i + 1}',
    ];

    expect(encontrados, isEmpty, reason: 'usá AppDialog');
  });

  testWidgets('el molde es plano: sin elevación ni sombra', (tester) async {
    await _abrir(tester, actions: _tresAcciones);

    // La separación la hace el velo, no la elevación (§5.3). Material 3 lo
    // dibujaría con sombra y tinte de superficie si el tema no dijera nada.
    final dialogo = tester.widget<Dialog>(find.byType(Dialog));
    final tema = AppTheme.dark.dialogTheme;
    expect(dialogo.elevation ?? tema.elevation, 0);
    expect(tema.surfaceTintColor, Colors.transparent);
    expect(tema.shadowColor, Colors.transparent);

    expect(tester.takeException(), isNull);
  });
}
