import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'creation_draft.dart';

/// Habilidades 2024 (para elecciones "de cualquier lista").
const _allSkills = [
  'acrobatics', 'animal-handling', 'arcana', 'athletics', 'deception',
  'history', 'insight', 'intimidation', 'investigation', 'medicine',
  'nature', 'perception', 'performance', 'persuasion', 'religion',
  'sleight-of-hand', 'stealth', 'survival',
];

String titleCase(String s) => s.isEmpty
    ? s
    : s
        .split(RegExp(r'[-_ ]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

/// Wizard de creación de personaje marcial (reglas 2024).
class CreationWizard extends StatefulWidget {
  final ContentRepository repo;
  final void Function(Character) onCreate;
  const CreationWizard({super.key, required this.repo, required this.onCreate});

  @override
  State<CreationWizard> createState() => _CreationWizardState();
}

class _CreationWizardState extends State<CreationWizard> {
  late final CreationDraft d = CreationDraft(widget.repo);
  int _step = 0;

  static const _titles = [
    'Clase',
    'Especie',
    'Trasfondo',
    'Características',
    'Equipo',
    'Nombre',
  ];

  void _next() {
    if (_step < _titles.length - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() => setState(() => _step--);

  void _finish() {
    final character = d.build();
    // PG actuales al máximo al crear.
    final sheet = CharacterCompiler(widget.repo).compile(character);
    character.combat.currentHp = sheet.maxHp;
    widget.onCreate(character);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear personaje · ${_titles[_step]}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _titles.length),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildStep(),
      ),
      bottomNavigationBar: _NavBar(
        step: _step,
        total: _titles.length,
        onBack: _step == 0 ? null : _back,
        onNext: _next,
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _ClassStep(draft: d, onChanged: _refresh),
        1 => _SpeciesStep(draft: d, onChanged: _refresh),
        2 => _BackgroundStep(draft: d, onChanged: _refresh),
        3 => _ScoresStep(draft: d, onChanged: _refresh),
        4 => _EquipmentStep(draft: d, onChanged: _refresh),
        _ => _NameStep(draft: d, repo: widget.repo, onChanged: _refresh),
      };

  void _refresh() => setState(() {});
}

// ----------------------------------------------------------------------------
// Pasos
// ----------------------------------------------------------------------------

class _ClassStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ClassStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final klass = draft.klass;
    final styles =
        repo.feats.values.where((f) => f.category == 'fighting-style').toList();
    final masteryWeapons = repo.weapons.values.toList();
    final slots = 3; // Guerrero 2024

    return ListView(
      children: [
        _SectionLabel('Clase'),
        Wrap(
          spacing: 8,
          children: repo.classes.values
              .map((c) => ChoiceChip(
                    label: Text(c.name),
                    selected: draft.classId == c.id,
                    onSelected: (_) {
                      draft.classId = c.id;
                      onChanged();
                    },
                  ))
              .toList(),
        ),
        if (klass != null) ...[
          const SizedBox(height: 20),
          _SectionLabel('Estilo de combate'),
          _SingleSelect(
            options: {for (final f in styles) f.id: f.name},
            selected: draft.fightingStyleId,
            onSelect: (id) {
              draft.fightingStyleId = id;
              onChanged();
            },
          ),
          const SizedBox(height: 20),
          _SectionLabel('Habilidades de clase (elige 2)'),
          _MultiSelect(
            options: {for (final s in klass.skillChoiceFrom) s: titleCase(s)},
            selected: draft.classSkills,
            max: klass.skillChoiceCount,
            onChanged: onChanged,
          ),
          const SizedBox(height: 20),
          _SectionLabel('Maestría de armas (elige $slots)'),
          _MultiSelectList(
            options: {for (final w in masteryWeapons) w.id: w.name},
            selected: draft.weaponMasteries,
            max: slots,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _SpeciesStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpeciesStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final race = draft.race;
    final grantsFeat = race?.effects.any((e) => e is GrantFeatEffect) ?? false;
    final originFeats =
        repo.feats.values.where((f) => f.category == 'origin').toList();

    return ListView(
      children: [
        _SectionLabel('Especie'),
        _SingleSelect(
          options: {for (final r in repo.races.values) r.id: r.name},
          selected: draft.raceId,
          onSelect: (id) {
            draft.raceId = id;
            draft.raceSkills.clear();
            draft.raceFeatId = null;
            onChanged();
          },
        ),
        if (race != null) ...[
          const SizedBox(height: 12),
          _TraitList(effects: race.effects),
          if (race.skillChoiceCount > 0) ...[
            const SizedBox(height: 16),
            _SectionLabel('Habilidad de especie (elige ${race.skillChoiceCount})'),
            _MultiSelect(
              options: {
                for (final s in (race.skillChoiceFrom.isEmpty
                    ? _allSkills
                    : race.skillChoiceFrom))
                  s: titleCase(s)
              },
              selected: draft.raceSkills,
              max: race.skillChoiceCount,
              onChanged: onChanged,
            ),
          ],
          if (grantsFeat) ...[
            const SizedBox(height: 16),
            _SectionLabel('Dote de origen (especie)'),
            _SingleSelect(
              options: {for (final f in originFeats) f.id: f.name},
              selected: draft.raceFeatId,
              onSelect: (id) {
                draft.raceFeatId = id;
                onChanged();
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _BackgroundStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _BackgroundStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final bg = draft.background;

    return ListView(
      children: [
        _SectionLabel('Trasfondo'),
        _SingleSelect(
          options: {for (final b in repo.backgrounds.values) b.id: b.name},
          selected: draft.backgroundId,
          onSelect: (id) {
            draft.backgroundId = id;
            draft.spreadPlusTwo = null;
            draft.spreadPlusOne = null;
            onChanged();
          },
        ),
        if (bg != null) ...[
          const SizedBox(height: 12),
          Text('Competencias: ${bg.skillProficiencies.map(titleCase).join(", ")}'),
          if (bg.originFeatId != null)
            Text('Dote de origen: '
                '${repo.feat(bg.originFeatId!)?.name ?? bg.originFeatId!}'),
          const SizedBox(height: 20),
          _SectionLabel('Aumento de característica (2024)'),
          SegmentedButton<AbilitySpreadMode>(
            segments: const [
              ButtonSegment(value: AbilitySpreadMode.twoOne, label: Text('+2 / +1')),
              ButtonSegment(
                  value: AbilitySpreadMode.oneOneOne, label: Text('+1 / +1 / +1')),
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
            Text('Cada una de ${bg.abilityOptions.map((a) => a.abbr).join(", ")} '
                'recibe +1.'),
        ],
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
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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

class _ScoresStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ScoresStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionLabel('Método'),
        SegmentedButton<ScoreMethod>(
          segments: const [
            ButtonSegment(
                value: ScoreMethod.standardArray, label: Text('Array estándar')),
            ButtonSegment(value: ScoreMethod.roll4d6, label: Text('Tirar 4d6')),
          ],
          selected: {draft.scoreMethod},
          onSelectionChanged: (s) {
            draft.applyScoreMethod(s.first);
            onChanged();
          },
        ),
        if (draft.scoreMethod == ScoreMethod.roll4d6)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
              icon: const Icon(Icons.casino),
              label: const Text('Volver a tirar'),
            ),
          ),
        const SizedBox(height: 8),
        Text('Pool: ${draft.pool.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ...Ability.values.map((a) => _ScoreRow(draft: draft, ability: a, onChanged: onChanged)),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final CreationDraft draft;
  final Ability ability;
  final VoidCallback onChanged;
  const _ScoreRow(
      {required this.draft, required this.ability, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final available = draft.availableFor(ability);
    final assigned = draft.assignedScores[ability];
    final items = <int>{?assigned, ...available}.toList()
      ..sort((a, b) => b.compareTo(a));
    final spread = draft.abilitySpread[ability] ?? 0;
    final finalScore = (assigned ?? 0) + spread;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(ability.abbr,
              style: Theme.of(context).textTheme.titleMedium)),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: const Text('—'),
              value: assigned,
              items: items
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                draft.assignedScores[ability] = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 12),
          if (spread > 0)
            Text('+$spread', style: const TextStyle(color: Colors.greenAccent)),
          SizedBox(
            width: 56,
            child: Text(assigned == null ? '' : '= $finalScore',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _EquipmentStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _EquipmentStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final armors = repo.armor.values.where((a) => !a.isShield).toList();
    final weapons = repo.weapons.values.toList();

    return ListView(
      children: [
        _SectionLabel('Armadura'),
        _SingleSelect(
          options: {for (final a in armors) a.id: '${a.name} (CA ${a.baseAc})'},
          selected: draft.equippedArmorId,
          onSelect: (id) {
            draft.equippedArmorId = id;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Escudo (+2 CA)'),
          value: draft.shieldEquipped,
          onChanged: (v) {
            draft.shieldEquipped = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _SectionLabel('Arma equipada'),
        _SingleSelect(
          options: {for (final w in weapons) w.id: '${w.name} (${w.damageDice})'},
          selected: draft.weaponId,
          onSelect: (id) {
            draft.weaponId = id;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _NameStep extends StatefulWidget {
  final CreationDraft draft;
  final ContentRepository repo;
  final VoidCallback onChanged;
  const _NameStep(
      {required this.draft, required this.repo, required this.onChanged});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final _controller = TextEditingController(text: widget.draft.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    // Previsualización con lo elegido hasta ahora.
    final preview = CharacterCompiler(widget.repo).compile(d.build());
    final race = d.race?.name ?? '—';
    final klass = d.klass?.name ?? '—';

    return ListView(
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del personaje',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            d.name = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 20),
        _SectionLabel('Resumen'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$race $klass · Nivel 1',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  Text('PG ${preview.maxHp}'),
                  Text('CA ${preview.armorClass}'),
                  Text('Vel ${preview.speed} ft'),
                  Text('Perc. Pas ${preview.passivePerception}'),
                ]),
                const SizedBox(height: 8),
                Text(Ability.values
                    .map((a) => '${a.abbr} ${preview.abilityScores[a]}')
                    .join('   ')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Widgets reutilizables
// ----------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Selección única mediante chips.
class _SingleSelect extends StatelessWidget {
  final Map<String, String> options; // id -> label
  final String? selected;
  final ValueChanged<String> onSelect;
  const _SingleSelect(
      {required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries
          .map((e) => ChoiceChip(
                label: Text(e.value),
                selected: selected == e.key,
                onSelected: (_) => onSelect(e.key),
              ))
          .toList(),
    );
  }
}

/// Multiselección con tope, mediante chips.
class _MultiSelect extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> selected;
  final int max;
  final VoidCallback onChanged;
  const _MultiSelect({
    required this.options,
    required this.selected,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isSel = selected.contains(e.key);
        return FilterChip(
          label: Text(e.value),
          selected: isSel,
          onSelected: (v) {
            if (v) {
              if (selected.length >= max) return;
              selected.add(e.key);
            } else {
              selected.remove(e.key);
            }
            onChanged();
          },
        );
      }).toList(),
    );
  }
}

/// Multiselección con tope, mediante lista (para listas largas como armas).
class _MultiSelectList extends StatelessWidget {
  final Map<String, String> options;
  final List<String> selected;
  final int max;
  final VoidCallback onChanged;
  const _MultiSelectList({
    required this.options,
    required this.selected,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.entries.map((e) {
        final isSel = selected.contains(e.key);
        return CheckboxListTile(
          dense: true,
          title: Text(e.value),
          value: isSel,
          onChanged: (v) {
            if (v == true) {
              if (selected.length >= max) return;
              selected.add(e.key);
            } else {
              selected.remove(e.key);
            }
            onChanged();
          },
        );
      }).toList(),
    );
  }
}

class _TraitList extends StatelessWidget {
  final List<Effect> effects;
  const _TraitList({required this.effects});
  @override
  Widget build(BuildContext context) {
    final traits =
        effects.whereType<PassiveTraitEffect>().map((e) => e.name).toList();
    if (traits.isEmpty) return const SizedBox.shrink();
    return Text('Rasgos: ${traits.join(", ")}',
        style: Theme.of(context).textTheme.bodySmall);
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  const _NavBar({
    required this.step,
    required this.total,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == total - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (onBack != null)
              OutlinedButton(onPressed: onBack, child: const Text('Atrás')),
            const Spacer(),
            FilledButton.icon(
              onPressed: onNext,
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Crear personaje' : 'Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}
