import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
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

  /// Los pasos son dinámicos: el de "Conjuros" solo aparece para clases
  /// lanzadoras, tras asignar características (necesita el mod. de aptitud).
  List<String> get _titles => [
        'Clase',
        'Especie',
        'Trasfondo',
        'Características',
        if (d.isCaster) 'Conjuros',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: _buildStep(),
          ),
        ),
      ),
      bottomNavigationBar: _NavBar(
        step: _step,
        total: _titles.length,
        onBack: _step == 0 ? null : _back,
        onNext: _next,
      ),
    );
  }

  Widget _buildStep() => switch (_titles[_step]) {
        'Clase' => _ClassStep(draft: d, onChanged: _refresh),
        'Especie' => _SpeciesStep(draft: d, onChanged: _refresh),
        'Trasfondo' => _BackgroundStep(draft: d, onChanged: _refresh),
        'Características' => _ScoresStep(draft: d, onChanged: _refresh),
        'Conjuros' => _SpellsStep(draft: d, onChanged: _refresh),
        'Equipo' => _EquipmentStep(draft: d, onChanged: _refresh),
        _ => _NameStep(draft: d, repo: widget.repo, onChanged: _refresh),
      };

  void _refresh() => setState(() {
        // Cambiar de clase puede agregar/quitar el paso de Conjuros: reajusta.
        if (_step >= _titles.length) _step = _titles.length - 1;
      });
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
    final masteryWeapons = draft.proficientWeapons;
    final slots = draft.weaponMasterySlots;

    return ListView(
      children: [
        Eyebrow('Clase'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: repo.classes.values
              .map((c) => ChoiceChip(
                    label: Text(c.name),
                    selected: draft.classId == c.id,
                    onSelected: (_) {
                      draft.classId = c.id;
                      draft.classSkills.clear();
                      draft.weaponMasteries.clear();
                      draft.fightingStyleId = null;
                      draft.cantrips.clear();
                      draft.spells.clear();
                      onChanged();
                    },
                  ))
              .toList(),
        ),
        if (klass != null) ...[
          if (draft.grantsFightingStyle) ...[
            const SizedBox(height: 20),
            Eyebrow('Estilo de combate'),
            _SingleSelect(
              options: {for (final f in styles) f.id: f.name},
              selected: draft.fightingStyleId,
              onSelect: (id) {
                draft.fightingStyleId = id;
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 20),
          Eyebrow('Habilidades de clase (elige ${klass.skillChoiceCount})'),
          CappedChipSelect(
            options: {
              for (final s in (klass.skillChoiceFrom.isEmpty
                  ? _allSkills
                  : klass.skillChoiceFrom))
                s: titleCase(s)
            },
            selected: draft.classSkills,
            max: klass.skillChoiceCount,
            disabled: {
              ...draft.raceSkills,
              ...?draft.background?.skillProficiencies,
            },
            onChanged: onChanged,
          ),
          if (slots > 0) ...[
            const SizedBox(height: 20),
            Eyebrow('Maestría de armas (elige $slots)'),
            Text('Solo armas con las que ${klass.name} es competente.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            _WeaponChecklist(
              weapons: masteryWeapons,
              selected: draft.weaponMasteries,
              max: slots,
              onChanged: onChanged,
            ),
          ],
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
        Eyebrow('Especie'),
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
            Eyebrow('Habilidad de especie (elige ${race.skillChoiceCount})'),
            CappedChipSelect(
              options: {
                for (final s in (race.skillChoiceFrom.isEmpty
                    ? _allSkills
                    : race.skillChoiceFrom))
                  s: titleCase(s)
              },
              selected: draft.raceSkills,
              max: race.skillChoiceCount,
              disabled: {
                ...draft.classSkills,
                ...?draft.background?.skillProficiencies,
              },
              onChanged: onChanged,
            ),
          ],
          if (grantsFeat) ...[
            const SizedBox(height: 16),
            Eyebrow('Dote de origen (especie)'),
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
        Eyebrow('Trasfondo'),
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
          Eyebrow('Aumento de característica (2024)'),
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
        Eyebrow('Método'),
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
            Text('+$spread', style: TextStyle(color: context.palette.gold)),
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
        Eyebrow('Armadura'),
        _SingleSelect(
          options: {for (final a in armors) a.id: '${a.name} (CA ${a.baseAc})'},
          selected: draft.equippedArmorId,
          noneLabel: 'Sin armadura',
          onNone: () {
            draft.equippedArmorId = null;
            onChanged();
          },
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
        Eyebrow('Arma equipada'),
        _WeaponSelect(
          weapons: weapons,
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

class _SpellsStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellsStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sc = draft.spellcasting;
    if (sc == null) {
      return const Center(child: Text('Esta clase no lanza conjuros.'));
    }
    final all = draft.repo.spellsForList(sc.spellList);
    final maxLevel = sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final cantrips = all.where((s) => s.isCantrip).toList();
    final leveled =
        all.where((s) => !s.isCantrip && s.level <= maxLevel).toList();
    final prepared = sc.preparation == SpellPreparation.prepared;

    return ListView(
      children: [
        Text(
          'CD de salvación ${sc.saveDc} · Ataque de conjuro '
          '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus} (${sc.ability.abbr})',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (sc.cantripsKnown > 0) ...[
          const SizedBox(height: 20),
          Eyebrow('Trucos (elige ${sc.cantripsKnown})'),
          CappedChipSelect(
            options: {for (final s in cantrips) s.id: s.name},
            selected: draft.cantrips,
            max: sc.cantripsKnown,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 20),
        Eyebrow(prepared
            ? 'Conjuros preparados (elige ${sc.preparedCount})'
            : 'Conjuros conocidos'),
        Text('Podés preparar conjuros de hasta nivel $maxLevel.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        CappedChipSelect(
          options: {
            for (final s in leveled) s.id: '${s.name} (Nv ${s.level})'
          },
          selected: draft.spells,
          max: prepared ? sc.preparedCount : 999,
          onChanged: onChanged,
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
        Eyebrow('Resumen'),
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

/// Selección única mediante chips. Si se pasa [noneLabel] + [onNone], se
/// muestra un chip inicial que representa "ninguno" (selección = null).
class _SingleSelect extends StatelessWidget {
  final Map<String, String> options; // id -> label
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? noneLabel;
  final VoidCallback? onNone;
  const _SingleSelect({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.noneLabel,
    this.onNone,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (noneLabel != null && onNone != null)
          ChoiceChip(
            label: Text(noneLabel!),
            selected: selected == null,
            onSelected: (_) => onNone!(),
          ),
        ...options.entries.map((e) => ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: (_) => onSelect(e.key),
            )),
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
      child: Text(label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
        for (final group in [
          ('simple', simple),
          ('martial', martial),
        ])
          if (group.$2.isNotEmpty) ...[
            _weaponGroupHeader(context, _weaponCategoryLabel(group.$1)),
            ...group.$2.map((w) {
              final isSel = widget.selected.contains(w.id);
              return CheckboxListTile(
                dense: true,
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
            child: Text('Sin coincidencias.',
                style: Theme.of(context).textTheme.bodySmall),
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
        for (final group in [
          ('simple', simple),
          ('martial', martial),
        ])
          if (group.$2.isNotEmpty) ...[
            _weaponGroupHeader(context, _weaponCategoryLabel(group.$1)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.$2
                  .map((w) => ChoiceChip(
                        label: Text('${w.name} (${w.damageDice})'),
                        selected: widget.selected == w.id,
                        onSelected: (_) => widget.onSelect(w.id),
                      ))
                  .toList(),
            ),
          ],
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Sin coincidencias.',
                style: Theme.of(context).textTheme.bodySmall),
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
