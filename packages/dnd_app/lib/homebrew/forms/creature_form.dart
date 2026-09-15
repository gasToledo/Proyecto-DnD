part of '../homebrew_screen.dart';

/// Formulario de criatura homebrew: el monstruo propio del DM.
///
/// Arriba lo que hace falta para pelear con ella —tipo, tamaño, velocidad, CA
/// y PG— y el resto plegado. Al costado va el perfil tal como lo va a mostrar
/// el Bestiario, que es el mismo `creatureProfileBody` que se lee en la mesa.
///
/// Se aparta de los otros formularios en un punto: [Creature] guarda CA, PG y
/// daño como **fórmulas** porque los compañeros invocados dependen de quien los
/// invoca ("12 + tu modificador por Inteligencia"). Un monstruo del DM no
/// depende de nadie, así que acá los campos son números y se guardan como el
/// texto del número. Quien necesite una fórmula la escribe en el JSON e
/// importa el pack: el formulario no la ofrece porque nombrar variables del
/// personaje en un monstruo de mesa no significa nada.
///
/// ponytail: sin salvaciones ni habilidades con competencia — son dos mapas de
/// 6 y 18 entradas y ningún monstruo del SRD las necesita para pelear. Se
/// suman cuando alguien las pida, y mientras tanto se conservan al editar.
class CreatureForm extends StatefulWidget {
  final Creature? initial;

  /// Para el perfil de la vista previa, que nombra los conjuros del catálogo.
  final ContentRepository repo;
  const CreatureForm({super.key, required this.repo, this.initial});
  @override
  State<CreatureForm> createState() => _CreatureFormState();
}

/// Un rasgo mientras se edita: sus controladores viven acá y no en el estado
/// del formulario porque las filas se agregan y se quitan, y un mapa por
/// índice se desincroniza en el primer borrado del medio.
class _TraitDraft {
  final TextEditingController name;
  final TextEditingController description;

  _TraitDraft([CreatureTrait? t])
    : name = TextEditingController(text: t?.name ?? ''),
      description = TextEditingController(text: t?.description ?? '');

  List<TextEditingController> get controllers => [name, description];

  CreatureTrait build() => CreatureTrait(
    name: name.text.trim(),
    description: description.text.trim(),
  );
}

class _ActionDraft {
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController attackBonus;
  final TextEditingController damage;
  final TextEditingController reach;
  String damageType;
  CreatureActionKind kind;

  _ActionDraft([CreatureAction? a])
    : name = TextEditingController(text: a?.name ?? ''),
      description = TextEditingController(text: a?.description ?? ''),
      attackBonus = TextEditingController(text: a?.attackBonus ?? ''),
      damage = TextEditingController(text: a?.damage ?? ''),
      reach = TextEditingController(text: a?.reach ?? ''),
      damageType = a?.damageType ?? '',
      kind = a?.kind ?? CreatureActionKind.action;

  List<TextEditingController> get controllers => [
    name,
    description,
    attackBonus,
    damage,
    reach,
  ];

  CreatureAction build() {
    final bonus = attackBonus.text.trim();
    final dmg = damage.text.trim();
    return CreatureAction(
      name: name.text.trim(),
      description: description.text.trim(),
      // Vacío significa «no es un ataque», no «bono cero»: es lo que distingue
      // un Mordisco de un Reparar, y `isAttack` se define por esto.
      attackBonus: bonus.isEmpty ? null : bonus,
      damage: dmg.isEmpty ? null : dmg,
      damageType: dmg.isEmpty || damageType.isEmpty ? null : damageType,
      reach: reach.text.trim(),
      kind: kind,
    );
  }
}

