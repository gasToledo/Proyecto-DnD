part of '../homebrew_screen.dart';

/// Formulario de armadura, con el mismo armazón que el de arma: arriba lo que
/// hace falta para guardarla —nombre, categoría y CA— y lo demás plegado.
///
/// Además de la fila de la lista, el panel muestra la CA que va a quedar en la
/// ficha con dos Destrezas de ejemplo: «tope +2» no dice nada hasta que se ve
/// que un personaje ágil se queda en 16.
class ArmorForm extends StatefulWidget {
  final Armor? initial;
  const ArmorForm({super.key, this.initial});
  @override
  State<ArmorForm> createState() => _ArmorFormState();
}

class _ArmorFormState extends State<ArmorForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _baseAc = watch('${widget.initial?.baseAc ?? 11}');
  late final _maxDex = watch(widget.initial?.maxDexBonus?.toString() ?? '');
  late final _strReq = watch(
    widget.initial?.strengthRequirement?.toString() ?? '',
  );
  late final _weight = watch(
    widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = watch('${widget.initial?.costCp ?? 0}');
  late String _category = widget.initial?.category ?? 'light';
  late bool _addDex = widget.initial?.addDexMod ?? true;
  late bool _stealth = widget.initial?.stealthDisadvantage ?? false;
  late final _description = watch(widget.initial?.description ?? '');

  /// Las Destrezas con las que el panel muestra la CA: una que pasa el tope
  /// del manual y una que no.
  static const _exampleDex = [3, 1];

  /// La armadura tal como está escrita. Mismo criterio que `_weapon`: un
  /// número a medio tipear cae en un defecto para la vista previa, y al
  /// guardar no llega porque el formulario valida antes.
  Armor _armor() => Armor(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    baseAc: int.tryParse(_baseAc.text.trim()) ?? 0,
    addDexMod: _addDex,
    maxDexBonus: int.tryParse(_maxDex.text.trim()),
    strengthRequirement: int.tryParse(_strReq.text.trim()),
    stealthDisadvantage: _stealth,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    description: _description.text.trim(),
  );

  void _save() => Navigator.of(context).pop(_armor());

  bool get _shield => _category == 'shield';

  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'category':
        final rule = armorCategoryRules[_category];
        if (rule == null) return null;
        return _explained(
          'Categoría',
          _armorCategories[_category] ?? _category,
          rule,
          armorTrainingRule,
        );
      case 'baseAc':
        return _explained(
          'CA base',
          _baseAc.text.trim().isEmpty ? 'Sin cargar' : _baseAc.text.trim(),
          _shield ? shieldBaseAcRule : armorBaseAcRule,
        );
      case 'addDex':
        return _explained(
          'Destreza',
          _addDex ? 'Suma Destreza' : 'Sin Destreza',
          armorAddDexRule,
        );
      case 'maxDex':
        final cap = _maxDex.text.trim();
        return _explained(
          'Tope de Destreza',
          cap.isEmpty ? 'Sin tope' : 'Hasta +$cap',
          armorMaxDexRule,
        );
      case 'strength':
        final str = _strReq.text.trim();
        return _explained(
          'Exigencia',
          str.isEmpty ? 'Sin requisito de Fuerza' : 'Fuerza $str',
          armorStrengthRule,
        );
      case 'stealth':
        return _explained(
          'Exigencia',
          _stealth ? 'Sigilo con desventaja' : 'Sin desventaja en Sigilo',
          armorStealthRule,
        );
    }
    return null;
  }

  @override
  Iterable<String> get chosenKeys => [
    'category',
    if (!_shield && _addDex && _maxDex.text.trim().isNotEmpty) 'maxDex',
    if (_strReq.text.trim().isNotEmpty) 'strength',
    if (_stealth) 'stealth',
  ];

  String get _dexSummary {
    if (!_addDex) return 'sin Destreza';
    final cap = _maxDex.text.trim();
    return cap.isEmpty ? 'Destreza entera' : 'hasta +$cap';
  }

  String get _demandsSummary {
    final str = _strReq.text.trim();
    final parts = [
      if (str.isNotEmpty) 'Fuerza $str',
      if (_stealth) 'Sigilo con desventaja',
    ];
    return parts.isEmpty ? 'ninguna' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final armor = _armor();
    return _FormScaffold(
      title: 'Armadura',
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: 'Así queda en tu lista',
        preview: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _rowPreview(
              armor.name,
              pills: _armorPills(armor),
              stats: _armorStats(armor),
            ),
            // Un escudo no tiene una CA propia que mostrar: suma a la otra.
            if (!armor.isShield) ...[
              const SizedBox(height: 14),
              const Eyebrow('En la ficha'),
              _statBand(context, [
                for (final dex in _exampleDex)
                  ('CA con DES +$dex', '${armor.armorClassFor(dex)}'),
              ], wide: false),
            ],
          ],
        ),
        hint:
            'Tocá la categoría, la CA o cómo suma la Destreza para ver qué '
            'cambia.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la armadura'),
        ),
        _fieldRow(
          flex: const [3, 2],
          [
            _categoryDropdown(
              _armorCategories,
              _category,
              (v) => setState(() {
                _category = v;
                focus = 'category';
              }),
              onTap: () => focusOn('category'),
            ),
            _text(
              _baseAc,
              _shield ? 'CA que suma' : 'CA base',
              number: true,
              validator: (v) => _intInRange(v, 1, 30, optional: false),
              onTap: () => focusOn('baseAc'),
            ),
          ],
        ),
        explainHere((f) => f == 'category' || f == 'baseAc'),
        ..._optionalRule,
        // Un escudo no suma Destreza: la sección solo confundiría. Lo que
        // traiga guardado igual se conserva, porque el estado no se toca.
        if (!_shield)
          section(
            icon: Icons.directions_run,
            title: 'Cómo suma la Destreza',
            summary: _dexSummary,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Suma modificador de DES'),
                value: _addDex,
                onChanged: (v) => setState(() {
                  _addDex = v;
                  focus = 'addDex';
                }),
              ),
              if (_addDex)
                _text(
                  _maxDex,
                  'Tope de DES (vacío = sin tope)',
                  number: true,
                  validator: (v) => _intInRange(v, 0, 10, optional: true),
                  onTap: () => focusOn('maxDex'),
                ),
              explainHere((f) => f == 'addDex' || f == 'maxDex'),
            ],
          ),
        section(
          icon: Icons.fitness_center,
          title: 'Exigencias',
          summary: _demandsSummary,
          children: [
            _text(
              _strReq,
              'Requisito de Fuerza (opcional)',
              number: true,
              validator: (v) => _intInRange(v, 1, 30, optional: true),
              onTap: () => focusOn('strength'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desventaja en Sigilo'),
              value: _stealth,
              onChanged: (v) => setState(() {
                _stealth = v;
                focus = 'stealth';
              }),
            ),
            explainHere((f) => f == 'strength' || f == 'stealth'),
          ],
        ),
        _economySection(this, _weight, _costCp),
        _legendSection(this, _description, 'la leyenda de la armadura'),
      ],
    );
  }
}

/// Las pills de una armadura en la lista y en la vista previa del formulario.
List<String> _armorPills(Armor a) => [
  _armorCategories[a.category] ?? a.category,
  if (a.stealthDisadvantage) 'Sigilo con desventaja',
];

/// Las cifras de una armadura, con el mismo motivo que [_armorPills].
List<(String, String)> _armorStats(Armor a) => [
  ('CA', a.isShield ? '+${a.baseAc}' : '${a.baseAc}'),
  if (a.weight > 0) ('Peso', '${formatPounds(a.weight)} lb'),
  if (a.costCp > 0) ('Precio', formatCost(a.costCp)),
];
