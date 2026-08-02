part of 'homebrew_screen.dart';

extension _HomebrewTabs on _HomebrewScreenState {
  Widget _list({
    required String addLabel,
    required VoidCallback onAdd,
    required List<Widget> items,
  }) {
    return PageBody(
      children: [
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Todavía no agregaste nada aquí.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          DenseRows(children: items),
      ],
    );
  }

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
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Armas
  Widget _weaponsTab() => _list(
    addLabel: 'Agregar arma',
    onAdd: () => _editWeapon(),
    items: sortedByName(store.weapons.values, (e) => e.name)
        .map(
          (w) => _tile(
            w.name,
            '${w.category} · ${w.damageDice} '
            '${DamageType.labelFor(w.damageType)}',
            onEdit: () => _editWeapon(w),
            onDelete: () => _delete(
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
    if (w == null) return;
    if (!await _persist(() => store.saveWeapon(w))) return;
    repo.weapons[w.id] = w;
    _refresh();
  }

  // ---------------------------------------------------------- Armaduras
  Widget _armorTab() => _list(
    addLabel: 'Agregar armadura',
    onAdd: () => _editArmor(),
    items: sortedByName(store.armor.values, (e) => e.name)
        .map(
          (a) => _tile(
            a.name,
            '${a.category} · CA ${a.baseAc}',
            onEdit: () => _editArmor(a),
            onDelete: () => _delete(
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
    if (a == null) return;
    if (!await _persist(() => store.saveArmor(a))) return;
    repo.armor[a.id] = a;
    _refresh();
  }

  // --------------------------------------------------------------- Dotes
  Widget _featsTab() => _list(
    addLabel: 'Agregar dote',
    onAdd: () => _editFeat(),
    items: sortedByName(store.feats.values, (e) => e.name)
        .map(
          (f) => _tile(
            f.name,
            '${f.category} · ${f.effects.length} efecto(s)',
            onEdit: () => _editFeat(f),
            onDelete: () => _delete(
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
    if (f == null) return;
    if (!await _persist(() => store.saveFeat(f))) return;
    repo.feats[f.id] = f;
    _refresh();
  }

  // --------------------------------------------------------------- Razas
  Widget _racesTab() => _list(
    addLabel: 'Agregar raza',
    onAdd: () => _editRace(),
    items: sortedByName(store.races.values, (e) => e.name)
        .map(
          (r) => _tile(
            r.name,
            '${r.size} · ${r.speed} ft · ${r.effects.length} rasgo(s)',
            onEdit: () => _editRace(r),
            onDelete: () => _delete(
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
    if (r == null) return;
    if (!await _persist(() => store.saveRace(r))) return;
    repo.races[r.id] = r;
    _refresh();
  }

  // ---------------------------------------------------------- Trasfondos
  Widget _backgroundsTab() => _list(
    addLabel: 'Agregar trasfondo',
    onAdd: () => _editBackground(),
    items: sortedByName(store.backgrounds.values, (e) => e.name)
        .map(
          (b) => _tile(
            b.name,
            b.skillProficiencies.join(', '),
            onEdit: () => _editBackground(b),
            onDelete: () => _delete(
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
    if (b == null) return;
    if (!await _persist(() => store.saveBackground(b))) return;
    repo.backgrounds[b.id] = b;
    _refresh();
  }

  // ---------------------------------------------------------- Conjuros
  Widget _spellsTab() => _list(
    addLabel: 'Agregar conjuro',
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
                '${s.classes.isEmpty ? "" : " · ${s.classes.join(", ")}"}',
                onEdit: () => _editSpell(s),
                onDelete: () => _delete(
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
    if (s == null) return;
    if (!await _persist(() => store.saveSpell(s))) return;
    repo.spells[s.id] = s;
    _refresh();
  }

  Future<void> _delete(
    Future<void> Function() fromStore,
    VoidCallback fromRepo,
  ) async {
    if (!await _persist(fromStore)) return;
    fromRepo();
    _refresh();
  }
}
