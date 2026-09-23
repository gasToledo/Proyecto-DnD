import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/api_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import 'npc_shared.dart';

/// La biblioteca de PNJ del DM: todos, estén o no en alguna campaña.
///
/// El filtro principal es **por campaña** y los tags van debajo, más chicos:
/// en la mesa la pregunta es «¿quién está en esta campaña?», y el tag
/// («Waterdeep», «Enemigos») afina dentro de eso. Es la jerarquía que se eligió
/// en el diseño; al revés, los tags competían con las campañas por la mirada.
class NpcLibraryView extends StatefulWidget {
  final ApiClient api;
  final ContentRepository repo;
  final List<Campaign> campaigns;

  /// Abre la ficha de un PNJ. La biblioteca se relee al volver: la ficha pudo
  /// cambiarle el nombre, los tags o borrarlo.
  final Future<void> Function(NpcEntry entry) onOpen;

  /// Importa un PNJ desde un archivo. Devuelve si se importó algo.
  final Future<bool> Function() onImport;

  const NpcLibraryView({
    super.key,
    required this.api,
    required this.repo,
    required this.campaigns,
    required this.onOpen,
    required this.onImport,
  });

  @override
  State<NpcLibraryView> createState() => _NpcLibraryViewState();
}

/// `null` es «todas»; [_noCampaign], las que no están en ninguna.
const _noCampaign = '';

class _NpcLibraryViewState extends State<NpcLibraryView> {
  List<NpcEntry>? _entries;
  Object? _error;
  final _search = TextEditingController();
  String? _campaignFilter;
  String? _tagFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final entries = await widget.api.listNpcs();
      if (mounted) setState(() => _entries = entries);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    final created = await createNpcFlow(
      context,
      api: widget.api,
      repo: widget.repo,
    );
    if (created == null || !mounted) return;
    await _load();
    if (mounted) await widget.onOpen(created);
    if (mounted) await _load();
  }

  Future<void> _import() async {
    if (await widget.onImport() && mounted) await _load();
  }

  Future<void> _open(NpcEntry entry) async {
    await widget.onOpen(entry);
    if (mounted) await _load();
  }

  bool _matchesCampaign(NpcEntry entry) => switch (_campaignFilter) {
    null => true,
    _noCampaign => entry.campaigns.isEmpty,
    final id => entry.isIn(id),
  };

  bool _matches(NpcEntry entry) {
    final query = _search.text.trim().toLowerCase();
    return _matchesCampaign(entry) &&
        (_tagFilter == null || entry.npc.hasTag(_tagFilter!)) &&
        (query.isEmpty || entry.npc.name.toLowerCase().contains(query));
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _campaignFilter = null;
    _tagFilter = null;
  });

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (_error != null) {
      return AppErrorView(
        message: 'No se pudo leer tu biblioteca de PNJ.',
        details: '$_error',
        onRetry: _load,
      );
    }
    if (entries == null) {
      return const Center(child: AppBusyLabel('Cargando tus PNJ…'));
    }
    final visible = [
      for (final e in entries)
        if (_matches(e)) e,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, entries.length),
        if (entries.isNotEmpty) _filters(context, entries),
        Expanded(
          child: entries.isEmpty
              ? AppEmptyState(
                  icon: Icons.groups_2_outlined,
                  message:
                      'Tu biblioteca de PNJ está vacía. Creá el primero o '
                      'importá uno: el de otro DM, o un personaje que '
                      'exportó un jugador.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo PNJ'),
                    ),
                  ],
                )
              : visible.isEmpty
              ? AppEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  message: 'Ningún PNJ coincide con los filtros.',
                  actions: [
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                )
              : _grid(visible),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, int count) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              const Text(
                'PNJ',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
              ),
              Text(
                count == 1
                    ? '1 personaje · compartido entre tus campañas'
                    : '$count personajes · compartidos entre tus campañas',
                style: TextStyle(color: pal.textMuted),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Importar PNJ'),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo PNJ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context, List<NpcEntry> entries) {
    final pal = context.palette;
    // Los tags de toda la biblioteca, sin dos que difieran en mayúsculas.
    final tags = Npc.normalizeTags([for (final e in entries) ...e.npc.tags]);
    int tagCount(String tag) => entries.where((e) => e.npc.hasTag(tag)).length;

    ChoiceChip campaignChip(String label, String? value, int count) =>
        ChoiceChip(
          label: Text('$label  $count'),
          selected: _campaignFilter == value,
          onSelected: (_) => setState(() => _campaignFilter = value),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar por nombre',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              campaignChip('Todas', null, entries.length),
              for (final campaign in widget.campaigns)
                campaignChip(
                  campaign.name,
                  campaign.id,
                  entries.where((e) => e.isIn(campaign.id)).length,
                ),
              campaignChip(
                'Sin campaña',
                _noCampaign,
                entries.where((e) => e.campaigns.isEmpty).length,
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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
                    label: Text('$tag  ${tagCount(tag)}'),
                    selected: _tagFilter?.toLowerCase() == tag.toLowerCase(),
                    onSelected: (selected) =>
                        setState(() => _tagFilter = selected ? tag : null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<NpcEntry> visible) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 1100
            ? 3
            : box.maxWidth >= 700
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 152,
          ),
          itemCount: visible.length,
          itemBuilder: (context, i) => _NpcCard(
            entry: visible[i],
            repo: widget.repo,
            onTap: () => _open(visible[i]),
          ),
        );
      },
    );
  }
}

class _NpcCard extends StatelessWidget {
  final NpcEntry entry;
  final ContentRepository repo;
  final VoidCallback onTap;

  const _NpcCard({
    required this.entry,
    required this.repo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final npc = entry.npc;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: pal.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Medallion(
                    portraitKey: npcPortraitKey(npc, entry.sheet),
                    fallback: npc.name.characters.first,
                    size: 44,
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
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          npcTypeLine(npc, entry.sheet, repo),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textMuted,
                            fontStyle: npc.hasStats
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(height: 22, child: ClipRect(child: npcTagPills(npc))),
              const Spacer(),
              Divider(height: 14, color: pal.hairline),
              Text(
                entry.campaigns.isEmpty
                    ? 'Sin campaña todavía'
                    : entry.campaigns.map((c) => c.campaignName).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: entry.campaigns.isEmpty
                      ? pal.textMuted
                      : Theme.of(context).colorScheme.onSurface,
                  fontStyle: entry.campaigns.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
