part of '../homebrew_screen.dart';

/// Formulario de conjuro: arriba lo que se lee en la ficha antes de lanzarlo
/// —nivel, escuela, tiempo, alcance y duración— y lo demás plegado.
///
/// El tiempo de lanzamiento es una lista y no texto libre porque la ficha lo
/// reconoce por cómo empieza (`Spell.actionType`): «Accion adicional» escrito
/// a mano se leía como algo que tarda más de un turno y perdía su ícono. Uno
/// que no está en la lista (una reacción con su disparador, de un pack) se
/// conserva como opción.
class SpellForm extends StatefulWidget {
  final Spell? initial;
  const SpellForm({super.key, this.initial});
  @override
  State<SpellForm> createState() => _SpellFormState();
}

/// Clases lanzadoras a las que se puede asignar un conjuro (id → etiqueta).
const _spellClasses = {
  'wizard': 'Mago',
  'sorcerer': 'Hechicero',
  'cleric': 'Clérigo',
  'druid': 'Druida',
  'bard': 'Bardo',
  'warlock': 'Brujo',
  'paladin': 'Paladín',
  'ranger': 'Explorador',
  'artificer': 'Artífice',
};

/// Los tiempos de lanzamiento que usa el catálogo, sin las reacciones con
/// disparador (que se conservan de a una, ver [SpellForm]).
const _castingTimes = [
  'Acción',
  'Acción Adicional',
  'Reacción',
  '1 minuto',
  '10 minutos',
  '1 hora',
  '8 horas',
  '12 horas',
  '24 horas',
];

const _componentNames = {'V': 'Verbal', 'S': 'Somático', 'M': 'Material'};

