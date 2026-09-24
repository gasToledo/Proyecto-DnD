part of 'codex_screen.dart';

/// Ancho del área de contenido a partir del cual entran la lista y el detalle
/// al mismo tiempo. Es el del Bestiario: se mide sin el panel de 236 px.
const double _splitWidth = 760;

/// Una categoría del Códice: lista con buscador y filtro, y el detalle de la
/// entrada elegida. Es el molde del Bestiario del Modo DM para todo lo que no
/// es una criatura.
class _CodexCategoryView extends StatefulWidget {
  final CodexCategory category;
  final List<CodexEntry> entries;
  final String? initialId;
  final String initialQuery;

  const _CodexCategoryView({
    super.key,
    required this.category,
    required this.entries,
    this.initialId,
    this.initialQuery = '',
  });

  @override
  State<_CodexCategoryView> createState() => _CodexCategoryViewState();
}

class _CodexCategoryViewState extends State<_CodexCategoryView> {
  late final _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  late String _query = widget.initialQuery;

  /// El valor de [CodexEntry.facet] elegido, o null para todos.
  String? _facet;

  late CodexEntry? _selected = widget.initialId == null
      ? null
      : widget.entries.where((e) => e.id == widget.initialId).firstOrNull;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Los valores del filtro, en el orden de [CodexEntry.facetRank]: nivel de
  /// conjuro, rareza, categoría de dote. Salen de lo cargado, así que el
  /// homebrew con una rareza o categoría nueva también aparece.
  List<String> get _facets {
    final ranks = <String, int>{};
    for (final e in widget.entries) {
      if (e.facet case final f?) ranks.putIfAbsent(f, () => e.facetRank);
    }
    return ranks.keys.toList()..sort((a, b) => ranks[a]!.compareTo(ranks[b]!));
  }

  List<CodexEntry> get _results {
    final needle = foldForSearch(_query.trim());
    return [
      for (final e in widget.entries)
        if ((_facet == null || e.facet == _facet) &&
            (needle.isEmpty || foldForSearch(e.name).contains(needle)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _splitWidth;
        if (!wide && _selected != null) {
          return _detail(
            context,
            _selected!,
            onBack: () => setState(() => _selected = null),
          );
        }
        final list = _list(context, results);
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 320, child: list),
            VerticalDivider(width: 1, color: context.palette.hairline),
            Expanded(
              child: _selected == null
                  ? AppEmptyState(
                      icon: widget.category.icon,
                      message: 'Elegí una entrada para leerla.',
                    )
                  : _detail(context, _selected!),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, List<CodexEntry> results) {
    final pal = context.palette;
    final facets = _facets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Buscar en ${widget.category.label.toLowerCase()}',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (facets.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _facet == null,
                  onSelected: (_) => setState(() => _facet = null),
                ),
                for (final f in facets)
                  ChoiceChip(
                    label: Text(f),
                    selected: _facet == f,
                    // Tocar el elegido lo suelta: es la forma de volver a
                    // «Todos» sin buscar el primer chip.
                    onSelected: (on) => setState(() => _facet = on ? f : null),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            results.length == 1 ? '1 entrada' : '${results.length} entradas',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off,
                  message: 'Nada coincide con lo que buscaste.',
                  actions: [
                    OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _facet = null;
                        });
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: pal.hairline),
                  itemBuilder: (context, i) {
                    final e = results[i];
                    return ListTile(
                      key: ValueKey('codex-${widget.category.name}-${e.id}'),
                      selected: e.id == _selected?.id,
                      selectedTileColor: pal.goldSoft,
                      title: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: e.subtitle.isEmpty
                          ? null
                          : Text(
                              e.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => setState(() => _selected = e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, CodexEntry e, {VoidCallback? onBack}) {
    final pal = context.palette;
    return ListView(
      key: ValueKey('codex-detail-${e.id}'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver al listado'),
            ),
          ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              e.name,
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 24),
            ),
            SourceBadge(e.source),
          ],
        ),
        if (e.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            e.subtitle,
            style: TextStyle(fontSize: 13, color: pal.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        ...e.body(context),
      ],
    );
  }
}
