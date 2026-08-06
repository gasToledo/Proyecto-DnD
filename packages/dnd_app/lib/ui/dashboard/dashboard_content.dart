part of '../dashboard_screen.dart';

extension _DashboardContent on _DashboardScreenState {
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
      onChanged: (v) => _updateState(() => _query = v),
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
                  _updateState(() => _query = '');
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
      onSelected: (v) => _updateState(() => _sort = v),
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

        // El delegado reparte el ancho en columnas de a lo sumo
        // `_kCardMaxExtent`, así que el ancho real de una tarjeta no se sabe
        // sin repetir esa cuenta acá: subir el máximo no la ensancha si
        // igual entra una columna más. Con el ancho ya resuelto, la tarjeta
        // se escala en proporción y el alto de la celda la acompaña.
        final available = constraints.maxWidth - horizontalPadding * 2;
        final columns = (available / _kCardMaxExtent).ceil().clamp(1, 99);
        final cardWidth = (available - _kCardSpacing * (columns - 1)) / columns;
        final scale = (cardWidth / _kCardBaseWidth).clamp(1.0, 1.3);

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            32,
          ),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _kCardMaxExtent,
            mainAxisExtent: _kCardBaseHeight * scale,
            crossAxisSpacing: _kCardSpacing,
            mainAxisSpacing: _kCardSpacing,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            final card = _CharacterCard(
              character: c,
              sheet: CharacterCompiler(repo).compile(c),
              repo: repo,
              scale: scale,
              isFavorite: _isFavorite(c),
              onTap: () => _openSheet(c),
              onToggleFavorite: () => _toggleFavorite(c),
              onRename: () => _renameCharacter(c),
              onExport: () => _exportCharacter(c),
              onDelete: () => _confirmDelete(c),
            );
            return _ReorderableCard(
              id: c.id,
              onDropped: (draggedId) => _reorder(draggedId, c.id, list),
              cardWidth: cardWidth,
              child: card,
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
}