class _SpellFormState extends State<SpellForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late String _level = '${widget.initial?.level ?? 0}';
  late String _school = widget.initial?.school ?? '';
  late String _castingTime = widget.initial?.castingTime ?? 'Acción';
  late final _range = watch(widget.initial?.range ?? '');
  late final _duration = watch(widget.initial?.duration ?? 'Instantánea');
  late final _description = watch(widget.initial?.description ?? '');
  late bool _concentration = widget.initial?.concentration ?? false;
  late bool _ritual = widget.initial?.ritual ?? false;
  late final Set<String> _classes = {...?widget.initial?.classes};

  // Los componentes se guardan como una línea («V, S, M (una pizca de
  // ceniza)»), que es como los trae el catálogo entero; acá se separan en las
  // tres letras y el material para elegirlos de a uno.
  late final Set<String> _components = _componentLetters(
    widget.initial?.components ?? 'V, S',
  );
  late final _material = watch(
    _componentMaterial(widget.initial?.components ?? ''),
  );

  static Set<String> _componentLetters(String text) {
    final head = text.split('(').first;
    return {for (final m in RegExp(r'\b[VSM]\b').allMatches(head)) m[0]!};
  }

  static String _componentMaterial(String text) {
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    return open < 0 || close < open ? '' : text.substring(open + 1, close);
  }

  String get _componentsText {
    final letters = [
      for (final c in _componentNames.keys)
        if (_components.contains(c)) c,
    ].join(', ');
    final material = _material.text.trim();
    return _components.contains('M') && material.isNotEmpty
        ? '$letters ($material)'
        : letters;
  }

  Spell _spell() => Spell(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    level: int.tryParse(_level) ?? 0,
    school: _school,
    castingTime: _castingTime,
    range: _range.text.trim(),
    components: _componentsText,
    duration: _duration.text.trim(),
    concentration: _concentration,
    ritual: _ritual,
    description: _description.text.trim(),
    classes: _classes.toList(),
  );

  void _save() => Navigator.of(context).pop(_spell());

  /// Claves: `level`, `school`, `time`, `comp:<letra>`, `concentration`,
  /// `ritual` y `classes`.
  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'level':
        final level = int.tryParse(_level) ?? 0;
        return level == 0
            ? _explained('Nivel', 'Truco', spellCantripRule)
            : _explained('Nivel', 'Nivel $level', spellLevelRule(level));
      case 'school':
        final rule = spellSchoolRules[_school];
        if (rule == null) return null;
        return _explained('Escuela', _school, rule, spellSchoolNote);
      case 'time':
        final type = _spell().actionType;
        return _explained('Tiempo de lanzamiento', _castingTime, switch (type) {
          SpellActionType.action => spellCastingTimeRules['Acción']!,
          SpellActionType.bonusAction =>
            spellCastingTimeRules['Acción Adicional']!,
          SpellActionType.reaction => spellCastingTimeRules['Reacción']!,
          SpellActionType.longer => spellLongCastingRule,
        });
      case 'concentration':
        return _explained('Duración', 'Concentración', spellConcentrationRule);
      case 'ritual':
        return _explained('Lanzamiento', 'Ritual', spellRitualRule);
      case 'classes':
        return _explained('Listas de clase', _classesSummary, spellClassesRule);
    }
    final letter = key.substring('comp:'.length);
    final rule = spellComponentRules[letter];
    if (rule == null) return null;
    return _explained('Componente', _componentNames[letter]!, rule);
  }

  @override
  Iterable<String> get chosenKeys => [
    'level',
    if (_school.isNotEmpty) 'school',
    'time',
    for (final c in _componentNames.keys)
      if (_components.contains(c)) 'comp:$c',
    if (_concentration) 'concentration',
    if (_ritual) 'ritual',
    if (_classes.isNotEmpty) 'classes',
  ];

  String get _classesSummary {
    final names = [
      for (final e in _spellClasses.entries)
        if (_classes.contains(e.key)) e.value,
      // Una clase de un pack que el formulario no ofrece se sigue nombrando.
      for (final id in _classes)
        if (!_spellClasses.containsKey(id)) id,
    ];
    return names.isEmpty ? 'ninguna' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final spell = _spell();
    return _FormScaffold(
      title: 'Conjuro',
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: 'Cómo se va a ver en la ficha',
        preview: DenseRows(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewName(context, spell.name, size: 18),
                  const SizedBox(height: 4),
                  spellDetailsBody(context, spell),
                ],
              ),
            ),
          ],
        ),
        hint:
            'Tocá el nivel, la escuela, el tiempo de lanzamiento o un '
            'componente para ver qué implica.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del conjuro'),
        ),
        _fieldRow(
          flex: const [2, 3],
          [
            _idDropdown(
              label: 'Nivel',
              value: _level,
              options: {
                '0': 'Truco',
                for (var n = 1; n <= 9; n++) '$n': 'Nivel $n',
              },
              onChanged: (v) => setState(() {
                _level = v;
                focus = 'level';
              }),
              onTap: () => focusOn('level'),
            ),
            _idDropdown(
              label: 'Escuela',
              value: _school,
              options: {
                '': 'Sin escuela',
                for (final s in spellSchoolRules.keys) s: s,
              },
              onChanged: (v) => setState(() {
                _school = v;
                focus = 'school';
              }),
              onTap: () => focusOn('school'),
            ),
          ],
        ),
        _fieldRow([
          _idDropdown(
            label: 'Tiempo de lanzamiento',
            value: _castingTime,
            // El tiempo que no está en la lista se ofrece con su texto y no
            // como «desconocido»: es una reacción legítima con su disparador.
            options: {
              for (final t in _castingTimes) t: t,
              if (!_castingTimes.contains(_castingTime))
                _castingTime: _castingTime,
            },
            onChanged: (v) => setState(() {
              _castingTime = v;
              focus = 'time';
            }),
            onTap: () => focusOn('time'),
          ),
          _text(_range, 'Alcance (p.ej. 60 pies)'),
        ]),
        _text(_duration, 'Duración'),
        explainHere((f) => f == 'level' || f == 'school' || f == 'time'),
        ..._optionalRule,
        section(
          icon: Icons.back_hand_outlined,
          title: 'Componentes',
          summary: _componentsText.isEmpty ? 'ninguno' : _componentsText,
          children: [
            _idChips(
              {
                for (final e in _componentNames.entries)
                  e.key: '${e.key} · ${e.value}',
              },
              _components,
              redraw,
              onTap: (c) => focus = 'comp:$c',
            ),
            if (_components.contains('M'))
              _text(_material, 'Material (p.ej. una pizca de ceniza)'),
            explainHere((f) => f.startsWith('comp:')),
          ],
        ),
        section(
          icon: Icons.hourglass_bottom,
          title: 'Concentración y ritual',
          summary: _orNone([
            if (_concentration) 'concentración',
            if (_ritual) 'ritual',
          ], 'ninguno'),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Concentración'),
              value: _concentration,
              onChanged: (v) => setState(() {
                _concentration = v;
                focus = 'concentration';
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ritual'),
              value: _ritual,
              onChanged: (v) => setState(() {
                _ritual = v;
                focus = 'ritual';
              }),
            ),
            explainHere((f) => f == 'concentration' || f == 'ritual'),
          ],
        ),
        section(
          icon: Icons.groups_outlined,
          title: 'Listas de clase',
          summary: _classesSummary,
          children: [
            _idChips(
              _spellClasses,
              _classes,
              redraw,
              onTap: (_) => focus = 'classes',
            ),
            explainHere((f) => f == 'classes'),
          ],
        ),
        section(
          icon: Icons.menu_book_outlined,
          title: 'Descripción',
          summary: _description.text.trim().isEmpty ? 'sin cargar' : 'cargada',
          children: [_text(_description, 'Qué hace el conjuro', maxLines: 8)],
        ),
      ],
    );
  }
}
