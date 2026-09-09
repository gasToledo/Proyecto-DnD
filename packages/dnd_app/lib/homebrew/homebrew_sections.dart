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
          LayoutBuilder(
            builder: (context, box) {
              // Angosto, «Duplicar del catálogo» se queda con el ícono y
              // «Agregar arma» con el verbo: los dos botones enteros miden
              // unos 660 px juntos y no entran en un teléfono. Qué se agrega
              // ya lo dice el título que está al lado.
              final tight = box.maxWidth < _headerWideWidth;
              // `Wrap` y no `Row` con `Spacer`: cuando el título y los dos
              // botones no entran en una línea, los botones bajan a la
              // siguiente en vez de desbordar. Con espacio de sobra queda
              // igual que un Row —el título a la izquierda, los botones a la
              // derecha— que es lo que hace `spaceBetween`.
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tight)
                        IconButton(
                          tooltip: 'Duplicar del catálogo',
                          icon: const Icon(Icons.content_copy_outlined),
                          onPressed: () => _duplicateFromCatalog(category),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _duplicateFromCatalog(category),
                          icon: const Icon(
                            Icons.content_copy_outlined,
                            size: 18,
                          ),
                          label: const Text('Duplicar del catálogo'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add),
                        label: Text(tight ? 'Agregar' : category.addLabel),
                      ),
                    ],
                  ),
                ],
              );
            },
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

  /// Una fila de contenido: el nombre, lo cualitativo en pills y lo comparable
  /// en cifras.
  ///
  /// Antes todo eso era una sola línea gris de prosa separada por puntos.
  /// Un peso, un precio o una CA existen para compararse con los de la fila de
  /// al lado, y para eso piden cifras tabulares y una columna, no una oración.
  ///
  /// Las acciones están siempre a la vista y no al pasar el mouse: en un
  /// teléfono no hay hover, y una acción que solo aparece al apuntarla no
  /// existe para quien navega con el teclado o con el dedo.
  Widget _tile(
    String title, {
    List<String> pills = const [],
    List<(String, String)> stats = const [],
    required VoidCallback onEdit,
    required VoidCallback onDuplicate,
    required VoidCallback onDelete,
  }) {
    final pal = context.palette;

    Widget stat((String, String) entry, {required bool wide}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          entry.$1.toUpperCase(),
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            color: pal.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          entry.$2,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    Widget statsBand({required bool wide}) => Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [for (final entry in stats) stat(entry, wide: wide)],
    );

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: LayoutBuilder(
          builder: (context, box) {
            // Con ancho de sobra las cifras van a la derecha, donde se
            // alinean con las de las otras filas y se pueden comparar de un
            // barrido vertical. Apretadas caen debajo del nombre, que es lo
            // único que entra en un teléfono sin encimarse.
            final wide = box.maxWidth >= _rowWideWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final pill in pills)
                              GoldPill(pill, highlighted: false),
                          ],
                        ),
                      ],
                      if (!wide && stats.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        statsBand(wide: false),
                      ],
                    ],
                  ),
                ),
                if (wide && stats.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  // Flexible para que una fila con muchas cifras las apile en
                  // dos corridas antes que desbordar.
                  Flexible(child: statsBand(wide: true)),
                ],
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Duplicar $title',
                  icon: const Icon(Icons.content_copy_outlined),
                  onPressed: onDuplicate,
                ),
                IconButton(
                  tooltip: 'Eliminar $title',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Las filas de una categoría: ordenadas, filtradas por la búsqueda y con
  /// sus tres acciones (editar tocándola, duplicar y borrar).
  ///
  /// Las arma un solo lugar porque las leen dos vistas —la lista de la
  /// categoría y los resultados de la búsqueda— y una fila que se dibujara
  /// distinto en cada una sería la misma entrada con dos caras.
  ///
  /// El reparto es siempre el mismo: en `pills` lo cualitativo (categoría,
  /// propiedades, rareza) y en `stats` lo que se compara contra la fila de al
  /// lado (peso, precio, CA, PG).
  List<Widget> _rowsOf(_Category category) => switch (category) {
    _Category.weapons => [
      for (final w in _filtered(store.weapons.values, (e) => e.name))
        _tile(
          w.name,
          pills: [
            _weaponCategories[w.category] ?? w.category,
            DamageType.labelFor(w.damageType),
            if (w.magicBonus != 0) '+${w.magicBonus}',
            for (final property in w.properties)
              _weaponPropOptions[property] ?? property,
          ],
          stats: [
            (
              'Daño',
              w.versatileDice == null
                  ? w.damageDice
                  : '${w.damageDice} / ${w.versatileDice}',
            ),
            if (w.weight > 0) ('Peso', '${formatPounds(w.weight)} lb'),
            if (w.costCp > 0) ('Precio', formatCost(w.costCp)),
          ],
          onEdit: () => _editWeapon(w),
          onDuplicate: () => _openCopy(category, w.toJson()),
          onDelete: () => _delete(
            'el arma',
            w.name,
            w.id,
            () => store.deleteWeapon(w.id),
            () => repo.weapons.remove(w.id),
          ),
        ),
    ],
    _Category.armor => [
      for (final a in _filtered(store.armor.values, (e) => e.name))
        _tile(
          a.name,
          pills: [
            _armorCategories[a.category] ?? a.category,
            if (a.stealthDisadvantage) 'Sigilo con desventaja',
          ],
          stats: [
            ('CA', '${a.baseAc}'),
            if (a.weight > 0) ('Peso', '${formatPounds(a.weight)} lb'),
            if (a.costCp > 0) ('Precio', formatCost(a.costCp)),
          ],
          onEdit: () => _editArmor(a),
          onDuplicate: () => _openCopy(category, a.toJson()),
          onDelete: () => _delete(
            'la armadura',
            a.name,
            a.id,
            () => store.deleteArmor(a.id),
            () => repo.armor.remove(a.id),
          ),
        ),
    ],
    _Category.items => [
      for (final i in _filtered(store.items.values, (e) => e.name))
        _tile(
          i.name,
          pills: [
            _itemCategories[i.category] ?? i.category,
            if (i.rarity != null) _itemRarities[i.rarity] ?? i.rarity!,
            if (i.requiresAttunement) 'Sintonización',
          ],
          stats: [
            if (i.weight > 0) ('Peso', '${formatPounds(i.weight)} lb'),
            if (i.costCp > 0) ('Precio', formatCost(i.costCp)),
            if (i.maxCharges != null) ('Cargas', '${i.maxCharges}'),
            if (i.bundleSize > 1) ('Paquete', '${i.bundleSize}'),
          ],
          onEdit: () => _editItem(i),
          onDuplicate: () => _openCopy(category, i.toJson()),
          onDelete: () => _delete(
            'el objeto',
            i.name,
            i.id,
            () => store.deleteItem(i.id),
            () => repo.items.remove(i.id),
          ),
        ),
    ],
    _Category.feats => [
      for (final f in _filtered(store.feats.values, (e) => e.name))
        _tile(
          f.name,
          pills: [
            _featCategories[f.category] ?? f.category,
            if (f.repeatable) 'Repetible',
          ],
          stats: [('Efectos', '${f.effects.length}')],
          onEdit: () => _editFeat(f),
          onDuplicate: () => _openCopy(category, f.toJson()),
          onDelete: () => _delete(
            'la dote',
            f.name,
            f.id,
            () => store.deleteFeat(f.id),
            () => repo.feats.remove(f.id),
          ),
        ),
    ],
    _Category.races => [
      for (final r in _filtered(store.races.values, (e) => e.name))
        _tile(
          r.name,
          pills: [r.size],
          stats: [
            ('Velocidad', '${r.speed} ft'),
            ('Rasgos', '${r.effects.length}'),
          ],
          onEdit: () => _editRace(r),
          onDuplicate: () => _openCopy(category, r.toJson()),
          onDelete: () => _delete(
            'la especie',
            r.name,
            r.id,
            () => store.deleteRace(r.id),
            () => repo.races.remove(r.id),
          ),
        ),
    ],
    _Category.backgrounds => [
      for (final b in _filtered(store.backgrounds.values, (e) => e.name))
        _tile(
          b.name,
          pills: [
            for (final skill in b.skillProficiencies) Skill.labelFor(skill),
          ],
          stats: [
            if (b.toolProficiencies.isNotEmpty)
              ('Herramientas', '${b.toolProficiencies.length}'),
          ],
          onEdit: () => _editBackground(b),
          onDuplicate: () => _openCopy(category, b.toJson()),
          onDelete: () => _delete(
            'el trasfondo',
            b.name,
            b.id,
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
          pills: [
            s.isCantrip ? 'Truco' : 'Nivel ${s.level}',
            if (s.school.isNotEmpty) s.school,
            if (s.concentration) 'Concentración',
            if (s.ritual) 'Ritual',
            for (final klass in s.classes) _spellClasses[klass] ?? klass,
          ],
          onEdit: () => _editSpell(s),
          onDuplicate: () => _openCopy(category, s.toJson()),
          onDelete: () => _delete(
            'el conjuro',
            s.name,
            s.id,
            () => store.deleteSpell(s.id),
            () => repo.spells.remove(s.id),
          ),
        ),
    ],
    _Category.creatures => [
      for (final c in _filtered(store.creatures.values, (e) => e.name))
        _tile(
          c.name,
          pills: [
            c.kind,
            if (c.availableToCharacters) 'Disponible para personajes',
          ],
          stats: [
            ('CA', c.ac),
            ('PG', c.hp),
            if (c.cr != null) ('VD', _formatCr(c.cr)),
          ],
          onEdit: () => _editCreature(c),
          onDuplicate: () => _openCopy(category, c.toJson()),
          onDelete: () => _delete(
            'la criatura',
            c.name,
            c.id,
            () => store.deleteCreature(c.id),
            () => repo.creatures.remove(c.id),
          ),
        ),
    ],
  };

  // ------------------------------------------------------------- Duplicar

  /// Abre el formulario con una **copia** de [json].
  ///
  /// Duplicar es el atajo que más cambia el uso diario: casi ningún homebrew
  /// nace de cero, nace de una espada larga a la que se le cambian dos campos.
  /// La copia viaja por JSON porque es el mismo ida y vuelta que ya hacen el
  /// guardado y la importación: lo que el formulario no edita llega igual al
  /// documento nuevo.
  void _openCopy(_Category category, Map<String, dynamic> json) {
    final name = '${json['name']} (copia)';
    final copy = {
      ...json,
      'id': homebrewId(name),
      'name': name,
      'source': ContentSource.homebrew.toJson(),
    };
    switch (category) {
      case _Category.weapons:
        _editWeapon(Weapon.fromJson(copy));
      case _Category.armor:
        _editArmor(Armor.fromJson(copy));
      case _Category.items:
        _editItem(Item.fromJson(copy));
      case _Category.feats:
        _editFeat(Feat.fromJson(copy));
      case _Category.races:
        _editRace(Race.fromJson(copy));
      case _Category.backgrounds:
        _editBackground(Background.fromJson(copy));
      case _Category.spells:
        _editSpell(Spell.fromJson(copy));
      case _Category.creatures:
        _editCreature(Creature.fromJson(copy));
    }
  }

  /// Elegir una entrada oficial y abrirla como copia propia.
  Future<void> _duplicateFromCatalog(_Category category) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CatalogPicker(category: category, options: _catalogOf(category)),
    );
    if (chosen == null || !mounted) return;
    final json = _catalogJson(category, chosen);
    if (json != null) _openCopy(category, json);
  }

  /// El catálogo elegible: todo lo que **no** es tuyo, por id y nombre.
  ///
  /// Lo propio queda afuera porque para eso está el botón de duplicar de cada
  /// fila, que ya sabe cuál es.
  List<(String, String)> _catalogOf(_Category category) {
    List<(String, String)> from<T>(
      Iterable<T> values,
      String Function(T) id,
      String Function(T) name,
      ContentSource Function(T) source,
    ) => [
      for (final value in sortedByName(
        values.where((v) => source(v) != ContentSource.homebrew),
        name,
      ))
        (id(value), name(value)),
    ];

    return switch (category) {
      _Category.weapons => from(
        repo.weapons.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.armor => from(
        repo.armor.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.items => from(
        repo.items.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.feats => from(
        repo.feats.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.races => from(
        repo.races.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.backgrounds => from(
        repo.backgrounds.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.spells => from(
        repo.spells.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
      _Category.creatures => from(
        repo.creatures.values,
        (e) => e.id,
        (e) => e.name,
        (e) => e.source,
      ),
    };
  }

  /// El documento de una entrada del catálogo. Se resuelve recién al elegirla:
  /// serializar los cientos de conjuros y criaturas para llenar una lista de
  /// nombres sería trabajo tirado.
  Map<String, dynamic>? _catalogJson(_Category category, String id) =>
      switch (category) {
        _Category.weapons => repo.weapons[id]?.toJson(),
        _Category.armor => repo.armor[id]?.toJson(),
        _Category.items => repo.items[id]?.toJson(),
        _Category.feats => repo.feats[id]?.toJson(),
        _Category.races => repo.races[id]?.toJson(),
        _Category.backgrounds => repo.backgrounds[id]?.toJson(),
        _Category.spells => repo.spells[id]?.toJson(),
        _Category.creatures => repo.creatures[id]?.toJson(),
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
    String id,
    Future<void> Function() fromStore,
    VoidCallback fromRepo,
  ) async {
    final pal = context.palette;
    // Quién lo usa se calcula antes de preguntar: es el dato que convierte el
    // aviso en una decisión. Vacío también informa —«ninguna ficha lo usa» es
    // permiso para borrar tranquilo—, así que no es un caso a esconder.
    final users = charactersUsing(id, widget.characters);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: '¿Eliminar $kind «$name»?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (users.isEmpty)
              const Text('Ninguna de tus fichas lo está usando.')
            else ...[
              Text(
                users.length == 1
                    ? 'Lo usa 1 ficha:'
                    : 'Lo usan ${users.length} fichas:',
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: pal.plaque,
                  border: Border.all(color: pal.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final character in users)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                character.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${repo.characterClass(character.classId)?.name ?? character.classId} '
                              '${character.level}',
                              style: TextStyle(
                                fontSize: 13,
                                color: pal.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                users.length == 1
                    ? 'Va a quedar con una advertencia en su ficha.'
                    : 'Van a quedar con una advertencia en sus fichas.',
                style: TextStyle(color: pal.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Esta acción no se puede deshacer.'),
          ],
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Eliminar',
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.pop(ctx, true),
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

/// Ancho a partir del cual una fila muestra sus cifras a la derecha, donde se
/// alinean con las de las filas vecinas. Es el mismo corte que usa el perfil
/// de criatura para decidir si apila o no.
const double _rowWideWidth = 520;

/// Ancho a partir del cual el encabezado de la lista muestra sus dos botones
/// con el rótulo entero. Sale de medirlos: juntos rondan los 660 px.
const double _headerWideWidth = 700;

/// Elegir una entrada del catálogo oficial para copiarla.
///
/// Vive acá y no en `app_widgets.dart` porque hoy la usa una sola pantalla; si
/// aparece un segundo lugar que elija contenido por nombre, ahí se muda a la
/// biblioteca compartida.
class _CatalogPicker extends StatefulWidget {
  final _Category category;

  /// Las opciones como (id, nombre), ya ordenadas.
  final List<(String, String)> options;

  const _CatalogPicker({required this.category, required this.options});

  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(String, String)> get _results {
    final needle = foldForSearch(_query.trim());
    if (needle.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (foldForSearch(option.$2).contains(needle)) option,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final results = _results;
    return AppDialog(
      title: 'Duplicar ${widget.category.label.toLowerCase()}',
      width: 420,
      scrollable: false,
      content: SizedBox(
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Buscar en el catálogo',
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? AppEmptyState(
                      icon: Icons.search_off,
                      message:
                          'Nada del catálogo coincide con «${_query.trim()}».',
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: pal.hairline),
                      itemBuilder: (context, index) {
                        final (id, name) = results[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Text(name),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
