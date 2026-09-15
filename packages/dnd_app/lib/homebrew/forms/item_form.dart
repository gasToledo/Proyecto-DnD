part of '../homebrew_screen.dart';

/// Formulario de objeto homebrew: arriba nombre, categoría, peso y precio, que
/// es todo lo que necesita un objeto mundano, y lo mágico plegado.
///
/// No valida colisión de id contra armas y armaduras: `homebrewId` arma
/// `hb-<slug>-<timestamp>`, así que un id de acá no puede pisar uno del
/// catálogo oficial ni otro homebrew.
///
/// ponytail: las cargas no se editan, solo se conservan del original. Van en
/// su propia sección cuando alguien arme una varita propia.
class ItemForm extends StatefulWidget {
  final Item? initial;

  /// Para ofrecer las bases permitidas por su nombre. Es la única cosa del
  /// formulario que sale del catálogo y no de lo que se escribe.
  final ContentRepository repo;

  const ItemForm({super.key, required this.repo, this.initial});

  @override
  State<ItemForm> createState() => _ItemFormState();
}

const _baseItemKinds = {
  'none': 'Ninguno',
  'weapon': 'Arma',
  'armor': 'Armadura',
  'shield': 'Escudo',
};

class _ItemFormState extends State<ItemForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _weight = watch(
    widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = watch('${widget.initial?.costCp ?? 0}');
  late final _description = watch(widget.initial?.description ?? '');
  late final _acBonus = watch('${_initialAcBonus(widget.initial)}');
  late final _magicBonus = watch('${widget.initial?.magicBonus ?? 0}');
  late final Set<String> _eligibleBases = {
    ...?widget.initial?.eligibleBaseItemIds,
  };
  late String _category = widget.initial?.category ?? 'gear';
  late String? _rarity = widget.initial?.rarity;
  late bool _attunement = widget.initial?.requiresAttunement ?? false;
  late String _baseItemKind = widget.initial?.baseItemKind ?? 'none';
  late final Set<String> _resistances = {
    for (final e in widget.initial?.effects ?? const <Effect>[])
      if (e is ResistanceEffect) e.damageType,
  };

  static int _initialAcBonus(Item? item) {
    for (final e in item?.effects ?? const <Effect>[]) {
      if (e is ArmorClassBonusEffect) return e.amount;
    }
    return 0;
  }

  int get _acBonusValue => int.tryParse(_acBonus.text.trim()) ?? 0;
  int get _magicBonusValue => int.tryParse(_magicBonus.text.trim()) ?? 0;

  Item _item() => Item(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    bundleSize: widget.initial?.bundleSize ?? 1,
    description: _description.text.trim(),
    rarity: _rarity,
    requiresAttunement: _attunement,
    magicBonus: _magicBonusValue,
    baseItemKind: _baseItemKind == 'none' ? null : _baseItemKind,
    eligibleBaseItemIds: _eligibleBases.toList(),
    // Las cargas no se editan acá, pero un objeto del catálogo que las
    // tiene deja de ser el mismo objeto sin ellas.
    maxCharges: widget.initial?.maxCharges,
    rechargeAmount: widget.initial?.rechargeAmount,
    effects: [
      if (_acBonusValue != 0) ArmorClassBonusEffect(_acBonusValue),
      for (final type in _resistances) ResistanceEffect(type),
      // El formulario solo sabe de esos dos efectos: el resto se conserva
      // tal cual en vez de desaparecer al guardar.
      ...?widget.initial?.effects.where(
        (e) => e is! ArmorClassBonusEffect && e is! ResistanceEffect,
      ),
    ],
  );

  void _save() => Navigator.of(context).pop(_item());

  /// Claves: `category`, `rarity`, `attunement`, `acBonus`, `res:<tipo>`,
  /// `base` y `magicBonus`.
  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'category':
        final rule = itemCategoryRules[_category];
        if (rule == null) return null;
        return _explained(
          'Categoría',
          _itemCategories[_category] ?? _category,
          rule,
          itemCategoryNote,
        );
      case 'rarity':
        final rarity = _rarity;
        return rarity == null
            ? _explained('Rareza', 'Mundano', itemMundaneRule)
            : _explained(
                'Rareza',
                _itemRarities[rarity] ?? rarity,
                itemRarityRule,
              );
      case 'attunement':
        return _explained(
          'Magia',
          _attunement ? 'Sintonización' : 'Sin sintonización',
          itemAttunementRule,
        );
      case 'acBonus':
        return _explained(
          'Efecto',
          'CA ${_signed(_acBonusValue)}',
          itemAcBonusRule,
        );
      case 'base':
        return _explained(
          'Objeto base',
          _baseItemKinds[_baseItemKind] ?? _baseItemKind,
          itemBaseRule,
        );
      case 'magicBonus':
        return _explained(
          'Objeto base',
          'Bonificador ${_signed(_magicBonusValue)}',
          itemMagicBonusRule,
        );
    }
    final type = key.substring('res:'.length);
    return _explained(
      'Efecto',
      'Resistencia: ${DamageType.labelFor(type)}',
      itemResistanceRule,
      DamageType.fromId(type)?.description,
    );
  }

  @override
  Iterable<String> get chosenKeys => [
    'category',
    if (_rarity != null) 'rarity',
    if (_attunement) 'attunement',
    if (_acBonusValue != 0) 'acBonus',
    for (final t in DamageType.values)
      if (_resistances.contains(t.id)) 'res:${t.id}',
    if (_baseItemKind != 'none') 'base',
    if (_magicBonusValue != 0) 'magicBonus',
  ];

  String get _effectsSummary => _orNone([
    if (_acBonusValue != 0) 'CA ${_signed(_acBonusValue)}',
    for (final t in DamageType.values)
      if (_resistances.contains(t.id)) 'Resistencia: ${t.label}',
  ], 'ninguno');

  @override
  Widget build(BuildContext context) {
    final item = _item();
    return _FormScaffold(
      title: 'Objeto',
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: 'Así queda en tu lista',
        preview: _rowPreview(
          item.name,
          pills: _itemPills(item),
          stats: _itemStats(item),
        ),
        hint:
            'Tocá la categoría, la rareza o un efecto para ver qué hace el '
            'objeto en la ficha.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del objeto'),
        ),
        _fieldRow(
          flex: const [3, 2, 2],
          [
            _categoryDropdown(
              _itemCategories,
              _category,
              (v) => setState(() {
                _category = v;
                focus = 'category';
              }),
              onTap: () => focusOn('category'),
            ),
            _text(_weight, 'Peso (lb)', number: true, validator: _weightValue),
            _text(
              _costCp,
              'Precio (pc)',
              number: true,
              validator: (v) => _intInRange(v, 0, 100000000, optional: false),
            ),
          ],
        ),
        explainHere((f) => f == 'category'),
        ..._optionalRule,
        section(
          icon: Icons.auto_awesome,
          title: 'Magia',
          summary: _orNone([
            if (_rarity != null) _itemRarities[_rarity] ?? _rarity!,
            if (_attunement) 'sintonización',
          ], 'mundano'),
          children: [
            _idDropdown(
              label: 'Rareza',
              value: _rarity ?? _mundane,
              options: _itemRarities,
              onChanged: (v) => setState(() {
                _rarity = v == _mundane ? null : v;
                focus = 'rarity';
                // Sin rareza no hay objeto mágico, y un objeto mundano no se
                // sintoniza: dejar el interruptor prendido guardaría una
                // combinación que el motor considera inválida.
                if (_rarity == null) _attunement = false;
              }),
              onTap: () => focusOn('rarity'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere sintonización'),
              subtitle: _rarity == null
                  ? const Text('Solo los objetos mágicos se sintonizan.')
                  : null,
              value: _attunement,
              onChanged: _rarity == null
                  ? null
                  : (v) => setState(() {
                      _attunement = v;
                      focus = 'attunement';
                    }),
            ),
            explainHere((f) => f == 'rarity' || f == 'attunement'),
          ],
        ),
        section(
          icon: Icons.shield_outlined,
          title: 'Efectos mientras esté equipado',
          summary: _effectsSummary,
          children: [
            _text(
              _acBonus,
              'Bonificador a la Clase de Armadura',
              number: true,
              validator: (v) => _intInRange(v, -5, 10, optional: false),
              onTap: () => focusOn('acBonus'),
            ),
            const SizedBox(height: 8),
            const Text('Resistencias'),
            const SizedBox(height: 6),
            _idChips(
              {for (final t in DamageType.values) t.id: t.label},
              _resistances,
              redraw,
              onTap: (id) => focus = 'res:$id',
            ),
            explainHere((f) => f == 'acBonus' || f.startsWith('res:')),
          ],
        ),
        section(
          icon: Icons.layers_outlined,
          title: 'Objeto base',
          summary: _baseItemKind == 'none'
              ? 'ninguno'
              : _orNone([
                  _baseItemKinds[_baseItemKind] ?? _baseItemKind,
                  if (_magicBonusValue != 0) _signed(_magicBonusValue),
                ], ''),
          children: [
            _fieldRow(
              flex: const [3, 2],
              [
                _idDropdown(
                  label: 'Objeto base',
                  value: _baseItemKind,
                  options: _baseItemKinds,
                  // Las bases elegidas son de la familia anterior y no valen
                  // para la nueva: el motor las rechazaría igual
                  // (`_validBase`), pero quedarían guardadas y sin nada que
                  // las muestre.
                  onChanged: (v) => setState(() {
                    _baseItemKind = v;
                    _eligibleBases.clear();
                    focus = 'base';
                  }),
                  onTap: () => focusOn('base'),
                ),
                _text(
                  _magicBonus,
                  'Bonificador mágico',
                  number: true,
                  validator: (v) => _intInRange(v, -5, 10, optional: false),
                  onTap: () => focusOn('magicBonus'),
                ),
              ],
            ),
            // Solo con una familia elegida: sin objeto base no hay nada que
            // restringir, y el campo pedía escribir los ids del catálogo a
            // mano.
            if (_baseItemKind != 'none') ...[
              const SizedBox(height: 8),
              const Eyebrow('Bases permitidas'),
              const SizedBox(height: 4),
              Text(
                _eligibleBases.isEmpty
                    ? 'Sin marcar ninguna, sirve cualquiera de la familia '
                          'elegida.'
                    : 'Solo se va a poder usar lo que marques acá.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _idChips(_baseOptions(), _eligibleBases, redraw),
            ],
            explainHere((f) => f == 'base' || f == 'magicBonus'),
          ],
        ),
        section(
          icon: Icons.menu_book_outlined,
          title: 'Descripción',
          summary: _description.text.trim().isEmpty ? 'sin cargar' : 'cargada',
          children: [_text(_description, 'Descripción', maxLines: 5)],
        ),
      ],
    );
  }

  /// Las bases del catálogo que puede tomar la familia elegida, por su nombre.
  /// Escudo y armadura salen del mismo catálogo y los separa `isShield`, igual
  /// que en `InventoryOps._validBase`.
  Map<String, String> _baseOptions() => switch (_baseItemKind) {
    'weapon' => {for (final w in widget.repo.weaponsSorted) w.id: w.name},
    'armor' => {
      for (final a in widget.repo.armorSorted)
        if (!a.isShield) a.id: a.name,
    },
    'shield' => {
      for (final a in widget.repo.armorSorted)
        if (a.isShield) a.id: a.name,
    },
    _ => const {},
  };
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Las pills de un objeto en la lista y en la vista previa del formulario.
List<String> _itemPills(Item i) => [
  _itemCategories[i.category] ?? i.category,
  if (i.rarity != null) _itemRarities[i.rarity] ?? i.rarity!,
  if (i.requiresAttunement) 'Sintonización',
];

/// Las cifras de un objeto, con el mismo motivo que [_itemPills].
List<(String, String)> _itemStats(Item i) => [
  if (i.weight > 0) ('Peso', '${formatPounds(i.weight)} lb'),
  if (i.costCp > 0) ('Precio', formatCost(i.costCp)),
  if (i.maxCharges != null) ('Cargas', '${i.maxCharges}'),
  if (i.bundleSize > 1) ('Paquete', '${i.bundleSize}'),
];
