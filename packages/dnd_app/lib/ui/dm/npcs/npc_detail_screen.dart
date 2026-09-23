import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exception.dart';
import '../../../api/api_models.dart';
import '../../../data/characters_controller.dart';
import '../../../data/settings_service.dart';
import '../../../homebrew/homebrew_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import '../../portrait_screen.dart';
import '../../sheet_screen.dart';
import 'npc_shared.dart';
import 'npc_table_view.dart';
import 'npc_transfer.dart';

/// La ficha de un PNJ: quién es, cómo habla, qué se sabe de él, con qué pelea
/// y cómo está en cada campaña.
///
/// Es del DM y de nadie más: ningún dato de esta pantalla viaja a un jugador.
/// El trasfondo y las notas tampoco viajan al generador de retratos (ver
/// `buildNpcPortraitPrompt`).
class NpcDetailScreen extends StatefulWidget {
  final ApiClient api;
  final ContentRepository repo;
  final String npcId;
  final List<Campaign> campaigns;

  /// Los tags que ya usa la biblioteca, para sugerirlos.
  final List<String> knownTags;
  final AppThemeController? theme;
  final SettingsController? settingsController;

  const NpcDetailScreen({
    super.key,
    required this.api,
    required this.repo,
    required this.npcId,
    required this.campaigns,
    this.knownTags = const [],
    this.theme,
    this.settingsController,
  });

  @override
  State<NpcDetailScreen> createState() => _NpcDetailScreenState();
}

enum _NpcMenuAction { export, delete }

class _NpcDetailScreenState extends State<NpcDetailScreen> {
  NpcEntry? _entry;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await widget.api.getNpc(widget.npcId);
      if (!mounted) return;
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _report(Object error) {
    if (!mounted) return;
    showAppMessage(
      context,
      error is ApiException ? error.message : '$error',
      tone: AppMessageTone.error,
    );
  }

  /// Guarda el documento entero, como el resto del Modo DM: no hay rutas finas
  /// por campo que puedan desincronizarse.
  Future<void> _save(Npc updated) async {
    final entry = _entry;
    if (entry == null) return;
    setState(
      () => _entry = NpcEntry(
        npc: updated,
        campaigns: entry.campaigns,
        sheet: entry.sheet,
      ),
    );
    try {
      await widget.api.updateNpc(updated);
    } catch (error) {
      _report(error);
      await _load();
    }
  }

  Future<void> _editText({
    required String title,
    required String label,
    required String current,
    required Npc Function(String value) apply,
    int maxLines = 1,
    bool allowEmpty = true,
  }) async {
    final value = await showTextPromptDialog(
      context,
      title: title,
      label: label,
      current: current,
      maxLines: maxLines,
      allowEmpty: allowEmpty,
      textCapitalization: TextCapitalization.sentences,
    );
    if (value == null || !mounted) return;
    await _save(apply(value.trim()));
  }

  Future<void> _rename(Npc npc) => _editText(
    title: 'Editar nombre',
    label: 'Nombre del PNJ',
    current: npc.name,
    allowEmpty: false,
    apply: (value) => npc.copyWith(name: value),
  );

  Future<void> _addTag(Npc npc) async {
    var known = widget.knownTags;
    if (known.isEmpty) {
      // Los tags de toda la biblioteca, para sugerirlos. Si no se pueden leer
      // se sigue sin sugerencias: no es motivo para no dejar escribir uno.
      try {
        known = Npc.normalizeTags([
          for (final entry in await widget.api.listNpcs()) ...entry.npc.tags,
        ]);
      } on ApiException {
        known = const [];
      }
      if (!mounted) return;
    }
    final suggestions = [
      for (final tag in known)
        if (!npc.hasTag(tag)) tag,
    ];
    final tag = await showDialog<String>(
      context: context,
      builder: (_) => _TagDialog(suggestions: suggestions),
    );
    if (tag == null || tag.trim().isEmpty || !mounted) return;
    await _save(npc.copyWith(tags: [...npc.tags, tag.trim()]));
  }

