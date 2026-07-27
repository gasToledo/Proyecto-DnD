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
  late String _category = widget.initial?.category ?? 'light';
  late bool _addDex = widget.initial?.addDexMod ?? true;
  late bool _stealth = widget.initial?.stealthDisadvantage ?? false;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Armadura',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _categoryDropdown(
          ['light', 'medium', 'heavy', 'shield'],
          _category,
          (v) => setState(() => _category = v),
        ),
        _text(_baseAc, 'CA base', number: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Suma modificador de DEX'),
          value: _addDex,
          onChanged: (v) => setState(() => _addDex = v),
        ),
        _text(_maxDex, 'Tope de DEX (opcional, p.ej. 2)', number: true),
        _text(_strReq, 'Requisito de Fuerza (opcional)', number: true),
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
        baseAc: int.tryParse(_baseAc.text.trim()) ?? 10,
        addDexMod: _addDex,
        maxDexBonus: int.tryParse(_maxDex.text.trim()),
        strengthRequirement: int.tryParse(_strReq.text.trim()),
        stealthDisadvantage: _stealth,
      ),
    );
  }
}
