part of '../homebrew_screen.dart';

class FeatForm extends StatefulWidget {
  final Feat? initial;
  const FeatForm({super.key, this.initial});
  @override
  State<FeatForm> createState() => _FeatFormState();
}

class _FeatFormState extends State<FeatForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _category = widget.initial?.category ?? 'general';
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Dote',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _categoryDropdown(
          ['origin', 'general', 'fighting-style', 'dragonmark', 'epic-boon'],
          _category,
          (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 12),
        const Eyebrow('Efectos'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      Feat(
        id: widget.initial?.id ?? homebrewId(_name.text),
        name: _name.text.trim(),
        source: ContentSource.homebrew,
        category: _category,
        effects: _effects,
      ),
    );
  }
}
