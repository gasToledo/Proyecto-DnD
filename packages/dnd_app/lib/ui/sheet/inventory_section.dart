part of '../sheet_screen.dart';

/// Anchos fijos de las columnas del listado en pantalla ancha.
///
/// Son constantes y no `Expanded` porque el criterio de aceptación de §8.7 es
/// que cantidad, equipado y acciones **no cambien de columna entre filas**: con
/// anchos elásticos, una fila con nombre largo corre las demás celdas y la
/// tabla deja de leerse en vertical.
const _colQuantity = 44.0;
const _colEquipped = 76.0;
const _colWeight = 76.0;
const _colMenu = 44.0;

/// Etiqueta visible de la familia. La comparten la fila y el buscador para que
/// el jugador lea lo mismo en los dos lados.
String _itemKindLabel(String kind, String? category) => switch (kind) {
  'weapon' => 'Arma',
  'armor' => 'Armadura',
  _ => switch (category) {
    'tool' => 'Herramienta',
    'ammunition' => 'Munición',
    'focus' => 'Canalizador',
    'pack' => 'Paquete',
    'container' => 'Contenedor',
    'magic' => 'Objeto mágico',
    _ => 'Equipo',
  },
};

/// Ícono por familia de objeto. Es lo único que distingue el tipo en la lista:
/// §8.7 prohíbe explícitamente asignar un color distinto a cada uno.
IconData _itemIcon(String kind, String? category) {
  if (kind == 'weapon') return Icons.hardware;
  if (kind == 'armor') return Icons.shield_outlined;
  return switch (category) {
    'tool' => Icons.build_outlined,
    'ammunition' => Icons.arrow_outward,
    'focus' => Icons.auto_awesome_outlined,
    'pack' => Icons.luggage_outlined,
    'container' => Icons.inbox_outlined,
    'magic' => Icons.auto_fix_high_outlined,
    _ => Icons.inventory_2_outlined,
  };
}

