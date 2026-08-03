part of '../sheet_screen.dart';

extension _SheetInventorySection on _SheetScreenState {
  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() {
    final armors = repo.armorSorted.where((a) => !a.isShield).toList();
    final weapons = repo.weaponsSorted;
    return sheetCard(
      icon: Icons.backpack,
      title: 'Inventario y equipo',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('Armadura equipada'),
            DropdownButtonFormField<String?>(
              key: ValueKey('armor-${_c.equippedArmorId}'),
              initialValue: _c.equippedArmorId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin armadura'),
                ),
                ...armors.map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (CA ${a.baseAc})'),
                  ),
                ),
              ],
              onChanged: (v) => _replace(_c.copyWith(equippedArmorId: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Escudo (+2 CA)'),
              value: _c.shieldEquipped,
              onChanged: (v) => _replace(_c.copyWith(shieldEquipped: v)),
            ),
            const SizedBox(height: 16),
            const Eyebrow('Armas equipadas'),
            _equippedWeapons(weapons),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(width: 108, child: _acPlaque(sheet.armorClass)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'La Clase de Armadura se recalcula automáticamente según la '
                    'armadura, el escudo y tu modificador de Destreza.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Armas equipadas: una fila por arma con cómo se empuña, más un combo para
  /// sumar otra. `equippedWeaponIds` admite varias (el motor arma un ataque por
  /// cada una) y cómo se empuña cambia el ataque, así que se decide acá.
  Widget _equippedWeapons(List<Weapon> weapons) {
    final equipped = _c.equippedWeaponIds;
    final available = weapons.where((w) => !equipped.contains(w.id)).toList();

    void setWeapons(List<String> ids) =>
        _replace(_c.copyWith(equippedWeaponIds: ids));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (equipped.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Sin arma (puños).',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final id in equipped)
            _equippedWeaponRow(id, () => setWeapons([...equipped]..remove(id))),
        if (available.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('add-weapon-${equipped.length}'),
            initialValue: null,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Agregar arma',
            ),
            items: [
              for (final w in available)
                DropdownMenuItem(
                  value: w.id,
                  child: Text('${w.name} (${w.damageDice})'),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setWeapons([...equipped, v]);
            },
          ),
      ],
    );
  }

  /// Una fila de arma equipada: nombre, cómo se empuña y quitarla.
  ///
  /// Los dos interruptores solo aparecen cuando el arma los admite: Secundaria
  /// exige la propiedad Ligera y A dos manos exige daño versátil. Así la UI no
  /// deja armar una combinación que el motor tendría que advertir.
  Widget _equippedWeaponRow(String id, VoidCallback onRemove) {
    final w = repo.weapon(id);
    final offHand = _c.weaponOffHand[id] ?? false;
    final twoHanded = _c.weaponTwoHanded[id] ?? false;

    // Solo se empuña un arma en la secundaria: marcar una desmarca la anterior.
    void setOffHand(bool value) =>
        _replace(_c.copyWith(weaponOffHand: value ? {id: true} : const {}));

    void setTwoHanded(bool value) => _replace(
      _c.copyWith(weaponTwoHanded: {..._c.weaponTwoHanded, id: value}),
    );

    return Padding(
      key: ValueKey('equipped-$id'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(w?.name ?? id)),
          if (w != null && w.isLight)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                key: ValueKey('off-hand-$id'),
                label: const Text('Secundaria'),
                selected: offHand,
                onSelected: setOffHand,
              ),
            ),
          if (w?.versatileDice != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                key: ValueKey('two-handed-$id'),
                label: const Text('A dos manos'),
                selected: twoHanded,
                onSelected: setTwoHanded,
              ),
            ),
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
