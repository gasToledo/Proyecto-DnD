import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../creation/creation_wizard.dart';
import '../data/backup_bundle.dart';
import '../data/characters_controller.dart';
import '../data/creation_draft_store.dart';
import '../data/data_recovery.dart';
import '../data/homebrew_store.dart';
import '../data/settings_service.dart';
import '../data/transfer_service.dart';
import '../homebrew/homebrew_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'import_dialog.dart';
import 'settings_dialog.dart';
import 'sheet_screen.dart';

/// Ancho a partir del cual el panel lateral queda fijo. Por debajo se colapsa a
/// un Drawer y la ventana angosta sigue siendo usable.
const _kWideBreakpoint = 900.0;

/// Criterio de orden del roster.
enum _SortMode {
  name('Nombre'),
  level('Nivel'),
  klass('Clase');

  const _SortMode(this.label);
  final String label;
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Dashboard del roster: panel lateral con las secciones, buscador, orden y una
/// grilla de tarjetas que muestran los datos clave de cada personaje de un
/// vistazo (PG, CA, velocidad e iniciativa) sin tener que abrir la ficha.
class DashboardScreen extends StatefulWidget {
  final ContentRepository repo;
  final CharactersController controller;
  final HomebrewStore homebrew;
  final VoidCallback onToggleTheme;
  const DashboardScreen({
    super.key,
    required this.repo,
    required this.controller,
    required this.homebrew,
    required this.onToggleTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.name;
  Object? _shownSaveError;
  String? _activeOperation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDataNotices());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerState);
    _searchCtrl.dispose();
    super.dispose();
  }

  ContentRepository get repo => widget.repo;
  CharactersController get controller => widget.controller;

