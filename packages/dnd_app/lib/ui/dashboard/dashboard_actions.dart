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
        builder: (_) => SheetScreen(
          character: c,
          repo: repo,
          controller: controller,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  void _openHomebrew() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomebrewScreen(repo: repo, store: widget.homebrew),
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
      builder: (ctx) => SimpleDialog(
        title: const Text('Importar / Exportar'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'import'),
            child: const Text('Importar…'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'backup'),
            child: const Text('Exportar respaldo completo'),
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
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar a ${c.name}?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Importar respaldo'),
        content: Text(
          'Se van a agregar los personajes (y el homebrew y las preferencias, '
          'si el respaldo los incluye) de "${file!.name}" a esta cuenta. Los '
          'personajes existentes no se tocan; un id repetido se guarda como '
          'copia nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
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
