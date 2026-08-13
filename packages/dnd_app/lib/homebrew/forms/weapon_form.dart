part of '../homebrew_screen.dart';

class WeaponForm extends StatefulWidget {
  final Weapon? initial;
  const WeaponForm({super.key, this.initial});
  @override
  State<WeaponForm> createState() => _WeaponFormState();
}

class _WeaponFormState extends State<WeaponForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _dice = TextEditingController(
    text: widget.initial?.damageDice ?? '1d6',
  );
  late String _type = widget.initial?.damageType ?? DamageType.slashing.id;
  late final _versatile = TextEditingController(
    text: widget.initial?.versatileDice ?? '',
  );
  late final _mastery = TextEditingController(
    text: widget.initial?.mastery ?? '',
  );
  late final _weight = TextEditingController(
    text: widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = TextEditingController(
    text: '${widget.initial?.costCp ?? 0}',
  );
  late final _magicBonus = TextEditingController(
    text: '${widget.initial?.magicBonus ?? 0}',
  );
  late String _category = widget.initial?.category ?? 'simple';
  late final Set<String> _props = {...?widget.initial?.properties};

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Arma',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del arma'),
        ),
        _categoryDropdown(
          _weaponCategories,
          _category,
          (v) => setState(() => _category = v),
        ),
        _text(
          _dice,
          'Dado de daño (p.ej. 1d8)',
          validator: (v) => _diceValue(v, optional: false),
        ),
        _damageTypeDropdown(_type, (v) => setState(() => _type = v)),
        _text(
          _versatile,
          'Dado versátil (opcional, p.ej. 1d10)',
          validator: (v) => _diceValue(v, optional: true),
        ),
        _text(_mastery, 'Maestría (opcional, p.ej. sap)'),
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
        _text(
          _magicBonus,
          'Bonificador mágico (+0 a +3)',
          number: true,
          validator: (v) => _intInRange(v, 0, 3, optional: false),
        ),
        const SizedBox(height: 8),
        const Eyebrow('Propiedades'),
        _idChips(_weaponPropOptions, _props, () => setState(() {})),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      Weapon(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        category: _category,
        damageDice: _dice.text.trim(),
        damageType: _type,
        properties: _props.toList(),
        versatileDice: _versatile.text.trim().isEmpty
            ? null
            : _versatile.text.trim(),
        mastery: _mastery.text.trim().isEmpty ? null : _mastery.text.trim(),
        weight: double.parse(_weight.text.trim()),
        costCp: int.parse(_costCp.text.trim()),
        magicBonus: int.parse(_magicBonus.text.trim()),
      ),
    );
  }
}
