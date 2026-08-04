import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/homebrew_store.dart';
import '../data/transfer_service.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;
import 'effect_editor.dart';

part 'forms/armor_form.dart';
part 'forms/background_form.dart';
part 'forms/feat_form.dart';
part 'forms/form_widgets.dart';
part 'forms/race_form.dart';
part 'forms/spell_form.dart';
part 'forms/weapon_form.dart';
part 'homebrew_tabs.dart';

const _skills = [
  'acrobatics',
  'animal-handling',
  'arcana',
  'athletics',
  'deception',
  'history',
  'insight',
  'intimidation',
  'investigation',
  'medicine',
  'nature',
  'perception',
  'performance',
  'persuasion',
  'religion',
  'sleight-of-hand',
  'stealth',
  'survival',
];
const _weaponProps = [
  'finesse',
  'versatile',
  'two-handed',
  'light',
  'heavy',
  'thrown',
  'ranged',
  'ammunition',
  'reach',
  'loading',
];

/// Editor de contenido homebrew. Lo creado se fusiona en el [ContentRepository]
/// compartido, así queda disponible de inmediato en el wizard y la ficha.
class HomebrewScreen extends StatefulWidget {
  final ContentRepository repo;
  final HomebrewStore store;
  const HomebrewScreen({super.key, required this.repo, required this.store});

  @override
  State<HomebrewScreen> createState() => _HomebrewScreenState();
}

class _HomebrewScreenState extends State<HomebrewScreen> {
  ContentRepository get repo => widget.repo;
  HomebrewStore get store => widget.store;

  void _refresh() => setState(() {});

  /// Ejecuta una escritura en disco del store homebrew; si falla (permisos,
  /// disco lleno) lo muestra en vez de dejar la excepción sin capturar.
  Future<bool> _persist(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo guardar el contenido homebrew: $e',
          tone: AppMessageTone.error,
        );
      }
      return false;
    }
  }

  Future<void> _exportHomebrew() async {
    final content = store.exportContent();
    final total = content.values.fold<int>(0, (s, l) => s + l.length);
    if (total == 0) {
      showAppMessage(context, 'No hay contenido homebrew para exportar.');
      return;
    }
    final transfer = TransferService(store.api);
    browser.downloadBytes(
      transfer.exportHomebrew(content),
      fileName: transfer.homebrewExportFileName(),
      mimeType: 'application/json',
    );
    showAppMessage(
      context,
      'Homebrew exportado ($total entrada(s)).',
      tone: AppMessageTone.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _importHomebrew() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      dialogTitle: 'Elegí un pack homebrew (.json)',
    );
    final file = picked?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;
    try {
      final content = TransferService.parseHomebrewImport(
        utf8.decode(file!.bytes!),
      );
      if (!mounted) return;
      // No pisar homebrew existente sin avisar: si hay ids en colisión, pedir
      // confirmación antes de sobrescribir.
      final collisions = store.countCollisions(content);
      if (collisions > 0) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sobrescribir homebrew'),
            content: Text(
              '$collisions entrada(s) del pack comparten id con '
              'contenido que ya tenés. Al importar se reemplazarán. '
              '¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sobrescribir'),
              ),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      final count = await store.importContent(content);
      // Fusiona lo importado en el repo compartido, así queda disponible de
      // inmediato en el wizard y las fichas (igual que al guardar un ítem).
      repo.addAll(store.toRepository());
      if (!mounted) return;
      setState(() {});
      showAppMessage(
        context,
        'Importadas $count entradas de homebrew.',
        tone: AppMessageTone.success,
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo importar el homebrew: $e',
          tone: AppMessageTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contenido homebrew'),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Exportar homebrew',
              onPressed: _exportHomebrew,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Importar homebrew',
              onPressed: _importHomebrew,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Armas'),
              Tab(text: 'Armaduras'),
              Tab(text: 'Dotes'),
              Tab(text: 'Razas'),
              Tab(text: 'Trasfondos'),
              Tab(text: 'Conjuros'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _weaponsTab(),
            _armorTab(),
            _featsTab(),
            _racesTab(),
            _backgroundsTab(),
            _spellsTab(),
          ],
        ),
      ),
    );
  }
}
