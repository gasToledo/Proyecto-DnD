part of '../homebrew_screen.dart';

class ArmorForm extends StatefulWidget {
  final Armor? initial;
  const ArmorForm({super.key, this.initial});
  @override
  State<ArmorForm> createState() => _ArmorFormState();
}

class _ArmorFormState extends State<ArmorForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _baseAc = TextEditingController(
    text: '${widget.initial?.baseAc ?? 11}',
  );
  late final _maxDex = TextEditingController(
    text: widget.initial?.maxDexBonus?.toString() ?? '',
  );
  late final _strReq = TextEditingController(
    text: widget.initial?.strengthRequirement?.toString() ?? '',
  );
  late final _weight = TextEditingController(
    text: widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = TextEditingController(
    text: '${widget.initial?.costCp ?? 0}',
  );
  late String _category = widget.initial?.category ?? 'light';
  late bool _addDex = widget.initial?.addDexMod ?? true;
  late bool _stealth = widget.initial?.stealthDisadvantage ?? false;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Armadura',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la armadura'),
        ),
        _categoryDropdown(
          _armorCategories,
          _category,
          (v) => setState(() => _category = v),
        ),
        _text(
          _baseAc,
          'CA base',
          number: true,
          validator: (v) => _intInRange(v, 1, 30, optional: false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Suma modificador de DEX'),
          value: _addDex,
          onChanged: (v) => setState(() => _addDex = v),
        ),
        _text(
          _maxDex,
          'Tope de DEX (opcional, p.ej. 2)',
          number: true,
          validator: (v) => _intInRange(v, 0, 10, optional: true),
        ),
        _text(
          _strReq,
          'Requisito de Fuerza (opcional)',
          number: true,
          validator: (v) => _intInRange(v, 1, 30, optional: true),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Desventaja en Sigilo'),
          value: _stealth,
          onChanged: (v) => setState(() => _stealth = v),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      Armor(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        category: _category,
        // Sin `?? 10`: el formulario ya no deja llegar acá un valor que no
        // parsee, y sustituirlo en silencio guardaba una armadura distinta de
        // la que se escribió.
        baseAc: int.parse(_baseAc.text.trim()),
        addDexMod: _addDex,
        maxDexBonus: int.tryParse(_maxDex.text.trim()),
        strengthRequirement: int.tryParse(_strReq.text.trim()),
        stealthDisadvantage: _stealth,
        weight: double.parse(_weight.text.trim()),
        costCp: int.parse(_costCp.text.trim()),
      ),
    );
  }
}
