import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exception.dart';
import '../../../api/api_models.dart';
import '../../../data/homebrew_store.dart';
import '../../../data/npc_bundle.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import '../../../web/browser.dart' as browser;
import 'npc_shared.dart';

/// Qué eligió el DM llevar en el archivo, además de lo que va siempre.
typedef NpcExportOptions = ({bool background, bool tags, bool notes});

/// El PNJ tal como viaja con [options]: lo desmarcado se vacía. Las campañas y
/// el estado en cada una **nunca** viajan: no están en el documento del PNJ,
/// así que no hay nada que sacar.
Npc npcForExport(Npc npc, NpcExportOptions options) => npc.copyWith(
  background: options.background ? npc.background : '',
  tags: options.tags ? npc.tags : const [],
  notes: options.notes ? npc.notes : const [],
);

Future<void> exportNpcFlow(
  BuildContext context, {
  required ApiClient api,
  required NpcEntry entry,
}) async {
  final options = await showDialog<NpcExportOptions>(
    context: context,
    builder: (_) => ExportNpcDialog(entry: entry),
  );
  if (options == null || !context.mounted) return;
  try {
    final sheet = entry.sheet;
    final homebrew = sheet == null
        ? const <String, List<Map<String, dynamic>>>{}
        : homebrewUsedBy(sheet, await api.listHomebrew());
    final portraits = <NpcBundlePortrait>[];
    Future<void> collect(String owner, List<String> keys) async {
      for (final key in keys) {
        final bytes = await api.fetchPortraitBytes(key);
        if (bytes != null) {
          portraits.add((owner: owner, key: key, bytes: bytes));
        }
      }
    }

    await collect('npc', entry.npc.portraitPaths);
    if (sheet != null) await collect('character', sheet.portraitPaths);
    final bytes = NpcBundleCodec.encode(
      npc: npcForExport(entry.npc, options),
      sheet: sheet,
      homebrew: homebrew,
      portraits: portraits,
    );
    final slug = entry.npc.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    browser.downloadBytes(
      bytes,
      fileName: '${slug.isEmpty ? 'pnj' : slug}.zip',
      mimeType: 'application/zip',
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      showAppMessage(context, e.message, tone: AppMessageTone.error);
    }
  }
}

class ExportNpcDialog extends StatefulWidget {
  final NpcEntry entry;
  const ExportNpcDialog({super.key, required this.entry});

  @override
  State<ExportNpcDialog> createState() => _ExportNpcDialogState();
}

class _ExportNpcDialogState extends State<ExportNpcDialog> {
  bool _background = true;
  bool _tags = true;
  bool _notes = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final npc = widget.entry.npc;
    Widget always(String text) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.check, color: pal.gold),
      title: Text(text),
    );
    return AppDialog(
      title: 'Exportar PNJ',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            npc.name,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 18),
          ),
          const SizedBox(height: 12),
          const Eyebrow('Qué viaja en el archivo'),
          always('Nombre, retrato, apariencia y «cómo habla»'),
          always(switch (npc.sheetKind) {
            NpcSheetKind.none => 'Su tipo: sin estadísticas',
            NpcSheetKind.block => 'Su bloque',
            NpcSheetKind.character =>
              'Su ficha de personaje y el homebrew que usa',
          }),
          CheckboxListTile(
            value: _background,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Trasfondo'),
            onChanged: (v) => setState(() => _background = v ?? false),
          ),
          CheckboxListTile(
            value: _tags,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Tags'),
            subtitle: npc.tags.isEmpty ? null : Text(npc.tags.join(', ')),
            onChanged: (v) => setState(() => _tags = v ?? false),
          ),
          CheckboxListTile(
            value: _notes,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Notas'),
            subtitle: const Text('Son de tus mesas.'),
            onChanged: (v) => setState(() => _notes = v ?? false),
          ),
          const SizedBox(height: 8),
          Text(
            'Nunca viaja en qué campañas está ni si vive o murió en cada una. '
            'Quien lo importe recibe su propia copia: lo que cambie después no '
            'te llega.',
            style: TextStyle(fontSize: 12.5, color: pal.textMuted),
          ),
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          'Descargar .zip',
          primary: true,
          onPressed: () => Navigator.of(
            context,
          ).pop((background: _background, tags: _tags, notes: _notes)),
        ),
      ],
    );
  }
}

/// Elige un archivo y, si vale, lo importa. Devuelve si se importó algo.
Future<bool> importNpcFlow(
  BuildContext context, {
  required ApiClient api,
  required ContentRepository repo,
  required List<Campaign> campaigns,
  HomebrewStore? homebrew,
}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    withData: true,
    dialogTitle: 'Elegir el archivo del PNJ o del personaje',
  );
  final raw = picked?.files.singleOrNull?.bytes;
  if (raw == null || !context.mounted) return false;
  final Uint8List bytes;
  final NpcBundlePreview preview;
  try {
    // Un personaje exportado desde «Mis personajes» entra como PNJ con ficha.
    bytes = NpcBundleCodec.adoptCharacterExport(raw);
    preview = NpcBundleCodec.preview(bytes);
  } on FormatException catch (e) {
    showAppMessage(context, e.message, tone: AppMessageTone.error);
    return false;
  } on UnsupportedDataVersionException {
    showAppMessage(
      context,
      'El archivo viene de una versión más nueva de la app.',
      tone: AppMessageTone.error,
    );
    return false;
  }
  final imported = await showDialog<NpcEntry>(
    context: context,
    builder: (_) => ImportNpcDialog(
      api: api,
      repo: repo,
      bytes: bytes,
      preview: preview,
      campaigns: campaigns,
      homebrew: homebrew,
    ),
  );
  return imported != null;
}

