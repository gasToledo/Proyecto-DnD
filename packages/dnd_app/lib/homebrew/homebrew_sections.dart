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
          appNavItem(
            context,
            icon: Icons.auto_fix_high,
            label: 'Portada',
            active: _section == null,
            onTap: () => run(() => _open(null)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Eyebrow('Tu contenido'),
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
                    active: _section == category,
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

  Widget _content() => switch (_section) {
    null => _portada(),
    _Category.weapons => _weaponsSection(),
    _Category.armor => _armorSection(),
    _Category.items => _itemsSection(),
    _Category.feats => _featsSection(),
    _Category.races => _racesSection(),
    _Category.backgrounds => _backgroundsSection(),
    _Category.spells => _spellsSection(),
    _Category.creatures => _creaturesSection(),
  };

  /// Nombres de una categoría, ordenados. De acá salen tanto el conteo del
  /// panel como la muestra de la portada, así que las dos cifras no pueden
  /// discrepar.
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
      sortedByName(values, name).map(name).toList();

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

  // -------------------------------------------------------------- Armas
  Widget _weaponsSection() => _list(
    _Category.weapons,
    onAdd: () => _editWeapon(),
    items: sortedByName(store.weapons.values, (e) => e.name)
        .map(
          (w) => _tile(
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
        )
        .toList(),
  );

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
  Widget _armorSection() => _list(
    _Category.armor,
    onAdd: () => _editArmor(),
    items: sortedByName(store.armor.values, (e) => e.name)
        .map(
          (a) => _tile(
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
        )
        .toList(),
  );

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
  Widget _itemsSection() => _list(
    _Category.items,
    onAdd: () => _editItem(),
    items: sortedByName(store.items.values, (e) => e.name)
        .map(
          (i) => _tile(
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
        )
        .toList(),
  );

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
  Widget _featsSection() => _list(
    _Category.feats,
    onAdd: () => _editFeat(),
    items: sortedByName(store.feats.values, (e) => e.name)
        .map(
          (f) => _tile(
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
        )
        .toList(),
  );

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
  Widget _racesSection() => _list(
    _Category.races,
    onAdd: () => _editRace(),
    items: sortedByName(store.races.values, (e) => e.name)
        .map(
          (r) => _tile(
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
        )
        .toList(),
  );

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
  Widget _backgroundsSection() => _list(
    _Category.backgrounds,
    onAdd: () => _editBackground(),
    items: sortedByName(store.backgrounds.values, (e) => e.name)
        .map(
          (b) => _tile(
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
        )
        .toList(),
  );

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
  Widget _spellsSection() => _list(
    _Category.spells,
    onAdd: () => _editSpell(),
    items:
        (store.spells.values.toList()..sort(
              (a, b) => a.level != b.level
                  ? a.level.compareTo(b.level)
                  : compareContentNames(a.name, b.name),
            ))
            .map(
              (s) => _tile(
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
            )
            .toList(),
  );

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
  Widget _creaturesSection() => _list(
    _Category.creatures,
    onAdd: () => _editCreature(),
    items: sortedByName(store.creatures.values, (e) => e.name)
        .map(
          (c) => _tile(
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
        )
        .toList(),
  );

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