  Future<void> _addNote(Npc npc) async {
    final text = await showTextPromptDialog(
      context,
      title: 'Nueva nota',
      label: 'Nota',
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _save(
      npc.copyWith(
        notes: [
          NpcNote(
            id: 'nota-${DateTime.now().microsecondsSinceEpoch}',
            date: DateTime.now(),
            text: text.trim(),
          ),
          ...npc.notes,
        ],
      ),
    );
  }

  Future<void> _editBlock(Npc npc) async {
    final edited = await Navigator.of(context).push<Creature>(
      MaterialPageRoute(
        builder: (_) => CreatureForm(repo: widget.repo, initial: npc.block),
      ),
    );
    if (edited == null || !mounted) return;
    await _save(npc.copyWith(block: edited));
  }

  /// La ficha completa de un PNJ con ficha de personaje, con la misma pantalla
  /// que un jugador. Guarda por la ruta de personajes, que no le cambia el
  /// tipo a la fila: sigue siendo la ficha de un PNJ.
  Future<void> _openSheet(Character sheet) async {
    final controller = CharactersController(widget.api)..characters.add(sheet);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SheetScreen(
          character: sheet,
          repo: widget.repo,
          controller: controller,
          settingsController: widget.settingsController,
          theme: widget.theme ?? AppThemeController(),
          npcMode: true,
        ),
      ),
    );
    await controller.flush();
    controller.dispose();
    if (mounted) await _load();
  }

  Future<void> _setStatus(String campaignId, NpcStatus status) async {
    try {
      await widget.api.linkCampaignNpc(
        campaignId,
        widget.npcId,
        status: status,
      );
      await _load();
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _linkToCampaign(NpcEntry entry) async {
    final options = [
      for (final c in widget.campaigns)
        if (!entry.isIn(c.id)) c,
    ];
    final picked = await showDialog<Campaign>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Sumar a una campaña',
        content: options.isEmpty
            ? const Text('Ya está en todas tus campañas.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in options)
                    ListTile(
                      title: Text(c.name),
                      onTap: () => Navigator.of(ctx).pop(c),
                    ),
                ],
              ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await widget.api.linkCampaignNpc(picked.id, widget.npcId);
      await _load();
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _delete(NpcEntry entry) async {
    final pal = context.palette;
    final where = entry.campaigns.isEmpty
        ? 'de tu biblioteca'
        : 'de tu biblioteca y de '
              '${entry.campaigns.map((c) => c.campaignName).join(', ')}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: 'Borrar a ${entry.npc.name}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se borra $where, con su ficha, su trasfondo, sus notas y sus '
              'retratos. No se puede deshacer.',
            ),
            const SizedBox(height: 10),
            Text(
              'Las batallas pasadas lo siguen nombrando en el Cuaderno. Si '
              'está en un combate abierto, su fila queda con el nombre y sin '
              'perfil.',
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              '¿Solo querés sacarlo de una campaña? Usá «Quitar de esta '
              'campaña» desde la lista de PNJ de esa campaña.',
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
          ],
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DialogAction(
            'Borrar PNJ',
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deleteNpc(entry.npc.id);
      if (!mounted) return;
      showAppMessage(
        context,
        '${entry.npc.name} se borró.',
        tone: AppMessageTone.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _openPortrait(NpcEntry entry) async {
    final sheet = entry.sheet;
    if (entry.npc.sheetKind == NpcSheetKind.character && sheet != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PortraitScreen(
            character: sheet,
            repo: widget.repo,
            api: widget.api,
            settingsController: widget.settingsController,
            onUpdated: (updated) => widget.api.upsertCharacter(updated),
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PortraitScreen.forNpc(
            npc: entry.npc,
            repo: widget.repo,
            api: widget.api,
            settingsController: widget.settingsController,
            onNpcUpdated: (updated) => widget.api.updateNpc(updated),
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(
        title: Text(entry?.npc.name ?? 'PNJ'),
        actions: [
          if (entry != null) ...[
            IconButton(
              tooltip: 'Mostrar a la mesa',
              icon: const Icon(Icons.co_present_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NpcTableViewScreen(
                    name: entry.npc.name,
                    portraitKey: npcPortraitKey(entry.npc, entry.sheet),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Retrato',
              icon: const Icon(Icons.face_retouching_natural),
              onPressed: () => _openPortrait(entry),
            ),
            PopupMenuButton<_NpcMenuAction>(
              tooltip: 'Más acciones',
              onSelected: (action) => switch (action) {
                _NpcMenuAction.export => exportNpcFlow(
                  context,
                  api: widget.api,
                  entry: entry,
                ),
                _NpcMenuAction.delete => _delete(entry),
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _NpcMenuAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.file_upload_outlined),
                    title: Text('Exportar'),
                  ),
                ),
                PopupMenuItem(
                  value: _NpcMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: context.palette.crimson,
                    ),
                    title: Text(
                      'Borrar PNJ',
                      style: TextStyle(color: context.palette.crimson),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return AppErrorView(
        message: 'No se pudo leer el PNJ.',
        details: '$_error',
        onRetry: _load,
      );
    }
    final entry = _entry;
    if (entry == null) {
      return _loading
          ? const Center(child: AppBusyLabel('Cargando el PNJ…'))
          : AppEmptyState(
              icon: Icons.person_off_outlined,
              message: 'Este PNJ ya no existe.',
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            );
    }
    final npc = entry.npc;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final left = [
          _identity(context, entry),
          _card(
            context,
            title: 'Cómo habla',
            onEdit: () => _editText(
              title: 'Cómo habla',
              label: 'Una o dos líneas para interpretarlo',
              current: npc.speech,
              maxLines: 3,
              apply: (v) => npc.copyWith(speech: v),
            ),
            child: _prose(context, npc.speech, 'Todavía no dice cómo habla.'),
          ),
          _card(
            context,
            title: 'Trasfondo',
            onEdit: () => _editText(
              title: 'Trasfondo',
              label: 'Trasfondo',
              current: npc.background,
              maxLines: 10,
              apply: (v) => npc.copyWith(background: v),
            ),
            child: _prose(context, npc.background, 'Sin trasfondo.'),
          ),
          _notes(context, npc),
        ];
        final right = [_stats(context, entry), _campaigns(context, entry)];
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 16),
                  SizedBox(width: 360, child: Column(children: right)),
                ],
              )
            else ...[
              ...left,
              ...right,
            ],
          ],
        );
      },
    );
  }

  Widget _identity(BuildContext context, NpcEntry entry) {
    final pal = context.palette;
    final npc = entry.npc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Medallion(
            portraitKey: npcPortraitKey(npc, entry.sheet),
            fallback: npc.name.characters.first,
            size: 76,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        npc.name,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 28,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar nombre',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _rename(npc),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GoldPill(npcTypeLine(npc, entry.sheet, widget.repo)),
                    for (final tag in npc.tags)
                      InputChip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          color: pal.textMuted,
                        ),
                        onDeleted: () => _save(
                          npc.copyWith(
                            tags: [
                              for (final t in npc.tags)
                                if (t != tag) t,
                            ],
                          ),
                        ),
                        deleteButtonTooltipMessage: 'Quitar «$tag»',
                      ),
                    TextButton.icon(
                      onPressed: () => _addTag(npc),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tag'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prose(BuildContext context, String text, String empty) => Text(
    text.isEmpty ? empty : text,
    style: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: text.isEmpty ? context.palette.textMuted : null,
      fontStyle: text.isEmpty ? FontStyle.italic : null,
    ),
  );

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    VoidCallback? onEdit,
    Widget? trailing,
  }) {
    final pal = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 17),
                ),
              ),
              ?trailing,
              if (onEdit != null)
                IconButton(
                  tooltip: 'Editar ${title.toLowerCase()}',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _notes(BuildContext context, Npc npc) {
    final pal = context.palette;
    return _card(
      context,
      title: 'Notas',
      trailing: TextButton.icon(
        onPressed: () => _addNote(npc),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Agregar nota'),
      ),
      child: npc.notes.isEmpty
          ? _prose(context, '', 'Sin notas.')
          : Column(
              children: [
                for (final note in npc.notes)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: pal.plaque,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(note.date.toLocal()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pal.textMuted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(note.text),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Borrar nota',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _save(
                            npc.copyWith(
                              notes: [
                                for (final n in npc.notes)
                                  if (n.id != note.id) n,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _stats(BuildContext context, NpcEntry entry) {
    final pal = context.palette;
    final npc = entry.npc;
    switch (npc.sheetKind) {
      case NpcSheetKind.none:
        return _card(
          context,
          title: 'Estadísticas',
          child: _prose(
            context,
            '',
            'Sin estadísticas. En combate entra como neutral, con turno y '
                'sin PG.',
          ),
        );
      case NpcSheetKind.block:
        final block = npc.block ?? emptyNpcBlock(npc.name);
        return _card(
          context,
          title: 'Bloque',
          trailing: npc.baseCreatureName == null
              ? null
              : Text(
                  'basado en ${npc.baseCreatureName}',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatPlaque(label: 'CA', value: block.ac),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatPlaque(
                      label: 'PG',
                      value: block.hp,
                      valueColor: pal.crimson,
                    ),
                  ),
                  if (block.cr != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatPlaque(
                        label: 'VD',
                        value: challengeRatingLabel(block.cr!),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              for (final action in block.actions.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${action.name}. ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: [
                            if (action.attackBonus != null)
                              '+${action.attackBonus}',
                            if (action.damage != null) action.damage!,
                          ].join(' · '),
                          style: TextStyle(color: pal.textMuted),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _editBlock(npc),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar bloque'),
              ),
              const SizedBox(height: 8),
              Text(
                'Es una copia: si la criatura del bestiario cambia, este '
                'bloque no se toca.',
                style: TextStyle(fontSize: 11.5, color: pal.textMuted),
              ),
            ],
          ),
        );
      case NpcSheetKind.character:
        final sheet = entry.sheet;
        return _card(
          context,
          title: 'Ficha',
          child: sheet == null
              ? _prose(context, '', 'No se pudo leer su ficha.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      npcTypeLine(npc, sheet, widget.repo),
                      style: TextStyle(color: pal.textMuted),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _openSheet(sheet),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir ficha completa'),
                    ),
                  ],
                ),
        );
    }
  }

  Widget _campaigns(BuildContext context, NpcEntry entry) {
    return _card(
      context,
      title: 'En tus campañas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.campaigns.isEmpty)
            _prose(context, '', 'Todavía no está en ninguna campaña.'),
          for (final link in entry.campaigns)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.campaignName),
                  const SizedBox(height: 6),
                  NpcStatusSelector(
                    status: link.status,
                    semanticLabel: 'Estado en ${link.campaignName}',
                    onChanged: (s) => _setStatus(link.campaignId, s),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _linkToCampaign(entry),
            icon: const Icon(Icons.add),
            label: const Text('Sumar a otra campaña'),
          ),
        ],
      ),
    );
  }
}

/// Un tag nuevo, con los que ya existen en la biblioteca como atajo: así
/// «Waterdeep» no termina escrito de tres formas.
class _TagDialog extends StatefulWidget {
  final List<String> suggestions;
  const _TagDialog({required this.suggestions});

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final matching = [
      for (final tag in widget.suggestions)
        if (tag.toLowerCase().contains(query)) tag,
    ];
    return AppDialog(
      title: 'Agregar tag',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tag'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          if (matching.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in matching)
                  ActionChip(
                    label: Text(tag),
                    onPressed: () => Navigator.of(context).pop(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          'Agregar',
          primary: true,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
