part of '../sheet_screen.dart';

extension _SheetNavigation on _SheetScreenState {
  // -------------------------------------------------------------- Sidebar

  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final klassObj = repo.characterClass(_c.classId);
    final portrait = _c.portraitPaths.isNotEmpty
        ? _c.portraitPaths.first
        : null;
    final hasPortrait = portrait != null;

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
          appNavItem(
            context,
            icon: Icons.arrow_back,
            label: 'Mis personajes',
            onTap: () => run(() => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.plaque,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: pal.hairline),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: hasPortrait
                      ? () => _openPortraitViewer(portrait)
                      : null,
                  child: MouseRegion(
                    cursor: hasPortrait
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: ClassMedallion(
                      klass: klassObj,
                      image: hasPortrait
                          ? PortraitImage.provider(portrait)
                          : null,
                      fallback: _c.name.characters.first,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${klassObj?.name ?? _c.classId} nivel ${_c.level}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: pal.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final tab in _SheetTab.values)
            appNavItem(
              context,
              icon: tab.icon,
              label: tab.label,
              active: _tab == tab,
              onTap: () => run(() => _selectTab(tab)),
            ),
          const Spacer(),
          appNavItem(
            context,
            icon: Icons.face_retouching_natural,
            label: 'Retrato',
            onTap: () => run(_openPortrait),
          ),
          appNavItem(
            context,
            icon: Icons.arrow_upward,
            label: 'Subir nivel',
            onTap: () => run(_openLevelUp),
          ),
          const SizedBox(height: 8),
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

  // ------------------------------------------------------------------ Body

  Widget _sheetBody() {
    final s = sheet;
    final klassObj = repo.characterClass(_c.classId);
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final sub = _c.subclassId == null
        ? null
        : repo.subclass(_c.subclassId!)?.name;
    final klassLine = sub == null
        ? (klassObj?.name ?? _c.classId)
        : '${klassObj?.name ?? _c.classId} ($sub)';
    final bg = repo.background(_c.backgroundId)?.name ?? '';
    final subtitle = [race, klassLine, if (bg.isNotEmpty) bg].join(' · ');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                children: [
                  InkWell(
                    onTap: _editName,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _c.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_outlined, size: 16, color: muted),
                        ],
                      ),
                    ),
                  ),
                  Text(subtitle, style: TextStyle(color: muted)),
                  GoldPill('Nivel ${_c.level}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _statPlaques(s),
        const SectionRule(),
        _tabContent(_tab),
      ],
    );
  }

  /// Agrupa tarjetas en columnas fijas en pantallas anchas; en angostas las
  /// apila en una sola columna (equivalente perezoso al CSS grid auto-fit del
  /// diseño original).
  Widget responsiveColumns(List<List<Widget>> columns) {
    return LayoutBuilder(
      builder: (context, box) {
        Widget stack(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
        if (box.maxWidth < 640) {
          return stack([for (final col in columns) ...col]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: stack(columns[i])),
            ],
          ],
        );
      },
    );
  }

  /// Tarjeta con encabezado (ícono + título + acción opcional), estilo
  /// consistente con el resto de la ficha.
  Widget sheetCard({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    final pal = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pal.hairline)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: pal.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
