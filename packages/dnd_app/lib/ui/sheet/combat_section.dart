part of '../sheet_screen.dart';

extension _SheetCombatSection on _SheetScreenState {
  // -------------------------------------------------------------- Combate

  Widget _buildCombat() {
    final s = sheet;
    final combat = _c.combat;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PageBody(
      children: [
        _hpPanel(s, combat),
        const SizedBox(height: 14),
        _hpControls(s),
        const SizedBox(height: 22),
        if (combat.currentHp <= 0) ...[
          const Eyebrow('Salvaciones de muerte'),
          _deathSaves(combat),
          const SizedBox(height: 22),
        ],
        const Eyebrow('Descansos y recuperación'),
        Text(
          'El descanso corto no cura PG: recarga recursos de recarga corta. '
          'Para curarte, gastá dados de golpe.',
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
        const SizedBox(height: 22),
        if (s.resources.isNotEmpty) ...[
          const Eyebrow('Recursos'),
          DenseRows(children: [for (final r in s.resources) _resourceRow(r)]),
          const SizedBox(height: 22),
        ],
        const Eyebrow('Condiciones'),
        _conditionChips(combat),
        const SizedBox(height: 22),
        if (s.attacks.isNotEmpty) ...[
          const Eyebrow('Ataques'),
          DenseRows(children: [for (final a in s.attacks) _attackRow(a)]),
        ],
      ],
    );
  }

  Widget _hpPanel(ComputedSheet s, CombatState combat) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ratio = s.maxHp == 0 ? 0.0 : combat.currentHp / s.maxHp;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
        ],
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
