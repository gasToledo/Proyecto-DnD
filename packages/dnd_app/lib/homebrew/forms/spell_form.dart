part of '../homebrew_screen.dart';

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

class _SpellFormState extends State<SpellForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _level = TextEditingController(
    text: '${widget.initial?.level ?? 0}',
  );
  late final _school = TextEditingController(
    text: widget.initial?.school ?? '',
  );
  late final _castingTime = TextEditingController(
    text: widget.initial?.castingTime ?? 'Acción',
  );
  late final _range = TextEditingController(text: widget.initial?.range ?? '');
  late final _components = TextEditingController(
    text: widget.initial?.components ?? 'V, S',
  );
  late final _duration = TextEditingController(
    text: widget.initial?.duration ?? 'Instantánea',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late bool _concentration = widget.initial?.concentration ?? false;
  late bool _ritual = widget.initial?.ritual ?? false;
  late final Set<String> _classes = {...?widget.initial?.classes};

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Conjuro',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del conjuro'),
        ),
        _text(
          _level,
          'Nivel (0 = truco)',
          number: true,
          validator: (v) => _intInRange(v, 0, 9, optional: false),
        ),
        _text(_school, 'Escuela (p.ej. Evocación)'),
        _text(_castingTime, 'Tiempo de lanzamiento'),
        _text(_range, 'Alcance'),
        _text(_components, 'Componentes (p.ej. V, S, M)'),
        _text(_duration, 'Duración'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Concentración'),
          value: _concentration,
          onChanged: (v) => setState(() => _concentration = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ritual'),
          value: _ritual,
          onChanged: (v) => setState(() => _ritual = v),
        ),
        const SizedBox(height: 8),
        const Eyebrow('Listas de clase'),
        _idChips(_spellClasses, _classes, () => setState(() {})),
        const SizedBox(height: 12),
        const Eyebrow('Descripción'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      Spell(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        // Sin `clamp`: un 12 escrito por error se guardaba como nivel 9 sin
        // avisar. Ahora el campo lo rechaza y el conjuro no se guarda.
        level: int.parse(_level.text.trim()),
        school: _school.text.trim(),
        castingTime: _castingTime.text.trim(),
        range: _range.text.trim(),
        components: _components.text.trim(),
        duration: _duration.text.trim(),
        concentration: _concentration,
        ritual: _ritual,
        description: _description.text.trim(),
        classes: _classes.toList(),
      ),
    );
  }
}
