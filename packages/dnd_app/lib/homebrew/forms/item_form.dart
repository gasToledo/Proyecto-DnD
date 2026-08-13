part of '../homebrew_screen.dart';

/// Formulario de objeto homebrew.
///
/// No valida colisión de id contra armas y armaduras: `homebrewId` arma
/// `hb-<slug>-<timestamp>`, así que un id de acá no puede pisar uno del
/// catálogo oficial ni otro homebrew.
class ItemForm extends StatefulWidget {
  final Item? initial;

  const ItemForm({super.key, this.initial});

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
  late String _category = widget.initial?.category ?? 'gear';
  late String? _rarity = widget.initial?.rarity;
  late bool _attunement = widget.initial?.requiresAttunement ?? false;
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

  /// Peso en libras, con medias libras. A diferencia del precio no es entero:
  /// la tabla del manual tiene objetos de ¼ y de ½ libra.
  String? _weightValue(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribí un peso, 0 si no cuenta.';
    final n = double.tryParse(text);
    if (n == null) return 'Tiene que ser un número.';
    return n < 0 ? 'No puede ser negativo.' : null;
  }

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
        effects: [
          if (acBonus != 0) ArmorClassBonusEffect(acBonus),
          for (final type in _resistances) ResistanceEffect(type),
        ],
      ),
    );
  }
}
