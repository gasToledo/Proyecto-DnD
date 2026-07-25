part of '../sheet_screen.dart';

extension _SheetInventorySection on _SheetScreenState {
  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() {
    final armors = repo.armor.values.where((a) => !a.isShield).toList();
    final weapons = repo.weapons.values.toList();
    return PageBody(
      children: [
        const Eyebrow('Armadura equipada'),
        DropdownButtonFormField<String?>(
          key: ValueKey('armor-${_c.equippedArmorId}'),
          initialValue: _c.equippedArmorId,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin armadura')),
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
        const Eyebrow('Arma equipada'),
        DropdownButtonFormField<String?>(
          key: ValueKey(
            'weapon-'
            '${_c.equippedWeaponIds.isEmpty ? null : _c.equippedWeaponIds.first}',
          ),
          initialValue: _c.equippedWeaponIds.isEmpty
              ? null
              : _c.equippedWeaponIds.first,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Sin arma (puños)'),
            ),
            ...weapons.map(
              (w) => DropdownMenuItem(
                value: w.id,
                child: Text('${w.name} (${w.damageDice})'),
              ),
            ),
          ],
          onChanged: (v) => _replace(_c.copyWith(equippedWeaponIds: [?v])),
        ),
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
    );
  }
}