extension _SheetInventorySection on _SheetScreenState {
  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _coinsAndLoadCard(),
      const SizedBox(height: 16),
      _inventoryCard(),
    ],
  );

  /// Resumen separado del listado, como pide §8.7: monedas, carga y
  /// sintonización no son filas de la mochila sino totales sobre ella.
  Widget _coinsAndLoadCard() {
    final pal = context.palette;
    final s = sheet;
    final attuned = InventoryOps.attunedCount(_c, repo);
    return sheetCard(
      icon: Icons.savings_outlined,
      title: 'Monedas y carga',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('Monedas'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final k in coinDenominations) _coinField(k)],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: 108, child: _acPlaque(s.armorClass)),
                SizedBox(
                  width: 148,
                  child: StatPlaque(
                    label: 'CARGA',
                    value:
                        '${formatPounds(s.carriedWeight)} / '
                        '${s.carryingCapacity} lb',
                    valueColor: s.isEncumbered ? pal.crimson : null,
                  ),
                ),
                SizedBox(
                  width: 148,
                  child: StatPlaque(
                    label: 'SINTONIZADOS',
                    value: '$attuned / $attunementSlots',
                    valueColor: attuned > attunementSlots ? pal.crimson : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Un campo por denominación. Lo que se escribe se guarda al salir del campo
  /// y no en cada tecla: escribir "120" pasaría por 1 y por 12, y cada paso
  /// intermedio sería un guardado y un recálculo de la carga.
  Widget _coinField(String key) => SizedBox(
    width: 84,
    child: TextField(
      controller: _coinCtrls[key],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.end,
      decoration: InputDecoration(
        isDense: true,
        labelText: coinLabels[key]!.toUpperCase(),
        border: const OutlineInputBorder(),
      ),
      onTapOutside: (_) => _commitCoins(),
      onSubmitted: (_) => _commitCoins(),
    ),
  );

  void _commitCoins() {
    final next = <String, int>{};
    for (final k in coinDenominations) {
      final value = int.tryParse(_coinCtrls[k]!.text.trim()) ?? 0;
      if (value > 0) next[k] = value;
    }
    if (mapEquals(next, _c.coins)) return;
    _replace(_c.copyWith(coins: next));
  }

  /// Lo que se lista: la mochila guardada más lo que esté equipado sin línea
  /// propia (una ficha armada en código, una importación vieja).
  List<InventoryEntry> get _inventoryEntries => InventoryOps.entries(_c, repo);

  Widget _inventoryCard() => sheetCard(
    icon: Icons.backpack,
    title: 'Inventario',
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_inventoryEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'La mochila está vacía.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                // El mismo corte que usa `responsiveColumns`, para que la ficha
                // entera cambie de forma en el mismo ancho.
                final wide = box.maxWidth >= 640;
                return DenseRows(
                  children: [
                    if (wide) _inventoryHeader(),
                    for (final e in _inventoryEntries)
                      wide ? _inventoryRowWide(e) : _inventoryRowCompact(e),
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addInventoryItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar objeto'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _inventoryHeader() {
    final style = TextStyle(
      fontSize: 11,
      letterSpacing: 1.1,
      color: context.palette.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(child: Text('OBJETO', style: style)),
          SizedBox(
            width: _colQuantity,
            child: Text('CANT.', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _colEquipped,
            child: Text('EQUIPADO', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _colWeight,
            child: Text('PESO', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: _colMenu),
        ],
      ),
    );
  }

  Widget _inventoryRowWide(InventoryEntry e) {
    final info = _itemInfo(e);
    return Padding(
      key: ValueKey('inv-${e.itemId}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: _itemName(e, info)),
          SizedBox(
            width: _colQuantity,
            child: Text('${e.quantity}', textAlign: TextAlign.center),
          ),
          SizedBox(width: _colEquipped, child: _equippedControl(e, info)),
          SizedBox(
            width: _colWeight,
            child: Text(
              info.weight == 0
                  ? '—'
                  : '${formatPounds(info.weight * e.quantity)} lb',
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(width: _colMenu, child: _itemMenu(e, info)),
        ],
      ),
    );
  }

  /// En compacto cada fila es una tarjeta de dos líneas. Los controles van en
  /// un [Wrap] y no en una fila: con un nombre largo, una fila fuerza scroll
  /// horizontal, que es justo lo que §8.7 prohíbe.
  Widget _inventoryRowCompact(InventoryEntry e) {
    final info = _itemInfo(e);
    return Padding(
      key: ValueKey('inv-${e.itemId}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _itemName(e, info)),
              if (e.quantity > 1) Text('×${e.quantity}'),
              SizedBox(width: _colMenu, child: _itemMenu(e, info)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (info.equippable) _equippedControl(e, info, withLabel: true),
              Text(
                info.weight == 0
                    ? 'Sin peso'
                    : '${formatPounds(info.weight * e.quantity)} lb',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemName(InventoryEntry e, _ItemInfo info) {
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    // El nombre solo no alcanza cuando el SRD repite uno (Vara es a la vez
    // equipo y canalizador arcano), así que la categoría va debajo siempre.
    final detail = <String>[
      info.kindLabel,
      if (info.bundleSize > 1) 'paquete de ${info.bundleSize}',
      if (e.attuned && info.attunable) 'sintonizado',
      if (info.twoHandedHint != null) info.twoHandedHint!,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(info.icon, size: 16, color: context.palette.textMuted),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.name),
              Text(detail, style: muted),
              if (e.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    e.note,
                    key: ValueKey('note-${e.itemId}'),
                    style: muted.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Casilla de equipado. Para lo que no se puede equipar —una cuerda, una
  /// antorcha— la celda queda vacía pero conserva su ancho, así la columna no
  /// se corre entre filas.
  Widget _equippedControl(
    InventoryEntry e,
    _ItemInfo info, {
    bool withLabel = false,
  }) {
    if (!info.equippable) return const SizedBox.shrink();
    final box = Checkbox(
      key: ValueKey('equip-${e.itemId}'),
      value: info.equipped,
      onChanged: (v) =>
          _replace(InventoryOps.setEquipped(_c, e.itemId, v ?? false, repo)),
    );
    if (!withLabel) return Center(child: box);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [box, const Text('Equipado')],
    );
  }

  /// Acciones secundarias en menú contextual, como pide §8.7. La casilla de
  /// equipar se queda afuera porque es la acción frecuente.
  Widget _itemMenu(InventoryEntry e, _ItemInfo info) {
    final weapon = repo.weapon(e.itemId);
    return PopupMenuButton<String>(
      key: ValueKey('menu-${e.itemId}'),
      tooltip: 'Acciones de ${info.name}',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _runItemAction(action, e),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'quantity', child: Text('Cantidad…')),
        const PopupMenuItem(value: 'note', child: Text('Nota…')),
        if (info.attunable)
          PopupMenuItem(
            value: 'attune',
            child: Text(e.attuned ? 'Quitar sintonización' : 'Sintonizar'),
          ),
        if (weapon != null && weapon.isLight)
          CheckedPopupMenuItem(
            value: 'off-hand',
            checked: _c.weaponOffHand[e.itemId] ?? false,
            child: const Text('Mano secundaria'),
          ),
        if (weapon?.versatileDice != null)
          CheckedPopupMenuItem(
            value: 'two-handed',
            checked: _c.weaponTwoHanded[e.itemId] ?? false,
            child: const Text('A dos manos'),
          ),
        const PopupMenuItem(value: 'remove', child: Text('Quitar')),
      ],
    );
  }

  Future<void> _runItemAction(String action, InventoryEntry e) async {
    switch (action) {
      case 'quantity':
        final info = _itemInfo(e);
        final raw = await showTextPromptDialog(
          context,
          title: 'Cantidad',
          label: info.bundleSize > 1
              ? 'Paquetes de ${info.bundleSize}'
              : 'Unidades',
          current: '${e.quantity}',
          keyboardType: TextInputType.number,
        );
        final value = int.tryParse(raw ?? '');
        if (value == null || value < 1) return;
        _updateEntry(e.itemId, (entry) => entry.copyWith(quantity: value));
      case 'note':
        final note = await showTextPromptDialog(
          context,
          title: 'Nota',
          label: 'Qué dice, de dónde salió, para qué sirve',
          current: e.note,
          allowEmpty: true,
          maxLines: 4,
        );
        if (note == null) return;
        _updateEntry(e.itemId, (entry) => entry.copyWith(note: note));
      case 'attune':
        _updateEntry(
          e.itemId,
          (entry) => entry.copyWith(attuned: !entry.attuned),
        );
      case 'off-hand':
        // Solo se empuña un arma en la secundaria: marcar una desmarca la otra.
        final on = _c.weaponOffHand[e.itemId] ?? false;
        _replace(_c.copyWith(weaponOffHand: on ? const {} : {e.itemId: true}));
      case 'two-handed':
        final on = _c.weaponTwoHanded[e.itemId] ?? false;
        _replace(
          _c.copyWith(weaponTwoHanded: {..._c.weaponTwoHanded, e.itemId: !on}),
        );
      case 'remove':
        _replace(
          InventoryOps.remove(
            _c.copyWith(inventory: _inventoryEntries),
            e.itemId,
            repo,
            quantity: e.quantity,
          ),
        );
    }
  }

  /// Aplica un cambio a una línea. Guarda la lista **materializada**, así una
  /// entrada que hasta ahora solo existía porque el objeto estaba equipado pasa
  /// a ser una línea de verdad en cuanto se la edita.
  void _updateEntry(
    String itemId,
    InventoryEntry Function(InventoryEntry) change,
  ) => _replace(
    _c.copyWith(
      inventory: [
        for (final entry in _inventoryEntries)
          entry.itemId == itemId ? change(entry) : entry,
      ],
    ),
  );

  Future<void> _addInventoryItem() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _AddItemDialog(repo: repo),
    );
    if (id == null) return;
    _replace(InventoryOps.add(_c, id));
  }

  /// Todo lo que la fila necesita saber del objeto, resuelto una sola vez.
  _ItemInfo _itemInfo(InventoryEntry e) {
    final entry = repo.catalogEntry(e.itemId);
    final item = repo.item(e.itemId);
    final weapon = repo.weapon(e.itemId);
    if (entry == null) {
      // El id quedó huérfano: homebrew que no se cargó, o un pack de contenido
      // que ya no está. Se muestra igual, porque borrárselo al jugador sin
      // avisar sería peor que mostrarle una línea incompleta.
      return _ItemInfo(
        name: e.itemId,
        kindLabel: 'No está en el catálogo',
        icon: Icons.help_outline,
        weight: 0,
        bundleSize: 1,
        equippable: false,
        equipped: false,
        attunable: false,
        twoHandedHint: null,
      );
    }
    return _ItemInfo(
      name: entry.name,
      kindLabel: _itemKindLabel(entry.kind, item?.category),
      icon: _itemIcon(entry.kind, item?.category),
      weight: entry.weight,
      bundleSize: item?.bundleSize ?? 1,
      equippable:
          entry.kind != 'item' || (item!.effects.isNotEmpty || item.isMagic),
      equipped: InventoryOps.isEquipped(_c, e, repo),
      attunable: item?.requiresAttunement ?? false,
      twoHandedHint: weapon == null || !weapon.requiresTwoHands()
          ? null
          // La lanza de caballería es el único caso: montado deja de exigirlas.
          : weapon.twoHandedUnlessMounted
          ? 'exige dos manos salvo montado'
          : 'exige dos manos',
    );
  }
}

/// Lo que la fila necesita del catálogo, ya resuelto.
class _ItemInfo {
  final String name;
  final String kindLabel;
  final IconData icon;
  final double weight;
  final int bundleSize;
  final bool equippable;
  final bool equipped;
  final bool attunable;
  final String? twoHandedHint;

  const _ItemInfo({
    required this.name,
    required this.kindLabel,
    required this.icon,
    required this.weight,
    required this.bundleSize,
    required this.equippable,
    required this.equipped,
    required this.attunable,
    required this.twoHandedHint,
  });
}

/// Buscador sobre los tres catálogos que pueden entrar en la mochila.
///
/// Muestra la categoría al lado del nombre porque los ids son distintos pero
/// los nombres no siempre: el SRD traduce *Pole* y *Rod* como "Vara".
class _AddItemDialog extends StatefulWidget {
  final ContentRepository repo;
  const _AddItemDialog({required this.repo});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final all = <({String id, String name, String detail, int costCp})>[
      for (final w in repo.weaponsSorted)
        (
          id: w.id,
          name: w.name,
          detail: _itemKindLabel('weapon', null),
          costCp: w.costCp,
        ),
      for (final a in repo.armorSorted)
        (
          id: a.id,
          name: a.name,
          detail: a.isShield ? 'Escudo' : _itemKindLabel('armor', null),
          costCp: a.costCp,
        ),
      for (final i in repo.itemsSorted)
        (
          id: i.id,
          name: i.name,
          detail: [
            _itemKindLabel('item', i.category),
            if (i.bundleSize > 1) 'paquete de ${i.bundleSize}',
          ].join(' · '),
          costCp: i.costCp,
        ),
    ];
    final needle = _query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? all
        : [
            for (final e in all)
              if (e.name.toLowerCase().contains(needle)) e,
          ];

    return AlertDialog(
      title: const Text('Agregar objeto'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar objeto…',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Sin resultados.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, i) {
                        final e = matches[i];
                        return ListTile(
                          dense: true,
                          title: Text(e.name),
                          subtitle: Text(e.detail),
                          trailing: Text(formatCost(e.costCp)),
                          onTap: () => Navigator.pop(context, e.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
