part of '../homebrew_screen.dart';

class RaceForm extends StatefulWidget {
  final Race? initial;
  const RaceForm({super.key, this.initial});
  @override
  State<RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<RaceForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _size = widget.initial?.size ?? 'Mediano';
  late final _creatureType = TextEditingController(
    text: widget.initial?.creatureType ?? 'Humanoide',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _speed = TextEditingController(
    text: '${widget.initial?.speed ?? 30}',
  );
  late final _skillCount = TextEditingController(
    text: '${widget.initial?.skillChoiceCount ?? 0}',
  );
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Raza / Especie',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la especie'),
        ),
        _text(_description, 'Descripción', maxLines: 5),
        _text(_creatureType, 'Tipo de criatura'),
        // Tamaño es un valor cerrado: escribirlo a mano dejaba pasar un
        // "mediano" en minúscula que el resto del motor no reconoce.
        _idDropdown(
          label: 'Tamaño',
          value: _size,
          options: _raceSizes,
          onChanged: (v) => setState(() => _size = v),
        ),
        _text(
          _speed,
          'Velocidad (ft)',
          number: true,
          validator: (v) => _intInRange(v, 0, 120, optional: false),
        ),
        _text(
          _skillCount,
          'Habilidades a elegir',
          number: true,
          validator: (v) => _intInRange(v, 0, 18, optional: false),
        ),
        const SizedBox(height: 12),
        const Eyebrow('Rasgos (efectos)'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      Race(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        creatureType: _creatureType.text.trim(),
        description: _description.text.trim(),
        size: _size,
        // El formulario no edita la elección de tamaño, así que se conserva la
        // que traiga el original: editar la velocidad no debería borrarla.
        sizeOptions: widget.initial?.sizeOptions ?? const [],
        // Sin `?? 30` ni `?? 0`: el formulario ya validó los dos, y taparlos
        // con un defecto guardaba una especie distinta de la escrita.
        speed: int.parse(_speed.text.trim()),
        skillChoiceCount: int.parse(_skillCount.text.trim()),
        effects: _effects,
      ),
    );
  }
}
