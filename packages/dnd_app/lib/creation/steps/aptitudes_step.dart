part of '../creation_wizard.dart';

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

/// Competencias que concede una dote (Habilidoso, Mente Aguda). A diferencia de
/// las de clase y especie, estas mezclan habilidades y herramientas y la lista
/// sale de la ficha compilada, no de un campo del contenido.
class _ProficiencyChoicePicker extends StatelessWidget {
  final ProficiencyChoiceSlot slot;
  final List<String> chosen;
  final Set<String> already;
  final int max;
  final VoidCallback onChanged;
  const _ProficiencyChoicePicker({
    required this.slot,
    required this.chosen,
    required this.already,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final full = chosen.length >= max;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / 172).floor().clamp(1, 6);
        final w = (box.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in slot.options)
              SizedBox(
                width: w,
                child: _ProficiencyCard(
                  id: id,
                  isSkill: slot.skills.contains(id),
                  selected: chosen.contains(id),
                  // Tenerla ya por otra vía no la vuelve inválida, pero gastar
                  // la dote en ella no suma nada: se muestra bloqueada.
                  locked: already.contains(id) && !chosen.contains(id),
                  onTap:
                      (already.contains(id) && !chosen.contains(id)) ||
                          (full && !chosen.contains(id))
                      ? null
                      : () {
                          if (!chosen.remove(id)) chosen.add(id);
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

/// Tarjeta de una competencia elegible por dote. Distingue habilidad de
/// herramienta porque la misma lista mezcla las dos.
class _ProficiencyCard extends StatelessWidget {
  final String id;
  final bool isSkill;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  const _ProficiencyCard({
    required this.id,
    required this.isSkill,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = isSkill ? Skill.labelFor(id) : toolProficiencyLabel(id);
    return Opacity(
      opacity: locked ? .45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.goldSoft : p.plaque,
            border: Border.all(color: selected ? p.gold : p.hairline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSkill ? Icons.psychology_alt : Icons.handyman,
                size: 15,
                color: selected ? p.gold : p.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? p.gold : p.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final klass = draft.klass;
    final race = draft.race;
    final bg = draft.background;
    final granted = {...?bg?.skillProficiencies};
    final grantsFeat = race?.effects.any((e) => e is GrantFeatEffect) ?? false;
    final originFeats = grantsFeat
        ? _eligibleOriginFeats(draft)
        : const <Feat>[];

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
        // Competencias que declara una dote: la de origen recién elegida o la
        // que ya concede el trasfondo. Se pregunta a la ficha, así que sumar
        // otra dote que las conceda no toca este paso.
        ...() {
          draft.pruneProficiencyChoices();
          final slots = draft.proficiencyChoiceSlots;
          if (slots.isEmpty) return <Widget>[];
          // Lo que ya se tiene por otra vía, para no gastar la dote dos veces.
          final sheet = draft.previewSheet;
          final already = {
            ...sheet.skillProficiencies,
            ...sheet.toolProficiencies,
          }..removeAll(draft.chosenProficiencies);
          final total = slots.fold<int>(0, (n, s) => n + s.count);
          return <Widget>[
            const SizedBox(height: 26),
            _SectionHeader(
              title: 'Competencias por dote',
              counter: '${draft.chosenProficiencies.length}/$total',
            ),
            const SizedBox(height: 6),
            Text(
              slots.map((s) => '${s.featName} (${s.count})').join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final slot in slots) ...[
              _ProficiencyChoicePicker(
                slot: slot,
                chosen: draft.chosenProficiencies,
                already: already,
                max: total,
                onChanged: onChanged,
              ),
              const SizedBox(height: 12),
            ],
          ];
        }(),
      ],
    );
  }
}

/// Dotes de origen que el personaje puede tomar realmente. Ninguna de las
/// oficiales tiene prerrequisitos, pero una homebrew sí puede tenerlos, y el
/// paso corre después de Puntuaciones, así que ya hay con qué compararlos.
///
/// La dote tentativa se deja fuera del personaje evaluado: una dote que sube
/// una característica no debe poder cumplir su propio prerrequisito.
///
/// Tampoco se ofrece la dote de origen que ya concede el trasfondo: el
/// personaje la tendría por dos vías y el PHB solo permite repetir las dotes
/// que lo declaran. Sin este filtro, un Humano con trasfondo de Soldado podía
/// elegir Atacante Salvaje y quedar con la dote duplicada.
List<Feat> _eligibleOriginFeats(CreationDraft draft) {
  final repo = draft.repo;
  final base = draft.build().copyWith(featIds: const []);
  final sheet = CharacterCompiler(repo).compile(base);
  final validator = CharacterValidator(repo);
  final grantedByBackground = draft.background?.originFeatId;
  return repo.featsSorted
      .where((f) => f.category == 'origin')
      .where((f) => f.repeatable || f.id != grantedByBackground)
      .where((f) => validator.unmetFeatPrerequisite(f, base, sheet) == null)
      .toList();
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
                    if (featSummary(feat).isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        featSummary(feat),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    SourceBadge(feat.source),
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
