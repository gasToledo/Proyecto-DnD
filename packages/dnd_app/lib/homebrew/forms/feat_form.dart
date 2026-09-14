part of '../homebrew_screen.dart';

class FeatForm extends StatefulWidget {
  final Feat? initial;

  /// Para que el editor de efectos pueda ofrecer y nombrar contenido del
  /// catálogo (los conjuros y las dotes que la dote conceda).
  final ContentRepository repo;
  const FeatForm({super.key, required this.repo, this.initial});
  @override
  State<FeatForm> createState() => _FeatFormState();
}

class _FeatFormState extends State<FeatForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _category = widget.initial?.category ?? 'general';
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Dote',
      onSave: _save,
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre de la dote'),
        ),
        _categoryDropdown(
          _featCategories,
          _category,
          (v) => setState(() => _category = v),
        ),
        _text(_description, 'Descripción', maxLines: 5),
        const SizedBox(height: 12),
        const Eyebrow('Efectos'),
        EffectEditor(
          effects: _effects,
          repo: widget.repo,
          onChanged: () => setState(() {}),
        ),
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
        description: _description.text.trim(),
        effects: _effects,
        // Lo que el formulario no edita se conserva: una dote del catálogo
        // duplicada sin su prerrequisito sería otra dote.
        repeatable: widget.initial?.repeatable ?? false,
        exclusiveGroup: widget.initial?.exclusiveGroup,
        prerequisite: widget.initial?.prerequisite,
        spellcastingAbilityOptions:
            widget.initial?.spellcastingAbilityOptions ?? const [],
      ),
    );
  }
}
