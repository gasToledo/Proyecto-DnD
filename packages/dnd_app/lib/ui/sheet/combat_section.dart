part of '../sheet_screen.dart';

extension _SheetCombatSection on _SheetScreenState {
  // -------------------------------------------------------------- Combate

  Widget _buildCombat() {
    final s = sheet;
    final hasSpells = s.spellcasting != null || s.innateSpells.isNotEmpty;
    return responsiveColumns([
      [_hpCard(s), _defenseCard(s), _restResourcesCard(s)],
      [
        if (s.attacks.isNotEmpty) _attacksCard(s),
        if (hasSpells) _spellsCard(s),
      ],
      [_savesCard(s), _conditionsCard()],
    ]);
  }

  Widget _hpCard(ComputedSheet s) {
    final combat = _c.combat;
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ratio = s.maxHp == 0 ? 0.0 : combat.currentHp / s.maxHp;
    return sheetCard(
      icon: Icons.favorite,
      title: 'Puntos de golpe',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${combat.currentHp}',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 40,
                    height: 1,
                    color: pal.crimson,
                  ),
                ),
                Text(
                  ' / ${s.maxHp} PG',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    color: muted,
                  ),
                ),
                const Spacer(),
                if (combat.tempHp > 0) GoldPill('+${combat.tempHp} temp'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 8,
                backgroundColor: pal.plaque,
                valueColor: AlwaysStoppedAnimation(pal.crimson),
              ),
            ),
            const SizedBox(height: 14),
            _hpControls(s),
            if (combat.currentHp <= 0) ...[
              const SizedBox(height: 16),
              const Eyebrow('Salvaciones de muerte'),
              _deathSaves(combat),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hpControls(ComputedSheet s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.crimson,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _mutateCombat(() {
            CombatOps.applyDamage(_c.combat, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Daño'),
        ),
        OutlinedButton.icon(
          onPressed: () => _mutateCombat(() {
            CombatOps.applyHealing(_c.combat, s.maxHp, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Curar'),
        ),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            CombatOps.setTempHp(_c.combat, _amount);
            _amountCtrl.clear();
          }),
          child: const Text('PG temp'),
        ),
      ],
    );
  }

  Widget _deathSaves(CombatState combat) {
    Widget pips(int filled, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < filled ? Icons.circle : Icons.circle_outlined,
          color: color,
          size: 20,
        ),
      ),
    );
    return Row(
      children: [
        pips(combat.deathSuccesses, context.palette.gold),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            final r = CombatOps.recordDeathSave(_c.combat, success: true);
            if (r == 'stable') _snack('¡Estabilizado!');
          }),
          child: const Text('+Éxito'),
        ),
        const Spacer(),
        pips(combat.deathFailures, context.palette.crimson),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            final r = CombatOps.recordDeathSave(_c.combat, success: false);
            if (r == 'dead') _snack('El personaje ha muerto.');
          }),
          child: const Text('+Fallo'),
        ),
      ],
    );
  }

  Widget _defenseCard(ComputedSheet s) {
    final pal = context.palette;
    final armor = _c.equippedArmorId == null
        ? null
        : repo.armorPiece(_c.equippedArmorId!);
    final armorLine = [
      armor?.name ?? 'Sin armadura',
      if (_c.shieldEquipped) 'escudo',
    ].join(' + ');
    final resistances = [...s.resistances].map(_title).toList()..sort();
    final immunities = [...s.immunities].map(_title).toList()..sort();
    return sheetCard(
      icon: Icons.shield,
      title: 'Defensa',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 60, child: _acPlaque(s.armorClass)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(armorLine),
                  if (resistances.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Resistencias: ${resistances.join(", ")}',
                      style: TextStyle(fontSize: 12.5, color: pal.textMuted),
                    ),
                  ],
                  if (immunities.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Inmunidades: ${immunities.join(", ")}',
                      style: TextStyle(fontSize: 12.5, color: pal.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shortRest(ComputedSheet s) {
    final restored = s.resources
        .where((r) => r.recharge == RechargeOn.shortRest)
        .map((r) => r.name)
        .toList();
    _mutateCombat(
      () => CombatOps.shortRest(
        _c.combat,
        s.resources,
        spellcasting: s.spellcasting,
      ),
    );
    final msg = restored.isEmpty
        ? 'Descanso corto. No cura PG: gastá dados de golpe para curarte.'
        : 'Descanso corto: recuperaste ${restored.join(", ")}. '
              'Para curarte, gastá dados de golpe.';
    _snack(msg);
  }

  void _longRest(ComputedSheet s) {
    _mutateCombat(
      () => CombatOps.longRest(_c.combat, s.maxHp, s.resources, _c.level),
    );
    _snack('Descanso largo: PG al máximo y recursos recargados.');
  }

  Widget _restResourcesCard(ComputedSheet s) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return sheetCard(
      icon: Icons.bolt,
      title: 'Recursos y descansos',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El descanso corto no cura PG: recarga recursos de recarga '
              'corta. Para curarte, gastá dados de golpe.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _shortRest(s),
                  icon: const Icon(Icons.local_cafe, size: 18),
                  label: const Text('Descanso corto'),
                ),
                FilledButton.icon(
                  onPressed: () => _longRest(s),
                  icon: const Icon(Icons.bedtime, size: 18),
                  label: const Text('Descanso largo'),
                ),
                OutlinedButton.icon(
                  onPressed: _c.combat.hitDiceUsed >= _c.level
                      ? null
                      : () {
                          final healed = CombatOps.spendHitDie(
                            _c.combat,
                            s,
                            _c.level,
                          );
                          _mutateCombat(() {});
                          _snack('Recuperaste $healed PG (dado de golpe)');
                        },
                  icon: const Icon(Icons.casino, size: 18),
                  label: Text(
                    'Dado de golpe (${_c.level - _c.combat.hitDiceUsed}/${_c.level})',
                  ),
                ),
              ],
            ),
            if (s.resources.isNotEmpty) ...[
              const SizedBox(height: 16),
              DenseRows(
                children: [for (final r in s.resources) _resourceRow(r)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resourceRow(CharacterResource r) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final used = _c.combat.resourceUsage[r.id] ?? 0;
    final hasInfo = r.description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: hasInfo ? r.description : '',
              waitDuration: const Duration(milliseconds: 400),
              child: InkWell(
                onTap: hasInfo
                    ? () => _showInfoDialog(r.name, r.description)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (hasInfo) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.info_outline, size: 14, color: muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    UsagePips(
                      max: r.max,
                      filled: r.max - used,
                      filledIcon: Icons.bolt,
                      emptyIcon: Icons.bolt_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SpendRecoverButtons(
            spendTooltip: 'Usar',
            onSpend: used >= r.max
                ? null
                : () => _mutateCombat(
                    () => _c.combat.resourceUsage[r.id] = used + 1,
                  ),
            onRecover: used <= 0
                ? null
                : () => _mutateCombat(
                    () => _c.combat.resourceUsage[r.id] = used - 1,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _attacksCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.gps_fixed,
      title: 'Ataques',
      child: DenseRows(children: [for (final a in s.attacks) _attackRow(a)]),
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

  Widget _savesCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.security,
      title: 'Salvaciones',
      child: DenseRows(
        children: [for (final a in Ability.values) _saveRow(s, a)],
      ),
    );
  }

  Widget _saveRow(ComputedSheet s, Ability a) {
    final pal = context.palette;
    final proficient = s.savingThrowProficiencies.contains(a);
    final color = proficient ? pal.gold : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
            child: Text(a.label, style: TextStyle(color: color)),
          ),
          Text(
            _signed(s.savingThrow(a)),
            style: TextStyle(fontFamily: 'Georgia', fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _conditionsCard() {
    return sheetCard(
      icon: Icons.emergency,
      title: 'Condiciones',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _conditionChips(_c.combat),
      ),
    );
  }

  Widget _conditionChips(CombatState combat) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _conditions.entries.map((e) {
        final active = combat.conditions.contains(e.key);
        return Tooltip(
          message: e.value.description,
          waitDuration: const Duration(milliseconds: 400),
          child: FilterChip(
            label: Text(e.value.label),
            selected: active,
            onSelected: (v) => _mutateCombat(() {
              if (v) {
                combat.conditions.add(e.key);
              } else {
                combat.conditions.remove(e.key);
              }
            }),
          ),
        );
      }).toList(),
    );
  }

  /// Diálogo de información reutilizable (título + contenido desplazable + Cerrar).
  void _infoDialog(String title, Widget content) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String description) =>
      _infoDialog(title, Text(description));
}
