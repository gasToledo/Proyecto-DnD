part of '../creation_wizard.dart';

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
