part of '../homebrew_screen.dart';

/// Formulario de trasfondo: arriba las tres características y la dote de
/// origen, que son lo que el trasfondo 2024 decide del personaje, y lo demás
/// plegado.
///
/// Las herramientas se eligen por nombre: se escribían separadas por coma, y
/// el catálogo guarda ids (`thieves-tools`) que nadie iba a tipear igual.
///
/// ponytail: el equipo inicial no se edita, solo se conserva del original. Va
/// en su propia sección cuando alguien arme un trasfondo que no parta de uno
/// del manual.
class BackgroundForm extends StatefulWidget {
  final Background? initial;
  final ContentRepository repo;
  const BackgroundForm({super.key, this.initial, required this.repo});
  @override
  State<BackgroundForm> createState() => _BackgroundFormState();
}

/// Categorías de dote que pueden ser la de origen de un trasfondo: las de
/// origen y, en Eberron, las marcas dracónicas.
const _originFeatCategories = {'origin', 'dragonmark'};

class _BackgroundFormState extends State<BackgroundForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _tagline = watch(widget.initial?.tagline ?? '');
  late final _description = watch(widget.initial?.description ?? '');
  late final Set<Ability> _abilities = {...?widget.initial?.abilityOptions};
  late final Set<String> _skills = {...?widget.initial?.skillProficiencies};
  late final Set<String> _tools = {...?widget.initial?.toolProficiencies};
  late String _originFeatId = widget.initial?.originFeatId ?? '';
  late final List<Effect> _effects = [...?widget.initial?.effects];

  Feat? get _originFeat => widget.repo.feat(_originFeatId);

  Background _background() => Background(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    abilityOptions: [
      for (final a in Ability.values)
        if (_abilities.contains(a)) a,
    ],
    skillProficiencies: _skills.toList(),
    toolProficiencies: _tools.toList(),
    originFeatId: _originFeatId.isEmpty ? null : _originFeatId,
    tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
    description: _description.text.trim(),
    effects: _effects,
    // El equipo inicial y el emblema no se editan acá: un trasfondo del
    // catálogo duplicado sin su equipo empezaría la partida con las manos
    // vacías.
    startingEquipment: widget.initial?.startingEquipment ?? const [],
    iconId: widget.initial?.iconId,
  );

  void _save() => Navigator.of(context).pop(_background());

  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'abilities':
        return _explained(
          'Características',
          'Las tres del aumento',
          backgroundAbilitiesRule,
        );
      case 'feat':
        final feat = _originFeat;
        return feat == null
            ? _explained(
                'Dote de origen',
                'Sin dote de origen',
                backgroundOriginFeatRule,
              )
            : _explained(
                'Dote de origen',
                feat.name,
                featSummary(feat, widget.repo),
                backgroundOriginFeatRule,
              );
      case 'skills':
        return _explained(
          'Competencias',
          _orNone([for (final s in _skills) Skill.labelFor(s)], 'Ninguna'),
          skillProficiencyRule,
        );
      case 'tools':
        return _explained(
          'Herramientas',
          _orNone([for (final t in _tools) toolProficiencyLabel(t)], 'Ninguna'),
          toolProficiencyRule,
        );
    }
    return null;
  }

  @override
  Iterable<String> get chosenKeys => [
    if (_abilities.isNotEmpty) 'abilities',
    if (_originFeat != null) 'feat',
    if (_skills.isNotEmpty) 'skills',
    if (_tools.isNotEmpty) 'tools',
  ];

  @override
  Widget build(BuildContext context) {
    final bg = _background();
    final feat = _originFeat;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: 'Trasfondo',
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
                  _previewName(context, bg.name, size: 18),
                  if (bg.tagline case final tagline?)
                    Text(tagline, style: TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  _statBand(context, [
                    (
                      'Competencias',
                      _orNone([
                        for (final s in bg.skillProficiencies)
                          Skill.labelFor(s),
                      ], '—'),
                    ),
                    if (feat != null) ('Dote de origen', feat.name),
                    (
                      'Aumento',
                      _orNone([for (final a in bg.abilityOptions) a.abbr], '—'),
                    ),
                  ], wide: false),
                  if (feat != null) ...[
                    const SizedBox(height: 12),
                    const Eyebrow('Qué te da su dote de origen'),
                    ..._traitsPreview(context, feat.effects, widget.repo),
                  ],
                ],
              ),
            ),
          ],
        ),
        hint:
            'Tocá las características o la dote de origen para ver qué le dan '
            'al personaje.',
      ),
      children: [
        _text(
          _name,
          'Nombre',
          validator: (v) => _requiredText(v, 'el nombre del trasfondo'),
        ),
        const SizedBox(height: 8),
        // Un campo del formulario y no chips sueltos: con menos de tres, la
        // creación no puede repartir el +2/+1 y el trasfondo quedaba
        // guardado sin servir.
        FormField<void>(
          validator: (_) => _abilities.length == 3
              ? null
              : 'Elegí exactamente tres características.',
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Características · elegí 3'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in Ability.values)
                    FilterChip(
                      label: Text(a.abbr),
                      selected: _abilities.contains(a),
                      // Al tope, las no elegidas se deshabilitan en vez de
                      // ignorar el toque en silencio: un chip que no responde
                      // parece roto.
                      onSelected:
                          _abilities.length >= 3 && !_abilities.contains(a)
                          ? null
                          : (v) {
                              setState(() {
                                v ? _abilities.add(a) : _abilities.remove(a);
                                focus = 'abilities';
                              });
                              field.didChange(null);
                            },
                    ),
                ],
              ),
              if (field.errorText case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _idDropdown(
          label: 'Dote de origen',
          value: _originFeatId,
          options: {
            '': '(ninguna)',
            for (final f in widget.repo.featsSorted)
              if (_originFeatCategories.contains(f.category)) f.id: f.name,
            // Una dote de otra categoría que ya traía el original se sigue
            // ofreciendo por su nombre, en vez de como «desconocida».
            if (feat != null) feat.id: feat.name,
          },
          onChanged: (v) => setState(() {
            _originFeatId = v;
            focus = 'feat';
          }),
          onTap: () => focusOn('feat'),
        ),
        explainHere((f) => f == 'abilities' || f == 'feat'),
        ..._optionalRule,
        section(
          icon: Icons.school_outlined,
          title: 'Competencias',
          summary: _orNone([
            ...[for (final s in _skills) Skill.labelFor(s)],
            ...[for (final t in _tools) toolProficiencyLabel(t)],
          ], 'ninguna'),
          children: [
            const Eyebrow('Habilidades'),
            _idChips(
              _skillOptions,
              _skills,
              redraw,
              onTap: (_) => focus = 'skills',
            ),
            const SizedBox(height: 12),
            const Eyebrow('Herramientas'),
            _idChips(
              {
                for (final id in toolProficiencyIds)
                  id: toolProficiencyLabel(id),
                // Una herramienta de un pack que el glosario no conoce se
                // sigue mostrando, marcada, para poder quitarla.
                for (final id in _tools)
                  if (!toolProficiencyIds.contains(id)) id: id,
              },
              _tools,
              redraw,
              onTap: (_) => focus = 'tools',
            ),
            explainHere((f) => f == 'skills' || f == 'tools'),
          ],
        ),
        section(
          icon: Icons.menu_book_outlined,
          title: 'Presentación',
          summary: _orNone([
            if (_tagline.text.trim().isNotEmpty) 'lema',
            if (_description.text.trim().isNotEmpty) 'descripción',
          ], 'sin cargar'),
          children: [
            _text(_tagline, 'Lema (una línea, se ve al elegirlo)'),
            _text(_description, 'Descripción', maxLines: 5),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: 'Efectos adicionales',
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
