part of '../creation_wizard.dart';

/// muestra un chip inicial que representa "ninguno" (selección = null).
class _SingleSelect extends StatelessWidget {
  final Map<String, String> options; // id -> label
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Procedencia por opción, cuando corresponde mostrarla (id -> fuente).
  /// Los linajes la necesitan por el mismo motivo que las especies: una subraza
  /// puede venir de otro libro y eso hay que verlo antes de elegirla.
  final Map<String, ContentSource>? sources;

  const _SingleSelect({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.sources,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: switch (sources?[e.key]) {
              final source? => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value),
                  const SizedBox(width: 8),
                  SourceBadge(source),
                ],
              ),
              null => Text(e.value),
            },
            selected: selected == e.key,
            onSelected: (_) => onSelect(e.key),
          ),
      ],
    );
  }
}

/// Etiqueta en español de la categoría de arma.
String _weaponCategoryLabel(String category) =>
    category == 'simple' ? 'Simples' : 'Marciales';

/// Subtítulo con daño y (si aplica) la propiedad de maestría del arma.
String _weaponSubtitle(Weapon w) {
  final dmg = '${w.damageDice} ${DamageType.labelFor(w.damageType)}';
  return w.mastery == null
      ? dmg
      : '$dmg · Maestría: ${weaponMasteryName(w.mastery!)}';
}

/// Encabezado de grupo (Simples / Marciales) dentro de un picker de armas.
Widget _weaponGroupHeader(BuildContext context, String label) => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 2),
  child: Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

/// Multiselección de armas con tope, búsqueda y agrupación por categoría.
/// Usada para elegir Maestrías de Armas sobre la lista ya filtrada por
/// competencia.
class _WeaponChecklist extends StatefulWidget {
  final List<Weapon> weapons;
  final List<String> selected;
  final int max;
  final VoidCallback onChanged;
  const _WeaponChecklist({
    required this.weapons,
    required this.selected,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_WeaponChecklist> createState() => _WeaponChecklistState();
}

class _WeaponChecklistState extends State<_WeaponChecklist> {
  String _query = '';
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.weapons
        .where((w) => q.isEmpty || w.name.toLowerCase().contains(q))
        .toList();
    final simple = matches.where((w) => w.category == 'simple').toList();
    final martial = matches.where((w) => w.category == 'martial').toList();
    final full = widget.selected.length >= widget.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeaponSearchField(onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 8),
        // La lista scrollea sola: sin esto el catálogo entero estiraba la
        // página y la rueda del mouse movía todo el paso.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: ListView(
              controller: _scroll,
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 12),
              children: [
                for (final group in [('simple', simple), ('martial', martial)])
                  if (group.$2.isNotEmpty) ...[
                    _weaponGroupHeader(context, _weaponCategoryLabel(group.$1)),
                    ...group.$2.map((w) {
                      final isSel = widget.selected.contains(w.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: isSel,
                        title: Text(w.name),
                        subtitle: Text(_weaponSubtitle(w)),
                        onChanged: (isSel || !full)
                            ? (v) {
                                if (v == true) {
                                  if (!widget.selected.contains(w.id)) {
                                    widget.selected.add(w.id);
                                  }
                                } else {
                                  widget.selected.remove(w.id);
                                }
                                widget.onChanged();
                                setState(() {});
                              }
                            : null,
                      );
                    }),
                  ],
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin coincidencias.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Selección de armas con búsqueda y agrupación por categoría. Admite varias
/// (un pícaro con dos dagas, por ejemplo); la opción "Sin arma (puños)" las
/// quita todas.
class _WeaponSelect extends StatefulWidget {
  final List<Weapon> weapons;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  const _WeaponSelect({
    required this.weapons,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  @override
  State<_WeaponSelect> createState() => _WeaponSelectState();
}

class _WeaponSelectState extends State<_WeaponSelect> {
  String _query = '';
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.weapons
        .where((w) => q.isEmpty || w.name.toLowerCase().contains(q))
        .toList();
    final simple = matches.where((w) => w.category == 'simple').toList();
    final martial = matches.where((w) => w.category == 'martial').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeaponSearchField(onChanged: (v) => setState(() => _query = v)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              label: const Text('Sin arma (puños)'),
              selected: widget.selected.isEmpty,
              onSelected: (_) => widget.onClear(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Igual que el checklist de maestrías: el catálogo entero estiraba el
        // paso, así que scrollea solo.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: ListView(
              controller: _scroll,
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 12),
              children: [
                for (final group in [('simple', simple), ('martial', martial)])
                  if (group.$2.isNotEmpty) ...[
                    _weaponGroupHeader(context, _weaponCategoryLabel(group.$1)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.$2
                          .map(
                            (w) => FilterChip(
                              label: Text('${w.name} (${w.damageDice})'),
                              selected: widget.selected.contains(w.id),
                              onSelected: (_) => widget.onToggle(w.id),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin coincidencias.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de búsqueda compacto compartido por los pickers de armas.
class _WeaponSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _WeaponSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 20),
        hintText: 'Buscar arma…',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _TraitList extends StatelessWidget {
  final List<Effect> effects;
  const _TraitList({required this.effects});
  @override
  Widget build(BuildContext context) {
    final traits = effects
        .whereType<PassiveTraitEffect>()
        .map((e) => e.name)
        .toList();
    if (traits.isEmpty) return const SizedBox.shrink();
    return Text(
      'Rasgos: ${traits.join(", ")}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Resuelve una elección abierta declarada por el contenido
/// ([FeatureChoiceSlot]): Estilo de Combate, Invocaciones Sobrenaturales…
///
/// Las opciones son dotes de la categoría que nombra el slot, así que salen de
/// `featsByCategory` y no de ninguna lista de ids en la aplicación. Los
/// prerrequisitos los evalúa el validador del motor, el mismo que usa el
/// selector de dotes de la subida de nivel.
class _FeatureChoiceSelect extends StatelessWidget {
  final FeatureChoiceSlot slot;
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _FeatureChoiceSelect({
    required this.slot,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final chosen = draft.featureChoices[slot.groupId] ?? const <String>[];
    final base = draft.build();
    final validator = CharacterValidator(repo);
    final options = repo
        .featsByCategory(slot.featCategory)
        .where(
          (f) =>
              chosen.contains(f.id) ||
              validator.unmetFeatPrerequisite(f, base, draft.previewSheet) ==
                  null,
        )
        .toList();

    if (options.isEmpty) {
      return Text(
        'No hay opciones disponibles todavía.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    void setChoices(List<String> ids) {
      if (ids.isEmpty) {
        draft.featureChoices.remove(slot.groupId);
      } else {
        draft.featureChoices[slot.groupId] = ids;
      }
      onChanged();
    }

    if (slot.count == 1) {
      return _SingleSelect(
        options: {for (final f in options) f.id: f.name},
        selected: chosen.isEmpty ? null : chosen.first,
        sources: {for (final f in options) f.id: f.source},
        onSelect: (id) => setChoices([id]),
      );
    }

    // ponytail: el `Set` no puede representar una opción repetible tomada dos
    // veces. Hoy no importa: se crea siempre en nivel 1 y las repetibles del
    // catálogo piden nivel 2+, así que nunca llegan acá. Si un homebrew declara
    // una repetible sin `minLevel`, replicar el contador de `level_up_widgets`.
    final selected = chosen.toSet();
    return CappedChipSelect(
      options: {for (final f in options) f.id: f.name},
      selected: selected,
      max: slot.count,
      onChanged: () => setChoices(selected.toList()),
    );
  }
}
