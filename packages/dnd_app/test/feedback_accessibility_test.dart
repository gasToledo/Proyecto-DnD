import 'dart:io';

import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/data/transfer_service.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/import_dialog.dart';
import 'package:dnd_app/ui/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTransferService extends TransferService {
  @override
  Future<Directory> exportsDir() async => Directory(r'C:\FichasDnD\exports');

  @override
  Future<List<File>> listExportFiles() async => const [];
}

class _RetryTransferService extends _MemoryTransferService {
  var attempts = 0;

  @override
  Future<List<File>> listExportFiles() async {
    attempts++;
    if (attempts == 1) throw const FileSystemException('sin permisos');
    return const [];
  }
}

class _MemorySettingsService extends SettingsService {
  AppSettings settings = AppSettings();

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;
}

void main() {
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

  testWidgets(
    'importación cabe en una ventana baja y distingue el estado vacío',
    (tester) async {
      tester.view.physicalSize = const Size(520, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ImportDialog(transfer: _MemoryTransferService()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay archivos exportados aún.'), findsOneWidget);
      await tester.tap(find.text('Importar ruta'));
      await tester.pump();
      expect(find.text('Ingresá una ruta para importar.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('importación permite reintentar si falla la carpeta', (
    tester,
  ) async {
    final transfer = _RetryTransferService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ImportDialog(transfer: transfer)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo leer'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(transfer.attempts, 2);
    expect(find.text('No hay archivos exportados aún.'), findsOneWidget);
  });

  testWidgets('ajustes cabe en una ventana baja y permite recorrido por foco', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _MemorySettingsService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SettingsDialog(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proveedor de retratos:'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