  void _handleControllerState() {
    final error = controller.lastSaveError;
    if (error == null || identical(error, _shownSaveError) || !mounted) return;
    _shownSaveError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppMessage(
        context,
        'No se pudieron guardar los últimos cambios: $error',
        tone: AppMessageTone.error,
      );
    });
  }

  Future<void> _showDataNotices() async {
    if (!mounted) return;
    final issues = <DataRecoveryIssue>[
      ...controller.recoveryIssues,
      ...widget.homebrew.recoveryIssues,
    ];
    if (issues.isNotEmpty) {
      final moved = issues.where((issue) => issue.wasMoved).toList();
      final preserved = issues.where((issue) => !issue.wasMoved).toList();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            preserved.isEmpty
                ? 'Archivos apartados para recuperación'
                : 'Datos que requieren atención',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Text(
                [
                  if (moved.isNotEmpty)
                    'Se apartaron ${moved.length} archivo(s) ilegible(s) para '
                        'que puedas revisarlos:\n'
                        '${moved.map((e) => e.recoveryPath).join('\n')}',
                  if (preserved.isNotEmpty)
                    'No se modificaron ${preserved.length} archivo(s) que esta '
                        'versión de la aplicación no puede abrir:\n'
                        '${preserved.map((e) => '${e.originalPath}\n${e.error}').join('\n\n')}',
                ].join('\n\n'),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    final migrations = <DataMigrationBackup>[
      ...controller.migrationBackups,
      ...widget.homebrew.migrationBackups,
    ];
    if (migrations.isNotEmpty) {
      showAppMessage(
        context,
        'Se actualizaron ${migrations.length} archivo(s) al formato actual. '
        'Las copias anteriores quedaron en recovery/migrations.',
        tone: AppMessageTone.success,
        duration: const Duration(seconds: 5),
      );
    }
  }

  String _klassName(Character c) =>
      repo.characterClass(c.classId)?.name ?? c.classId;
  String _raceName(Character c) => repo.race(c.raceId)?.name ?? c.raceId;

  /// Filtra por nombre/clase/especie y ordena según el criterio elegido.
  List<Character> _visible(List<Character> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          _klassName(c).toLowerCase().contains(q) ||
          _raceName(c).toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _SortMode.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortMode.level:
        list.sort((a, b) => b.level.compareTo(a.level));
      case _SortMode.klass:
        list.sort((a, b) => _klassName(a).compareTo(_klassName(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _kWideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(context),
                Expanded(child: _content(context)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Fichas D&D 5e')),
          drawer: Drawer(
            child: SafeArea(
              child: Builder(builder: (ctx) => _sidebar(ctx, inDrawer: true)),
            ),
          ),
          body: _content(context),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Panel lateral
  // --------------------------------------------------------------------------

  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Desde el panel colapsado, navegar debe cerrar el Drawer primero.
    void run(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Fichas\n'),
                        TextSpan(
                          text: 'D&D 5e',
                          style: TextStyle(color: pal.gold),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      height: 1.1,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _navItem(
            context,
            icon: Icons.groups,
            label: 'Personajes',
            active: true,
          ),
          _navItem(
            context,
            icon: Icons.auto_fix_high,
            label: 'Homebrew',
            onTap: () => run(_openHomebrew),
          ),
          _navItem(
            context,
            icon: Icons.import_export,
            label: 'Importar / Exportar',
            onTap: () => run(_transferDialog),
          ),
          _navItem(
            context,
            icon: Icons.settings,
            label: 'Ajustes',
            onTap: () => run(
              () => showDialog<bool>(
                context: this.context,
                builder: (_) => const SettingsDialog(),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.dark_mode, size: 16),
            label: const Text('Cambiar tema'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(color: pal.hairline),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final pal = context.palette;
    final fg = active
        ? pal.gold
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? pal.goldSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: pal.plaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Contenido: encabezado + grilla
  // --------------------------------------------------------------------------

  Widget _content(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final all = controller.characters;
        final list = _visible(all);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, all.length),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: SectionRule(),
            ),
            Expanded(
              child: all.isEmpty
                  ? _emptyState(
                      context,
                      Icons.shield_outlined,
                      'Todavía no hay personajes.',
                    )
                  : list.isEmpty
                  ? _emptyState(
                      context,
                      Icons.search_off,
                      'Ningún personaje coincide con la búsqueda.',
                    )
                  : _grid(list),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, int total) {
    final pal = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Mis personajes',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  color: onSurface,
                ),
              ),
              GoldPill('$total'),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _SaveStatusIndicator(controller: controller),
              if (_activeOperation != null)
                AppBusyLabel(_activeOperation!, indicatorSize: 16),
              SizedBox(width: 230, height: 40, child: _searchField(pal)),
              _sortButton(context),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _openWizard,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Crear personaje'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppPalette pal) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: pal.plaque,
        hintText: 'Buscar por nombre o clase…',
        hintStyle: TextStyle(fontSize: 13, color: pal.textMuted),
        prefixIcon: Icon(Icons.search, size: 19, color: pal.textMuted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 16, color: pal.textMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border(pal.hairline),
        enabledBorder: border(pal.hairline),
        focusedBorder: border(pal.gold),
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    final pal = context.palette;
    return PopupMenuButton<_SortMode>(
      tooltip: 'Ordenar',
      initialValue: _sort,
      onSelected: (v) => setState(() => _sort = v),
      itemBuilder: (_) => [
        for (final m in _SortMode.values)
          PopupMenuItem(value: m, child: Text(m.label)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pal.plaque,
          border: Border.all(color: pal.hairline),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: pal.textMuted),
            const SizedBox(width: 7),
            Text(
              _sort.label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: pal.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Character> list) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final horizontalPadding = isCompact ? 16.0 : 32.0;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            32,
          ),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isCompact ? 560 : 420,
            mainAxisExtent: 196,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return _CharacterCard(
              character: c,
              sheet: CharacterCompiler(repo).compile(c),
              repo: repo,
              onTap: () => _openSheet(c),
              onRename: () => _renameCharacter(c),
              onExport: () => _exportCharacter(c),
              onDelete: () => _confirmDelete(c),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, IconData icon, String message) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: muted)),
        ],
      ),
    );
  }

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
        builder: (_) =>
            SheetScreen(character: c, repo: repo, controller: controller),
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
    setState(() => _activeOperation = label);
    return true;
  }

  void _finishOperation() {
    if (mounted) setState(() => _activeOperation = null);
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

class ImportPreviewDialog extends StatelessWidget {
  final BackupBundle bundle;
  final int characterCollisions;
  final int homebrewTotal;
  final int homebrewCollisions;

  const ImportPreviewDialog({
    super.key,
    required this.bundle,
    required this.characterCollisions,
    required this.homebrewTotal,
    required this.homebrewCollisions,
  });

  @override
  Widget build(BuildContext context) {
    final hasAdditionalData =
        bundle.homebrew != null || bundle.preferences != null;
    final names = bundle.characters
        .take(6)
        .map((entry) => '• ${entry.character.name}')
        .join('\n');
    final remaining = bundle.characters.length - 6;
    return AlertDialog(
      title: const Text('Revisar importación'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${bundle.characters.length} personaje(s) y '
                '${bundle.portraitCount} retrato(s).',
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(names),
                if (remaining > 0) Text('…y $remaining más.'),
              ],
              if (characterCollisions > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$characterCollisions personaje(s) ya existen. Se '
                  'importarán como copias nuevas; no se sobrescribirán.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              if (bundle.homebrew != null) ...[
                const SizedBox(height: 16),
                Text('Homebrew: $homebrewTotal elemento(s).'),
                if (homebrewCollisions > 0)
                  Text(
                    '$homebrewCollisions elemento(s) existentes serán '
                    'reemplazados al restaurar todo.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              if (bundle.preferences != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Preferencias: proveedor y modelo de imágenes. '
                  'Las credenciales locales se conservarán.',
                ),
              ],
              const SizedBox(height: 18),
              Text(
                hasAdditionalData
                    ? 'Elegí qué parte del respaldo querés restaurar.'
                    : 'Confirmá para importar este contenido.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (hasAdditionalData)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo personajes'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, hasAdditionalData),
          child: Text(hasAdditionalData ? 'Restaurar todo' : 'Importar'),
        ),
      ],
    );
  }
}

class _SaveStatusIndicator extends StatelessWidget {
  final CharactersController controller;

  const _SaveStatusIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final state = controller.saveState;
    final (icon, label, color) = switch (state) {
      CharacterSaveState.saving => (Icons.sync, 'Guardando…', pal.gold),
      CharacterSaveState.error => (
        Icons.error_outline,
        'Error al guardar',
        Theme.of(context).colorScheme.error,
      ),
      CharacterSaveState.saved => (
        Icons.cloud_done_outlined,
        'Guardado',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Estado del guardado: $label',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Container(
          key: ValueKey(state),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Tarjeta
// ----------------------------------------------------------------------------

/// Tarjeta de personaje: identidad arriba (retrato, nombre, especie·clase,
/// trasfondo y nivel) y los datos de combate abajo (PG, CA, velocidad,
/// iniciativa), para no tener que abrir la ficha para verlos.
class _CharacterCard extends StatefulWidget {
  final Character character;
  final ComputedSheet sheet;
  final ContentRepository repo;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  const _CharacterCard({
    required this.character,
    required this.sheet,
    required this.repo,
    required this.onTap,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final s = widget.sheet;
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final klassObj = widget.repo.characterClass(c.classId);
    final klass = klassObj?.name ?? c.classId;
    final accent = classAccent(klassObj, pal.gold);
    final race = widget.repo.race(c.raceId)?.name ?? c.raceId;
    final background = widget.repo.background(c.backgroundId)?.name;
    final portrait = c.portraitPaths.isNotEmpty ? c.portraitPaths.first : null;
    final hasPortrait = portrait != null && File(portrait).existsSync();
    final hp = c.combat.currentHp;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: _hover ? pal.gold : pal.hairline),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(70),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClassMedallion(
                        klass: klassObj,
                        image: hasPortrait ? FileImage(File(portrait)) : null,
                        fallback: c.name.characters.first,
                        size: 56,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 18,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  classIcon(klassObj),
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '$race · $klass',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (background != null) ...[
                              const SizedBox(height: 6),
                              GoldPill(background),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Medallion(fallback: '${c.level}', size: 40),
                          const SizedBox(height: 3),
                          Text(
                            'NIVEL',
                            style: TextStyle(
                              fontSize: 8.5,
                              letterSpacing: 1,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 18, color: muted),
                          onSelected: (v) {
                            if (v == 'rename') widget.onRename();
                            if (v == 'export') widget.onExport();
                            if (v == 'delete') widget.onDelete();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Renombrar'),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Text('Exportar'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: pal.hairline,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Rótulo flexible: con 3 columnas la tarjeta es
                                // angosta y el valor nunca debe quedar tapado.
                                Expanded(
                                  child: Text(
                                    'PG',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      letterSpacing: 1,
                                      color: pal.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$hp/${s.maxHp}',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13,
                                    height: 1,
                                    color: pal.crimson,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ThinBar(
                              ratio: s.maxHp == 0 ? 0 : hp / s.maxHp,
                              color: pal.crimson,
                              track: pal.plaque,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShieldBadge('${s.armorClass}'),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: StatPlaque(
                          label: 'Vel',
                          value: '${s.speed}',
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: StatPlaque(
                          label: 'Inic',
                          value: _signed(s.initiative),
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
