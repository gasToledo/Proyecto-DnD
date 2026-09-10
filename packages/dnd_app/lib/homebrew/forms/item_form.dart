part of '../homebrew_screen.dart';

/// Formulario de objeto homebrew.
///
/// No valida colisión de id contra armas y armaduras: `homebrewId` arma
/// `hb-<slug>-<timestamp>`, así que un id de acá no puede pisar uno del
/// catálogo oficial ni otro homebrew.
class ItemForm extends StatefulWidget {
  final Item? initial;

  /// Para ofrecer las bases permitidas por su nombre. Es la única cosa del
  /// formulario que sale del catálogo y no de lo que se escribe.
  final ContentRepository repo;

  const ItemForm({super.key, required this.repo, this.initial});

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _weight = TextEditingController(
    text: widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = TextEditingController(
    text: '${widget.initial?.costCp ?? 0}',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _acBonus = TextEditingController(
    text: '${_initialAcBonus(widget.initial)}',
  );
  late final _magicBonus = TextEditingController(
    text: '${widget.initial?.magicBonus ?? 0}',
  );
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

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Objeto',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del objeto'),
        ),
        _categoryDropdown(
          _itemCategories,
          _category,
          (v) => setState(() => _category = v),
        ),
        _text(
          _weight,
          'Peso en libras (0 si no cuenta)',
          number: true,
          validator: _weightValue,
        ),
        _text(
          _costCp,
          'Precio en piezas de cobre (1 po = 100)',
          number: true,
          validator: (v) => _intInRange(v, 0, 100000000, optional: false),
        ),
        _text(_description, 'Descripción', maxLines: 5),
        _idDropdown(
          label: 'Rareza',
          value: _rarity ?? _mundane,
          options: _itemRarities,
          onChanged: (v) => setState(() {
            _rarity = v == _mundane ? null : v;
            // Sin rareza no hay objeto mágico, y un objeto mundano no se
            // sintoniza: dejar el interruptor prendido guardaría una
            // combinación que el motor considera inválida.
            if (_rarity == null) _attunement = false;
          }),
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
              : (v) => setState(() => _attunement = v),
        ),
        _idDropdown(
          label: 'Objeto base',
          value: _baseItemKind,
          options: const {
            'none': 'Ninguno',
            'weapon': 'Arma',
            'armor': 'Armadura',
            'shield': 'Escudo',
          },
          // Las bases elegidas son de la familia anterior y no valen para la
          // nueva: el motor las rechazaría igual (`_validBase`), pero quedarían
          // guardadas y sin nada que las muestre.
          onChanged: (v) => setState(() {
            _baseItemKind = v;
            _eligibleBases.clear();
          }),
        ),
        _text(
          _magicBonus,
          'Bonificador mágico del objeto base',
          number: true,
          validator: (v) => _intInRange(v, -5, 10, optional: false),
        ),
        // Solo con una familia elegida: sin objeto base no hay nada que
        // restringir, y el campo pedía escribir los ids del catálogo a mano.
        if (_baseItemKind != 'none') ...[
          const SizedBox(height: 8),
          const Eyebrow('Bases permitidas'),
          const SizedBox(height: 4),
          Text(
            _eligibleBases.isEmpty
                ? 'Sin marcar ninguna, sirve cualquiera de la familia elegida.'
                : 'Solo se va a poder usar lo que marques acá.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _idChips(_baseOptions(), _eligibleBases, () => setState(() {})),
        ],
        const SizedBox(height: 8),
        const Eyebrow('Efectos mientras esté equipado'),
        _text(
          _acBonus,
          'Bonificador a la Clase de Armadura',
          number: true,
          validator: (v) => _intInRange(v, -5, 10, optional: false),
        ),
        const SizedBox(height: 8),
        const Text('Resistencias'),
        const SizedBox(height: 6),
        _idChips(
          {for (final t in DamageType.values) t.id: DamageType.labelFor(t.id)},
          _resistances,
          () => setState(() {}),
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

  void _save() {
    final acBonus = int.parse(_acBonus.text.trim());
    Navigator.of(context).pop(
      Item(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        category: _category,
        weight: double.parse(_weight.text.trim()),
        costCp: int.parse(_costCp.text.trim()),
        bundleSize: widget.initial?.bundleSize ?? 1,
        description: _description.text.trim(),
        rarity: _rarity,
        requiresAttunement: _attunement,
        magicBonus: int.parse(_magicBonus.text.trim()),
        baseItemKind: _baseItemKind == 'none' ? null : _baseItemKind,
        eligibleBaseItemIds: _eligibleBases.toList(),
        // Las cargas no se editan acá, pero un objeto del catálogo que las
        // tiene deja de ser el mismo objeto sin ellas.
        maxCharges: widget.initial?.maxCharges,
        rechargeAmount: widget.initial?.rechargeAmount,
        effects: [
          if (acBonus != 0) ArmorClassBonusEffect(acBonus),
          for (final type in _resistances) ResistanceEffect(type),
          // El formulario solo sabe de esos dos efectos: el resto se conserva
          // tal cual en vez de desaparecer al guardar.
          ...?widget.initial?.effects.where(
            (e) => e is! ArmorClassBonusEffect && e is! ResistanceEffect,
          ),
        ],
      ),
    );
  }
}