class _CreatureFormState extends State<CreatureForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _ac = watch(widget.initial?.ac ?? '12');
  late final _hp = watch(widget.initial?.hp ?? '10');
  late final _hitDice = watch(widget.initial?.hitDice ?? '');
  late final _speed = watch(widget.initial?.speed ?? '30 pies');
  late final _senses = watch(widget.initial?.senses ?? '');
  late final _languages = watch(widget.initial?.languages ?? '');
  late final _defenses = watch(widget.initial?.defenses ?? '');
  late final _cr = watch(_formatCr(widget.initial?.cr));
  late final _initiative = watch('${widget.initial?.initiativeBonus ?? ''}');
  late final _passive = watch('${widget.initial?.passivePerception ?? ''}');
  late final _legendary = watch(
    '${widget.initial?.legendaryActionsPerRound ?? ''}',
  );
  late final Map<Ability, TextEditingController> _abilities = {
    for (final a in Ability.values)
      a: watch('${widget.initial?.abilityScores[a] ?? 10}'),
  };

  late CreatureType _type =
      widget.initial?.creatureType ?? CreatureType.monstrosity;
  late CreatureSize _size = widget.initial?.creatureSize ?? CreatureSize.medium;
  late bool _available = widget.initial?.availableToCharacters ?? false;

  late final List<_TraitDraft> _traits = [
    for (final t in widget.initial?.traits ?? const <CreatureTrait>[])
      _listen(_TraitDraft(t)),
  ];
  late final List<_ActionDraft> _actions = [
    for (final a in widget.initial?.actions ?? const <CreatureAction>[])
      _listen(_ActionDraft(a)),
  ];

  /// Las filas repetibles no pasan por [watch]: se liberan al quitarlas, no
  /// al cerrar el formulario, y liberarlas dos veces falla.
  D _listen<D extends Object>(D draft) {
    final controllers = switch (draft) {
      final _TraitDraft t => t.controllers,
      final _ActionDraft a => a.controllers,
      _ => const <TextEditingController>[],
    };
    for (final c in controllers) {
      c.addListener(redraw);
    }
    return draft;
  }

  void _drop(List<TextEditingController> controllers) {
    for (final c in controllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    for (final t in _traits) {
      _drop(t.controllers);
    }
    for (final a in _actions) {
      _drop(a.controllers);
    }
    super.dispose();
  }

  /// La línea de perfil, compuesta con la concordancia que pide el tipo:
  /// «Bestia Mediana» pero «Gigante Grande».
  String get _kind =>
      '${_type.label} ${_type.feminine ? _size.feminineLabel : _size.label}';

  Creature _creature() => Creature(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    kind: _kind,
    type: _type,
    size: _size,
    ac: _ac.text.trim(),
    hp: _hp.text.trim(),
    hitDice: _hitDice.text.trim().isEmpty ? null : _hitDice.text.trim(),
    speed: _speed.text.trim(),
    abilityScores: {
      for (final e in _abilities.entries)
        e.key: int.tryParse(e.value.text.trim()) ?? 10,
    },
    // Se conservan tal cual porque el formulario no las edita: editar una
    // criatura importada no puede vaciarle las competencias.
    savingThrows: widget.initial?.savingThrows ?? const {},
    skills: widget.initial?.skills ?? const {},
    senses: _senses.text.trim(),
    languages: _languages.text.trim(),
    passivePerception: int.tryParse(_passive.text.trim()),
    legendaryActionsPerRound: int.tryParse(_legendary.text.trim()),
    initiativeBonus: int.tryParse(_initiative.text.trim()),
    defenses: _defenses.text.trim(),
    cr: _parseCr(_cr.text),
    availableToCharacters: _available,
    traits: [for (final t in _traits) t.build()],
    actions: [for (final a in _actions) a.build()],
  );

  void _save() => Navigator.of(context).pop(_creature());

  /// Claves: `type`, `size`, `hitDice`, `cr`, `available` y, por acción,
  /// `action:<índice>:bonus|kind|damageType`.
  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'type':
        return _explained(
          'Tipo',
          _type.label,
          creatureTypeRule,
          _type == CreatureType.beast ? creatureBeastNote : null,
        );
      case 'size':
        final rule = creatureSizeRules[_size.id];
        if (rule == null) return null;
        return _explained('Tamaño', _size.label, rule, sizeRule);
      case 'hitDice':
        return _explained(
          'Dados de golpe',
          _hitDice.text.trim().isEmpty ? 'Sin cargar' : _hitDice.text.trim(),
          'Con dados de golpe cargados, al sumarla a un combate se puede '
              'pedir que cada copia tire los suyos.',
        );
      case 'cr':
        final cr = _parseCr(_cr.text);
        return _explained(
          'Desafío',
          cr == null ? 'Sin VD' : 'VD ${_formatCr(cr)}',
          creatureCrRule,
        );
      case 'available':
        return _explained(
          'Fuera de combate',
          _available ? 'También para personajes' : 'Solo en tus combates',
          'Hoy solo lo mira el pozo de Forma Salvaje: una bestia con valor de '
              'desafío puede aparecer entre las formas del druida. Apagado, la '
              'criatura vive únicamente en tus combates.',
        );
    }
    final parts = key.split(':');
    final index = parts.length == 3 ? int.tryParse(parts[1]) : null;
    // El foco puede apuntar a una acción que ya se quitó.
    if (index == null || index >= _actions.length) return null;
    final action = _actions[index];
    return switch (parts[2]) {
      'bonus' => _explained(
        'Acción',
        'Bono de ataque',
        creatureAttackBonusRule,
      ),
      'kind' => switch (creatureActionKindRules[action.kind.id]) {
        final rule? => _explained('Cuándo se usa', action.kind.label, rule),
        null => null,
      },
      'damageType' => switch (DamageType.fromId(action.damageType)) {
        final type? => _explained(
          'Tipo de daño',
          type.label,
          type.description,
          damageTypeRule,
        ),
        null => null,
      },
      _ => null,
    };
  }

  @override
  Iterable<String> get chosenKeys => [
    'type',
    'size',
    if (_parseCr(_cr.text) != null) 'cr',
    'available',
  ];

  String get _profileSummary => _orNone([
    if (_parseCr(_cr.text) case final cr?) 'VD ${_formatCr(cr)}',
    if (_senses.text.trim().isNotEmpty) _senses.text.trim(),
  ], 'sin cargar');

  @override
  Widget build(BuildContext context) {
    final creature = _creature();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: 'Criatura',
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: 'Cómo se va a ver en el Bestiario',
        preview: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _previewName(context, creature.name, size: 20),
            Text(creature.kind, style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            ...creatureProfileBody(context, widget.repo, creature),
          ],
        ),
        hint:
            'Tocá el tipo, el tamaño o una acción para ver qué cambia en la '
            'mesa.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la criatura'),
        ),
        _fieldRow(
          flex: const [3, 3, 3],
          [
            _enumDropdown<CreatureType>(
              label: 'Tipo',
              value: _type,
              options: CreatureType.values,
              labelOf: (t) => t.label,
              onChanged: (t) => setState(() {
                _type = t;
                focus = 'type';
              }),
              onTap: () => focusOn('type'),
            ),
            _enumDropdown<CreatureSize>(
              label: 'Tamaño',
              value: _size,
              options: CreatureSize.values,
              labelOf: (s) => s.label,
              onChanged: (s) => setState(() {
                _size = s;
                focus = 'size';
              }),
              onTap: () => focusOn('size'),
            ),
            _text(_speed, 'Velocidad (p.ej. 30 pies, volar 60 pies)'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Se va a leer «$_kind».',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        _fieldRow(
          flex: const [2, 2, 5],
          [
            _text(
              _ac,
              'CA',
              number: true,
              validator: (v) => _intInRange(v, 1, 40, optional: false),
            ),
            _text(
              _hp,
              'PG',
              number: true,
              validator: (v) => _intInRange(v, 1, 999, optional: false),
            ),
            _text(
              _hitDice,
              'Dados de golpe (opcional, p.ej. 2d6 + 2)',
              validator: _hitDiceValue,
              onTap: () => focusOn('hitDice'),
            ),
          ],
        ),
        explainHere((f) => f == 'type' || f == 'size' || f == 'hitDice'),
        ..._optionalRule,
        section(
          icon: Icons.grid_view,
          title: 'Características',
          summary: [
            for (final a in Ability.values) _abilities[a]!.text.trim(),
          ].join(' · '),
          children: [
            Wrap(
              spacing: 12,
              children: [
                for (final a in Ability.values)
                  SizedBox(
                    width: 92,
                    child: _text(
                      _abilities[a]!,
                      a.abbr,
                      number: true,
                      validator: (v) => _intInRange(v, 1, 30, optional: false),
                    ),
                  ),
              ],
            ),
          ],
        ),
        section(
          icon: Icons.badge_outlined,
          title: 'Perfil',
          summary: _profileSummary,
          children: [
            _fieldRow([
              _text(
                _cr,
                'Valor de desafío (p.ej. 1/4 o 5)',
                validator: _crValue,
                onTap: () => focusOn('cr'),
              ),
              _text(
                _initiative,
                'Bono de iniciativa (vacío = DES)',
                number: true,
                validator: (v) => _intInRange(v, -10, 20, optional: true),
              ),
            ]),
            _fieldRow([
              _text(
                _passive,
                'Percepción pasiva (opcional)',
                number: true,
                validator: (v) => _intInRange(v, 1, 40, optional: true),
              ),
              _text(
                _legendary,
                'Acciones legendarias por ronda',
                number: true,
                validator: (v) => _intInRange(v, 1, 10, optional: true),
              ),
            ]),
            _text(_senses, 'Sentidos (p.ej. visión en la oscuridad 60 pies)'),
            _text(_languages, 'Idiomas'),
            _text(_defenses, 'Resistencias, inmunidades y vulnerabilidades'),
            explainHere((f) => f == 'cr'),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: 'Rasgos',
          summary: _orNone([
            for (final t in _traits)
              if (t.name.text.trim().isNotEmpty) t.name.text.trim(),
          ], 'sin rasgos'),
          children: [
            for (final entry in _traits.asMap().entries)
              _block(
                title: 'Rasgo',
                onRemove: () => setState(
                  () => _drop(_traits.removeAt(entry.key).controllers),
                ),
                children: [
                  _text(
                    entry.value.name,
                    'Nombre',
                    validator: (v) => _requiredText(v, 'el nombre del rasgo'),
                  ),
                  _text(entry.value.description, 'Descripción', maxLines: 3),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _traits.add(_listen(_TraitDraft()))),
                icon: const Icon(Icons.add),
                label: const Text('Agregar rasgo'),
              ),
            ),
          ],
        ),
        section(
          icon: Icons.bolt,
          title: 'Acciones',
          summary: switch (_actions.length) {
            0 => 'sin acciones',
            1 => '1 acción',
            final n => '$n acciones',
          },
          children: [
            for (final entry in _actions.asMap().entries)
              _block(
                title: entry.value.kind.label,
                onRemove: () => setState(
                  () => _drop(_actions.removeAt(entry.key).controllers),
                ),
                children: _actionFields(entry.key, entry.value),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _actions.add(_listen(_ActionDraft()))),
                icon: const Icon(Icons.add),
                label: const Text('Agregar acción'),
              ),
            ),
          ],
        ),
        section(
          icon: Icons.person_outline,
          title: 'Fuera de combate',
          summary: _available
              ? 'también para personajes'
              : 'solo en tus combates',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Disponible en la construcción de personajes'),
              value: _available,
              onChanged: (v) => setState(() {
                _available = v;
                focus = 'available';
              }),
            ),
            explainHere((f) => f == 'available'),
          ],
        ),
      ],
    );
  }

  List<Widget> _actionFields(int index, _ActionDraft a) => [
    _fieldRow(
      flex: const [3, 2],
      [
        _text(
          a.name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la acción'),
        ),
        _enumDropdown<CreatureActionKind>(
          label: 'Cuándo se usa',
          value: a.kind,
          options: CreatureActionKind.values,
          labelOf: (k) => k.label,
          onChanged: (k) => setState(() {
            a.kind = k;
            focus = 'action:$index:kind';
          }),
          onTap: () => focusOn('action:$index:kind'),
        ),
      ],
    ),
    _fieldRow([
      _text(
        a.attackBonus,
        'Bono de ataque (vacío = no es ataque)',
        number: true,
        validator: (v) => _intInRange(v, -10, 30, optional: true),
        onTap: () => focusOn('action:$index:bonus'),
      ),
      _text(a.reach, 'Alcance (p.ej. 5 pies)'),
    ]),
    _fieldRow([
      _text(a.damage, 'Daño (p.ej. 1d8 + 3)'),
      _idDropdown(
        label: 'Tipo de daño',
        value: a.damageType,
        options: {
          '': 'Sin daño',
          for (final t in DamageType.values) t.id: t.label,
        },
        onChanged: (v) => setState(() {
          a.damageType = v;
          focus = 'action:$index:damageType';
        }),
        onTap: () => focusOn('action:$index:damageType'),
      ),
    ]),
    _text(
      a.description,
      'Descripción (lo que pasa además del daño)',
      maxLines: 3,
    ),
    explainHere((f) => f.startsWith('action:$index:')),
  ];

  /// Marco de una fila repetible (un rasgo, una acción) con su botón de quitar.
  Widget _block({
    required String title,
    required VoidCallback onRemove,
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(title)),
              IconButton(
                tooltip: 'Quitar',
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              ),
            ],
          ),
          ...children,
        ],
      ),
    ),
  );
}

