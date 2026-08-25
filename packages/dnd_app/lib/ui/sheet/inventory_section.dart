part of '../sheet_screen.dart';

/// Anchos fijos de las columnas del listado en pantalla ancha.
///
/// Son constantes y no `Expanded` porque el criterio de aceptación de §8.7 es
/// que cantidad, equipado y acciones **no cambien de columna entre filas**: con
/// anchos elásticos, una fila con nombre largo corre las demás celdas y la
/// tabla deja de leerse en vertical. Los encabezados de familia no rompen esa
/// alineación: separan grupos, pero las columnas siguen siendo las mismas.
const _colQuantity = 92.0;
const _colEquipped = 76.0;
const _colWeight = 76.0;
const _colMenu = 44.0;

const _invFilterAll = 'Todos';
const _invFilterEquipped = 'Equipados';
const _invFilterMagic = 'Mágicos';

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

/// Orden en que se muestran las familias, y su título en plural.
///
/// El orden no es alfabético: primero lo que se empuña, después lo que se
/// gasta, y al final lo que solo se lleva encima. Una familia que no esté acá
/// —homebrew con una categoría nueva— va al fondo con su propio nombre, en vez
/// de desaparecer.
const _groupTitles = <String, String>{
  'Arma': 'Armas',
  'Armadura': 'Armaduras',
  'Munición': 'Munición',
  'Canalizador': 'Canalizadores',
  'Objeto mágico': 'Objetos mágicos',
  'Herramienta': 'Herramientas',
  'Contenedor': 'Contenedores',
  'Paquete': 'Paquetes',
  'Equipo': 'Equipo',
};

/// Nombre largo de cada denominación. La abreviatura sola («PE») es un rótulo
/// de formulario: en la mesa nadie recuerda cuál es electro y cuál platino.
const _coinNames = <String, String>{
  'cp': 'cobre',
  'sp': 'plata',
  'ep': 'electro',
  'gp': 'oro',
  'pp': 'platino',
};

/// Ícono por familia de objeto. Es lo único que distingue el tipo dentro de un
/// grupo: §8.7 prohíbe explícitamente asignar un color distinto a cada uno.
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

/// Una línea de la mochila con todo lo que la fila necesita, resuelto una sola
/// vez: agrupar y dibujar leen lo mismo en vez de consultar el catálogo dos
/// veces por objeto.
typedef _Line = ({InventoryEntry entry, _ItemInfo info});

