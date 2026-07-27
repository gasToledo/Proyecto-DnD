part of '../homebrew_screen.dart';

class RaceForm extends StatefulWidget {
  final Race? initial;
  const RaceForm({super.key, this.initial});
  @override
  State<RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<RaceForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _size = TextEditingController(
    text: widget.initial?.size ?? 'Mediano',
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
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _text(_size, 'Tamaño (Pequeño/Mediano/Grande)'),
        _text(_speed, 'Velocidad (ft)', number: true),
        _text(_skillCount, 'Habilidades a elegir', number: true),
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
        size: _size.text.trim(),
        speed: int.tryParse(_speed.text.trim()) ?? 30,
        skillChoiceCount: int.tryParse(_skillCount.text.trim()) ?? 0,
        effects: _effects,
      ),
    );
  }
}
