import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../api/api_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import 'npc_shared.dart';

enum _RowAction { open, unlink }

/// Los PNJ de una campaña, con su estado **en esta** campaña.
///
/// Los datos los lleva la campaña (`_CampaignDetail`) y no esta vista: el
/// combate necesita la misma lista para saber a quién puede sumar y cómo pelea
/// cada uno, y dos copias de «los PNJ de la mesa» se desalinearían.
class CampaignNpcsView extends StatefulWidget {
  final List<CampaignNpcEntry>? npcs;
  final Object? error;
  final ContentRepository repo;
  final VoidCallback onRetry;
  final VoidCallback onBringFromLibrary;
  final void Function(CampaignNpcEntry entry, NpcStatus status) onStatus;
  final void Function(CampaignNpcEntry entry) onUnlink;
  final void Function(CampaignNpcEntry entry) onOpen;

  const CampaignNpcsView({
    super.key,
    required this.npcs,
    required this.error,
    required this.repo,
    required this.onRetry,
    required this.onBringFromLibrary,
    required this.onStatus,
    required this.onUnlink,
    required this.onOpen,
  });

  @override
  State<CampaignNpcsView> createState() => _CampaignNpcsViewState();
}

class _CampaignNpcsViewState extends State<CampaignNpcsView> {
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    if (widget.error != null) {
      return AppErrorView(
        message: 'No se pudieron leer los PNJ de la campaña.',
        details: '${widget.error}',
        onRetry: widget.onRetry,
      );
    }
    final npcs = widget.npcs;
    if (npcs == null) {
      return const Center(child: AppBusyLabel('Cargando los PNJ…'));
    }
    if (npcs.isEmpty) {
      return AppEmptyState(
        icon: Icons.groups_2_outlined,
        message:
            'Esta campaña todavía no tiene PNJ. Traé los de tu biblioteca o '
            'creá uno nuevo.',
        actions: [
          OutlinedButton.icon(
            onPressed: widget.onBringFromLibrary,
            icon: const Icon(Icons.library_add_outlined),
            label: const Text('Traer de la biblioteca'),
          ),
        ],
      );
    }

    int count(NpcStatus s) => npcs.where((n) => n.status == s).length;
    final tags = Npc.normalizeTags([for (final n in npcs) ...n.npc.tags]);
    final visible = [
      for (final n in npcs)
        if (_tag == null || n.npc.hasTag(_tag!)) n,
    ];
    final summary = [
      npcs.length == 1 ? '1 PNJ' : '${npcs.length} PNJ',
      '${count(NpcStatus.alive)} ${count(NpcStatus.alive) == 1 ? 'vivo' : 'vivos'}',
      '${count(NpcStatus.dead)} ${count(NpcStatus.dead) == 1 ? 'muerto' : 'muertos'}',
      '${count(NpcStatus.unknown)} '
          '${count(NpcStatus.unknown) == 1 ? 'desconocido' : 'desconocidos'}',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(summary, style: TextStyle(color: pal.textMuted)),
            ),
            if (tags.isNotEmpty)
              Text(
                'TAGS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: pal.textMuted,
                ),
              ),
            for (final tag in tags)
              FilterChip(
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 12),
                label: Text(tag),
                selected: _tag?.toLowerCase() == tag.toLowerCase(),
                onSelected: (on) => setState(() => _tag = on ? tag : null),
              ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: widget.onBringFromLibrary,
              icon: const Icon(Icons.library_add_outlined, size: 18),
              label: const Text('Traer de la biblioteca'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AppEmptyState(
              icon: Icons.filter_alt_off_outlined,
              message: 'Ningún PNJ de esta campaña tiene ese tag.',
              actions: [
                TextButton(
                  onPressed: () => setState(() => _tag = null),
                  child: const Text('Limpiar filtro'),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final (i, entry) in visible.indexed) ...[
                  if (i > 0) Divider(height: 1, color: pal.hairline),
                  _row(context, entry),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, CampaignNpcEntry entry) {
    final pal = context.palette;
    final npc = entry.npc;
    final dead = entry.status == NpcStatus.dead;
    final identity = Row(
      children: [
        Medallion(
          portraitKey: npcPortraitKey(npc, entry.sheet),
          fallback: npc.name.characters.first,
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                npc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  // Tachado y atenuado, no solo en rojo: el estado se tiene que
                  // leer sin distinguir colores.
                  decoration: dead ? TextDecoration.lineThrough : null,
                  color: dead ? pal.textMuted : null,
                ),
              ),
              Text(
                npcTypeLine(npc, entry.sheet, widget.repo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
    final status = NpcStatusSelector(
      status: entry.status,
      semanticLabel: 'Estado de ${npc.name}',
      onChanged: (s) => widget.onStatus(entry, s),
    );
    final menu = PopupMenuButton<_RowAction>(
      tooltip: 'Acciones de ${npc.name}',
      onSelected: (action) => switch (action) {
        _RowAction.open => widget.onOpen(entry),
        _RowAction.unlink => widget.onUnlink(entry),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _RowAction.open, child: Text('Abrir ficha')),
        PopupMenuItem(
          value: _RowAction.unlink,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Quitar de esta campaña'),
            subtitle: Text('Sigue en tu biblioteca y en tus otras campañas.'),
          ),
        ),
      ],
      icon: const Icon(Icons.more_horiz),
    );

    return Opacity(
      opacity: dead ? .7 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 760) {
              return Row(
                children: [
                  SizedBox(width: 280, child: identity),
                  const SizedBox(width: 12),
                  Expanded(child: npcTagPills(npc)),
                  status,
                  menu,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    menu,
                  ],
                ),
                if (npc.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  npcTagPills(npc),
                ],
                const SizedBox(height: 8),
                status,
              ],
            );
          },
        ),
      ),
    );
  }
}
