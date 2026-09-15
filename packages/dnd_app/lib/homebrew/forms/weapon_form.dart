part of '../homebrew_screen.dart';

/// Formulario de arma: arriba lo que hace falta para guardar un arma usable
/// —nombre, categoría, dado y tipo de daño— y el resto en secciones plegadas.
///
/// Al costado van la fila tal como va a quedar en la lista y la explicación de
/// lo que se está tocando. Quien arma su primera arma no sabe qué hace «Sutil»
/// ni «Derribar», y ese es el momento de decírselo. En una pantalla angosta no
/// hay panel: la explicación aparece debajo del campo.
///
/// ponytail: el alcance normal y largo no se edita (se conserva el del
/// original). Va en Propiedades, mostrándose con «A distancia» o «Arrojadiza»
/// marcadas, cuando alguien arme un arco propio.
class WeaponForm extends StatefulWidget {
  final Weapon? initial;
  const WeaponForm({super.key, this.initial});
  @override
  State<WeaponForm> createState() => _WeaponFormState();
}

enum _WeaponSection { properties, mastery, economy, legend }

class _WeaponFormState extends State<WeaponForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _dice = TextEditingController(
    text: widget.initial?.damageDice ?? '1d6',
  );
  late String _type = widget.initial?.damageType ?? DamageType.slashing.id;
  late final _versatile = TextEditingController(
    text: widget.initial?.versatileDice ?? '',
  );
  late String _mastery = widget.initial?.mastery ?? '';
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
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );

  /// Qué se está tocando, para explicarlo: `category`, `type`, `mastery` o
  /// `prop:<id>`. Null hasta la primera elección.
  String? _focus;
  final Set<_WeaponSection> _open = {};

  List<TextEditingController> get _controllers => [
    _name,
    _dice,
    _versatile,
    _weight,
    _costCp,
    _magicBonus,
    _description,
  ];

  @override
  void initState() {
    super.initState();
    // La vista previa y los resúmenes de las secciones cerradas muestran lo
    // que se escribe, así que cada tecla redibuja.
    for (final c in _controllers) {
      c.addListener(_redraw);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _redraw() => setState(() {});

  void _toggle(_WeaponSection section) => setState(
    () => _open.contains(section) ? _open.remove(section) : _open.add(section),
  );

  /// El arma tal como está escrita.
  ///
  /// La vista previa la pide en cada tecla, así que un número a medio tipear
  /// cae en 0 en vez de romper. Al guardar ese caso no llega: [_FormScaffold]
  /// valida antes de llamar a [_save].
  Weapon _weapon() => Weapon(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    damageDice: _dice.text.trim(),
    damageType: _type,
    properties: _props.toList(),
    // Lo que el formulario no muestra se conserva del original, para que
    // editar —o duplicar— un arma del catálogo no le cambie la regla.
    twoHandedUnlessMounted: widget.initial?.twoHandedUnlessMounted ?? false,
    rangeNormal: widget.initial?.rangeNormal ?? 0,
    rangeLong: widget.initial?.rangeLong ?? 0,
    versatileDice: _versatile.text.trim().isEmpty
        ? null
        : _versatile.text.trim(),
    mastery: _mastery.isEmpty ? null : _mastery,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    magicBonus: int.tryParse(_magicBonus.text.trim()) ?? 0,
    description: _description.text.trim(),
  );

  void _save() => Navigator.of(context).pop(_weapon());

  /// La explicación de [key], con el mismo formato de [_focus]. Null cuando
  /// no hay texto que dar: una categoría o una propiedad que trajo un pack y
  /// el glosario no conoce.
  _Explained? _explain(String key) {
    switch (key) {
      case 'category':
        final rule = weaponCategoryRules[_category];
        if (rule == null) return null;
        return (
          kicker: 'Categoría',
          title: _weaponCategories[_category] ?? _category,
          text: rule,
          note: null,
        );
      case 'type':
        final type = DamageType.fromId(_type);
        if (type == null) return null;
        return (
          kicker: 'Tipo de daño',
          title: type.label,
          text: type.description,
          note: damageTypeRule,
        );
      case 'mastery':
        if (_mastery.isEmpty) {
          return (
            kicker: 'Maestría',
            title: 'Sin maestría',
            text: 'Al que tiene el rasgo Maestría con armas no le suma nada.',
            note: null,
          );
        }
        final mastery = weaponMasteries[_mastery];
        if (mastery == null) return null;
        return (
          kicker: 'Maestría',
          title: mastery.name,
          text: mastery.description,
          note: weaponMasteryRule,
        );
    }
    final property = weaponProperties[key.substring('prop:'.length)];
    if (property == null) return null;
    return (
      kicker: 'Propiedad',
      title: property.name,
      text: property.description,
      note: null,
    );
  }

  /// La explicación debajo del campo, para cuando no hay panel lateral.
  /// [here] dice si el foco actual es de este lugar del formulario.
  Widget _explainHere(bool Function(String focus) here) {
    final focus = _focus;
    final explained = focus == null ? null : _explain(focus);
    if (focus == null || explained == null || !here(focus)) {
      return const SizedBox.shrink();
    }
    return _WithoutPanel(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _Explanation(explained),
      ),
    );
  }

  String get _propertiesSummary {
    final names = [
      for (final p in weaponProperties.values)
        if (_props.contains(p.id)) p.name,
    ];
    return names.isEmpty ? 'ninguna' : names.join(', ');
  }

  String get _masterySummary {
    final bonus = int.tryParse(_magicBonus.text.trim()) ?? 0;
    return [
      _mastery.isEmpty ? 'sin maestría' : weaponMasteryName(_mastery),
      if (bonus != 0) '+$bonus',
    ].join(' · ');
  }

  String get _economySummary {
    final weight = double.tryParse(_weight.text.trim()) ?? 0;
    final cost = int.tryParse(_costCp.text.trim()) ?? 0;
    if (weight <= 0 && cost <= 0) return 'sin cargar';
    return [
      if (weight > 0) '${formatPounds(weight)} lb',
      if (cost > 0) formatCost(cost),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Arma',
      onSave: _save,
      onInvalid: () => setState(() => _open.addAll(_WeaponSection.values)),
      panel: _panel(_weapon()),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del arma'),
        ),
        _fieldRow(
          flex: const [3, 2, 3],
          [
            _categoryDropdown(
              _weaponCategories,
              _category,
              (v) => setState(() {
                _category = v;
                _focus = 'category';
              }),
              onTap: () => setState(() => _focus = 'category'),
            ),
            _text(
              _dice,
              'Dado de daño',
              validator: (v) => _diceValue(v, optional: false),
            ),
            _damageTypeDropdown(
              _type,
              (v) => setState(() {
                _type = v;
                _focus = 'type';
              }),
              onTap: () => setState(() => _focus = 'type'),
            ),
          ],
        ),
        _explainHere((f) => f == 'category' || f == 'type'),
        ..._optionalRule,
        _FormSection(
          icon: Icons.tune,
          title: 'Propiedades',
          summary: _propertiesSummary,
          expanded: _open.contains(_WeaponSection.properties),
          onToggle: () => _toggle(_WeaponSection.properties),
          children: [
            _idChips(
              _weaponPropOptions,
              _props,
              _redraw,
              onTap: (id) => _focus = 'prop:$id',
            ),
            // A dos manos, el dado versátil reemplaza al normal: sin la
            // propiedad no significa nada. Si el arma ya trae uno se muestra
            // igual, para que nunca quede un valor guardado sin verse.
            if (_props.contains('versatile') ||
                _versatile.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _text(
                _versatile,
                'Dado versátil (p.ej. 1d10)',
                validator: (v) => _diceValue(v, optional: true),
              ),
            ],
            _explainHere((f) => f.startsWith('prop:')),
          ],
        ),
        _FormSection(
          icon: Icons.auto_awesome,
          title: 'Maestría y magia',
          summary: _masterySummary,
          expanded: _open.contains(_WeaponSection.mastery),
          onToggle: () => _toggle(_WeaponSection.mastery),
          children: [
            _fieldRow(
              flex: const [3, 2],
              [
                _idDropdown(
                  label: 'Maestría',
                  value: _mastery,
                  options: _masteryOptions,
                  onChanged: (v) => setState(() {
                    _mastery = v;
                    _focus = 'mastery';
                  }),
                  onTap: () => setState(() => _focus = 'mastery'),
                ),
                _text(
                  _magicBonus,
                  'Bonificador mágico (+0 a +3)',
                  number: true,
                  validator: (v) => _intInRange(v, 0, 3, optional: false),
                ),
              ],
            ),
            _explainHere((f) => f == 'mastery'),
          ],
        ),
        _FormSection(
          icon: Icons.paid_outlined,
          title: 'Economía',
          summary: _economySummary,
          expanded: _open.contains(_WeaponSection.economy),
          onToggle: () => _toggle(_WeaponSection.economy),
          children: [
            _fieldRow([
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
            ]),
          ],
        ),
        _FormSection(
          icon: Icons.menu_book_outlined,
          title: 'Leyenda',
          summary: _description.text.trim().isEmpty ? 'sin cargar' : 'cargada',
          expanded: _open.contains(_WeaponSection.legend),
          onToggle: () => _toggle(_WeaponSection.legend),
          children: [
            _text(
              _description,
              'Descripción (la leyenda del arma)',
              maxLines: 5,
            ),
          ],
        ),
      ],
    );
  }

  /// El panel lateral: la fila de la lista, lo que se está tocando y lo que ya
  /// se eligió.
  Widget _panel(Weapon weapon) {
    final focus = _focus;
    final explained = focus == null ? null : _explain(focus);
    final chosen = [
      for (final key in [
        'category',
        'type',
        if (_mastery.isNotEmpty) 'mastery',
        for (final p in weaponProperties.keys)
          if (_props.contains(p)) 'prop:$p',
      ])
        if (key != focus) ?_explain(key),
    ];
    return Builder(
      builder: (context) {
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('Así queda en tu lista'),
            DenseRows(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weapon.name.isEmpty
                            ? 'Todavía sin nombre'
                            : weapon.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: weapon.name.isEmpty ? muted : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final pill in _weaponPills(weapon))
                            GoldPill(pill, highlighted: false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _statBand(context, _weaponStats(weapon), wide: false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (explained != null)
              _Explanation(explained)
            else
              Text(
                'Tocá la categoría, el tipo de daño, una propiedad o la '
                'maestría para ver qué hace.',
                style: TextStyle(fontSize: 13, height: 1.45, color: muted),
              ),
            if (chosen.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ChosenList(chosen),
            ],
          ],
        );
      },
    );
  }
}

/// Las pills de un arma en la lista. Las comparten la lista y la vista previa
/// del formulario: si se separaran, la vista previa mostraría otra fila.
List<String> _weaponPills(Weapon w) => [
  _weaponCategories[w.category] ?? w.category,
  DamageType.labelFor(w.damageType),
  if (w.magicBonus != 0) '+${w.magicBonus}',
  for (final property in w.properties) _weaponPropOptions[property] ?? property,
];

/// Las cifras de un arma en la lista, con el mismo motivo que [_weaponPills].
List<(String, String)> _weaponStats(Weapon w) => [
  (
    'Daño',
    w.versatileDice == null
        ? w.damageDice
        : '${w.damageDice} / ${w.versatileDice}',
  ),
  if (w.weight > 0) ('Peso', '${formatPounds(w.weight)} lb'),
  if (w.costCp > 0) ('Precio', formatCost(w.costCp)),
];
