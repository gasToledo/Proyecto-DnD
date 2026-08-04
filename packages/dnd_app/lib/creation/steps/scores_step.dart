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
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
            _MethodTab(
              icon: Icons.casino,
              label: 'Tirar 4d6',
              selected: draft.scoreMethod == ScoreMethod.roll4d6,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
            ),
            _MethodTab(
              icon: Icons.calculate,
              label: 'Compra de puntos',
              selected: draft.scoreMethod == ScoreMethod.pointBuy,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.pointBuy);
                onChanged();
              },
            ),
            _MethodTab(
              icon: Icons.keyboard,
              label: 'Escribir a mano',
              selected: draft.scoreMethod == ScoreMethod.manual,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.manual);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (draft.scoreMethod == ScoreMethod.manual)
          const _ManualHint()
        else if (draft.scoreMethod == ScoreMethod.pointBuy)
          _PointBuyBar(draft: draft, onChanged: onChanged)
        else
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

/// Reemplaza a `_PoolBar` en compra de puntos: acá no hay valores que repartir
/// sino un presupuesto que se gasta. Muestra lo que queda y avisa cuando el
/// reparto todavía tiene puntos sin usar, que es un error fácil de cometer
/// porque el paso deja avanzar igual (seis puntuaciones válidas ya están).
class _PointBuyBar extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _PointBuyBar({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final remaining = draft.pointsRemaining;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Puntos restantes',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
              GoldPill('$remaining de $pointBuyBudget'),
              if (remaining == 0)
                Text(
                  'Presupuesto completo.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              if (draft.pointsSpent > 0)
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
          const SizedBox(height: 8),
          Text(
            'Cada característica va de $pointBuyMin a $pointBuyMax. Los últimos '
            'dos escalones cuestan el doble: 14 vale 7 puntos y 15 vale 9, no 6 '
            'y 7.',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Reemplaza al combo de valores en compra de puntos. El coste del próximo
/// escalón va a la vista porque no es lineal: sin eso, subir de 13 a 14 parece
/// costar lo mismo que de 9 a 10.
class _PointBuyStepper extends StatelessWidget {
  final CreationDraft draft;
  final Ability ability;
  final VoidCallback onChanged;
  const _PointBuyStepper({
    required this.draft,
    required this.ability,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final value = draft.assignedScores[ability] ?? pointBuyMin;
    final canRaise = draft.canRaisePointBuy(ability);
    final canLower = draft.canLowerPointBuy(ability);
    final nextCost = value < pointBuyMax
        ? pointBuyCost(value + 1)! - pointBuyCost(value)!
        : null;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canLower
                    ? () {
                        draft.stepPointBuy(ability, -1);
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Bajar ${ability.abbr}',
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: canRaise
                    ? () {
                        draft.stepPointBuy(ability, 1);
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Subir ${ability.abbr}',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextCost == null
              ? 'al máximo · gastados ${pointBuyCost(value)}'
              : 'subir cuesta $nextCost · gastados ${pointBuyCost(value)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: pal.textMuted),
        ),
      ],
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
    //
    // Una entrada por valor *distinto*, no por copia: DropdownButton exige que
    // como mucho un ítem coincida con el valor seleccionado, así que las copias
    // repetidas de una tirada 4d6 se distinguen por etiqueta (ver _valueLabel).
    final items = draft.pool.toSet().toList()..sort((a, b) => b.compareTo(a));
    final holders = draft.holdersExcept(ability);
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
          if (draft.scoreMethod == ScoreMethod.manual)
            _ManualScoreField(
              key: ValueKey('manual-${ability.name}'),
              initial: assigned,
              onSubmit: (v) {
                draft.setManualScore(ability, v);
                onChanged();
              },
            )
          else if (draft.scoreMethod == ScoreMethod.pointBuy)
            _PointBuyStepper(
              draft: draft,
              ability: ability,
              onChanged: onChanged,
            )
          else
            DropdownButtonFormField<int>(
              initialValue: assigned,
              isExpanded: true,
              // Por defecto Flutter fuerza 48 px por ítem: con 6 valores el menú
              // tapaba media pantalla. En null cada ítem se ajusta a su contenido.
              itemHeight: null,
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(10),
              hint: Text(
                'Elegir valor',
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              ),
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
              icon: Icon(Icons.expand_more, size: 18, color: pal.textMuted),
              decoration: InputDecoration(
                filled: true,
                fillColor: pal.plaque,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 12,
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
              // El botón cerrado dibuja solo el número: reutilizar el ítem del
              // menú (con su padding y su etiqueta) es lo que recortaba el texto.
              selectedItemBuilder: (context) => [
                for (final v in items)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$v', style: const TextStyle(fontSize: 14)),
                  ),
              ],
              items: [
                for (final v in items)
                  DropdownMenuItem(
                    value: v,
                    child: _ValueOption(
                      value: v,
                      holders: holders[v] ?? const [],
                      free: draft.freeCopiesOf(v, ability),
                    ),
                  ),
              ],
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

/// Reemplaza a `_PoolBar` en modo manual: ahí no hay pool que repartir.
class _ManualHint extends StatelessWidget {
  const _ManualHint();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard, size: 19, color: pal.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Escribí la puntuación base de cada característica '
              '($manualScoreMin a $manualScoreMax), sin contar el aumento del '
              'trasfondo. Si alguna queda fuera del rango habitual de '
              'generación (3 a 18) la ficha lo va a señalar como aviso, pero no '
              'te impide seguir.',
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de puntuación escrita a mano. Mantiene su propio controlador para no
/// reconstruir el texto mientras se tipea.
class _ManualScoreField extends StatefulWidget {
  final int? initial;
  final ValueChanged<int?> onSubmit;
  const _ManualScoreField({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<_ManualScoreField> createState() => _ManualScoreFieldState();
}

class _ManualScoreFieldState extends State<_ManualScoreField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Valor',
        hintStyle: TextStyle(fontSize: 13, color: pal.textMuted),
        filled: true,
        fillColor: pal.plaque,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 12,
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
      onChanged: (text) {
        final v = int.tryParse(text);
        // Un valor a medio escribir (p. ej. "0" camino a "10") no debe borrar
        // lo ya asignado ni contarse como característica completa.
        if (text.isEmpty) {
          widget.onSubmit(null);
        } else if (v != null && v >= manualScoreMin && v <= manualScoreMax) {
          widget.onSubmit(v);
        }
      },
    );
  }
}

/// Una opción del combo de valores. Distingue los ya tomados con color **y**
/// con texto ("14 · en DES"): el color solo no alcanza para daltónicos y,
/// sobre todo, no dice *dónde* quedó la otra copia de un valor repetido.
class _ValueOption extends StatelessWidget {
  final int value;
  final List<Ability> holders;
  final int free;
  const _ValueOption({
    required this.value,
    required this.holders,
    required this.free,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final taken = holders.isNotEmpty;
    final note = !taken
        ? null
        : free > 0
        ? 'en ${holders.map((a) => a.abbr).join(", ")} · '
              '${free == 1 ? "queda 1" : "quedan $free"}'
        : 'en ${holders.map((a) => a.abbr).join(", ")}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: free > 0 ? FontWeight.w600 : FontWeight.normal,
              color: free > 0 ? scheme.onSurface : pal.textMuted,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: pal.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _signedMod(int v) => v >= 0 ? '+$v' : '$v';

/// Encabezado de sección con rombo dorado y contador a la derecha.
