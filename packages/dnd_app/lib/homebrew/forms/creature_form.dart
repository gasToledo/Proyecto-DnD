part of '../homebrew_screen.dart';

/// Formulario de criatura homebrew: el monstruo propio del DM.
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
  const CreatureForm({super.key, this.initial});
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

  void dispose() {
    name.dispose();
    description.dispose();
  }

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

  void dispose() {
    name.dispose();
    description.dispose();
    attackBonus.dispose();
    damage.dispose();
    reach.dispose();
  }

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

class _CreatureFormState extends State<CreatureForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _ac = TextEditingController(text: widget.initial?.ac ?? '12');
  late final _hp = TextEditingController(text: widget.initial?.hp ?? '10');
  late final _hitDice = TextEditingController(
    text: widget.initial?.hitDice ?? '',
  );
  late final _speed = TextEditingController(
    text: widget.initial?.speed ?? '30 pies',
  );
  late final _senses = TextEditingController(
    text: widget.initial?.senses ?? '',
  );
  late final _languages = TextEditingController(
    text: widget.initial?.languages ?? '',
  );
  late final _defenses = TextEditingController(
    text: widget.initial?.defenses ?? '',
  );
  late final _cr = TextEditingController(text: _formatCr(widget.initial?.cr));
  late final _initiative = TextEditingController(
    text: '${widget.initial?.initiativeBonus ?? ''}',
  );
  late final _passive = TextEditingController(
    text: '${widget.initial?.passivePerception ?? ''}',
  );
  late final _legendary = TextEditingController(
    text: '${widget.initial?.legendaryActionsPerRound ?? ''}',
  );
  late final Map<Ability, TextEditingController> _abilities = {
    for (final a in Ability.values)
      a: TextEditingController(
        text: '${widget.initial?.abilityScores[a] ?? 10}',
      ),
  };

  late CreatureType _type =
      widget.initial?.creatureType ?? CreatureType.monstrosity;
  late CreatureSize _size = widget.initial?.creatureSize ?? CreatureSize.medium;
  late bool _available = widget.initial?.availableToCharacters ?? false;

  late final List<_TraitDraft> _traits = [
    for (final t in widget.initial?.traits ?? const <CreatureTrait>[])
      _TraitDraft(t),
  ];
  late final List<_ActionDraft> _actions = [
    for (final a in widget.initial?.actions ?? const <CreatureAction>[])
      _ActionDraft(a),
  ];

  @override
  void dispose() {
    for (final c in [
      _name,
      _ac,
      _hp,
      _hitDice,
      _speed,
      _senses,
      _languages,
      _defenses,
      _cr,
      _initiative,
      _passive,
      _legendary,
      ..._abilities.values,
    ]) {
      c.dispose();
    }
    for (final t in _traits) {
      t.dispose();
    }
    for (final a in _actions) {
      a.dispose();
    }
    super.dispose();
  }

  /// La línea de perfil, compuesta con la concordancia que pide el tipo:
  /// «Bestia Mediana» pero «Gigante Grande».
  String get _kind =>
      '${_type.label} ${_type.feminine ? _size.feminineLabel : _size.label}';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: 'Criatura',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la criatura'),
        ),
        Row(
          children: [
            Expanded(
              child: _enumDropdown<CreatureType>(
                label: 'Tipo',
                value: _type,
                options: CreatureType.values,
                labelOf: (t) => t.label,
                onChanged: (t) => setState(() => _type = t),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _enumDropdown<CreatureSize>(
                label: 'Tamaño',
                value: _size,
                options: CreatureSize.values,
                labelOf: (s) => s.label,
                onChanged: (s) => setState(() => _size = s),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Se va a leer «$_kind».',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _text(
                _ac,
                'CA',
                number: true,
                validator: (v) => _intInRange(v, 1, 40, optional: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _text(
                _hp,
                'PG',
                number: true,
                validator: (v) => _intInRange(v, 1, 999, optional: false),
              ),
            ),
          ],
        ),
        _text(
          _hitDice,
          'Dados de golpe (opcional, p.ej. 2d6 + 2)',
          validator: _hitDiceValue,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Con dados de golpe cargados, al sumarla a un combate se puede '
            'pedir que cada copia tire los suyos.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        _text(_speed, 'Velocidad (p.ej. 30 pies, volar 60 pies)'),

        const SizedBox(height: 8),
        const Eyebrow('Puntuaciones de característica'),
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

        const SizedBox(height: 8),
        const Eyebrow('Detalles del perfil'),
        _text(
          _cr,
          'Valor de desafío (opcional, p.ej. 1/4 o 5)',
          validator: _crValue,
        ),
        _text(
          _initiative,
          'Bono de iniciativa (opcional, vacío = modificador de DES)',
          number: true,
          validator: (v) => _intInRange(v, -10, 20, optional: true),
        ),
        _text(
          _passive,
          'Percepción pasiva (opcional)',
          number: true,
          validator: (v) => _intInRange(v, 1, 40, optional: true),
        ),
        _text(
          _legendary,
          'Acciones legendarias por ronda (opcional)',
          number: true,
          validator: (v) => _intInRange(v, 1, 10, optional: true),
        ),
        _text(_senses, 'Sentidos (p.ej. visión en la oscuridad 60 pies)'),
        _text(_languages, 'Idiomas'),
        _text(_defenses, 'Resistencias, inmunidades y vulnerabilidades'),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disponible en la construcción de personajes'),
          subtitle: Text(
            'Hoy solo lo mira el pozo de Forma Salvaje: una bestia con valor '
            'de desafío puede aparecer entre las formas del druida. Apagado, '
            'la criatura vive únicamente en tus combates.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          value: _available,
          onChanged: (v) => setState(() => _available = v),
        ),

        const SizedBox(height: 12),
        const Eyebrow('Rasgos'),
        for (final entry in _traits.asMap().entries)
          _block(
            title: 'Rasgo',
            onRemove: () =>
                setState(() => _traits.removeAt(entry.key).dispose()),
            children: [
              _text(
                entry.value.name,
                'Nombre',
                validator: (v) => _requiredText(v, 'el nombre del rasgo'),
              ),
              _text(entry.value.description, 'Descripción', maxLines: 3),
            ],
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _traits.add(_TraitDraft())),
          icon: const Icon(Icons.add),
          label: const Text('Agregar rasgo'),
        ),

        const SizedBox(height: 16),
        const Eyebrow('Acciones'),
        for (final entry in _actions.asMap().entries)
          _block(
            title: entry.value.kind.label,
            onRemove: () =>
                setState(() => _actions.removeAt(entry.key).dispose()),
            children: _actionFields(entry.value),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _actions.add(_ActionDraft())),
          icon: const Icon(Icons.add),
          label: const Text('Agregar acción'),
        ),
      ],
    );
  }

  List<Widget> _actionFields(_ActionDraft a) => [
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
      onChanged: (k) => setState(() => a.kind = k),
    ),
    Row(
      children: [
        Expanded(
          child: _text(
            a.attackBonus,
            'Bono de ataque (vacío = no es ataque)',
            number: true,
            validator: (v) => _intInRange(v, -10, 30, optional: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _text(a.reach, 'Alcance (p.ej. 5 pies)')),
      ],
    ),
    Row(
      children: [
        Expanded(child: _text(a.damage, 'Daño (p.ej. 1d8 + 3)')),
        const SizedBox(width: 12),
        Expanded(
          child: _idDropdown(
            label: 'Tipo de daño',
            value: a.damageType,
            options: {
              '': 'Sin daño',
              for (final t in DamageType.values) t.id: t.label,
            },
            onChanged: (v) => setState(() => a.damageType = v),
          ),
        ),
      ],
    ),
    _text(a.description, 'Descripción', maxLines: 3),
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  void _save() {
    Navigator.of(context).pop(
      Creature(
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
          for (final e in _abilities.entries) e.key: int.parse(e.value.text),
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
      ),
    );
  }
}

/// Desplegable sobre los valores de un enum. Hermano de [_idDropdown], que
/// existe para ids que viajan al JSON como texto; acá el valor **es** el enum.
Widget _enumDropdown<T>({
  required String label,
  required T value,
  required List<T> options,
  required String Function(T) labelOf,
  required ValueChanged<T> onChanged,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
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
