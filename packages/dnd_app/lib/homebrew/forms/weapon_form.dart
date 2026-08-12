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
      ),
    );
  }
}
