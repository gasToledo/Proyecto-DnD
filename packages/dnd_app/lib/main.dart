import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'creation/creation_wizard.dart';
import 'data/asset_content_loader.dart';
import 'data/character_store.dart';
import 'data/characters_controller.dart';
import 'data/homebrew_store.dart';
import 'data/transfer_service.dart';
import 'demo/demo_characters.dart';
import 'homebrew/homebrew_screen.dart';
import 'theme/app_theme.dart';
import 'ui/import_dialog.dart';
import 'ui/settings_dialog.dart';
import 'ui/sheet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DndApp());
}

class DndApp extends StatelessWidget {
  const DndApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fichas D&D 5e',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // El usuario siempre usa oscuro; es el tema prioritario.
      themeMode: ThemeMode.dark,
      home: const _Bootstrap(),
    );
  }
}

class _AppData {
  final ContentRepository repo;
  final CharactersController controller;
  final HomebrewStore homebrew;
  _AppData(this.repo, this.controller, this.homebrew);
}

/// Carga el contenido oficial y los personajes persistidos antes del dashboard.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<_AppData> _future = _init();

  Future<_AppData> _init() async {
    final repo = await AssetContentLoader.loadOfficial();
    // Fusiona el contenido homebrew sobre el oficial (mismo esquema).
    final homebrew = HomebrewStore();
    await homebrew.load();
    repo.addAll(homebrew.toRepository());

    final controller = CharactersController(CharacterStore());
    await controller.load();
    // Primera ejecución: sembramos el personaje de ejemplo y lo persistimos.
    if (controller.characters.isEmpty) {
      controller.add(demoSagan());
    }
    return _AppData(repo, controller, homebrew);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error al iniciar:\n${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return DashboardScreen(
          repo: snap.data!.repo,
          controller: snap.data!.controller,
          homebrew: snap.data!.homebrew,
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final ContentRepository repo;
  final CharactersController controller;
  final HomebrewStore homebrew;
  const DashboardScreen(
      {super.key,
      required this.repo,
      required this.controller,
      required this.homebrew});

  Future<void> _openWizard(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreationWizard(
          repo: repo,
          onCreate: controller.add,
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, Character c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SheetScreen(character: c, repo: repo, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis personajes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Contenido homebrew',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HomebrewScreen(repo: repo, store: homebrew),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            tooltip: 'Importar / Exportar',
            onSelected: (v) {
              switch (v) {
                case 'import':
                  _import(context);
                case 'backup':
                  _exportBackup(context);
                case 'folder':
                  TransferService().openExportsFolder();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Importar…')),
              PopupMenuItem(
                  value: 'backup', child: Text('Exportar respaldo completo')),
              PopupMenuItem(
                  value: 'folder', child: Text('Abrir carpeta de exportación')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final characters = controller.characters;
          if (characters.isEmpty) {
            return const Center(child: Text('Todavía no hay personajes.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: characters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = characters[i];
              final klass = repo.characterClass(c.classId)?.name ?? c.classId;
              final race = repo.race(c.raceId)?.name ?? c.raceId;
              final portrait =
                  c.portraitPaths.isNotEmpty ? c.portraitPaths.first : null;
              final hasPortrait = portrait != null && File(portrait).existsSync();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage:
                        hasPortrait ? FileImage(File(portrait)) : null,
                    child: hasPortrait ? null : Text(c.name.characters.first),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$race $klass · Nivel ${c.level}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete(context, c);
                      if (v == 'export') _exportCharacter(context, c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'export', child: Text('Exportar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                  onTap: () => _openSheet(context, c),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(context),
        icon: const Icon(Icons.add),
        label: const Text('Crear personaje'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Character c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Eliminar a ${c.name}?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await controller.remove(c);
  }

  Future<void> _exportCharacter(BuildContext context, Character c) async {
    final path = await TransferService().exportCharacter(c);
    if (!context.mounted) return;
    _showExported(context, 'Personaje exportado', path);
  }

  Future<void> _exportBackup(BuildContext context) async {
    final path = await TransferService().exportBackup(controller.characters);
    if (!context.mounted) return;
    _showExported(context,
        'Respaldo completo (${controller.characters.length} personajes)', path);
  }

  void _showExported(BuildContext context, String title, String path) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SelectableText('Guardado en:\n$path'),
        actions: [
          TextButton(
            onPressed: () => TransferService().openExportsFolder(),
            child: const Text('Abrir carpeta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final transfer = TransferService();
    final path = await showDialog<String>(
      context: context,
      builder: (_) => ImportDialog(transfer: transfer),
    );
    if (path == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imported = await transfer.importFromFile(path);
      final count = await controller.importCharacters(imported);
      messenger.showSnackBar(
          SnackBar(content: Text('Importados $count personaje(s).')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al importar: $e')));
    }
  }
}
