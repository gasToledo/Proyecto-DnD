part of '../dashboard_screen.dart';

extension _DashboardActions on _DashboardScreenState {
  // --------------------------------------------------------------------------
  // Acciones
  // --------------------------------------------------------------------------

  Future<void> _openWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreationWizard(
          repo: repo,
          onCreate: controller.add,
          draftStore: CreationDraftStore(),
        ),
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

  /// Las tres acciones de transferencia en un diálogo (antes era el menú del
  /// AppBar, que ya no existe con el panel lateral).
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
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'folder'),
            child: const Text('Abrir carpeta de exportación'),
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
      case 'folder':
        TransferService().openExportsFolder();
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
      final path = await TransferService().exportCharacter(c);
      if (!mounted) return;
      _showExported('Personaje exportado', path);
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
      final settings = await SettingsService().load();
      final path = await TransferService().exportBackup(
        controller.characters,
        homebrew: widget.homebrew.exportContent(),
        preferences: settings.toPortableJson(),
      );
      if (!mounted) return;
      _showExported(
        'Respaldo completo (${controller.characters.length} personajes)',
        path,
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

  void _showExported(String title, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SelectableText('Guardado en:\n$path'),
        actions: [
          TextButton(
            onPressed: () => TransferService().openExportsFolder(),
            child: const Text('Abrir carpeta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final transfer = TransferService();
    final path = await showDialog<String>(
      context: context,
      builder: (_) => ImportDialog(transfer: transfer),
    );
    if (path == null || !mounted) return;
    if (!_startOperation('Revisando respaldo…')) return;
    PreparedCharacterImport? prepared;
    var charactersSaved = false;
    try {
      final bundle = await transfer.readBundleOrLegacy(path);
      final existingIds = controller.characters
          .map((character) => character.id)
          .toSet();
      final characterCollisions = bundle.characters
          .where((entry) => existingIds.contains(entry.character.id))
          .length;
      final homebrewTotal =
          bundle.homebrew?.values.fold<int>(
            0,
            (total, entries) => total + entries.length,
          ) ??
          0;
      final homebrewCollisions = bundle.homebrew == null
          ? 0
          : widget.homebrew.countCollisions(bundle.homebrew!);
      final choice = await _chooseRestoreScope(
        bundle,
        characterCollisions: characterCollisions,
        homebrewTotal: homebrewTotal,
        homebrewCollisions: homebrewCollisions,
      );
      if (choice == null || !mounted) return;
      final restoreAll = choice;

      prepared = await transfer.prepareCharacterImport(bundle, existingIds);
      final imported = await controller.importCharactersDetailed(
        prepared.characters,
      );
      charactersSaved = true;

      var homebrewCount = 0;
      if (restoreAll && bundle.homebrew != null) {
        homebrewCount = await widget.homebrew.importContent(bundle.homebrew!);
        repo.addAll(widget.homebrew.toRepository());
      }
      if (restoreAll && bundle.preferences != null) {
        await SettingsService().restorePortable(bundle.preferences!);
      }

      if (!mounted) return;
      final extra = restoreAll
          ? ' También se restauraron $homebrewCount elemento(s) homebrew'
                '${bundle.preferences == null ? '.' : ' y las preferencias.'}'
          : '';
      showAppMessage(
        context,
        'Importados ${imported.length} personaje(s).$extra',
        tone: AppMessageTone.success,
      );
    } catch (e) {
      if (prepared != null && !charactersSaved) {
        await prepared.rollbackPortraits();
      }
      final prefix = charactersSaved
          ? 'Los personajes se importaron, pero falló el resto:'
          : 'Error al importar:';
      if (mounted) {
        showAppMessage(context, '$prefix $e', tone: AppMessageTone.error);
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

  Future<bool?> _chooseRestoreScope(
    BackupBundle bundle, {
    required int characterCollisions,
    required int homebrewTotal,
    required int homebrewCollisions,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ImportPreviewDialog(
        bundle: bundle,
        characterCollisions: characterCollisions,
        homebrewTotal: homebrewTotal,
        homebrewCollisions: homebrewCollisions,
      ),
    );
  }
}
