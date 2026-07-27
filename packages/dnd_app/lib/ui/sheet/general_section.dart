part of '../sheet_screen.dart';

extension _SheetGeneralSection on _SheetScreenState {
  // -------------------------------------------------------------- General

  Widget _buildGeneral() {
    final s = sheet;
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warnings = CharacterValidator(repo).validate(_c);
    final portrait = _c.portraitPaths.isNotEmpty
        ? _c.portraitPaths.first
        : null;
    final hasPortrait = portrait != null && File(portrait).existsSync();
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final klassObj = repo.characterClass(_c.classId);
    final klass = klassObj?.name ?? _c.classId;
    final accent = classAccent(klassObj, pal.gold);
    final sub = _c.subclassId == null
        ? null
        : repo.subclass(_c.subclassId!)?.name;
    final klassLine = sub == null ? klass : '$klass ($sub)';
    final bg = repo.background(_c.backgroundId)?.name ?? '';
    final subtitle = [race, klassLine, if (bg.isNotEmpty) bg].join(' · ');

    return PageBody(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: hasPortrait ? () => _openPortraitViewer(portrait) : null,
              child: MouseRegion(
                cursor: hasPortrait
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: ClassMedallion(
                  klass: klassObj,
                  image: hasPortrait ? FileImage(File(portrait)) : null,
                  fallback: _c.name.characters.first,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _editName,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _c.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_outlined, size: 16, color: muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(classIcon(klassObj), size: 16, color: accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(subtitle, style: TextStyle(color: muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${_c.level}',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 28,
                    height: 1,
                    color: pal.gold,
                  ),
                ),
                const SizedBox(height: 4),
                const Eyebrow('Nivel'),
              ],
            ),
          ],
        ),
        const SectionRule(),
        _statPlaques(s),
        const SectionRule(),
        const Eyebrow('Características'),
        _abilityRow(s),
        const SizedBox(height: 20),
        if (s.attacks.isNotEmpty) ...[
          const Eyebrow('Ataques'),
          DenseRows(children: [for (final a in s.attacks) _attackRow(a)]),
          const SizedBox(height: 20),
        ],
        if (s.passives.isNotEmpty) ...[
          const Eyebrow('Rasgos pasivos'),
          DenseRows(children: [for (final t in s.passives) _passiveRow(t)]),
          const SizedBox(height: 20),
        ],
        if (s.skillProficiencies.isNotEmpty) ...[
          const Eyebrow('Competencias'),
          _chips(s.skillProficiencies.map(Skill.labelFor).toList()),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Eyebrow('Advertencias'),
          DenseRows(
            children: [
              for (final w in warnings)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.warning_amber, color: pal.crimson),
                  title: Text(w.message),
                ),
            ],
          ),
        ],
      ],
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

  /// Píldora de maestría con el nombre en español y la regla en el tooltip.
  /// Una maestría desconocida (homebrew o importada) cae en su identificador y
  /// se muestra sin explicación, que es todo lo que se puede decir de ella.
  Widget _masteryPill(String id) {
    final m = weaponMasteries[id];
    final pill = GoldPill('Maestría: ${weaponMasteryName(id)}');
    if (m == null) return pill;
    return Tooltip(
      message: m.description,
      textAlign: TextAlign.start,
      child: pill,
    );
  }

  Widget _attackRow(Attack a) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${a.damage} ${_title(a.damageType)}',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    if (a.mastery != null) _masteryPill(a.mastery!),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _signed(a.attackBonus),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              color: context.palette.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passiveRow(PassiveTrait t) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(t.description, style: TextStyle(color: muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
