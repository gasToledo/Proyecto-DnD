part of 'homebrew_screen.dart';

extension _HomebrewSections on _HomebrewScreenState {
  // ------------------------------------------------------- Panel y portada

  /// El panel de categorías: qué hay, cuánto hay y las dos acciones que valen
  /// para todo el contenido.
  ///
  /// Reemplaza a las ocho pestañas desplazables, que en cualquier ventana
  /// angosta dejaban Conjuros y Criaturas fuera de la vista y no decían nada
  /// de lo que había adentro de cada una.
  Widget _rail(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final searching = _needle.isNotEmpty;
    // Desde el Drawer, navegar tiene que cerrarlo primero.
    void run(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    return Container(
      width: inDrawer ? null : 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arriba de la navegación y no adentro de una categoría: lo que se
          // busca es una entrada, y de qué categoría es se ve en el resultado.
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Buscar',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searching
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => run(_clearSearch),
                    )
                  : null,
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          appNavItem(
            context,
            icon: Icons.auto_fix_high,
            label: 'Portada',
            // Buscando no hay sección abierta: marcar una sería mentir sobre
            // lo que se está mostrando.
            active: !searching && _section == null,
            onTap: () => run(() => _open(null)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Eyebrow(searching ? 'Coincidencias' : 'Tu contenido'),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final category in _Category.values)
                  appNavItem(
                    context,
                    icon: category.icon,
                    label: category.label,
                    active: !searching && _section == category,
                    count: '${_namesOf(category).length}',
                    onTap: () => run(() => _open(category)),
                  ),
              ],
            ),
          ),
          Divider(color: pal.hairline, height: 25),
          // Bajaron del AppBar, donde eran dos íconos sin nombre que nadie
          // encontraba. Acá tienen su rótulo y quedan al lado de lo que
          // importan, que es todo el contenido y no una categoría.
          appNavItem(
            context,
            icon: Icons.download,
            label: 'Importar pack',
            onTap: () => run(_importHomebrew),
          ),
          appNavItem(
            context,
            icon: Icons.upload_file,
            label: 'Exportar todo',
            onTap: () => run(_exportHomebrew),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    // La búsqueda manda sobre la sección: mientras haya texto, lo que se
    // muestra son las coincidencias de todas las categorías.
    if (_needle.isNotEmpty) return _searchResults();
    final section = _section;
    if (section == null) return _portada();
    return _list(section, onAdd: () => _add(section), items: _rowsOf(section));
  }

  /// Los resultados de buscar, agrupados por categoría.
  ///
  /// Agrupados y no en una lista sola porque el mismo nombre significa cosas
  /// distintas según de dónde salga: un conjuro «Marea baja» y una criatura
  /// «Marea baja» son dos entradas, no una repetida.
  Widget _searchResults() {
    final groups = <_Category, List<Widget>>{};
    for (final category in _Category.values) {
      final rows = _rowsOf(category);
      if (rows.isNotEmpty) groups[category] = rows;
    }
    final total = groups.values.fold(0, (sum, rows) => sum + rows.length);

    // «Nada coincide» no es «no hay nada»: acá lo que corresponde es corregir
    // la búsqueda, no crear contenido.
    if (total == 0) {
      return AppEmptyState(
        icon: Icons.search_off,
        message: 'Nada de tu contenido coincide con «$_needle».',
        actions: [
          OutlinedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Limpiar búsqueda'),
          ),
        ],
      );
    }