/// La vista previa de un PNJ a importar, con la campaña opcional.
///
/// Si la ficha usa contenido oficial que esta instalación no tiene, lo dice y
/// no deja importar: ni siquiera se le pregunta al servidor.
class ImportNpcDialog extends StatefulWidget {
  final ApiClient api;
  final ContentRepository repo;
  final Uint8List bytes;
  final NpcBundlePreview preview;
  final List<Campaign> campaigns;

  /// El homebrew de la cuenta, para sumarle el que traiga la ficha. Null en
  /// los tests que no lo miran.
  final HomebrewStore? homebrew;

  const ImportNpcDialog({
    super.key,
    required this.api,
    required this.repo,
    required this.bytes,
    required this.preview,
    required this.campaigns,
    this.homebrew,
  });

  @override
  State<ImportNpcDialog> createState() => _ImportNpcDialogState();
}

class _ImportNpcDialogState extends State<ImportNpcDialog> {
  String? _campaignId;
  bool _busy = false;
  String? _error;

  late final List<String> _missing = missingOfficialContent(
    widget.preview,
    widget.repo,
  );

  /// El servidor guardó en la cuenta el homebrew que trae la ficha, pero el
  /// catálogo en memoria se arma al abrir la app: sin recargarlo, la ficha
  /// importada mostraba su arma como «No está en el catálogo» hasta recargar
  /// la página. Se recarga el store compartido —y no solo el catálogo— para
  /// que la sección Homebrew también lo vea.
  ///
  /// Si falla, el PNJ ya está importado: se avisa en vez de dejar el diálogo
  /// abierto, que invitaría a importarlo dos veces.
  Future<void> _mergeBundledHomebrew() async {
    final store = widget.homebrew;
    if (store == null || widget.preview.homebrewNames.isEmpty) return;
    try {
      await store.load();
      widget.repo.addAll(store.toRepository());
    } on ApiException {
      if (mounted) {
        showAppMessage(
          context,
          'El PNJ se importó, pero su homebrew aparece recién al recargar la '
          'página.',
          tone: AppMessageTone.error,
        );
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imported = await widget.api.importNpc(
        widget.bytes,
        campaignId: _campaignId,
      );
      await _mergeBundledHomebrew();
      if (mounted) Navigator.of(context).pop(imported);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final preview = widget.preview;
    final npc = preview.npc;
    return AppDialog(
      title: 'Importar PNJ',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.plaque,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  npc.name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  npcTypeLine(npc, preview.sheet, widget.repo),
                  style: TextStyle(fontSize: 12.5, color: pal.textMuted),
                ),
                if (npc.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  npcTagPills(npc),
                ],
                const SizedBox(height: 10),
                Text(
                  [
                    if (preview.portraitCount > 0)
                      preview.portraitCount == 1
                          ? '1 retrato'
                          : '${preview.portraitCount} retratos',
                    if (npc.background.isNotEmpty) 'trasfondo',
                    if (npc.notes.isNotEmpty) '${npc.notes.length} notas',
                    if (preview.homebrewNames.isNotEmpty)
                      'homebrew: ${preview.homebrewNames.join(', ')}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: pal.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_missing.isNotEmpty)
            Text(
              'No se puede importar: su ficha usa contenido que esta '
              'instalación no tiene (${_missing.join(', ')}).',
              style: TextStyle(color: pal.crimson),
            )
          else ...[
            DropdownButtonFormField<String?>(
              // Sin esto el menú mide cada opción a su ancho natural, y el
              // nombre de una campaña larga desborda el diálogo.
              isExpanded: true,
              initialValue: _campaignId,
              decoration: const InputDecoration(
                labelText: 'Sumarlo también a una campaña (opcional)',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Ninguna: queda sin campaña'),
                ),
                for (final c in widget.campaigns)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _campaignId = v),
            ),
            const SizedBox(height: 10),
            Text(
              'Importar nunca reemplaza nada: si ya tenés un PNJ con ese '
              'nombre, quedan los dos.',
              style: TextStyle(fontSize: 12.5, color: pal.textMuted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: pal.crimson)),
          ],
          if (_busy) ...[
            const SizedBox(height: 10),
            const AppBusyLabel('Importando…'),
          ],
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        DialogAction(
          'Importar',
          primary: true,
          onPressed: _busy || _missing.isNotEmpty ? null : _import,
        ),
      ],
    );
  }
}
