part of '../sheet_screen.dart';

extension _SheetNavigation on _SheetScreenState {
  // `toSet` conserva el orden de inserción: la clase inicial va primero.
  String _classSummary() => _c.classHistory
      .toSet()
      .map(
        (id) => '${repo.characterClass(id)?.name ?? id} ${_c.classLevel(id)}',
      )
      .join(' · ');

  /// Pill de una clase, con la subclase o cuándo se elige. Si ya tocaba y no
  /// se eligió no dice nada: eso lo avisa la validación, no la cabecera.
  Widget _classPill(String id) {
    final klass = repo.characterClass(id);
    final level = _c.classLevel(id);
    return GoldPill(
      '${klass?.name ?? id} $level',
      highlighted: false,
      detail: switch (_c.subclassForClass(id)) {
        final sub? => repo.subclass(sub)?.name ?? sub,
        null when klass != null && level < klass.subclassLevel =>
          'subclase en nivel ${klass.subclassLevel}',
        null => null,
      },
    );
  }

  // -------------------------------------------------------------- Sidebar

  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;

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
      // Con siete ítems, el retrato, las preferencias y el cartel del
      // guardado, el panel no entra en una ventana de 700 de alto — que es
      // una ventana de navegador cualquiera. Scrollea cuando no entra, y en
      // cuanto entra el `Spacer` vuelve a empujar el pie hacia abajo.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(child: _sidebarColumn(context, run)),
          ),
        ),
      ),
    );
  }

  Widget _sidebarColumn(BuildContext context, void Function(VoidCallback) run) {
    final pal = context.palette;
    final klassObj = repo.characterClass(_c.classId);
    final portrait = _c.portraitPaths.isNotEmpty
        ? _c.portraitPaths.first
        : null;
    final hasPortrait = portrait != null;

    return Column(
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
                onTap: hasPortrait ? () => _openPortraitViewer(portrait) : null,
                child: MouseRegion(
                  cursor: hasPortrait
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: ClassMedallion(
                    klass: klassObj,
                    portraitKey: hasPortrait ? portrait : null,
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
                      '${_classSummary()} · nivel ${_c.totalLevel}',
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
        // Va en el panel y no en el AppBar porque el AppBar solo existe en
        // ventana angosta: acá se ve en los dos layouts.
        appNavItem(
          context,
          icon: Icons.ios_share,
          label: 'Compartir',
          onTap: () => run(_shareCharacter),
        ),
        const SizedBox(height: 8),
        // La ficha guarda sola, sin botón: sin este cartel no hay forma de
        // saber si lo que se acaba de tipear llegó al servidor.
        SaveStatusIndicator(controller: ctrl),
        const SizedBox(height: 8),
        DisplayPreferences(controller: widget.theme),
      ],
    );
  }

  // ------------------------------------------------------------------ Body

  Widget _sheetBody() {
    final s = sheet;
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final bg = repo.background(_c.backgroundId)?.name ?? '';
    final subtitle = [race, if (bg.isNotEmpty) bg].join(' · ');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      children: [
        if (_showSheetHeader) ...[
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
                            // Flexible: un nombre largo en un teléfono angosto
                            // desbordaba la cabecera en vez de recortarse.
                            Flexible(
                              child: Text(
                                _c.name,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 16, color: muted),
                          ],
                        ),
                      ),
                    ),
                    Text(subtitle, style: TextStyle(color: muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Renglón propio y no pegado al nombre: con la multiclase la
          // composición de clases es parte del personaje, y en línea con el
          // subtítulo se perdía como un dato más entre puntos medios.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GoldPill('Nivel ${_c.level}'),
              for (final id in _c.classHistory.toSet()) _classPill(id),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Antes que la Forma Salvaje: es lo más urgente que puede decir esta
        // pantalla, y se ve en todas las pestañas porque nadie mira Combate
        // todo el tiempo esperando su turno.
        if (_turnBanner() case final banner?) ...[
          banner,
          const SizedBox(height: 16),
        ],
        // Va arriba de las placas y en todas las pestañas: son justo los
        // números que cambiaron, y una ficha que muestra otra CA sin decir por
        // qué se lee como un error de la app.
        if (wildShapeForm case final beast?) ...[
          _wildShapeBanner(beast),
          const SizedBox(height: 16),
        ],
        if (_showSheetHeader) ...[_tacticalBand(s), const SectionRule()],
        _tabContent(_tab),
      ],
    );
  }

  /// El cartel de turno, o `null` fuera de combate o cuando todavía falta.
  ///
  /// Deliberadamente no dice nada más: nunca el orden, nunca cuántos faltan,
  /// nunca quién más está en la mesa. Verlo delataría cuántos enemigos hay
  /// antes de que aparezcan — la misma frontera que ya separa Modo DM del
  /// resto de la app.
  Widget? _turnBanner() {
    final pal = context.palette;
    final (icon, color, text) = switch (_turn) {
      TurnStatus.next => (
        Icons.hourglass_top,
        pal.gold,
        'Preparate, seguís vos.',
      ),
      TurnStatus.active => (Icons.bolt, pal.verdant, 'Es tu turno.'),
      TurnStatus.waiting || TurnStatus.none => (null, null, null),
    };
    if (text == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
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
  ///
  /// Se pliega tocando el encabezado. El objetivo táctil es la fila entera y no
  /// solo la flecha: en el celular una flecha de 18px es un blanco incómodo, y
  /// tarjetas como Competencias son largas justo ahí.
  Widget sheetCard({
    required IconData icon,
    required String title,
    Widget? trailing,

    /// Con qué se recuerda que está plegada, cuando el título no alcanza.
    ///
    /// Por defecto es el título, que es único en casi toda la ficha. No lo es
    /// en Campaña: con dos campañas apiladas hay dos tarjetas «Batallas», y sin
    /// esto plegar una plegaría las dos.
    String? collapseKey,
    required Widget child,
  }) {
    final pal = context.palette;
    final key = collapseKey ?? title;
    final collapsed = _collapsedCards.contains(key);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggleCard(key),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
              decoration: BoxDecoration(
                border: collapsed
                    ? null
                    : Border(bottom: BorderSide(color: pal.hairline)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: pal.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // La acción de la tarjeta no tiene sentido con el contenido
                  // escondido, y encima competiría por el toque de plegado.
                  if (!collapsed && trailing != null) trailing,
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: context.motion(const Duration(milliseconds: 150)),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: pal.textMuted,
                      semanticLabel: collapsed ? 'Desplegar' : 'Plegar',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) child,
        ],
      ),
    );
  }
}
