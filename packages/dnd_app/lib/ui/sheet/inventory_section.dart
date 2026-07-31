part of '../sheet_screen.dart';

extension _SheetInventorySection on _SheetScreenState {
  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() {
    final armors = repo.armor.values.where((a) => !a.isShield).toList();
    final weapons = repo.weapons.values.toList();
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

  /// Armas equipadas: las actuales como chips que se pueden quitar, más un
  /// combo para sumar otra. El catálogo completo no entra como lista de chips,
  /// y `equippedWeaponIds` admite varias (el motor arma un ataque por cada una).
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in equipped)
                  InputChip(
                    key: ValueKey('equipped-$id'),
                    label: Text(repo.weapon(id)?.name ?? id),
                    onDeleted: () => setWeapons([...equipped]..remove(id)),
                  ),
              ],
            ),
          ),
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
        if (equipped.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Hay un ataque por arma. La regla de combate con dos armas '
              '(acción adicional, arma Ligera, sin modificador al daño sin el '
              'estilo de combate) todavía no se aplica sola.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
