part of 'level_up_screen.dart';

class _LevelBadge extends StatelessWidget {
  final int from;
  final int to;
  const _LevelBadge({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$from', style: TextStyle(color: pal.textMuted)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 15, color: pal.gold),
          ),
          Text(
            '$to',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              color: pal.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelUpStepper extends StatelessWidget {
  final List<_LevelUpStep> steps;
  final int current;
  final bool compact;
  final bool Function(int index) canReach;
  final ValueChanged<int> onSelected;

  const _LevelUpStepper({
    required this.steps,
    required this.current,
    required this.compact,
    required this.canReach,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    if (compact) {
      final step = steps[current];
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(bottom: BorderSide(color: pal.hairline)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(step.icon, size: 18, color: pal.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Paso ${current + 1} de ${steps.length}',
                  style: TextStyle(fontSize: 11, color: pal.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: (current + 1) / steps.length,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: pal.plaque,
              color: pal.gold,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: pal.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _StepButton(
                number: i + 1,
                step: steps[i],
                active: i == current,
                done: i < current,
                enabled: canReach(i),
                onTap: () => onSelected(i),
              ),
              if (i != steps.length - 1)
                Container(width: 24, height: 1, color: pal.hairline),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final int number;
  final _LevelUpStep step;
  final bool active;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.number,
    required this.step,
    required this.active,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final fg = active
        ? Theme.of(context).colorScheme.onSurface
        : enabled
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : pal.textMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: context.motion(const Duration(milliseconds: 180)),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? pal.gold
                    : done
                    ? pal.goldSoft
                    : pal.plaque,
                border: Border.all(
                  color: active || done ? pal.gold : pal.hairline,
                ),
              ),
              child: done
                  ? Icon(Icons.check, size: 14, color: pal.gold)
                  : Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Theme.of(context).colorScheme.onPrimary
                            : fg,
                      ),
                    ),
            ),
            const SizedBox(width: 7),
            Text(step.label, style: TextStyle(fontSize: 12, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _LevelUpFooter extends StatelessWidget {
  final int current;
  final int total;
  final String? pendingMessage;
  final bool canContinue;
  final bool isReview;
  final int level;
  final VoidCallback? onBack;
  final VoidCallback onContinue;

  const _LevelUpFooter({
    required this.current,
    required this.total,
    required this.pendingMessage,
    required this.canContinue,
    required this.isReview,
    required this.level,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: pal.hairline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 17),
                label: Text(compact ? '' : 'Atrás'),
              ),
              SizedBox(width: compact ? 8 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Paso ${current + 1} de $total',
                      style: TextStyle(fontSize: 11, color: pal.textMuted),
                    ),
                    if (pendingMessage != null)
                      Text(
                        pendingMessage!,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canContinue ? onContinue : null,
                icon: Icon(
                  isReview ? Icons.check : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  isReview
                      ? compact
                            ? 'Confirmar'
                            : 'Confirmar nivel $level'
                      : 'Continuar',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelUpIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;

  const _LevelUpIntro({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: pal.gold,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 30,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            body,
            style: TextStyle(
              height: 1.55,
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelUpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? tag;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _LevelUpCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tag,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 180)),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? pal.goldSoft : scheme.surface,
          border: Border.all(
            color: selected ? pal.gold : pal.hairline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: pal.gold),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  height: 1.5,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (tag != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.plaque,
                  border: Border.all(color: pal.hairline),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag!,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: selected ? pal.gold : pal.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;
  final String before;
  final String after;

  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.note,
    required this.before,
    required this.after,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: pal.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13.5)),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(fontSize: 11.5, color: pal.textMuted),
                  ),
              ],
            ),
          ),
          // Mismo tope y elipsis que el valor nuevo. Sin esto la fila desborda:
          // el resumen de espacios de un lanzador de nivel 20 son nueve tramos
          // ("4/3/3/3/3/2/2/1/1") y este texto no tenía dónde recortarse.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              before,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Georgia',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Icon(Icons.arrow_forward, size: 15, color: pal.gold),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, maxWidth: 180),
            child: Text(
              after,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                color: pal.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalle de la dote elegida en la subida de nivel.
///
/// La grilla de dotes son 57 chips con solo el nombre, así que sin esto hay que
/// elegir a ciegas. Se muestra el texto completo, sin recortar: la decisión es
/// permanente y el motivo de este panel es justamente poder leerla entera.
class _FeatDetail extends StatelessWidget {
  final Feat feat;
  const _FeatDetail(this.feat);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final summary = featSummary(feat);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, size: 18, color: pal.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feat.name,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SourceBadge(feat.source),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (feat.repeatable) ...[
            const SizedBox(height: 8),
            Text(
              'Se puede tomar más de una vez.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Insignia de espacios de conjuro de un nivel. Resalta en oro si el nivel se
/// abrió recién en esta subida.
class _SlotBadge extends StatelessWidget {
  final int level;
  final int count;
  final bool isNew;
  const _SlotBadge({
    required this.level,
    required this.count,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isNew ? pal.goldSoft : pal.plaque,
        border: Border.all(color: isNew ? pal.gold : pal.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nv $level  ×$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isNew ? pal.gold : null,
            ),
          ),
          if (isNew) ...[
            const SizedBox(width: 5),
            Text(
              'nuevo',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                color: pal.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un grupo de elección abierta: las opciones disponibles y las ya tomadas.
///
/// Cuando el grupo está lleno y es revisable, elegir una opción nueva pide
/// primero cuál se saca; sin eso la única salida sería quedar con una de más,
/// que es justo lo que la validación marca como error.
class _FeatureChoiceGroup extends StatelessWidget {
  final FeatureChoiceSlot slot;
  final List<String> chosen;
  final List<Feat> options;
  final ValueChanged<List<String>> onChanged;

  const _FeatureChoiceGroup({
    required this.slot,
    required this.chosen,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    if (options.isEmpty) {
      return Text(
        'No hay opciones disponibles todavía.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    // Las copias de una repetible cuentan, así que `length` sigue siendo el
    // total gastado del grupo.
    final full = chosen.length >= slot.count;
    final canDrop = slot.replaceable || !full;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (full && slot.replaceable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ya están completas. Tocá una elegida para soltarla y poder '
              'cambiarla.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final feat in options)
              // Una opción repetible puede tomarse varias veces, cada vez para
              // un truco distinto: tocarla suma una copia y el "−" resta. La
              // que no lo es sigue siendo un interruptor.
              if (feat.repeatable)
                _FeatureChoiceChip(
                  feat: feat,
                  count: chosen.where((id) => id == feat.id).length,
                  enabled: !full,
                  accent: pal.gold,
                  onTap: () => onChanged([...chosen, feat.id]),
                  onRemove: chosen.contains(feat.id) && canDrop
                      ? () =>
                            onChanged(List<String>.of(chosen)..remove(feat.id))
                      : null,
                )
              else
                _FeatureChoiceChip(
                  feat: feat,
                  count: chosen.contains(feat.id) ? 1 : 0,
                  // Con el grupo lleno solo se puede soltar lo ya elegido; un
                  // grupo no revisable ni siquiera eso.
                  enabled: chosen.contains(feat.id) ? canDrop : !full,
                  accent: pal.gold,
                  onTap: () {
                    final next = List<String>.of(chosen);
                    if (!next.remove(feat.id)) next.add(feat.id);
                    onChanged(next);
                  },
                ),
          ],
        ),
        // Una repetible aparece varias veces en `chosen`; su descripción, una.
        for (final id in chosen.toSet())
          if (options.where((f) => f.id == id).firstOrNull case final feat?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _FeatDetail(feat),
            ),
      ],
    );
  }
}

/// Chip de una opción. [count] son las copias tomadas: una opción repetible
/// puede llevar más de una, y entonces muestra "×N" y un botón para restar.
class _FeatureChoiceChip extends StatelessWidget {
  final Feat feat;
  final int count;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _FeatureChoiceChip({
    required this.feat,
    required this.count,
    required this.enabled,
    required this.accent,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final selected = count > 0;
    return Opacity(
      // Restar sigue disponible aunque no se pueda sumar: si no, un grupo lleno
      // dejaría la opción repetible atrapada.
      opacity: enabled || onRemove != null ? 1 : 0.45,
      child: Material(
        color: selected ? pal.goldSoft : scheme.surface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: selected ? accent : pal.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  feat.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? accent : scheme.onSurface,
                  ),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 6),
                  Text(
                    '×$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
                if (onRemove case final remove?) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: remove,
                    borderRadius: BorderRadius.circular(9),
                    child: Tooltip(
                      message: 'Quitar una de ${feat.name}',
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.remove, size: 16, color: accent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de Pericia: chips de las habilidades elegibles, que el compilador
/// ya filtró a las competencias que tiene el personaje.
///
/// No hay noción de "bloqueada por tenerla ya": acá tenerla es el requisito. Lo
/// único que limita es el cupo, y una habilidad tomada en otro cupo ya viene
/// fuera de `slot.skills`.
/// Selector de un cupo de [SpellChoiceSlot]. Las opciones ya vienen filtradas
/// por el motor —nivel, lista, escuela, tiempo de lanzamiento y lo que otro
/// rasgo ya concede—, así que acá solo se rotulan y se ordenan.
class _SpellChoiceGroup extends StatelessWidget {
  final ContentRepository repo;
  final SpellChoiceSlot slot;
  final List<String> chosen;
  final ValueChanged<List<String>> onChanged;

  const _SpellChoiceGroup({
    required this.repo,
    required this.slot,
    required this.chosen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (slot.options.isEmpty) {
      return Text(
        'No hay conjuros disponibles para este rasgo.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    // `slot.options` ya viene ordenado por nivel y nombre desde el motor. Lo
    // elegido puede haber quedado fuera del pozo si dejó de calificar, y en ese
    // caso el motor ya lo descartó: no hace falta filtrarlo de nuevo acá.
    final selected = {...chosen};
    return CappedChipSelect(
      options: {
        for (final id in slot.options)
          if (repo.spell(id) case final s?)
            id: s.isCantrip ? '${s.name} (truco)' : '${s.name} (Nv ${s.level})',
      },
      selected: selected,
      max: slot.count,
      onChanged: () => onChanged(selected.toList()),
    );
  }
}

/// Un cupo de competencia o de Pericia. Los dos usan el mismo widget porque el
/// motor los entrega con la misma forma; lo único que cambia es qué bloquea qué.
///
/// [locked] son las competencias que el personaje ya tiene por otra vía. En un
/// cupo normal hay que bloquearlas —elegirlas gastaría el cupo en algo que ya
/// se tiene—, pero en uno de **Pericia es al revés**: tener la competencia es
/// justamente el requisito, así que ahí no se pasa nada. La misma inversión
/// está explicada en el diálogo de la ficha (`ui/sheet/general_section.dart`).
class _ProficiencyChoiceGroup extends StatelessWidget {
  final ProficiencyChoiceSlot slot;
  final List<String> chosen;
  final Set<String> locked;
  final ValueChanged<List<String>> onChanged;

  const _ProficiencyChoiceGroup({
    required this.slot,
    required this.chosen,
    required this.onChanged,
    this.locked = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (slot.options.isEmpty) {
      return Text(
        slot.expertise
            ? 'No tenés competencias sobre las que aplicar Pericia.'
            : 'No quedan competencias disponibles para este rasgo.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final selected = {...chosen};
    return CappedChipSelect(
      options: {
        for (final id in slot.options)
          id: slot.skills.contains(id)
              ? Skill.labelFor(id)
              : toolProficiencyLabel(id),
      },
      selected: selected,
      max: slot.count,
      disabled: slot.expertise ? const {} : locked,
      onChanged: () => onChanged(selected.toList()),
    );
  }
}