/// Desplegable sobre los valores de un enum. Hermano de [_idDropdown], que
/// existe para ids que viajan al JSON como texto; acá el valor **es** el enum.
Widget _enumDropdown<T>({
  required String label,
  required T value,
  required List<T> options,
  required String Function(T) labelOf,
  required ValueChanged<T> onChanged,
  VoidCallback? onTap,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final o in options)
        DropdownMenuItem(value: o, child: Text(labelOf(o))),
    ],
    onChanged: (v) => onChanged(v ?? value),
  ),
);

/// El valor de desafío se escribe como se lee en el libro: `1/4`, `1/2`, `5`.
/// Se guarda como número para poder compararlo sin parsear una fracción en
/// cada filtro (ver [Creature.cr]).
num? _parseCr(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(t);
  if (fraction != null) {
    final denominator = int.parse(fraction[2]!);
    return denominator == 0 ? null : int.parse(fraction[1]!) / denominator;
  }
  return num.tryParse(t);
}

String _formatCr(num? cr) => switch (cr) {
  null => '',
  0.125 => '1/8',
  0.25 => '1/4',
  0.5 => '1/2',
  final n => '${n.toInt()}',
};

String? _crValue(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final cr = _parseCr(text);
  if (cr == null) return 'Se espera un número o una fracción, como 1/4 o 5.';
  return cr < 0 ? 'No puede ser negativo.' : null;
}

/// Los dados de golpe del perfil. Se validan con el mismo parser que después
/// los tira, así lo que el formulario acepta es exactamente lo que el combate
/// puede usar.
String? _hitDiceValue(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return DiceFormula.tryParse(text) == null
      ? 'Formato inválido: se espera algo como 2d6 + 2.'
      : null;
}
