part of '../sheet_screen.dart';

extension _SheetGeneralSection on _SheetScreenState {
  // ------------------------------------------------------------- Personaje

  Widget _buildPersonaje() {
    final s = sheet;
    final warnings = CharacterValidator(repo).validate(_c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warnings.isNotEmpty) ...[
          sheetCard(
            icon: Icons.warning_amber,
            title: 'Advertencias',
            child: DenseRows(
              children: [
                for (final w in warnings)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.warning_amber,
                      color: context.palette.crimson,
                    ),
                    title: Text(w.message),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        responsiveColumns([
          [_identityCard(), _abilitiesCard(s), _proficienciesCard(s)],
          [_skillsCard(s)],
          [_passivesCard(s)],
        ]),
      ],
    );
  }

  Widget _identityCard() {
    final pal = context.palette;
    final race = repo.race(_c.raceId);
    final bg = repo.background(_c.backgroundId)?.name ?? '—';
    final rows = <(String, String)>[
      ('Alineamiento', _c.alignment?.label ?? '—'),
      ('Tamaño', race?.size ?? '—'),
      ('Trasfondo', bg),
      if (_c.personalityTrait.isNotEmpty) ('Rasgo', _c.personalityTrait),
    ];
    return sheetCard(
      icon: Icons.badge,
      title: 'Identidad',
      child: DenseRows(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: pal.textMuted)),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(value, textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _abilitiesCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.fitness_center,
      title: 'Características',
      child: Padding(padding: const EdgeInsets.all(14), child: _abilityRow(s)),
    );
  }

  Widget _proficienciesCard(ComputedSheet s) {
    final labels = [
      ...s.armorProficiencies,
      ...s.weaponProficiencies,
      ...s.toolProficiencies,
    ].map(_title).toList()..sort();
    return sheetCard(
      icon: Icons.verified_user,
      title: 'Competencias',
      child: Padding(padding: const EdgeInsets.all(14), child: _chips(labels)),
    );
  }

  Widget _skillsCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.psychology,
      title: 'Habilidades',
      child: DenseRows(
        children: [for (final skill in Skill.values) _skillRow(s, skill)],
      ),
    );
  }

  Widget _skillRow(ComputedSheet s, Skill skill) {
    final pal = context.palette;
    final proficient = s.skillProficiencies.contains(skill.id);
    final mod =
        s.abilityModifiers[skill.ability]! +
        (proficient ? s.proficiencyBonus : 0);
    final color = proficient ? pal.gold : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: proficient ? pal.gold : pal.hairline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(skill.label, style: TextStyle(color: color)),
          ),
          Text(
            skill.ability.abbr,
            style: TextStyle(fontSize: 10.5, color: pal.textMuted),
          ),
          SizedBox(
            width: 42,
            child: Text(
              _signed(mod),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passivesCard(ComputedSheet s) {
    if (s.passives.isEmpty) return const SizedBox.shrink();
    return sheetCard(
      icon: Icons.auto_awesome,
      title: 'Rasgos y dotes',
      trailing: GoldPill('${s.passives.length}'),
      child: Column(
        children: [
          for (var i = 0; i < s.passives.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.palette.hairline),
            ExpansionTile(
              title: Text(s.passives[i].name),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedAlignment: Alignment.centerLeft,
              children: [
                Text(
                  s.passives[i].description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statPlaques(ComputedSheet s) {
    final pal = context.palette;
    final c = _c.combat;
    Widget box(Widget child) => SizedBox(width: 108, child: child);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        box(
          StatPlaque(
            label: 'Puntos de golpe',
            value: '${c.currentHp}/${s.maxHp}',
            valueColor: pal.crimson,
            footer: ThinBar(
              ratio: s.maxHp == 0 ? 0 : c.currentHp / s.maxHp,
              color: pal.crimson,
              track: pal.plaque,
            ),
          ),
        ),
        box(_acPlaque(s.armorClass)),
        box(StatPlaque(label: 'Velocidad', value: '${s.speed}')),
        box(StatPlaque(label: 'Iniciativa', value: _signed(s.initiative))),
        box(StatPlaque(label: 'Perc. pasiva', value: '${s.passivePerception}')),
        box(StatPlaque(label: 'Competencia', value: '+${s.proficiencyBonus}')),
        if (s.darkvision != null)
          box(StatPlaque(label: 'Visión osc.', value: '${s.darkvision}')),
      ],
    );
  }

  Widget _acPlaque(int ac) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ARMADURA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: pal.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          ShieldBadge('$ac'),
        ],
      ),
    );
  }

  Widget _abilityRow(ComputedSheet s) {
    final a = Ability.values;
    return Row(
      children: [
        for (var i = 0; i < a.length; i++) ...[
          Expanded(
            child: Tooltip(
              message: '${a[i].label}\n${a[i].description}',
              waitDuration: const Duration(milliseconds: 400),
              child: AbilityPlaque(
                abbr: a[i].abbr,
                score: s.abilityScores[a[i]]!,
                modifier: s.abilityModifiers[a[i]]!,
                saveProficient: s.savingThrowProficiencies.contains(a[i]),
              ),
            ),
          ),
          if (i < a.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _chips(List<String> labels) => labels.isEmpty
      ? Text('—', style: TextStyle(color: context.palette.textMuted))
      : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.map((l) => Chip(label: Text(l))).toList(),
        );
}
