part of '../homebrew_screen.dart';

/// Formulario de especie: arriba lo que se lee en la tarjeta al crear un
/// personaje —tipo, tamaño y velocidad— y lo demás plegado.
///
/// Suma lo que antes solo se conservaba: el lema, entre qué habilidades se
/// elige y los tamaños a elegir. Una especie propia sin eso ofrecía las 18
/// habilidades y un solo tamaño aunque su historia dijera otra cosa.
class RaceForm extends StatefulWidget {
  final Race? initial;

  /// Ver [FeatForm.repo].
  final ContentRepository repo;
  const RaceForm({super.key, required this.repo, this.initial});
  @override
  State<RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<RaceForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late String _size = widget.initial?.size ?? 'Mediano';
  late final _creatureType = watch(widget.initial?.creatureType ?? 'Humanoide');
  late final _tagline = watch(widget.initial?.tagline ?? '');
  late final _description = watch(widget.initial?.description ?? '');
  late final _speed = watch('${widget.initial?.speed ?? 30}');
  late final _skillCount = watch('${widget.initial?.skillChoiceCount ?? 0}');
  late final Set<String> _skillFrom = {...?widget.initial?.skillChoiceFrom};
  late final Set<String> _sizeOptions = {...?widget.initial?.sizeOptions};
  late final List<Effect> _effects = [...?widget.initial?.effects];

  int get _skillCountValue => int.tryParse(_skillCount.text.trim()) ?? 0;

  Race _race() => Race(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    creatureType: _creatureType.text.trim(),
    description: _description.text.trim(),
    tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
    size: _size,
    // Con un solo tamaño marcado no hay nada que elegir, y la creación
    // mostraría una elección de una opción: vale el tamaño de arriba.
    sizeOptions: _sizeOptions.length < 2
        ? const []
        : [
            for (final s in _raceSizes.keys)
              if (_sizeOptions.contains(s)) s,
          ],
    skillChoiceFrom: _skillFrom.toList(),
    // El emblema no se edita acá: se conserva el del original.
    iconId: widget.initial?.iconId,
    speed: int.tryParse(_speed.text.trim()) ?? 0,
    skillChoiceCount: _skillCountValue,
    effects: _effects,
  );

  void _save() => Navigator.of(context).pop(_race());

  @override
  _Explained? explain(String key) => switch (key) {
    'type' => _explained(
      'Tipo de criatura',
      _creatureType.text.trim().isEmpty
          ? 'Sin tipo'
          : _creatureType.text.trim(),
      raceCreatureTypeRule,
    ),
    'size' => switch (raceSizeRules[_size]) {
      final rule? => _explained('Tamaño', _size, rule, sizeRule),
      null => null,
    },
    'speed' => _explained(
      'Velocidad',
      '${_speed.text.trim()} pies',
      raceSpeedRule,
    ),
    'skillCount' => _explained(
      'Habilidades',
      _skillCountValue == 1 ? '1 a elegir' : '$_skillCountValue a elegir',
      raceSkillCountRule,
      skillProficiencyRule,
    ),
    'skillFrom' => _explained(
      'Habilidades',
      'Entre cuáles elige',
      raceSkillFromRule,
    ),
    'sizeOptions' => _explained(
      'Tamaño',
      'Tamaño a elegir',
      raceSizeOptionsRule,
    ),
    _ => null,
  };

  @override
  Iterable<String> get chosenKeys => [
    'type',
    'size',
    'speed',
    if (_skillCountValue > 0) 'skillCount',
    if (_skillFrom.isNotEmpty) 'skillFrom',
    if (_sizeOptions.length > 1) 'sizeOptions',
  ];

  String get _skillsSummary {
    final count = _skillCountValue;
    if (count <= 0) return 'ninguna';
    return _skillFrom.isEmpty
        ? '$count entre todas'
        : '$count entre ${_skillFrom.length}';
  }

  @override
  Widget build(BuildContext context) {
    final race = _race();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: 'Especie',
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: 'Cómo se va a ver al crear un personaje',
        preview: DenseRows(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewName(context, race.name, size: 18),
                  if (race.tagline case final tagline?)
                    Text(tagline, style: TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  _statBand(context, [
                    ('Tipo', race.creatureType),
                    (
                      'Tamaño',
                      race.sizeOptions.isEmpty ? race.size : 'a elegir',
                    ),
                    ('Velocidad', '${race.speed} pies'),
                    if (race.skillChoiceCount > 0)
                      ('Habilidades', '${race.skillChoiceCount} a elegir'),
                  ], wide: false),
                  if (race.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(race.description),
                  ],
                  const SizedBox(height: 12),
                  const Eyebrow('Rasgos'),
                  ..._traitsPreview(context, race.effects, widget.repo),
                ],
              ),
            ),
          ],
        ),
        hint:
            'Tocá el tipo, el tamaño, la velocidad o las habilidades para ver '
            'qué implican.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la especie'),
        ),
        _fieldRow(
          flex: const [3, 2, 2],
          [
            _text(
              _creatureType,
              'Tipo de criatura',
              onTap: () => focusOn('type'),
            ),
            // Tamaño es un valor cerrado: escribirlo a mano dejaba pasar un
            // "mediano" en minúscula que el resto del motor no reconoce.
            _idDropdown(
              label: 'Tamaño',
              value: _size,
              options: _raceSizes,
              onChanged: (v) => setState(() {
                _size = v;
                focus = 'size';
              }),
              onTap: () => focusOn('size'),
            ),
            _text(
              _speed,
              'Velocidad (ft)',
              number: true,
              validator: (v) => _intInRange(v, 0, 120, optional: false),
              onTap: () => focusOn('speed'),
            ),
          ],
        ),
        explainHere((f) => f == 'type' || f == 'size' || f == 'speed'),
        ..._optionalRule,
        section(
          icon: Icons.menu_book_outlined,
          title: 'Presentación',
          summary: _orNone([
            if (_tagline.text.trim().isNotEmpty) 'lema',
            if (_description.text.trim().isNotEmpty) 'descripción',
          ], 'sin cargar'),
          children: [
            _text(_tagline, 'Lema (una línea, se ve en la lista)'),
            _text(_description, 'Descripción', maxLines: 5),
          ],
        ),
        section(
          icon: Icons.school_outlined,
          title: 'Habilidades',
          summary: _skillsSummary,
          children: [
            _text(
              _skillCount,
              'Cuántas elige',
              number: true,
              validator: (v) => _intInRange(v, 0, 18, optional: false),
              onTap: () => focusOn('skillCount'),
            ),
            if (_skillCountValue > 0 || _skillFrom.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Eyebrow('Entre cuáles'),
              _idChips(
                _skillOptions,
                _skillFrom,
                redraw,
                onTap: (_) => focus = 'skillFrom',
              ),
            ],
            explainHere((f) => f == 'skillCount' || f == 'skillFrom'),
          ],
        ),
        section(
          icon: Icons.height,
          title: 'Tamaño a elegir',
          summary: _sizeOptions.length < 2
              ? 'solo $_size'
              : [
                  for (final s in _raceSizes.keys)
                    if (_sizeOptions.contains(s)) s,
                ].join(' o '),
          children: [
            _idChips(
              _raceSizes,
              _sizeOptions,
              redraw,
              onTap: (_) => focus = 'sizeOptions',
            ),
            explainHere((f) => f == 'sizeOptions'),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: 'Rasgos',
          summary: _effectsSummary(_effects),
          children: [
            EffectEditor(
              effects: _effects,
              repo: widget.repo,
              onChanged: redraw,
            ),
          ],
        ),
      ],
    );
  }
}
