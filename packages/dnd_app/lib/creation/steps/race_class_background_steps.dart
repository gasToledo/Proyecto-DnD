part of '../creation_wizard.dart';

class _RaceStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _RaceStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final race = draft.race;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Especie'),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: 'Elegí una especie para ver su detalle.',
          options: [
            for (final r in draft.repo.racesSorted)
              _ChoiceCard(
                icon: raceIcon(r),
                title: r.name,
                subtitle: r.tagline,
                source: r.source,
                accent: pal.gold,
                selected: draft.raceId == r.id,
                onTap: () {
                  if (draft.raceId != r.id) {
                    draft.raceId = r.id;
                    draft.lineageId = null;
                    draft.speciesSpellcastingAbility = null;
                    draft.raceSkills.clear();
                    draft.raceFeatId = null;
                  }
                  onChanged();
                },
              ),
          ],
          detail: race == null
              ? null
              : _DetailPanel(
                  title: race.name,
                  facts: [
                    ('Tamaño', race.size),
                    ('Velocidad', '${race.speed} ft'),
                    if (race.skillChoiceCount > 0)
                      ('Habilidades', '${race.skillChoiceCount} a elegir'),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TraitList(effects: race.effects),
                      if (draft.lineageOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Eyebrow('Linaje de especie'),
                        Text(
                          'Esta especie requiere elegir un linaje.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _SingleSelect(
                          options: {
                            for (final lineage in draft.lineageOptions)
                              lineage.id: lineage.name,
                          },
                          sources: {
                            for (final lineage in draft.lineageOptions)
                              lineage.id: lineage.source,
                          },
                          selected: draft.lineageId,
                          onSelect: (id) {
                            draft.lineageId = id;
                            draft.speciesSpellcastingAbility = null;
                            onChanged();
                          },
                        ),
                        if (draft.lineage case final lineage?) ...[
                          const SizedBox(height: 12),
                          Text(lineage.description),
                          if (lineage.featuresUpTo(1).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Nivel 1: '
                              '${lineage.featuresUpTo(1).map((f) => f.name).join(", ")}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                        if (draft.lineageUsesSpellcastingAbility) ...[
                          const SizedBox(height: 14),
                          _AbilityDropdown(
                            label: 'Aptitud mágica',
                            value: draft.speciesSpellcastingAbility,
                            options: const [
                              Ability.intelligence,
                              Ability.wisdom,
                              Ability.charisma,
                            ],
                            onChanged: (ability) {
                              draft.speciesSpellcastingAbility = ability;
                              onChanged();
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Se usa para la CD y los ataques de los conjuros del linaje.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Paso 2 · Clase. Lista de clases y, al lado, el panel de detalle con lo que
/// esa clase exige a nivel 1 (estilo de combate, maestrías de arma).
class _ClassStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ClassStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final klass = draft.klass;
    final styles = repo.featsSorted
        .where((f) => f.category == 'fighting-style')
        .toList();
    final slots = draft.weaponMasterySlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Clase'),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: 'Elegí una clase para ver su detalle.',
          options: [
            for (final c in repo.classesSorted)
              _ChoiceCard(
                icon: classIcon(c),
                title: c.name,
                subtitle:
                    'd${c.hitDie} · '
                    '${c.savingThrows.map((a) => a.abbr).join(" / ")}',
                source: c.source,
                accent: classAccent(c, context.palette.gold),
                selected: draft.classId == c.id,
                onTap: () {
                  draft.classId = c.id;
                  draft.classSkills.clear();
                  draft.weaponMasteries.clear();
                  draft.fightingStyleId = null;
                  draft.cantrips.clear();
                  draft.spells.clear();
                  onChanged();
                },
              ),
          ],
          detail: klass == null
              ? null
              : _DetailPanel(
                  title: klass.name,
                  facts: [
                    ('Dado de golpe', 'd${klass.hitDie}'),
                    (
                      'Salvaciones',
                      klass.savingThrows.map((a) => a.abbr).join(' · '),
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (draft.grantsFightingStyle) ...[
                        const Eyebrow('Estilo de combate'),
                        const SizedBox(height: 8),
                        _SingleSelect(
                          options: {for (final f in styles) f.id: f.name},
                          selected: draft.fightingStyleId,
                          onSelect: (id) {
                            draft.fightingStyleId = id;
                            onChanged();
                          },
                        ),
                      ],
                      if (slots > 0) ...[
                        const SizedBox(height: 18),
                        Eyebrow('Maestría de armas (elige $slots)'),
                        Text(
                          'Solo armas con las que ${klass.name} es competente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        _WeaponChecklist(
                          weapons: draft.proficientWeapons,
                          selected: draft.weaponMasteries,
                          max: slots,
                          onChanged: onChanged,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Paso 3 · Trasfondo. Incluye el aumento de característica 2024, que en estas
/// reglas viene del trasfondo (no de la especie).
class _BackgroundStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _BackgroundStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final bg = draft.background;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Trasfondo'),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: 'Elegí un trasfondo para ver su detalle.',
          options: [
            for (final b in repo.backgroundsSorted)
              _ChoiceCard(
                icon: backgroundIcon(b),
                title: b.name,
                // La línea de sabor vive en el panel de detalle, no acá: la
                // lista es para recorrer nombres y el detalle para leer.
                subtitle: null,
                source: b.source,
                accent: context.palette.gold,
                selected: draft.backgroundId == b.id,
                onTap: () {
                  draft.backgroundId = b.id;
                  draft.spreadPlusTwo = null;
                  draft.spreadPlusOne = null;
                  // El trasfondo nuevo puede conceder justo la dote de origen
                  // que ya estaba elegida para la especie. El paso de aptitudes
                  // deja de ofrecerla, pero volver atrás a cambiar el trasfondo
                  // dejaría la elección vieja en pie y duplicada.
                  final granted = b.originFeatId;
                  final chosen = draft.raceFeatId;
                  if (chosen != null &&
                      chosen == granted &&
                      !(draft.repo.feat(chosen)?.repeatable ?? false)) {
                    draft.raceFeatId = null;
                  }
                  onChanged();
                },
              ),
          ],
          detail: bg == null
              ? null
              : _DetailPanel(
                  title: bg.name,
                  facts: [
                    (
                      'Competencias',
                      bg.skillProficiencies.map(Skill.labelFor).join(', '),
                    ),
                    if (bg.originFeatId != null)
                      (
                        'Dote de origen',
                        repo.feat(bg.originFeatId!)?.name ?? bg.originFeatId!,
                      ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bg.tagline case final tagline?
                          when tagline.trim().isNotEmpty) ...[
                        Text(
                          tagline,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                      ],
                      const Eyebrow('Aumento de característica (2024)'),
                      const SizedBox(height: 8),
                      SegmentedButton<AbilitySpreadMode>(
                        segments: const [
                          ButtonSegment(
                            value: AbilitySpreadMode.twoOne,
                            label: Text('+2 / +1'),
                          ),
                          ButtonSegment(
                            value: AbilitySpreadMode.oneOneOne,
                            label: Text('+1 / +1 / +1'),
                          ),
                        ],
                        selected: {draft.spreadMode},
                        onSelectionChanged: (s) {
                          draft.spreadMode = s.first;
                          onChanged();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (draft.spreadMode == AbilitySpreadMode.twoOne)
                        _TwoOnePicker(draft: draft, onChanged: onChanged)
                      else
                        Text(
                          'Cada una de ${bg.abilityOptions.map((a) => a.abbr).join(", ")} '
                          'recibe +1.',
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TwoOnePicker extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _TwoOnePicker({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = draft.background?.abilityOptions ?? const [];
    return Row(
      children: [
        Expanded(
          child: _AbilityDropdown(
            label: '+2',
            value: draft.spreadPlusTwo,
            options: opts,
            onChanged: (a) {
              draft.spreadPlusTwo = a;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AbilityDropdown(
            label: '+1',
            value: draft.spreadPlusOne,
            options: opts.where((a) => a != draft.spreadPlusTwo).toList(),
            onChanged: (a) {
              draft.spreadPlusOne = a;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _AbilityDropdown extends StatelessWidget {
  final String label;
  final Ability? value;
  final List<Ability> options;
  final ValueChanged<Ability?> onChanged;
  const _AbilityDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Ability>(
          isExpanded: true,
          value: options.contains(value) ? value : null,
          items: options
              .map((a) => DropdownMenuItem(value: a, child: Text(a.abbr)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Paso 4 · Puntuaciones: método, valores pendientes y una tarjeta por
/// característica con el total, el aumento del trasfondo y el modificador.
