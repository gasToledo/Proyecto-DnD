part of '../creation_wizard.dart';

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
    final lineage = draft.lineage?.name;
    final species = lineage == null ? race : '$race ($lineage)';
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

    final spells = <String>{
      for (final spell in s.innateSpells) spell.name,
      for (final id in draft.cantrips) repo.spell(id)?.name ?? id,
      for (final id in draft.spells) repo.spell(id)?.name ?? id,
    };

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
                            '$species · $klass · $bg · Nivel 1',
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
