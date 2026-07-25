import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'creation_draft.dart';

String titleCase(String s) => s.isEmpty
    ? s
    : s
          .split(RegExp(r'[-_ ]'))
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

/// Ícono de cada paso en el stepper.
const _stepIcons = {
  CreationStep.raza: Icons.groups,
  CreationStep.clase: Icons.military_tech,
  CreationStep.trasfondo: Icons.history_edu,
  CreationStep.puntuaciones: Icons.tune,
  CreationStep.aptitudes: Icons.checklist,
  CreationStep.equipo: Icons.backpack,
  CreationStep.detalles: Icons.edit_note,
  CreationStep.resumen: Icons.verified,
};

/// Ancho a partir del cual se muestra el panel lateral de progreso.
const _kWideBreakpoint = 900.0;

/// Wizard de creación (reglas 2024). Ocho pasos fijos con stepper: se puede
/// volver a cualquier paso ya completo, pero nunca saltear uno pendiente.
class CreationWizard extends StatefulWidget {
  final ContentRepository repo;
  final void Function(Character) onCreate;
  const CreationWizard({super.key, required this.repo, required this.onCreate});

  @override
  State<CreationWizard> createState() => _CreationWizardState();
}

class _CreationWizardState extends State<CreationWizard> {
  late final CreationDraft d = CreationDraft(widget.repo);
  CreationStep _step = CreationStep.raza;
  bool _hasProgress = false;
  bool _allowPop = false;
  bool _confirmingClose = false;