extension _SheetInventorySection on _SheetScreenState {
  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_bagCard(), const SizedBox(height: 16), _inventoryCard()],
  );

  /// Los totales **sobre** la mochila, separados del listado como pide §8.7:
  /// monedas, carga y sintonización no son filas.
  ///
  /// La CA salió de acá: ya está en la banda táctica que encabeza las cuatro
  /// pestañas, y repetida dejaba de leerse como dato. El lugar que ocupaba es
  /// justo el que necesitaban la barra de carga y los cupos.
  Widget _bagCard() => sheetCard(
    icon: Icons.savings_outlined,
    title: 'Bolsa',
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: responsiveColumns([
        [_coinsBlock()],
        [_loadTile(), _attunementTile()],
      ]),
    ),
  );

  Widget _coinsBlock() {
    final pal = context.palette;
    final coins = _c.coins;
    var totalCp = 0;
    var count = 0;
    for (final k in coinDenominations) {
      final n = coins[k] ?? 0;
      totalCp += n * coinValueCp[k]!;
      count += n;
    }
    final strong = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Monedas'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [for (final k in coinDenominations) _coinField(k)],
        ),
        const SizedBox(height: 12),
        // Lo que se pregunta en la mesa cuando hay que pagar algo no es cuánto
        // cobre hay, sino cuánto suma todo junto y cuánto pesa.
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Equivale a '),
              TextSpan(text: formatPounds(totalCp / 100), style: strong),
              const TextSpan(text: ' po · pesan '),
              TextSpan(
                text: formatPounds(count / coinsPerPound),
                style: strong,
              ),
              const TextSpan(text: ' lb'),
            ],
          ),
          style: TextStyle(fontSize: 12.5, color: pal.textMuted),
        ),
      ],
    );
  }

  /// Un campo por denominación. Lo que se escribe se guarda al salir del campo
  /// y no en cada tecla: escribir "120" pasaría por 1 y por 12, y cada paso
  /// intermedio sería un guardado y un recálculo de la carga.
  ///
  /// El rótulo salió de dentro del campo: con `labelText`, la abreviatura se
  /// encoge sobre el borde al escribir y el nombre largo no entra en ningún
  /// lado. Va arriba, fijo, y el [Semantics] lo vuelve a atar al campo para
  /// quien no lo ve.
  Widget _coinField(String key) {
    final pal = context.palette;
    final abbr = coinLabels[key]!.toUpperCase();
    return Semantics(
      label: 'Monedas de ${_coinNames[key]} ($abbr)',
      child: Container(
        width: 100,
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 2),
        decoration: BoxDecoration(
          color: pal.plaque,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: pal.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  abbr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: pal.gold,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _coinNames[key]!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: pal.textMuted),
                  ),
                ),
              ],
            ),
            TextField(
              key: ValueKey('coin-$key'),
              controller: _coinCtrls[key],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                hintText: '0',
                hintStyle: TextStyle(fontSize: 19, color: pal.textMuted),
              ),
              onTapOutside: (_) => _commitCoins(),
              onSubmitted: (_) => _commitCoins(),
            ),
          ],
        ),
      ),
    );
  }

  void _commitCoins() {
    final next = <String, int>{};
    for (final k in coinDenominations) {
      final value = int.tryParse(_coinCtrls[k]!.text.trim()) ?? 0;
      if (value > 0) next[k] = value;
    }
    if (mapEquals(next, _c.coins)) return;
    _replace(_c.copyWith(coins: next));
  }

  /// La carga como proporción y no como par de números.
  ///
  /// «74 / 135 lb» obliga a hacer la división mentalmente y solo avisa cuando
  /// ya te pasaste. La barra muestra el margen que queda y separa el peso de
  /// los objetos del de las monedas, que el motor ya suma a la carga y que
  /// hasta ahora no aparecía en ningún lado.
  Widget _loadTile() {
    final pal = context.palette;
    final s = sheet;
    final cap = s.carryingCapacity;
    final coinWeight = _c.coins.values.fold(0, (a, b) => a + b) / coinsPerPound;
    // Restar en vez de volver a sumar: así los dos tramos de la barra suman
    // exactamente el total que muestra la cifra, aunque el motor cambie de
    // criterio sobre qué entra en la carga.
    final itemsWeight = (s.carriedWeight - coinWeight).clamp(
      0.0,
      double.infinity,
    );
    final over = s.isEncumbered;
    final color = over ? pal.crimson : pal.gold;
    return StatTile(
      label: 'Carga',
      labelTrailing: cap <= 0
          ? null
          : '${(s.carriedWeight / cap * 100).round()}% de la capacidad',
      value: formatPounds(s.carriedWeight),
      suffix: ' / $cap lb',
      valueColor: color,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadBar(itemsWeight, coinWeight, cap.toDouble(), color),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _loadLegend(color, 'Objetos ${formatPounds(itemsWeight)} lb'),
              _loadLegend(
                pal.textMuted,
                'Monedas ${formatPounds(coinWeight)} lb',
              ),
            ],
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Pasás tu capacidad de carga. En 2024 no hay penalización '
                      'de reglas: es un aviso, no un bloqueo.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Barra de dos tramos: objetos y monedas, sobre el hueco que falta para
  /// llenar la capacidad. Los `flex` van en milésimos porque son enteros y con
  /// porcentajes redondeados una mochila casi vacía desaparecía del todo.
  Widget _loadBar(double items, double coins, double capacity, Color color) {
    int flex(double weight) =>
        capacity <= 0 ? 0 : (weight / capacity * 1000).round().clamp(0, 1000);
    final itemsFlex = flex(items);
    final coinsFlex = flex(coins);
    final free = 1000 - itemsFlex - coinsFlex;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: Row(
          children: [
            if (itemsFlex > 0)
              Expanded(
                flex: itemsFlex,
                child: ColoredBox(color: color),
              ),
            if (coinsFlex > 0)
              Expanded(
                flex: coinsFlex,
                child: ColoredBox(color: context.palette.textMuted),
              ),
            if (free > 0)
              Expanded(
                flex: free,
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
          ],
        ),
      ),
    );
  }

  Widget _loadLegend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(fontSize: 11.5, color: context.palette.textMuted),
      ),
    ],
  );

  /// Los cupos de sintonización **ocupados**, no solo contados.
  ///
  /// «0 / 3» no dice con qué. Tres casillas con el nombre adentro responden la
  /// pregunta real —qué tengo sintonizado y cuánto me queda— con el mismo
  /// lenguaje que los recursos de Combate.
  Widget _attunementTile() {
    final pal = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // El mismo criterio que `InventoryOps.attunedCount`, pero conservando los
    // nombres: un flag viejo sobre un objeto que no exige sintonización no
    // ocupa cupo y tampoco tiene por qué mostrarse acá.
    final attuned = [
      for (final e in _inventoryEntries)
        if (e.attuned && repo.item(e.itemId)?.requiresAttunement == true)
          InventoryOps.resolve(e, repo).name,
    ];
    final over = attuned.length > attunementSlots;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SINTONIZACIÓN',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: pal.textMuted,
                  ),
                ),
              ),
              Text(
                '${attuned.length} / $attunementSlots',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: over ? pal.crimson : onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var i = 0; i < attunementSlots; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: _attunementPip(i < attuned.length ? attuned[i] : null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Se sintoniza desde el menú de cada objeto; acá se ve cuántos cupos '
            'quedan y con qué están ocupados.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: pal.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attunementPip(String? name) {
    final pal = context.palette;
    final free = name == null;
    return Tooltip(
      message: free ? 'Cupo de sintonización libre' : '$name — sintonizado',
      child: Container(
        height: 26,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: free ? Colors.transparent : pal.goldSoft,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: free ? pal.hairline : pal.gold),
        ),
        child: Text(
          free ? 'Cupo libre' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: free ? pal.textMuted : pal.gold,
          ),
        ),
      ),
    );
  }

  /// Lo que se lista: la mochila guardada más lo que esté equipado sin línea
  /// propia (una ficha armada en código, una importación vieja).
  List<InventoryEntry> get _inventoryEntries => InventoryOps.entries(_c, repo);

  /// Las líneas que pasan el buscador y el filtro, ya resueltas.
  List<_Line> get _visibleLines {
    final needle = _invQuery.trim().toLowerCase();
    final lines = <_Line>[];
    for (final e in _inventoryEntries) {
      final info = _itemInfo(e);
      if (needle.isNotEmpty && !info.name.toLowerCase().contains(needle)) {
        continue;
      }
      final passes = switch (_invFilter) {
        _invFilterEquipped => info.equipped,
        _invFilterMagic => info.magic,
        _ => true,
      };
      if (passes) lines.add((entry: e, info: info));
    }
    return lines;
  }

  /// Agrupa por la misma familia que ya calcula el catálogo, en el orden de
  /// [_groupTitles]. Las familias desconocidas van al final, en el orden en que
  /// aparecen.
  List<({String title, List<_Line> lines})> _grouped(List<_Line> lines) {
    final byKind = <String, List<_Line>>{};
    for (final line in lines) {
      byKind.putIfAbsent(line.info.kindLabel, () => []).add(line);
    }
    final order = [
      ...(_groupTitles.keys.where(byKind.containsKey)),
      ...byKind.keys.where((k) => !_groupTitles.containsKey(k)),
    ];
    return [
      for (final kind in order)
        (title: _groupTitles[kind] ?? kind, lines: byKind[kind]!),
    ];
  }

  Widget _inventoryCard() {
    final total = _inventoryEntries.length;
    final lines = _visibleLines;
    return sheetCard(
      icon: Icons.backpack,
      title: 'Inventario',
      trailing: total == 0
          ? null
          : GoldPill(
              lines.length == total
                  ? '$total ${total == 1 ? 'objeto' : 'objetos'}'
                  : '${lines.length} de $total',
              highlighted: false,
            ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (total == 0)
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
            else ...[
              _inventoryToolbar(),
              const SizedBox(height: 12),
              if (lines.isEmpty)
                _noMatches()
              else
                LayoutBuilder(
                  builder: (context, box) {
                    // El mismo corte que usa `responsiveColumns`, para que la
                    // ficha entera cambie de forma en el mismo ancho.
                    final wide = box.maxWidth >= 640;
                    return DenseRows(
                      children: [
                        if (wide) _inventoryHeader(),
                        for (final group in _grouped(lines)) ...[
                          _groupHeader(group.title, group.lines),
                          for (final line in group.lines)
                            wide
                                ? _inventoryRowWide(line)
                                : _inventoryRowCompact(line),
                        ],
                      ],
                    );
                  },
                ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addInventoryItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar objeto'),
                  ),
                  if (sheet.itemChoiceSlots.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _manageMagicItemPlans,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(
                        'Planos y réplicas '
                        '(${_c.magicItemChoices.length}/'
                        '${sheet.itemChoiceSlots.first.count})',
                      ),
                    ),
                  for (final slot in sheet.targetChoiceSlots)
                    OutlinedButton.icon(
                      key: ValueKey('manage-target-${slot.groupId}'),
                      onPressed: () => _manageTargetChoice(slot.groupId),
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(
                        '${slot.name} '
                        '(${slot.chosenEntryIds.length}/${slot.count})',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buscador y filtro. Píldoras y no un desplegable: son tres opciones y
  /// mostrarlas dice cuál está activa **y** qué otras hay, sin abrir nada.
  Widget _inventoryToolbar() => Wrap(
    spacing: 10,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 240,
        child: TextField(
          controller: _invSearchCtrl,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Buscar en la mochila…',
            border: OutlineInputBorder(),
          ),
          onChanged: _searchInventory,
        ),
      ),
      for (final filter in const [
        _invFilterAll,
        _invFilterEquipped,
        _invFilterMagic,
      ])
        ChoiceChip(
          label: Text(filter),
          selected: _invFilter == filter,
          showCheckmark: false,
          onSelected: (_) => _filterInventory(filter),
        ),
    ],
  );

  Widget _noMatches() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(Icons.search_off, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ningún objeto coincide con ese filtro.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
        ],
      ),
    );
  }

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

  /// Encabezado de familia, con su subtotal de peso. Ningún grupo recibe color
  /// propio: lo que separa es el fondo hundido, igual para todos.
  Widget _groupHeader(String title, List<_Line> lines) {
    final pal = context.palette;
    final weight = lines.fold(
      0.0,
      (total, l) => total + l.info.weight * l.entry.quantity,
    );
    return Container(
      color: pal.plaque,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${lines.length}',
            style: TextStyle(
              fontSize: 11,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            weight == 0 ? '—' : '${formatPounds(weight)} lb',
            style: TextStyle(
              fontSize: 11.5,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryRowWide(_Line line) {
    final e = line.entry;
    final info = line.info;
    return Padding(
      key: ValueKey('inv-${e.entryId}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: _itemName(e, info)),
          SizedBox(width: _colQuantity, child: _quantityStepper(e, info)),
          SizedBox(width: _colEquipped, child: _equippedControl(e, info)),
          SizedBox(
            width: _colWeight,
            child: Text(
              _rowWeight(e, info),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
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
  Widget _inventoryRowCompact(_Line line) {
    final e = line.entry;
    final info = line.info;
    return Padding(
      key: ValueKey('inv-${e.entryId}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _itemName(e, info)),
              SizedBox(width: _colMenu, child: _itemMenu(e, info)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _quantityStepper(e, info),
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

  String _rowWeight(InventoryEntry e, _ItemInfo info) =>
      info.weight == 0 ? '—' : '${formatPounds(info.weight * e.quantity)} lb';

  /// Cantidad editable en la fila. Sumar una bala pasaba por el menú, un
  /// diálogo, escribir el número y confirmar; con − y + el caso frecuente son
  /// dos clics, y el diálogo queda para poner una cantidad exacta grande.
  ///
  /// El − se apaga en 1 y no baja a 0: quitar la línea es otra acción, y está
  /// en el menú.
  Widget _quantityStepper(InventoryEntry e, _ItemInfo info) {
    void set(int value) =>
        _updateEntry(e.entryId, (entry) => entry.copyWith(quantity: value));
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepButton(
          Icons.remove,
          'Quitar una unidad de ${info.name}',
          e.quantity > 1 ? () => set(e.quantity - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${e.quantity}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _stepButton(
          Icons.add,
          'Agregar una unidad de ${info.name}',
          () => set(e.quantity + 1),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    final pal = context.palette;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 28,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            side: BorderSide(color: pal.hairline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Icon(icon, size: 15, semanticLabel: tooltip),
        ),
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
      if (info.rangeHint != null) 'alcance ${info.rangeHint}',
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
              // Sintonizado y Réplica salieron de la línea de detalle: son
              // estados del ejemplar, no parte de qué clase de objeto es, y
              // enterrados entre puntos medios no se veían.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(info.name),
                  if (e.attuned && info.attunable)
                    const GoldPill('Sintonizado'),
                  if (info.replica)
                    const GoldPill('Réplica', highlighted: false),
                  for (final slot in sheet.targetChoiceSlots)
                    if (slot.chosenEntryIds.contains(e.entryId))
                      GoldPill(slot.name, highlighted: false),
                ],
              ),
              Text(detail, style: muted),
              if (e.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    e.note,
                    key: ValueKey('note-${e.entryId}'),
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
  /// antorcha— la celda lleva una raya y conserva su ancho, así la columna no
  /// se corre entre filas y se ve que no es un olvido.
  Widget _equippedControl(
    InventoryEntry e,
    _ItemInfo info, {
    bool withLabel = false,
  }) {
    if (!info.equippable) {
      return withLabel
          ? const SizedBox.shrink()
          : Tooltip(
              message: 'No se equipa',
              child: Center(
                child: Text(
                  '—',
                  style: TextStyle(color: context.palette.textMuted),
                ),
              ),
            );
    }
    final box = Checkbox(
      key: ValueKey('equip-${e.entryId}'),
      value: info.equipped,
      onChanged: (v) =>
          _replace(InventoryOps.setEquipped(_c, e.entryId, v ?? false, repo)),
    );
    if (!withLabel) return Center(child: box);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [box, const Text('Equipado')],
    );
  }

  /// Acciones secundarias en menú contextual, como pide §8.7. La casilla de
  /// equipar y la cantidad se quedan afuera porque son las frecuentes.
  Widget _itemMenu(InventoryEntry e, _ItemInfo info) {
    final weapon = InventoryOps.resolve(e, repo).weapon;
    return PopupMenuButton<String>(
      key: ValueKey('menu-${e.entryId}'),
      tooltip: 'Acciones de ${info.name}',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _runItemAction(action, e),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'quantity', child: Text('Cantidad exacta…')),
        const PopupMenuItem(value: 'note', child: Text('Nota…')),
        if (info.attunable)
          CheckedPopupMenuItem(
            value: 'attune',
            checked: e.attuned,
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
        if (info.replica)
          const PopupMenuItem(
            value: 'transmute',
            child: Text('Transmutar réplica…'),
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
        _updateEntry(e.entryId, (entry) => entry.copyWith(quantity: value));
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
        _updateEntry(e.entryId, (entry) => entry.copyWith(note: note));
      case 'attune':
        _updateEntry(
          e.entryId,
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
      case 'transmute':
        await _transmuteReplica(e);
      case 'remove':
        _replace(
          InventoryOps.remove(
            _c.copyWith(inventory: _inventoryEntries),
            e.entryId,
            repo,
            quantity: e.quantity,
          ),
        );
    }
  }

  Future<void> _transmuteReplica(InventoryEntry entry) async {
    final itemId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transmutar en'),
        children: [
          for (final id in _c.magicItemChoices)
            if (id != entry.itemId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, id),
                child: Text(repo.item(id)?.name ?? id),
              ),
        ],
      ),
    );
    if (itemId == null) return;
    final item = repo.item(itemId);
    if (item == null) return;
    String? baseItemId;
    if (item.baseItemKind != null) {
      baseItemId = await _chooseMagicBase(item);
      if (baseItemId == null) return;
    }
    _replace(
      InventoryOps.transmuteReplica(
        _c,
        entry.entryId,
        itemId,
        repo,
        baseItemId: baseItemId,
      ),
    );
  }

  /// Aplica un cambio a una línea. Guarda la lista **materializada**, así una
  /// entrada que hasta ahora solo existía porque el objeto estaba equipado pasa
  /// a ser una línea de verdad en cuanto se la edita.
  void _updateEntry(
    String entryId,
    InventoryEntry Function(InventoryEntry) change,
  ) => _replace(
    _c.copyWith(
      inventory: [
        for (final entry in _inventoryEntries)
          entry.entryId == entryId ? change(entry) : entry,
      ],
    ),
  );

  /// El buscador no se cierra al agregar: en la mesa se cargan varias compras
  /// seguidas, y reabrirlo y volver a escribir para cada una era el grueso del
  /// trabajo.
  void _addInventoryItem() => showDialog<void>(
    context: context,
    builder: (_) => _AddItemDialog(
      repo: repo,
      onAdd: (id) => _replace(InventoryOps.add(_c, id)),
    ),
  );

  // ------------------------------------------ Objetivos contextuales de arma

  /// Selector dirigido por los cupos compilados. No conoce Pacto del Filo ni
  /// ninguna dote: muestra exactamente los ejemplares y armas que el motor
  /// declaró elegibles para el grupo recibido.
  Future<void> _manageTargetChoice(String groupId) async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          final matching = sheet.targetChoiceSlots.where(
            (candidate) => candidate.groupId == groupId,
          );
          if (matching.isEmpty) return const SizedBox.shrink();
          final slot = matching.single;
          final chosen = slot.chosenEntryIds.toSet();
          final canReplace = slot.replaceable || chosen.length < slot.count;

          void apply(Character next) {
            _replace(next);
            refresh(() {});
          }

          final existing = [
            for (final entryId in slot.eligibleEntryIds)
              if (_c.inventory.any((entry) => entry.entryId == entryId))
                _c.inventory.firstWhere((entry) => entry.entryId == entryId),
          ];

          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(slot.name)),
                GoldPill('${chosen.length}/${slot.count}'),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Elegí un ejemplar de la mochila o creá uno de los '
                        'permitidos por el rasgo.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Eyebrow('En la mochila'),
                      if (existing.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('No hay ejemplares elegibles.'),
                        )
                      else
                        for (final entry in existing)
                          ListTile(
                            key: ValueKey('target-$groupId-${entry.entryId}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              chosen.contains(entry.entryId)
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(InventoryOps.resolve(entry, repo).name),
                            subtitle: entry.origin == 'effect-target:$groupId'
                                ? const Text('Creada por este rasgo')
                                : null,
                            enabled:
                                chosen.contains(entry.entryId) || canReplace,
                            onTap: chosen.contains(entry.entryId) || !canReplace
                                ? null
                                : () => apply(
                                    InventoryOps.setEffectTarget(
                                      _c,
                                      groupId,
                                      entry.entryId,
                                      count: slot.count,
                                    ),
                                  ),
                          ),
                      if (slot.creatableWeaponIds.isNotEmpty) ...[
                        const Divider(height: 28),
                        const Eyebrow('Crear arma'),
                        for (final weaponId in slot.creatableWeaponIds)
                          ListTile(
                            key: ValueKey('target-create-$groupId-$weaponId'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.add_circle_outline),
                            title: Text(
                              repo.weapon(weaponId)?.name ?? weaponId,
                            ),
                            subtitle: const Text('Agregar y equipar'),
                            enabled: canReplace,
                            onTap: !canReplace
                                ? null
                                : () => apply(
                                    InventoryOps.createEffectTarget(
                                      _c,
                                      groupId,
                                      weaponId,
                                      repo,
                                      count: slot.count,
                                    ),
                                  ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (chosen.isNotEmpty && slot.replaceable)
                TextButton(
                  onPressed: () =>
                      apply(InventoryOps.clearEffectTargets(_c, groupId)),
                  child: const Text('Limpiar vínculo'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------- Planos y réplicas

  /// Planos elegidos y réplicas activas, en un solo cuadro.
  ///
  /// Antes eran tres diálogos encadenados —elegir planos, elegir cuál replicar,
  /// elegir la base— y solo se podía crear una réplica por vuelta. Acá los
  /// planos se guardan al tocarlos, como el resto de la ficha, y las réplicas
  /// se crean y se quitan sin salir.
  Future<void> _manageMagicItemPlans() async {
    final slot = sheet.itemChoiceSlots.first;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          // `_c` cambia con cada `_replace`; releerlo en cada dibujo es lo que
          // mantiene el diálogo y la ficha diciendo lo mismo.
          final chosen = _c.magicItemChoices;
          final missing = slot.count - chosen.length;
          void apply(Character next) {
            _replace(next);
            refresh(() {});
          }

          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(slot.name)),
                GoldPill('${chosen.length}/${slot.count}'),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Elegís ${slot.count} planos. Después decidís cuál '
                      'replicar: podés tener ${slot.maxActive} '
                      '${slot.maxActive == 1 ? 'réplica activa' : 'réplicas activas'} '
                      'a la vez.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in slot.optionItemIds)
                          FilterChip(
                            label: Text(repo.item(id)?.name ?? id),
                            selected: chosen.contains(id),
                            onSelected:
                                !chosen.contains(id) &&
                                    chosen.length >= slot.count
                                ? null
                                : (on) => apply(_togglePlan(id, on)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Eyebrow('Réplicas activas'),
                    _replicaBlock(slot, apply),
                  ],
                ),
              ),
            ),
            actions: [
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Falta elegir $missing.',
                    style: TextStyle(fontSize: 12, color: context.palette.gold),
                  ),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Marca o desmarca un plano. Al desmarcarlo se lleva su réplica: una réplica
  /// de un plano que ya no conocés no puede seguir en la mochila.
  Character _togglePlan(String id, bool on) {
    final choices = [..._c.magicItemChoices];
    if (on) {
      choices.add(id);
    } else {
      choices.remove(id);
    }
    return _c.copyWith(
      magicItemChoices: choices,
      inventory: [
        for (final e in _c.inventory)
          if (e.origin?.startsWith('artificer:replicate-magic-item:') != true ||
              choices.contains(e.itemId))
            e,
      ],
    );
  }

  InventoryEntry? _replicaOf(String itemId) {
    for (final e in _c.inventory) {
      if (e.origin == 'artificer:replicate-magic-item:$itemId') return e;
    }
    return null;
  }

  Widget _replicaBlock(ItemChoiceSlot slot, void Function(Character) apply) {
    final chosen = _c.magicItemChoices;
    if (chosen.isEmpty) {
      return Text(
        'Elegí un plano para poder replicarlo.',
        style: TextStyle(fontSize: 12.5, color: context.palette.textMuted),
      );
    }
    final active = [
      for (final id in chosen)
        if (_replicaOf(id) != null) id,
    ];
    final free = slot.maxActive - active.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in chosen)
              _replicaChip(id, active.contains(id), free > 0, apply),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          free > 0
              ? 'Quedan $free ${free == 1 ? 'cupo libre' : 'cupos libres'}.'
              : 'Sin cupos libres: quitá una réplica para crear otra.',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
      ],
    );
  }

  Widget _replicaChip(
    String id,
    bool active,
    bool hasFreeSlot,
    void Function(Character) apply,
  ) {
    final name = repo.item(id)?.name ?? id;
    final replica = _replicaOf(id);
    if (active && replica != null) {
      return InputChip(
        avatar: Icon(Icons.check, size: 16, color: context.palette.gold),
        label: Text(name),
        selected: true,
        showCheckmark: false,
        onDeleted: () => apply(
          InventoryOps.remove(
            _c,
            replica.entryId,
            repo,
            quantity: replica.quantity,
          ),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteButtonTooltipMessage: 'Quitar la réplica de $name',
      );
    }
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(name),
      // Sin cupo el chip queda apagado en vez de desaparecer: la lista de
      // planos elegidos no debería cambiar de largo según cuántas réplicas haya.
      onPressed: hasFreeSlot ? () => _createReplica(id, apply) : null,
      tooltip: hasFreeSlot
          ? 'Crear la réplica de $name'
          : 'No quedan cupos de réplica',
    );
  }

  Future<void> _createReplica(String id, void Function(Character) apply) async {
    final item = repo.item(id);
    if (item == null) return;
    String? baseItemId;
    if (item.baseItemKind != null) {
      // La base sigue siendo un cuadro aparte porque es una lista larga (todas
      // las armas del catálogo), no un par de opciones que entren acá.
      baseItemId = await _chooseMagicBase(item);
      if (baseItemId == null) return;
    }
    apply(
      InventoryOps.replicateMagicItem(_c, id, repo, baseItemId: baseItemId),
    );
  }

  Future<String?> _chooseMagicBase(Item item) => showDialog<String>(
    context: context,
    builder: (context) {
      final ids = item.eligibleBaseItemIds.isNotEmpty
          ? item.eligibleBaseItemIds
          : switch (item.baseItemKind) {
              'weapon' => repo.weaponsSorted.map((e) => e.id).toList(),
              'armor' =>
                repo.armorSorted
                    .where((e) => !e.isShield)
                    .map((e) => e.id)
                    .toList(),
              'shield' =>
                repo.armorSorted
                    .where((e) => e.isShield)
                    .map((e) => e.id)
                    .toList(),
              _ => <String>[],
            };
      return SimpleDialog(
        title: const Text('Elegí el objeto base'),
        children: [
          for (final id in ids)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, id),
              child: Text(repo.catalogEntry(id)?.name ?? id),
            ),
        ],
      );
    },
  );

  /// Todo lo que la fila necesita saber del objeto, resuelto una sola vez.
  _ItemInfo _itemInfo(InventoryEntry e) {
    final entry = repo.catalogEntry(e.itemId);
    final item = repo.item(e.itemId);
    final resolved = InventoryOps.resolve(e, repo);
    final weapon = resolved.weapon;
    final replica =
        e.origin?.startsWith('artificer:replicate-magic-item:') == true;
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
        magic: false,
        replica: replica,
        rangeHint: null,
        twoHandedHint: null,
      );
    }
    final kind = resolved.weapon != null
        ? 'weapon'
        : resolved.armor != null
        ? 'armor'
        : entry.kind;
    return _ItemInfo(
      name: resolved.name,
      kindLabel: _itemKindLabel(kind, item?.category),
      icon: _itemIcon(kind, item?.category),
      weight: resolved.weight,
      bundleSize: item?.bundleSize ?? 1,
      equippable:
          resolved.weapon != null ||
          resolved.armor != null ||
          (item != null && (item.effects.isNotEmpty || item.isMagic)),
      equipped: InventoryOps.isEquipped(_c, e, repo),
      attunable: item?.requiresAttunement ?? false,
      magic: (item?.isMagic ?? false) || replica,
      replica: replica,
      rangeHint: weapon?.rangeLabel,
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
  final bool magic;
  final bool replica;

  /// Alcance del arma, ya formateado por el motor. null en todo lo que no
  /// se dispara ni se arroja, que es casi toda la mochila.
  final String? rangeHint;
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
    required this.magic,
    required this.replica,
    required this.rangeHint,
    required this.twoHandedHint,
  });
}

/// Buscador sobre los tres catálogos que pueden entrar en la mochila.
///
/// Muestra la categoría al lado del nombre porque los ids son distintos pero
/// los nombres no siempre: el SRD traduce *Pole* y *Rod* como "Vara".
///
/// Los tres desplegables de antes (tipo, rareza, sintonización) ocupaban media
/// pantalla para filtrar una lista que casi siempre cabe entera: quedaron
/// reducidos a las mismas familias con que se agrupa la mochila, en píldoras.
/// El peso viaja al lado del precio, que es lo que decide si el objeto entra.
class _AddItemDialog extends StatefulWidget {
  final ContentRepository repo;
  final ValueChanged<String> onAdd;
  const _AddItemDialog({required this.repo, required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

typedef _CatalogRow = ({
  String id,
  String name,
  String family,
  String detail,
  double weight,
  int costCp,
});

class _AddItemDialogState extends State<_AddItemDialog> {
  String _query = '';
  String _family = _invFilterAll;
  int _added = 0;

  List<_CatalogRow> get _all {
    final repo = widget.repo;
    return [
      for (final w in repo.weaponsSorted)
        (
          id: w.id,
          name: w.name,
          family: 'Arma',
          detail: _itemKindLabel('weapon', null),
          weight: w.weight,
          costCp: w.costCp,
        ),
      for (final a in repo.armorSorted)
        (
          id: a.id,
          name: a.name,
          family: 'Armadura',
          detail: a.isShield ? 'Escudo' : _itemKindLabel('armor', null),
          weight: a.weight,
          costCp: a.costCp,
        ),
      for (final i in repo.itemsSorted)
        (
          id: i.id,
          name: i.name,
          family: _itemKindLabel('item', i.category),
          detail: [
            _itemKindLabel('item', i.category),
            if (i.bundleSize > 1) 'paquete de ${i.bundleSize}',
            if (i.requiresAttunement) 'sintonización',
          ].join(' · '),
          weight: i.weight,
          costCp: i.costCp,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final all = _all;
    final needle = _query.trim().toLowerCase();
    final matches = [
      for (final e in all)
        if ((needle.isEmpty || e.name.toLowerCase().contains(needle)) &&
            (_family == _invFilterAll || e.family == _family))
          e,
    ];
    // Solo las familias que existen en el catálogo cargado: con homebrew, una
    // píldora fija dejaría fuera categorías nuevas y ofrecería vacías.
    final families = {for (final e in all) e.family};

    return AlertDialog(
      title: const Text('Agregar objeto'),
      content: SizedBox(
        width: 460,
        height: 460,
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final family in [
                    _invFilterAll,
                    ..._groupTitles.keys.where(families.contains),
                    ...families.where((f) => !_groupTitles.containsKey(f)),
                  ])
                    ChoiceChip(
                      label: Text(
                        family == _invFilterAll
                            ? family
                            : _groupTitles[family] ?? family,
                      ),
                      selected: _family == family,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _family = family),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Sin resultados.'))
                  : ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: pal.hairline),
                      itemBuilder: (_, i) {
                        final e = matches[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      e.detail,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  e.weight == 0
                                      ? '—'
                                      : '${formatPounds(e.weight)} lb',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: muted,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 66,
                                child: Text(
                                  formatCost(e.costCp),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: pal.gold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                key: ValueKey('add-${e.id}'),
                                onPressed: () {
                                  widget.onAdd(e.id);
                                  setState(() => _added++);
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // `actions` es un OverflowBar y no una fila: `Expanded` ahí revienta, así
      // que el contador se separa del botón con la alineación del propio bar.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        Text(
          _added == 0
              ? 'Se pueden agregar varios sin cerrar.'
              : _added == 1
              ? '1 objeto agregado a la mochila.'
              : '$_added objetos agregados a la mochila.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
