import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../creation/creation_wizard.dart';
import '../data/backup_bundle.dart';
import '../data/characters_controller.dart';
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerState);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showRecoveryWarnings(),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar los últimos cambios: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  Future<void> _showRecoveryWarnings() async {
    if (!mounted) return;
    final issues = <DataRecoveryIssue>[
      ...controller.recoveryIssues,
      ...widget.homebrew.recoveryIssues,
    ];
    if (issues.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivos apartados para recuperación'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Text(
              'La aplicación encontró ${issues.length} archivo(s) ilegible(s). '
              'No fueron eliminados; se movieron para que puedas revisarlos:\n\n'
              '${issues.map((e) => e.recoveryPath).join('\n')}',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Mis personajes',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 12),
              GoldPill('$total'),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(32, 14, 32, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
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
        builder: (_) => CreationWizard(repo: repo, onCreate: controller.add),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await TransferService().exportCharacter(c);
      if (!mounted) return;
      _showExported('Personaje exportado', path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
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
    final messenger = ScaffoldMessenger.of(context);
    PreparedCharacterImport? prepared;
    var charactersSaved = false;
    try {
      final bundle = await transfer.readBundleOrLegacy(path);
      var restoreAll = false;
      final hasAdditionalData =
          bundle.homebrew != null || bundle.preferences != null;
      if (hasAdditionalData) {
        final choice = await _chooseRestoreScope(bundle);
        if (choice == null || !mounted) return;
        restoreAll = choice;
      }

      if (restoreAll && bundle.homebrew != null) {
        final collisions = widget.homebrew.countCollisions(bundle.homebrew!);
        if (collisions > 0) {
          final confirmed = await _confirmHomebrewOverwrite(collisions);
          if (!confirmed || !mounted) return;
        }
      }

      prepared = await transfer.prepareCharacterImport(
        bundle,
        controller.characters.map((character) => character.id).toSet(),
      );
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Importados ${imported.length} personaje(s).$extra'),
        ),
      );
    } catch (e) {
      if (prepared != null && !charactersSaved) {
        await prepared.rollbackPortraits();
      }
      final prefix = charactersSaved
          ? 'Los personajes se importaron, pero falló el resto:'
          : 'Error al importar:';
      messenger.showSnackBar(SnackBar(content: Text('$prefix $e')));
    }
  }

  Future<bool?> _chooseRestoreScope(BackupBundle bundle) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contenido del respaldo'),
        content: Text(
          'Incluye ${bundle.characters.length} personaje(s), '
          '${bundle.portraitCount} retrato(s)'
          '${bundle.homebrew == null ? '' : ' y contenido homebrew'}'
          '${bundle.preferences == null ? '' : ' y preferencias'}.\n\n'
          '¿Qué querés restaurar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Solo personajes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar todo'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmHomebrewOverwrite(int collisions) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Contenido homebrew existente'),
            content: Text(
              '$collisions elemento(s) tienen el mismo id y serán '
              'reemplazados por la versión del respaldo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
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
