part of '../dashboard_screen.dart';

extension _DashboardActions on _DashboardScreenState {
  // --------------------------------------------------------------------------
  // Acciones
  // --------------------------------------------------------------------------

  Future<void> _openWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreationWizard(repo: repo, onCreate: controller.add),
      ),
    );
  }

  void _openSheet(Character c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Envuelta en el mismo punto de entrada donde de verdad importa
        // enterarse pronto: abrir un personaje es el lugar natural para ver
        // "che, te echaron de esta campaña" o similar.
        builder: (_) => PendingEventsGate(
          api: controller.api,
          child: SheetScreen(
            character: c,
            repo: repo,
            controller: controller,
            theme: widget.theme,
          ),
        ),
      ),
    );
  }

  void _openHomebrew() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomebrewScreen(
          repo: repo,
          store: widget.homebrew,
          // Una foto de las fichas, para que borrar homebrew pueda decir
          // quién lo está usando. Desde ahí no se toca ningún personaje, así
          // que no puede quedar vieja mientras la pantalla está abierta.
          characters: controller.characters,
        ),
      ),
    );
  }

  /// Entra al Modo DM. Es una pantalla más sobre el Navigator, como Homebrew:
  /// volver atrás es salir, y no queda ningún estado prendido que recordar.
  ///
  /// Envuelta en `PendingEventsGate` porque el chequeo del arranque de la app
  /// (ver `main.dart`) pasa una sola vez: si la pestaña ya estaba abierta y un
  /// jugador dejó de compartir mientras tanto, sin esto el DM no se entera
  /// hasta recargar la página entera.
  void _openDmMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PendingEventsGate(
          api: controller.api,
          child: DmModeScreen(api: controller.api, repo: repo),
        ),
      ),
    );
  }

  /// Las dos acciones de transferencia en un diálogo (antes era el menú del
  /// AppBar, que ya no existe con el panel lateral). "Abrir carpeta de
  /// exportación" no tiene sentido en el cliente web: cada exportación ya es
  /// una descarga del navegador (ver capacidad `web-client`).
  Future<void> _transferDialog() async {
    final action = await showDialog<String>(
      context: context,
      // `AppDialog` y no `SimpleDialog`: era uno de los tres que quedaron con el
      // molde de Material cuando la aplicación pasó al suyo. Las opciones van en
      // el cuerpo y el pie queda para salir, como en los selectores de la ficha.
      builder: (ctx) => AppDialog(
        title: 'Importar / Exportar',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Importar…'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Exportar respaldo completo'),
              onTap: () => Navigator.pop(ctx, 'backup'),
            ),
          ],
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'import':
        await _import();
      case 'backup':
        await _exportBackup();
    }
  }

  Future<void> _renameCharacter(Character c) async {
    final newName = await showRenameDialog(context, c.name);
    if (newName == null || newName == c.name) return;
    controller.replace(c.copyWith(name: newName));
  }

  Future<void> _confirmDelete(Character c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: context.palette.crimson,
        title: '¿Eliminar a ${c.name}?',
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Eliminar',
            primary: true,
            color: context.palette.crimson,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) await controller.remove(c);
  }

  Future<void> _exportCharacter(Character c) async {
    if (!_startOperation('Exportando personaje…')) return;
    try {
      final transfer = TransferService(controller.api);
      final bytes = await transfer.exportCharacter(c);
      browser.downloadBytes(
        bytes,
        fileName: transfer.characterExportFileName(c),
        mimeType: 'application/zip',
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo exportar el personaje: $e',
          tone: AppMessageTone.error,
        );
      }
    } finally {
      _finishOperation();
    }
  }

  Future<void> _exportBackup() async {
    if (!_startOperation('Creando respaldo…')) return;
    try {
      final settings = await SettingsService(controller.api).load();
      final transfer = TransferService(controller.api);
      final bytes = await transfer.exportBackup(
        controller.characters,
        homebrew: widget.homebrew.exportContent(),
        preferences: settings.toJson(),
      );
      browser.downloadBytes(
        bytes,
        fileName: transfer.backupFileName(),
        mimeType: 'application/zip',
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo crear el respaldo: $e',
          tone: AppMessageTone.error,
        );
      }
    } finally {
      _finishOperation();
    }
  }

  /// Sube el respaldo elegido tal cual al servidor (`POST /api/import`), que
  /// lo valida y lo aplica de forma atómica (ver capacidad
  /// `account-data-import`). A diferencia de la versión de escritorio, no
  /// hay una vista previa del contenido: el cliente ya no decodifica el ZIP,
  /// así que no puede mostrar qué trae antes de confirmarlo con el servidor.
  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
      dialogTitle: 'Elegí un respaldo (.zip)',
    );
    final file = picked?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Importar respaldo',
        content: Text(
          'Se van a agregar los personajes (y el homebrew y las preferencias, '
          'si el respaldo los incluye) de "${file!.name}" a esta cuenta. Los '
          'personajes existentes no se tocan; un id repetido se guarda como '
          'copia nueva.',
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Importar',
            primary: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!_startOperation('Importando respaldo…')) return;
    try {
      final summary = await controller.api.importBackup(file!.bytes!);
      await controller.load();
      await widget.homebrew.load();
      repo.addAll(widget.homebrew.toRepository());
      if (!mounted) return;
      showAppMessage(
        context,
        'Importados ${summary.charactersImported} personaje(s) y '
        '${summary.portraitsImported} retrato(s).',
        tone: AppMessageTone.success,
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'Error al importar: $e',
          tone: AppMessageTone.error,
        );
      }
    } finally {
      _finishOperation();
    }
  }

  bool _startOperation(String label) {
    if (_activeOperation != null) {
      showAppMessage(context, 'Ya hay una operación en curso.');
      return false;
    }
    _updateState(() => _activeOperation = label);
    return true;
  }

  void _finishOperation() {
    if (mounted) _updateState(() => _activeOperation = null);
  }

  // --------------------------------------------------------------------------
}
