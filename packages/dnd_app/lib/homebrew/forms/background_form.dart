part of '../homebrew_screen.dart';

class BackgroundForm extends StatefulWidget {
  final Background? initial;
  final ContentRepository repo;
  const BackgroundForm({super.key, this.initial, required this.repo});
  @override
  State<BackgroundForm> createState() => _BackgroundFormState();
}

class _BackgroundFormState extends State<BackgroundForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _tools = TextEditingController(
    text: widget.initial?.toolProficiencies.join(', ') ?? '',
  );
  late final Set<Ability> _abilities = {...?widget.initial?.abilityOptions};
  late final Set<String> _skills2 = {...?widget.initial?.skillProficiencies};
  late String? _originFeatId = widget.initial?.originFeatId;
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    final feats = widget.repo.featsSorted;
    return _FormScaffold(
      title: 'Trasfondo',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        const SizedBox(height: 8),
        const Eyebrow('Características (elegí 3)'),
        Wrap(
          spacing: 6,
          children: Ability.values
              .map(
                (a) => FilterChip(
                  label: Text(a.abbr),
                  selected: _abilities.contains(a),
                  onSelected: (v) => setState(() {
                    if (v && _abilities.length < 3) {
                      _abilities.add(a);
                    } else {
                      _abilities.remove(a);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        const Eyebrow('Competencias de habilidad'),
        Wrap(
          spacing: 6,
          children: _skills
              .map(
                (s) => FilterChip(
                  label: Text(s),
                  selected: _skills2.contains(s),
                  onSelected: (v) =>
                      setState(() => v ? _skills2.add(s) : _skills2.remove(s)),
                ),
              )
              .toList(),
        ),
        _text(_tools, 'Herramientas (separadas por coma)'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _originFeatId,
          decoration: const InputDecoration(
            labelText: 'Dote de origen',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('(ninguna)')),
            ...feats.map(
              (f) => DropdownMenuItem(value: f.id, child: Text(f.name)),
            ),
          ],
          onChanged: (v) => setState(() => _originFeatId = v),
        ),
        const SizedBox(height: 12),
        const Eyebrow('Efectos adicionales'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    final tools = _tools.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      Background(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        abilityOptions: _abilities.toList(),
        skillProficiencies: _skills2.toList(),
        toolProficiencies: tools,
        originFeatId: _originFeatId,
        effects: _effects,
      ),
    );
  }
}