  static const _steps = CreationStep.values;
  bool get _isLast => _step == _steps.last;

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _step = _steps[_step.index + 1]);
  }

  void _back() => setState(() => _step = _steps[_step.index - 1]);

  void _goTo(CreationStep s) {
    if (!d.canGoTo(s)) return;
    setState(() => _step = s);
  }

  void _finish() {
    final character = d.build();
    // PG actuales al máximo al crear.
    final sheet = CharacterCompiler(widget.repo).compile(character);
    character.combat.currentHp = sheet.maxHp;
    widget.onCreate(character);
    _closeWithoutPrompt();
  }

  /// Un cambio puede volver inalcanzable el paso actual (p.ej. cambiar de clase
  /// borra las maestrías ya elegidas): en ese caso se retrocede al primero que
  /// quedó pendiente en vez de dejar al usuario varado.
  void _refresh() => setState(() {
    _hasProgress = true;
    if (!d.canGoTo(_step)) _step = d.firstIncompleteStep;
  });

  Future<void> _requestClose() async {
    if (!_hasProgress) {
      _closeWithoutPrompt();
      return;
    }
    if (_confirmingClose) return;
    _confirmingClose = true;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Descartar este personaje?'),
            content: const Text(
              'Las elecciones realizadas en el asistente se perderán.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Seguir creando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
    _confirmingClose = false;
    if (discard && mounted) _closeWithoutPrompt();
  }

  void _closeWithoutPrompt() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = d.pendingFor(_step);
    return PopScope(
      canPop: _allowPop || !_hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= _kWideBreakpoint;
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerAndStepper(context, wide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 40 : 20,
                      14,
                      wide ? 40 : 20,
                      8,
                    ),
                    child: _buildStep(),
                  ),
                ),
                _footer(context, pending),
              ],
            );
            if (!wide) return SafeArea(child: main);
            return SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _progressPanel(context),
                  Expanded(child: main),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Shell
  // --------------------------------------------------------------------------

  Widget _progressPanel(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Fichas\n'),
                        TextSpan(
                          text: 'D&D 5e',
                          style: TextStyle(color: pal.gold),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      height: 1.1,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            decoration: BoxDecoration(
              color: pal.plaque,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow('Progreso'),
                const SizedBox(height: 8),
                ThinBar(
                  ratio: (_step.index + 1) / _steps.length,
                  color: pal.gold,
                  track: scheme.surface,
                ),
                const SizedBox(height: 9),
                Text(
                  'Paso ${_step.index + 1} de ${_steps.length}',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAndStepper(BuildContext context, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final pal = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 22, wide ? 40 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Crear personaje',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 26,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: _requestClose,
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  side: BorderSide(color: pal.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _stepper(context),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (final s in _steps) {
      final active = s == _step;
      final done = s.index < _step.index && d.pendingFor(s).isEmpty;
      final reachable = d.canGoTo(s);
      final ring = active || done ? pal.gold : pal.hairline;
      final fill = active
          ? pal.gold
          : done
          ? pal.goldSoft
          : scheme.surface;
      final fg = active
          ? scheme.onPrimary
          : done
          ? pal.gold
          : pal.textMuted;
      children.add(
        Tooltip(
          message: reachable ? s.label : 'Completá los pasos anteriores',
          child: InkWell(
            onTap: reachable ? () => _goTo(s) : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: Border.all(color: ring, width: 2),
                    ),
                    child: Icon(_stepIcons[s], size: 22, color: fg),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: .4,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? pal.gold
                          : done
                          ? scheme.onSurfaceVariant
                          : pal.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (s != _steps.last) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              color: s.index < _step.index ? pal.gold : pal.hairline,
            ),
          ),
        );
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _footer(BuildContext context, List<String> pending) {
    final pal = context.palette;
    final blocked = pending.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          if (_step != _steps.first)
            OutlinedButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Atrás'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              blocked ? 'Falta: ${pending.join('  ·  ')}' : '',
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: blocked ? null : _next,
            icon: Icon(_isLast ? Icons.check : Icons.arrow_forward, size: 20),
            label: Text(_isLast ? 'Crear personaje' : 'Siguiente'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    CreationStep.raza => _RaceStep(draft: d, onChanged: _refresh),
    CreationStep.clase => _ClassStep(draft: d, onChanged: _refresh),
    CreationStep.trasfondo => _BackgroundStep(draft: d, onChanged: _refresh),
    CreationStep.puntuaciones => _ScoresStep(draft: d, onChanged: _refresh),
    CreationStep.aptitudes => _AptitudesStep(draft: d, onChanged: _refresh),
    CreationStep.equipo => _EquipmentStep(draft: d, onChanged: _refresh),
    CreationStep.detalles => _DetailsStep(draft: d, onChanged: _refresh),
    CreationStep.resumen => _SummaryStep(draft: d, repo: widget.repo),
  };
}

// ----------------------------------------------------------------------------
// Pasos
// ----------------------------------------------------------------------------

/// Tarjeta de elección: ícono en recuadro, nombre y línea de sabor. Es el
/// patrón compartido por los pasos de Especie, Clase y Trasfondo.
class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 228,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? accent : pal.hairline,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? accent : pal.goldSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? scheme.onPrimary : accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla fluida de [_ChoiceCard].
class _ChoiceGrid extends StatelessWidget {
  final List<Widget> children;
  const _ChoiceGrid({required this.children});
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 12, runSpacing: 12, children: children);
}

/// Paso 1 · Especie. Elección + rasgos de la especie elegida. Las habilidades y
/// la dote de origen se eligen más adelante, en Aptitudes.
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
        _ChoiceGrid(
          children: [
            for (final r in draft.repo.races.values)
              _ChoiceCard(
                icon: raceIcon(r),
                title: r.name,
                subtitle: r.tagline,
                accent: pal.gold,
                selected: draft.raceId == r.id,
                onTap: () {
                  draft.raceId = r.id;
                  draft.raceSkills.clear();
                  draft.raceFeatId = null;
                  onChanged();
                },
              ),
          ],
        ),
        if (race != null) ...[
          const SizedBox(height: 18),
          _DetailPanel(
            title: race.name,
            facts: [
              ('Tamaño', race.size),
              ('Velocidad', '${race.speed} ft'),
              if (race.skillChoiceCount > 0)
                ('Habilidades', '${race.skillChoiceCount} a elegir'),
            ],
            child: _TraitList(effects: race.effects),
          ),
        ],
      ],
    );
  }
}

/// Paso 2 · Clase. Grilla de clases y, debajo, el panel de detalle con lo que
/// esa clase exige a nivel 1 (estilo de combate, maestrías de arma).
class _ClassStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ClassStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final klass = draft.klass;
    final styles = repo.feats.values
        .where((f) => f.category == 'fighting-style')
        .toList();
    final slots = draft.weaponMasterySlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Clase'),
        const SizedBox(height: 10),
        _ChoiceGrid(
          children: [
            for (final c in repo.classes.values)
              _ChoiceCard(
                icon: classIcon(c),
                title: c.name,
                subtitle:
                    'd${c.hitDie} · '
                    '${c.savingThrows.map((a) => a.abbr).join(" / ")}',
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
        ),
        if (klass != null) ...[
          const SizedBox(height: 18),
          _DetailPanel(
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
        ],
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
        _ChoiceGrid(
          children: [
            for (final b in repo.backgrounds.values)
              _ChoiceCard(
                icon: backgroundIcon(b),
                title: b.name,
                subtitle: b.tagline,
                accent: context.palette.gold,
                selected: draft.backgroundId == b.id,
                onTap: () {
                  draft.backgroundId = b.id;
                  draft.spreadPlusTwo = null;
                  draft.spreadPlusOne = null;
                  onChanged();
                },
              ),
          ],
        ),
        if (bg != null) ...[
          const SizedBox(height: 18),
          _DetailPanel(
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
class _ScoresStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ScoresStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final unassigned = _unassignedValues(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Método'),
        const SizedBox(height: 10),
        Row(
          children: [
            _MethodTab(
              icon: Icons.view_list,
              label: 'Array estándar',
              selected: draft.scoreMethod == ScoreMethod.standardArray,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.standardArray);
                onChanged();
              },
            ),
            const SizedBox(width: 10),
            _MethodTab(
              icon: Icons.casino,
              label: 'Tirar 4d6',
              selected: draft.scoreMethod == ScoreMethod.roll4d6,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PoolBar(draft: draft, unassigned: unassigned, onChanged: onChanged),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 780
                ? 3
                : box.maxWidth >= 520
                ? 2
                : 1;
            final w = (box.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final a in Ability.values)
                  SizedBox(
                    width: w,
                    child: _ScoreCard(
                      draft: draft,
                      ability: a,
                      onChanged: onChanged,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Valores del pool que todavía no fueron asignados a ninguna característica.
List<int> _unassignedValues(CreationDraft draft) {
  final remaining = List.of(draft.pool);
  for (final v in draft.assignedScores.values) {
    remaining.remove(v);
  }
  return remaining..sort((a, b) => b.compareTo(a));
}

/// Pestaña de método de puntuación.
class _MethodTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? pal.goldSoft : scheme.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? pal.gold : pal.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? pal.gold : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? pal.gold : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra con los valores que quedan sin asignar y las acciones del pool.
class _PoolBar extends StatelessWidget {
  final CreationDraft draft;
  final List<int> unassigned;
  final VoidCallback onChanged;
  const _PoolBar({
    required this.draft,
    required this.unassigned,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            'Valores sin asignar',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          if (unassigned.isEmpty)
            Text(
              'Ninguno: ya están las 6.',
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final v in unassigned) GoldPill('$v')],
            ),
          if (draft.scoreMethod == ScoreMethod.roll4d6)
            OutlinedButton.icon(
              onPressed: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
              icon: const Icon(Icons.casino, size: 18),
              label: const Text('Tirar de nuevo'),
            ),
          if (draft.assignedScores.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                draft.clearScores();
                onChanged();
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Limpiar'),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de una característica: total grande, aumento del trasfondo,
/// selector de valor y modificador resultante.
class _ScoreCard extends StatelessWidget {
  final CreationDraft draft;
  final Ability ability;
  final VoidCallback onChanged;
  const _ScoreCard({
    required this.draft,
    required this.ability,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final assigned = draft.assignedScores[ability];
    // Se ofrecen todos los valores del pool: elegir uno ya tomado por otra
    // característica las intercambia (draft.assignScore), así siempre se puede
    // reordenar aunque estén las 6 asignadas.
    final items = draft.pool.toSet().toList()..sort((a, b) => b.compareTo(a));
    final spread = draft.abilitySpread[ability] ?? 0;
    final total = draft.previewScore(ability);
    final mod = abilityModifier(total);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Tooltip(
                  message: '${ability.label}\n${ability.description}',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    ability.abbr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (spread > 0)
                Text(
                  '+$spread',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pal.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assigned == null ? '—' : '$total',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 40,
              height: 1,
              color: assigned == null ? pal.textMuted : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            assigned == null ? 'sin asignar' : 'base $assigned',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: pal.textMuted),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: assigned,
            isExpanded: true,
            isDense: true,
            // Por defecto Flutter fuerza 48 px por ítem: con 6 valores el menú
            // tapaba media pantalla. En null cada ítem se ajusta a su contenido.
            itemHeight: null,
            menuMaxHeight: 260,
            borderRadius: BorderRadius.circular(10),
            hint: Text(
              'Elegir valor',
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
            icon: Icon(Icons.expand_more, size: 18, color: pal.textMuted),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: pal.plaque,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pal.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pal.hairline),
              ),
            ),
            items: items
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text('$v', style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              draft.assignScore(ability, v);
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Text(
            assigned == null ? 'MOD —' : 'MOD ${_signedMod(mod)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: assigned == null ? pal.textMuted : pal.crimson,
            ),
          ),
        ],
      ),
    );
  }
}

String _signedMod(int v) => v >= 0 ? '+$v' : '$v';

/// Encabezado de sección con rombo dorado y contador a la derecha.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? counterIcon;
  final String? counter;
  const _SectionHeader({required this.title, this.counterIcon, this.counter});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Transform.rotate(
          angle: 0.785398,
          child: Container(width: 8, height: 8, color: pal.gold),
        ),
        const SizedBox(width: 12),
        Expanded(child: Eyebrow(title)),
        if (counter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(counterIcon ?? Icons.task_alt, size: 16, color: pal.gold),
                const SizedBox(width: 8),
                Text(
                  counter!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tarjeta compacta de habilidad: nombre y característica que la gobierna.
class _SkillCard extends StatelessWidget {
  final String skillId;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  const _SkillCard({
    required this.skillId,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final skill = Skill.fromId(skillId);
    final enabled = onTap != null;
    final on = selected || locked;
    final fg = locked
        ? pal.gold
        : selected
        ? pal.gold
        : enabled
        ? scheme.onSurface
        : pal.textMuted;

    return Material(
      color: on ? pal.goldSoft : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? pal.gold : pal.hairline),
          ),
          child: Row(
            children: [
              if (locked) ...[
                Icon(Icons.lock, size: 13, color: pal.gold),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  Skill.labelFor(skillId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: fg),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                skill?.ability.abbr ?? '',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w600,
                  color: pal.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grilla de habilidades con tope de selección.
class _SkillPicker extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final Set<String> locked;
  final int max;
  final VoidCallback onChanged;
  const _SkillPicker({
    required this.options,
    required this.selected,
    required this.locked,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final full = selected.length >= max;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / 172).floor().clamp(1, 6);
        final w = (box.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in options)
              SizedBox(
                width: w,
                child: _SkillCard(
                  skillId: id,
                  selected: selected.contains(id),
                  locked: locked.contains(id),
                  onTap: locked.contains(id) || (full && !selected.contains(id))
                      ? null
                      : () {
                          if (!selected.remove(id)) selected.add(id);
                          onChanged();
                        },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Paso 5 · Aptitudes: las competencias que se eligen (de clase y de especie) y
/// la dote de origen que concede la especie. En 2024 no hay dotes libres a
/// nivel 1: las que hay vienen del origen, así que la grilla de dotes del
/// diseño se usa para elegir **esa** dote.
class _AptitudesStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _AptitudesStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final klass = draft.klass;
    final race = draft.race;
    final bg = draft.background;
    final granted = {...?bg?.skillProficiencies};
    final grantsFeat = race?.effects.any((e) => e is GrantFeatEffect) ?? false;
    final originFeats = repo.feats.values
        .where((f) => f.category == 'origin')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (klass != null) ...[
          _SectionHeader(
            title: 'Competencias de clase',
            counterIcon: Icons.task_alt,
            counter:
                '${draft.classSkills.length} / ${klass.skillChoiceCount} elegidas',
          ),
          if (granted.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Estas ya te las da el trasfondo:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _SkillPicker(
              options: granted.toList(),
              selected: const {},
              locked: granted,
              max: 0,
              onChanged: onChanged,
            ),
          ],
          const SizedBox(height: 12),
          _SkillPicker(
            options: skillOptions(
              klass.skillChoiceFrom,
            ).where((s) => !granted.contains(s)).toList(),
            selected: draft.classSkills,
            locked: draft.raceSkills,
            max: klass.skillChoiceCount,
            onChanged: onChanged,
          ),
        ],
        if (race != null && race.skillChoiceCount > 0) ...[
          const SizedBox(height: 26),
          _SectionHeader(
            title: 'Competencias de especie',
            counterIcon: Icons.task_alt,
            counter:
                '${draft.raceSkills.length} / ${race.skillChoiceCount} elegidas',
          ),
          const SizedBox(height: 12),
          _SkillPicker(
            options: skillOptions(
              race.skillChoiceFrom,
            ).where((s) => !granted.contains(s)).toList(),
            selected: draft.raceSkills,
            locked: draft.classSkills,
            max: race.skillChoiceCount,
            onChanged: onChanged,
          ),
        ],
        if (grantsFeat) ...[
          const SizedBox(height: 26),
          _SectionHeader(
            title: 'Dote de origen',
            counterIcon: Icons.workspace_premium,
            counter: draft.raceFeatId == null ? 'sin elegir' : '1 elegida',
          ),
          const SizedBox(height: 6),
          Text(
            'En 2024 las dotes de nivel 1 vienen del origen: '
            '${race!.name} te concede una a elección.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final cols = (box.maxWidth / 340).floor().clamp(1, 3);
              final w = (box.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final f in originFeats)
                    SizedBox(
                      width: w,
                      child: _FeatCard(
                        feat: f,
                        selected: draft.raceFeatId == f.id,
                        onTap: () {
                          draft.raceFeatId = draft.raceFeatId == f.id
                              ? null
                              : f.id;
                          onChanged();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Resumen legible de una dote. `Feat` no tiene descripción propia: lo que se
/// muestra sale de sus rasgos pasivos, y si no tiene, de los nombres de sus
/// efectos.
String _featSummary(Feat feat) {
  final traits = feat.effects.whereType<PassiveTraitEffect>();
  if (traits.isNotEmpty) {
    return traits
        .map((t) => t.description.isEmpty ? t.name : t.description)
        .join(' ');
  }
  return '';
}

/// Tarjeta de dote: ícono, nombre, descripción y marca de selección.
class _FeatCard extends StatelessWidget {
  final Feat feat;
  final bool selected;
  final VoidCallback onTap;
  const _FeatCard({
    required this.feat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? pal.gold : pal.hairline,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? pal.gold : pal.goldSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  size: 22,
                  color: selected ? scheme.onPrimary : pal.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      feat.name,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (_featSummary(feat).isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        _featSummary(feat),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? pal.gold : Colors.transparent,
                  border: Border.all(color: selected ? pal.gold : pal.hairline),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta en español de la categoría de armadura.
String _armorCategoryLabel(String c) => switch (c) {
  'light' => 'Ligera',
  'medium' => 'Media',
  'heavy' => 'Pesada',
  _ => 'Escudo',
};

/// Paso 6 · Equipo (y conjuros, para las clases lanzadoras).
class _EquipmentStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _EquipmentStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = draft.repo;
    final armors = repo.armor.values.where((a) => !a.isShield).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Armadura'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final cols = (box.maxWidth / 236).floor().clamp(1, 4);
            final w = (box.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: w,
                  child: _ChoiceCard(
                    icon: Icons.no_accounts,
                    title: 'Sin armadura',
                    subtitle: 'CA 10 + DES',
                    accent: pal.gold,
                    selected: draft.equippedArmorId == null,
                    onTap: () {
                      draft.equippedArmorId = null;
                      onChanged();
                    },
                  ),
                ),
                for (final a in armors)
                  SizedBox(
                    width: w,
                    child: _ChoiceCard(
                      icon: Icons.shield_moon,
                      title: a.name,
                      subtitle:
                          'CA ${a.baseAc} · '
                          '${_armorCategoryLabel(a.category)}',
                      accent: pal.gold,
                      selected: draft.equippedArmorId == a.id,
                      onTap: () {
                        draft.equippedArmorId = a.id;
                        onChanged();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _ShieldToggle(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Arma equipada'),
        const SizedBox(height: 12),
        _WeaponSelect(
          weapons: repo.weapons.values.toList(),
          selected: draft.weaponId,
          onSelect: (id) {
            draft.weaponId = id;
            onChanged();
          },
        ),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Conjuros'),
        const SizedBox(height: 12),
        if (draft.isCaster)
          _SpellsSection(draft: draft, onChanged: onChanged)
        else
          const _NoSpellsNotice(),
      ],
    );
  }
}

/// Escudo: es una elección aparte de la armadura (suma +2 CA).
class _ShieldToggle extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ShieldToggle({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final on = draft.shieldEquipped;
    return Material(
      color: on ? pal.goldSoft : scheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () {
          draft.shieldEquipped = !on;
          onChanged();
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: on ? pal.gold : pal.hairline),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield,
                size: 20,
                color: on ? pal.gold : pal.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Escudo (+2 CA)',
                  style: TextStyle(
                    fontSize: 14,
                    color: on ? pal.gold : scheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: on,
                onChanged: (v) {
                  draft.shieldEquipped = v;
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartel para clases que no lanzan conjuros.
class _NoSpellsNotice extends StatelessWidget {
  const _NoSpellsNotice();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 30, color: pal.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu clase no lanza conjuros',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Confiás en el acero y la maña. Seguí al próximo paso.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpellsSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellsSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sc = draft.spellcasting;
    if (sc == null) return const SizedBox.shrink();
    final all = draft.repo.spellsForList(sc.spellList);
    final maxLevel = sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final cantrips = all.where((s) => s.isCantrip).toList();
    final leveled = all
        .where((s) => !s.isCantrip && s.level <= maxLevel)
        .toList();
    final prepared = sc.preparation == SpellPreparation.prepared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CD de salvación ${sc.saveDc} · Ataque de conjuro '
          '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus} (${sc.ability.abbr})',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (sc.cantripsKnown > 0) ...[
          const SizedBox(height: 18),
          _SpellGroupHeader(
            title: 'Trucos',
            count: draft.cantrips.length,
            cap: sc.cantripsKnown,
          ),
          const SizedBox(height: 10),
          _SpellChips(
            spells: cantrips,
            selected: draft.cantrips,
            max: sc.cantripsKnown,
            icon: Icons.auto_fix_high,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 20),
        _SpellGroupHeader(
          title: prepared ? 'Conjuros preparados' : 'Conjuros conocidos',
          count: draft.spells.length,
          cap: prepared ? sc.preparedCount : null,
        ),
        Text(
          'Podés preparar conjuros de hasta nivel $maxLevel.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _SpellChips(
          spells: leveled,
          selected: draft.spells,
          max: prepared ? sc.preparedCount : 999,
          icon: Icons.auto_stories,
          showLevel: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Título de un grupo de conjuros con su contador.
class _SpellGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final int? cap;
  const _SpellGroupHeader({
    required this.title,
    required this.count,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          cap == null ? '$count' : '$count / $cap',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
      ],
    );
  }
}

/// Conjuros como chips seleccionables, con tope.
class _SpellChips extends StatelessWidget {
  final List<Spell> spells;
  final Set<String> selected;
  final int max;
  final IconData icon;
  final bool showLevel;
  final VoidCallback onChanged;
  const _SpellChips({
    required this.spells,
    required this.selected,
    required this.max,
    required this.icon,
    required this.onChanged,
    this.showLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final full = selected.length >= max;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final s in spells)
          Builder(
            builder: (context) {
              final on = selected.contains(s.id);
              final enabled = on || !full;
              return Material(
                color: on ? pal.goldSoft : scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: enabled
                      ? () {
                          if (!selected.remove(s.id)) selected.add(s.id);
                          onChanged();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? pal.gold : pal.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: on
                              ? pal.gold
                              : enabled
                              ? scheme.onSurfaceVariant
                              : pal.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          showLevel ? '${s.name} (Nv ${s.level})' : s.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: on
                                ? pal.gold
                                : enabled
                                ? scheme.onSurface
                                : pal.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Paso 7 · Detalles: nombre y sabor (alineamiento y rasgo de personalidad).
class _DetailsStep extends StatefulWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _DetailsStep({required this.draft, required this.onChanged});

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _trait = TextEditingController(
    text: widget.draft.personalityTrait,
  );

  @override
  void dispose() {
    _name.dispose();
    _trait.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Emblema'),
        const SizedBox(height: 12),
        Row(
          children: [
            ClassMedallion(
              klass: d.klass,
              fallback: d.name.trim().isEmpty
                  ? '?'
                  : d.name.trim().characters.first,
              size: 72,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasta que le pongas un retrato, tu personaje usa el '
                    'emblema de ${d.klass?.name ?? "su clase"}.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Podés generar o elegir un retrato después, desde la ficha.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Nombre'),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nombre del personaje',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            d.name = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Alineamiento'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sin definir'),
              selected: d.alignment == null,
              onSelected: (_) {
                setState(() => d.alignment = null);
                widget.onChanged();
              },
            ),
            for (final a in CharacterAlignment.values)
              ChoiceChip(
                label: Text(a.label),
                selected: d.alignment == a,
                onSelected: (_) {
                  setState(() => d.alignment = a);
                  widget.onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Rasgo de personalidad'),
        const SizedBox(height: 12),
        TextField(
          controller: _trait,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText:
                'Una línea que lo defina. Ej: "Nunca deja una deuda sin pagar."',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            d.personalityTrait = v;
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

/// Pastilla de resumen: texto sobre placa, con ícono opcional.
class _SummaryPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _SummaryPill(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: pal.gold),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de bloque dentro de la tarjeta de resumen.
class _SummaryLabel extends StatelessWidget {
  final String text;
  const _SummaryLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1,
        color: context.palette.textMuted,
      ),
    ),
  );
}

/// Paso 8 · Resumen: la ficha ya compilada, antes de confirmar.
class _SummaryStep extends StatelessWidget {
  final CreationDraft draft;
  final ContentRepository repo;
  const _SummaryStep({required this.draft, required this.repo});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final character = draft.build();
    final s = CharacterCompiler(repo).compile(character);

    final race = draft.race?.name ?? '—';
    final klass = draft.klass?.name ?? '—';
    final bg = draft.background?.name ?? '—';
    final skills = [...draft.classSkills, ...draft.raceSkills];

    final equipment = <String>[
      draft.equippedArmorId == null
          ? 'Sin armadura'
          : repo.armor[draft.equippedArmorId]?.name ?? draft.equippedArmorId!,
      if (draft.shieldEquipped) 'Escudo',
      draft.weaponId == null
          ? 'Sin arma (puños)'
          : repo.weapons[draft.weaponId]?.name ?? draft.weaponId!,
    ];

    final feats = <String>[
      for (final id in character.featIds) repo.feat(id)?.name ?? id,
      if (draft.background?.originFeatId case final id?)
        repo.feat(id)?.name ?? id,
    ];

    final spells = <String>[
      for (final id in draft.cantrips) repo.spell(id)?.name ?? id,
      for (final id in draft.spells) repo.spell(id)?.name ?? id,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Revisá y confirmá'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banda de identidad.
              Container(
                color: pal.plaque,
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                child: Row(
                  children: [
                    ClassMedallion(
                      klass: draft.klass,
                      fallback: character.name.characters.first,
                      size: 82,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character.name,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 30,
                              height: 1.05,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$race · $klass · $bg · Nivel 1',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (draft.alignment != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GoldPill(draft.alignment!.label),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: pal.hairline),
              // Cuerpo.
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SummaryLabel('Puntuaciones'),
                    Row(
                      children: [
                        for (final a in Ability.values) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: pal.plaque,
                                border: Border.all(color: pal.hairline),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    a.abbr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: pal.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${s.abilityScores[a]}',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 24,
                                      height: 1,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _signedMod(s.abilityModifiers[a]!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: pal.crimson,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (a != Ability.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SummaryLabel('En combate'),
                    Row(
                      children: [
                        Expanded(
                          child: StatPlaque(
                            label: 'PG',
                            value: '${s.maxHp}',
                            valueColor: pal.crimson,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatPlaque(
                            label: 'CA',
                            value: '${s.armorClass}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatPlaque(
                            label: 'Velocidad',
                            value: '${s.speed}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatPlaque(
                            label: 'Iniciativa',
                            value: _signedMod(s.initiative),
                          ),
                        ),
                      ],
                    ),
                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SummaryLabel('Competencias'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sk in skills)
                            _SummaryPill(Skill.labelFor(sk)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _SummaryLabel('Equipo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in equipment)
                          _SummaryPill(e, icon: Icons.backpack),
                      ],
                    ),
                    if (spells.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SummaryLabel('Conjuros'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sp in spells)
                            _SummaryPill(sp, icon: Icons.auto_fix_high),
                        ],
                      ),
                    ],
                    if (feats.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SummaryLabel('Dotes'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in feats)
                            _SummaryPill(f, icon: Icons.workspace_premium),
                        ],
                      ),
                    ],
                    if (draft.personalityTrait.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SummaryLabel('Rasgo de personalidad'),
                      Text(
                        draft.personalityTrait.trim(),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Panel de detalle de una elección: título, datos duros y contenido libre.
class _DetailPanel extends StatelessWidget {
  final String title;
  final List<(String, String)> facts;
  final Widget child;
  const _DetailPanel({
    required this.title,
    required this.facts,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    // El fondo va en un Material (y no en el BoxDecoration) para que los
    // controles de adentro —CheckboxListTile del selector de maestrías— puedan
    // pintar su tinta: un DecoratedBox con color la taparía.
    return Material(
      color: pal.plaque,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: pal.hairline),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 19,
                color: scheme.onSurface,
              ),
            ),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  for (final (label, value) in facts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${label.toUpperCase()}  ',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            color: pal.textMuted,
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
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
