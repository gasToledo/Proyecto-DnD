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
import '../data/update_service.dart';
import '../homebrew/homebrew_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'import_dialog.dart';
import 'settings_dialog.dart';
import 'sheet_screen.dart';

part 'dashboard/dashboard_actions.dart';
part 'dashboard/dashboard_content.dart';
part 'dashboard/dashboard_navigation.dart';
part 'dashboard/dashboard_widgets.dart';

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
  final UpdateService? updateService;
  final VoidCallback onToggleTheme;
  const DashboardScreen({
    super.key,
    required this.repo,
    required this.controller,
    required this.homebrew,
    this.updateService,
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

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showDataNotices();
      if (mounted) await _checkForUpdates();
    });
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
}
