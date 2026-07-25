part of '../creation_wizard.dart';

/// muestra un chip inicial que representa "ninguno" (selección = null).
class _SingleSelect extends StatelessWidget {
  final Map<String, String> options; // id -> label
  final String? selected;
  final ValueChanged<String> onSelect;
  const _SingleSelect({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
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
  final dmg = '${w.damageDice} ${titleCase(w.damageType)}';
  return w.mastery == null ? dmg : '$dmg · Maestría: ${titleCase(w.mastery!)}';
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

/// Selección única de arma con búsqueda y agrupación por categoría. Incluye una
/// opción "Sin arma (puños)" que representa la ausencia de arma (selección null).
class _WeaponSelect extends StatefulWidget {
  final List<Weapon> weapons;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _WeaponSelect({
    required this.weapons,
    required this.selected,
    required this.onSelect,
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
              selected: widget.selected == null,
              onSelected: (_) => widget.onSelect(null),
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
                            (w) => ChoiceChip(
                              label: Text('${w.name} (${w.damageDice})'),
                              selected: widget.selected == w.id,
                              onSelected: (_) => widget.onSelect(w.id),
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