    return Column(
      children: [
        _pageWidth(
          const EdgeInsets.fromLTRB(20, 18, 20, 0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total ${total == 1 ? 'resultado' : 'resultados'}',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'para «$_needle»',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageBody(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            children: [
              for (final group in groups.entries) ...[
                Eyebrow(group.key.label),
                DenseRows(children: group.value),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Nombres de una categoría, ordenados y filtrados por la búsqueda. De acá
  /// salen tanto el conteo del panel como la muestra de la portada, así que
  /// las dos cifras no pueden discrepar.
  List<String> _namesOf(_Category category) => switch (category) {
    _Category.weapons => _sortedNames(store.weapons.values, (e) => e.name),
    _Category.armor => _sortedNames(store.armor.values, (e) => e.name),
    _Category.items => _sortedNames(store.items.values, (e) => e.name),
    _Category.feats => _sortedNames(store.feats.values, (e) => e.name),
    _Category.races => _sortedNames(store.races.values, (e) => e.name),
    _Category.backgrounds => _sortedNames(
      store.backgrounds.values,
      (e) => e.name,
    ),
    _Category.spells => _sortedNames(store.spells.values, (e) => e.name),
    _Category.creatures => _sortedNames(store.creatures.values, (e) => e.name),
  };

  List<String> _sortedNames<T>(Iterable<T> values, String Function(T) name) =>
      _filtered(values, name).map(name).toList();

  /// Ordenadas por nombre y, si hay búsqueda activa, solo las que coinciden.
  List<T> _filtered<T>(Iterable<T> values, String Function(T) name) =>
      _matching(sortedByName(values, name), name);

  /// El filtro de la búsqueda, y el **único** lugar donde se decide qué
  /// coincide: el conteo del panel y las filas de la lista tienen que estar de
  /// acuerdo o el número miente.
  ///
  /// Pliega tildes y mayúsculas con `foldForSearch`, así «hoz de guerra»
  /// encuentra «Hoz de Guerra» y «pirana» encuentra «Piraña».
  List<T> _matching<T>(Iterable<T> values, String Function(T) name) {
    final needle = foldForSearch(_needle);
    if (needle.isEmpty) return values.toList();
    return [
      for (final value in values)
        if (foldForSearch(name(value)).contains(needle)) value,
    ];
  }

  /// La portada: qué tenés, de un vistazo.
  ///
  /// Antes se entraba directo a Armas —casi siempre vacía— y para saber si
  /// había algo guardado había que recorrer las ocho pestañas de a una.
  Widget _portada() {
    final total = _Category.values.fold(
      0,
      (sum, category) => sum + _namesOf(category).length,
    );
    if (total == 0) return _onboarding();

    return PageBody(
      children: [
        Text(
          'Tu taller',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total ${total == 1 ? 'entrada propia' : 'entradas propias'}. '
          'Todo lo que crees acá se suma al catálogo: aparece en la creación '
          'de personajes y en las fichas, igual que el contenido oficial.',
          style: TextStyle(fontSize: 13, color: context.palette.textMuted),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Categorías'),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 560 ? 2 : 1;
            final width = (box.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final category in _Category.values)
                  SizedBox(width: width, child: _categoryCard(category)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryCard(_Category category) {
    final pal = context.palette;
    final names = _namesOf(category);
    final empty = names.isEmpty;
    final accent = empty ? pal.textMuted : pal.gold;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(category),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(category.icon, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: empty
                            ? pal.textMuted
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${names.length}',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Una muestra, no un resumen: dice de qué se trata lo que hay
              // adentro sin prometer que estén todos.
              Text(
                empty ? 'Nada todavía.' : names.take(2).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La primera vez: sin nada guardado, la portada no tiene conteos que
  /// mostrar, y una grilla de ocho ceros no explica para qué sirve la pantalla.
  Widget _onboarding() {
    final pal = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_fix_high, color: pal.gold, size: 32),
                const SizedBox(height: 16),
                Text(
                  'Tu taller está vacío',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Homebrew es contenido tuyo: un arma, un conjuro, una '
                  'criatura. Se guarda en tu cuenta y se suma al catálogo, '
                  'así que desde que lo guardes aparece en la creación de '
                  'personajes y en las fichas, al lado del oficial.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _open(_Category.weapons),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Empezar por un arma'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importHomebrew,
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Importar un pack'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- Categorías

  /// El molde de las ocho listas: encabezado con el nombre, cuánto hay y el
  /// botón de agregar, y abajo las filas.
  Widget _list(
    _Category category, {
    required VoidCallback onAdd,
    required List<Widget> items,
  }) {
    return Column(
      children: [
        _pageWidth(
          const EdgeInsets.fromLTRB(20, 18, 20, 0),
          Row(
            children: [
              Text(
                category.label,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              GoldPill('${items.length}', highlighted: false),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(category.addLabel),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              // Acá «no hay nada» es la única situación posible: la pantalla
              // todavía no filtra ni busca, así que no hace falta el otro
              // vacío. El botón de crear ya está en el encabezado, arriba.
              ? AppEmptyState(
                  icon: category.icon,
                  message:
                      'Todavía no agregaste nada en '
                      '${category.label.toLowerCase()}.',
                )
              : PageBody(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  children: [DenseRows(children: items)],
                ),
        ),
      ],
    );
  }

  /// Centra algo con el mismo ancho máximo que [PageBody], para lo que va
  /// fuera de su lista (el encabezado, que no tiene que scrollear con ella).
  Widget _pageWidth(EdgeInsetsGeometry padding, Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(padding: padding, child: child),
    ),
  );

  Widget _tile(
    String title,
    String subtitle, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Eliminar $title',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  /// Las filas de una categoría: ordenadas, filtradas por la búsqueda y con
  /// su acción de editar y de borrar.
  ///
  /// Las arma un solo lugar porque las leen dos vistas —la lista de la
  /// categoría y los resultados de la búsqueda— y una fila que se dibujara
  /// distinto en cada una sería la misma entrada con dos caras.
  List<Widget> _rowsOf(_Category category) => switch (category) {
    _Category.weapons => [
      for (final w in _filtered(store.weapons.values, (e) => e.name))
        _tile(
          w.name,
          '${_weaponCategories[w.category] ?? w.category} · ${w.damageDice} '
          '${DamageType.labelFor(w.damageType)}',
          onEdit: () => _editWeapon(w),
          onDelete: () => _delete(
            'el arma',
            w.name,
            () => store.deleteWeapon(w.id),
            () => repo.weapons.remove(w.id),
          ),
        ),
    ],
    _Category.armor => [
      for (final a in _filtered(store.armor.values, (e) => e.name))
        _tile(
          a.name,
          '${_armorCategories[a.category] ?? a.category} · CA ${a.baseAc}',
          onEdit: () => _editArmor(a),
          onDelete: () => _delete(
            'la armadura',
            a.name,
            () => store.deleteArmor(a.id),
            () => repo.armor.remove(a.id),
          ),
        ),
    ],
    _Category.items => [
      for (final i in _filtered(store.items.values, (e) => e.name))
        _tile(
          i.name,
          [
            _itemCategories[i.category] ?? i.category,
            formatCost(i.costCp),
            if (i.weight > 0) '${formatPounds(i.weight)} lb',
            if (i.bundleSize > 1) 'paquete de ${i.bundleSize}',
            if (i.rarity != null) _itemRarities[i.rarity] ?? i.rarity!,
          ].join(' · '),
          onEdit: () => _editItem(i),
          onDelete: () => _delete(
            'el objeto',
            i.name,
            () => store.deleteItem(i.id),
            () => repo.items.remove(i.id),
          ),
        ),
    ],
    _Category.feats => [
      for (final f in _filtered(store.feats.values, (e) => e.name))
        _tile(
          f.name,
          '${_featCategories[f.category] ?? f.category} · '
          '${f.effects.length} efecto(s)',
          onEdit: () => _editFeat(f),
          onDelete: () => _delete(
            'la dote',
            f.name,
            () => store.deleteFeat(f.id),
            () => repo.feats.remove(f.id),
          ),
        ),
    ],
    _Category.races => [
      for (final r in _filtered(store.races.values, (e) => e.name))
        _tile(
          r.name,
          '${r.size} · ${r.speed} ft · ${r.effects.length} rasgo(s)',
          onEdit: () => _editRace(r),
          onDelete: () => _delete(
            'la especie',
            r.name,
            () => store.deleteRace(r.id),
            () => repo.races.remove(r.id),
          ),
        ),
    ],
    _Category.backgrounds => [
      for (final b in _filtered(store.backgrounds.values, (e) => e.name))
        _tile(
          b.name,
          b.skillProficiencies.map(Skill.labelFor).join(', '),
          onEdit: () => _editBackground(b),
          onDelete: () => _delete(
            'el trasfondo',
            b.name,
            () => store.deleteBackground(b.id),
            () => repo.backgrounds.remove(b.id),
          ),
        ),
    ],
    // Los conjuros son la excepción del orden: van por nivel y recién después
    // por nombre, que es como se los busca en el manual y en la ficha.
    _Category.spells => [
      for (final s in _matching(
        store.spells.values.toList()..sort(
          (a, b) => a.level != b.level
              ? a.level.compareTo(b.level)
              : compareContentNames(a.name, b.name),
        ),
        (e) => e.name,
      ))
        _tile(
          s.name,
          '${s.isCantrip ? "Truco" : "Nivel ${s.level}"}'
          '${s.school.isEmpty ? "" : " · ${s.school}"}'
          '${s.classes.isEmpty ? "" : " · ${s.classes.map((c) => _spellClasses[c] ?? c).join(", ")}"}',
          onEdit: () => _editSpell(s),
          onDelete: () => _delete(
            'el conjuro',
            s.name,
            () => store.deleteSpell(s.id),
            () => repo.spells.remove(s.id),
          ),
        ),
    ],
    _Category.creatures => [
      for (final c in _filtered(store.creatures.values, (e) => e.name))
        _tile(
          c.name,
          [
            c.kind,
            'CA ${c.ac}',
            '${c.hp} PG',
            if (c.cr != null) 'VD ${_formatCr(c.cr)}',
            if (c.availableToCharacters) 'disponible para personajes',
          ].join(' · '),
          onEdit: () => _editCreature(c),
          onDelete: () => _delete(
            'la criatura',
            c.name,
            () => store.deleteCreature(c.id),
            () => repo.creatures.remove(c.id),
          ),
        ),
    ],
  };

  /// Abre el formulario vacío de la categoría.
  void _add(_Category category) => switch (category) {
    _Category.weapons => _editWeapon(),
    _Category.armor => _editArmor(),
    _Category.items => _editItem(),
    _Category.feats => _editFeat(),
    _Category.races => _editRace(),
    _Category.backgrounds => _editBackground(),
    _Category.spells => _editSpell(),
    _Category.creatures => _editCreature(),
  };

  // -------------------------------------------------------------- Armas
  Future<void> _editWeapon([Weapon? initial]) async {
    final w = await Navigator.of(context).push<Weapon>(
      MaterialPageRoute(builder: (_) => WeaponForm(initial: initial)),
    );
    if (w == null) return _discarded();
    if (!await _persist(() => store.saveWeapon(w))) return;
    repo.weapons[w.id] = w;
    _saved(w.name);
  }

  // ---------------------------------------------------------- Armaduras
  Future<void> _editArmor([Armor? initial]) async {
    final a = await Navigator.of(context).push<Armor>(
      MaterialPageRoute(builder: (_) => ArmorForm(initial: initial)),
    );
    if (a == null) return _discarded();
    if (!await _persist(() => store.saveArmor(a))) return;
    repo.armor[a.id] = a;
    _saved(a.name);
  }

  // ------------------------------------------------------------- Objetos
  Future<void> _editItem([Item? initial]) async {
    final i = await Navigator.of(
      context,
    ).push<Item>(MaterialPageRoute(builder: (_) => ItemForm(initial: initial)));
    if (i == null) return _discarded();
    if (!await _persist(() => store.saveItem(i))) return;
    repo.items[i.id] = i;
    _saved(i.name);
  }

  // --------------------------------------------------------------- Dotes
  Future<void> _editFeat([Feat? initial]) async {
    final f = await Navigator.of(
      context,
    ).push<Feat>(MaterialPageRoute(builder: (_) => FeatForm(initial: initial)));
    if (f == null) return _discarded();
    if (!await _persist(() => store.saveFeat(f))) return;
    repo.feats[f.id] = f;
    _saved(f.name);
  }

  // --------------------------------------------------------------- Razas
  Future<void> _editRace([Race? initial]) async {
    final r = await Navigator.of(
      context,
    ).push<Race>(MaterialPageRoute(builder: (_) => RaceForm(initial: initial)));
    if (r == null) return _discarded();
    if (!await _persist(() => store.saveRace(r))) return;
    repo.races[r.id] = r;
    _saved(r.name);
  }

  // ---------------------------------------------------------- Trasfondos
  Future<void> _editBackground([Background? initial]) async {
    final b = await Navigator.of(context).push<Background>(
      MaterialPageRoute(
        builder: (_) => BackgroundForm(initial: initial, repo: repo),
      ),
    );
    if (b == null) return _discarded();
    if (!await _persist(() => store.saveBackground(b))) return;
    repo.backgrounds[b.id] = b;
    _saved(b.name);
  }

  // ---------------------------------------------------------- Conjuros
  Future<void> _editSpell([Spell? initial]) async {
    final s = await Navigator.of(context).push<Spell>(
      MaterialPageRoute(builder: (_) => SpellForm(initial: initial)),
    );
    if (s == null) return _discarded();
    if (!await _persist(() => store.saveSpell(s))) return;
    repo.spells[s.id] = s;
    _saved(s.name);
  }

  // ------------------------------------------------------------ Criaturas
  Future<void> _editCreature([Creature? initial]) async {
    final c = await Navigator.of(context).push<Creature>(
      MaterialPageRoute(builder: (_) => CreatureForm(initial: initial)),
    );
    if (c == null) return _discarded();
    if (!await _persist(() => store.saveCreature(c))) return;
    repo.creatures[c.id] = c;
    _saved(c.name);
  }

  /// Borra una entrada homebrew, preguntando primero.
  ///
  /// Preguntar no es ceremonia: el botón de borrar está a un toque en cada
  /// fila, no hay deshacer, y lo borrado puede estar en uso en una ficha ya
  /// creada. El aviso además nombra qué se va a borrar, para que un toque en
  /// la fila equivocada se note antes y no después.
  Future<void> _delete(
    String kind,
    String name,
    Future<void> Function() fromStore,
    VoidCallback fromRepo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar $kind «$name»?'),
        content: const Text(
          'Esta acción no se puede deshacer. Los personajes que ya lo estén '
          'usando van a quedar con una advertencia en la ficha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await _persist(fromStore)) return;
    fromRepo();
    _refresh();
    if (mounted) {
      showAppMessage(
        context,
        '$name se eliminó.',
        tone: AppMessageTone.success,
      );
    }
  }
}
