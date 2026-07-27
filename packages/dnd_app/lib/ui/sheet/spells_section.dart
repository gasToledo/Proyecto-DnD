part of '../sheet_screen.dart';

extension _SheetSpellsSection on _SheetScreenState {
  // ------------------------------------------------------------- Conjuros

  Widget _spellsCard(ComputedSheet sheetArg) {
    final sc = sheetArg.spellcasting;
    final combat = _c.combat;
    final pal = context.palette;

    final cantrips = sc == null
        ? <Spell>[]
        : (_c.cantripIds.map((id) => repo.spell(id)).whereType<Spell>().toList()
            ..sort((a, b) => a.name.compareTo(b.name)));
    final spells = sc == null
        ? <Spell>[]
        : (_c.spellIds.map((id) => repo.spell(id)).whereType<Spell>().toList()
            ..sort(
              (a, b) => a.level != b.level
                  ? a.level.compareTo(b.level)
                  : a.name.compareTo(b.name),
            ));

    final slotLevels = sc?.slotsByLevel.keys.toList() ?? <int>[];
    slotLevels.sort();

    return sheetCard(
      icon: Icons.auto_stories,
      title: 'Conjuros',
      trailing: sc == null
          ? null
          : TextButton.icon(
              onPressed: () => _openSpellEditor(sc),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                sc.preparation == SpellPreparation.prepared
                    ? 'Preparar'
                    : 'Editar',
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sc != null) ...[
              Row(
                children: [
                  Expanded(
                    child: StatPlaque(label: 'CD SALV.', value: '${sc.saveDc}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatPlaque(
                      label: 'ATAQUE',
                      value:
                          '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatPlaque(label: 'APTITUD', value: sc.ability.abbr),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  sc.preparation == SpellPreparation.prepared
                      ? 'Preparados: ${_c.spellIds.length} / ${sc.preparedCount}'
                      : 'Conocidos: ${_c.spellIds.length}',
                  if (sc.cantripsKnown > 0)
                    'Trucos: ${cantrips.length} / ${sc.cantripsKnown}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            if (sheet.innateSpells.isNotEmpty) ...[
              if (sc != null) const SizedBox(height: 20),
              const Eyebrow('Conjuros de especie y linaje'),
              const SizedBox(height: 6),
              DenseRows(
                children: [
                  for (final innate in sheet.innateSpells)
                    _innateSpellRow(innate),
                ],
              ),
            ],

            if (combat.concentratingOn != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: pal.gold),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.blur_on, size: 18, color: pal.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Concentrándote en ${combat.concentratingOn}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _mutateCombat(
                        () => CombatOps.endConcentration(combat),
                      ),
                      child: const Text('Terminar'),
                    ),
                  ],
                ),
              ),
            ],

            if (slotLevels.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Eyebrow('Espacios de conjuro'),
              DenseRows(
                children: [for (final lv in slotLevels) _slotRow(sc!, lv)],
              ),
            ],

            if (cantrips.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Eyebrow('Trucos'),
              DenseRows(children: [for (final s in cantrips) _spellRow(s)]),
            ],

            if (spells.isNotEmpty) ...[
              const SizedBox(height: 20),
              Eyebrow(
                sc!.preparation == SpellPreparation.prepared
                    ? 'Conjuros preparados'
                    : 'Conjuros conocidos',
              ),
              DenseRows(children: [for (final s in spells) _spellRow(s)]),
            ],

            if (sc != null &&
                cantrips.isEmpty &&
                spells.isEmpty &&
                sheet.innateSpells.isEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Todavía no elegiste conjuros. Editá al subir de nivel o al crear.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _innateSpellRow(InnateSpell innate) {
    final spell = repo.spell(innate.spellId);
    final use = switch (innate.use) {
      InnateSpellUse.atWill => 'A voluntad',
      InnateSpellUse.oncePerLongRest => '1/descanso largo',
      InnateSpellUse.proficiencyBonusPerLongRest =>
        'Competencia/descanso largo',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: spell == null ? null : () => _showSpellDialog(spell),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    innate.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$use · ${innate.ability.abbr} · '
                    'CD ${innate.saveDc} · Ataque '
                    '${innate.attackBonus >= 0 ? "+" : ""}${innate.attackBonus}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (spell?.concentration == true)
            TextButton(
              onPressed: () => _mutateCombat(
                () => CombatOps.startConcentration(_c.combat, innate.name),
              ),
              child: const Text('Concentrar'),
            ),
        ],
      ),
    );
  }

  void _openSpellEditor(Spellcasting sc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpellEditScreen(
          character: _c,
          repo: repo,
          spellcasting: sc,
          onSave: (cantrips, spells) =>
              _replace(_c.copyWith(cantripIds: cantrips, spellIds: spells)),
        ),
      ),
    );
  }

  Widget _slotRow(Spellcasting sc, int level) {
    final pal = context.palette;
    final combat = _c.combat;
    final max = sc.slotsByLevel[level] ?? 0;
    final used = combat.spellSlotsUsed[level] ?? 0;
    final remaining = CombatOps.spellSlotsRemaining(combat, sc, level);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              'Nivel $level',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: UsagePips(
              max: max,
              filled: remaining,
              filledIcon: Icons.circle,
              emptyIcon: Icons.circle_outlined,
              size: 16,
            ),
          ),
          Text(
            '$remaining/$max',
            style: TextStyle(color: pal.textMuted, fontSize: 12),
          ),
          SpendRecoverButtons(
            spendTooltip: 'Gastar espacio',
            recoverTooltip: 'Recuperar espacio',
            onSpend: remaining <= 0
                ? null
                : () => _mutateCombat(
                    () => CombatOps.spendSpellSlot(combat, sc, level),
                  ),
            onRecover: used <= 0
                ? null
                : () => _mutateCombat(
                    () => CombatOps.recoverSpellSlot(combat, level),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _spellRow(Spell s) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showSpellDialog(s),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (s.concentration) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.blur_on, size: 14, color: pal.gold),
                            ],
                            if (s.ritual) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(R)',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.isCantrip ? "Truco" : "Nivel ${s.level}"} · ${s.school}',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.info_outline, size: 14, color: muted),
                ],
              ),
            ),
          ),
          if (s.concentration)
            TextButton(
              onPressed: () => _mutateCombat(
                () => CombatOps.startConcentration(_c.combat, s.name),
              ),
              child: const Text('Concentrar'),
            ),
        ],
      ),
    );
  }

  void _showSpellDialog(Spell s) {
    _infoDialog(
      s.name,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${s.isCantrip ? "Truco" : "Nivel ${s.level}"} · ${s.school}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _spellMeta('Lanzamiento', s.castingTime),
          _spellMeta('Alcance', s.range),
          _spellMeta('Componentes', s.components),
          _spellMeta('Duración', s.duration),
          const SizedBox(height: 10),
          Text(s.description),
        ],
      ),
    );
  }

  Widget _spellMeta(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
