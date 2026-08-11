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
        if (s.companions.isNotEmpty) _companionsCard(s),
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
    final resistances = [...s.resistances].map(DamageType.labelFor).toList()
      ..sort();
    final immunities = [...s.immunities].map(DamageType.labelFor).toList()
      ..sort();
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
      () => CombatOps.longRest(
        _c.combat,
        s.maxHp,
        s.resources,
        _c.level,
        companionMaxHp: (instance) =>
            _companionMaxHp(s, instance) ??
            // Sin perfil no hay máximo que calcular: se lo deja como está en
            // vez de inventarle uno.
            instance.currentHp,
      ),
    );
    _snack('Descanso largo: PG al máximo y recursos recargados.');
  }

  /// PG máximos de un compañero invocado, o null si su forma ya no está en el
  /// catálogo.
  int? _companionMaxHp(ComputedSheet s, CompanionInstance instance) {
    for (final option in s.companions) {
      if (option.id != instance.optionId) continue;
      final form = option.form(instance.creatureId);
      if (form == null) return null;
      return resolveCreatureInt(
        form.hp,
        _companionVars(s, spellLevel: instance.spellLevel),
      );
    }
    return null;
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
                        // Flexible: "Invocaciones Sobrenaturales" y compañía
                        // desbordaban la fila en un teléfono angosto.
                        Flexible(
                          child: Text(
                            r.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
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
                      '${a.damage} ${DamageType.labelFor(a.damageType)}',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    if (a.mastery != null) _masteryPill(a.mastery!),
                    // Mano y acción salen calculadas del motor: derivarlas acá
                    // sería reimplementar la regla de dos armas en la ficha.
                    if (a.offHand) const GoldPill('Mano secundaria'),
                    if (a.action == AttackAction.bonusAction)
                      const GoldPill('Acción adicional'),
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

  // ------------------------------------------------------------ Compañeros

  /// Los valores del personaje que las fórmulas de una criatura pueden leer.
  /// [spellLevel] es el del espacio gastado al invocar; congelado en la
  /// instancia, así que un corcel ya convocado no mejora al subir de nivel.
  CreatureVars _companionVars(ComputedSheet s, {int spellLevel = 0}) =>
      CreatureVars.from(
        level: s.level,
        proficiencyBonus: s.proficiencyBonus,
        abilityModifiers: s.abilityModifiers,
        spellAttackBonus: s.spellcasting?.attackBonus ?? 0,
        spellSaveDc: s.spellcasting?.saveDc ?? 0,
        spellLevel: spellLevel,
      );

  Widget _companionsCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.pets,
      title: 'Compañeros',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _companionAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            for (final option in s.companions) ...[
              const SizedBox(height: 16),
              _companionBlock(s, option),
            ],
          ],
        ),
      ),
    );
  }

  Widget _companionBlock(ComputedSheet s, CompanionOption option) {
    final active = [
      for (final i in _c.combat.companions)
        if (i.optionId == option.id) i,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow(option.name)),
            OutlinedButton.icon(
              onPressed: () => _summonCompanion(s, option),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(active.isEmpty ? 'Invocar' : 'Invocar otro'),
            ),
          ],
        ),
        if (option.source.isNotEmpty)
          Text(option.source, style: TextStyle(fontSize: 12.5, color: muted)),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No hay ninguno invocado.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
        for (final instance in active) _companionInstance(s, option, instance),
      ],
    );
  }

  /// Pide la forma y el nivel de espacio que hagan falta, e invoca.
  Future<void> _summonCompanion(ComputedSheet s, CompanionOption option) async {
    var form = option.forms.first;
    if (option.forms.length > 1) {
      final chosen = await _pickFromList<Creature>(
        title: 'Elegí la forma',
        options: option.forms,
        label: (c) => c.name,
        subtitle: (c) => c.kind,
      );
      if (chosen == null) return;
      form = chosen;
    }

    var spellLevel = 0;
    if (option.scalesWithSpellLevel) {
      // El pozo son los niveles con espacios disponibles: invocar gasta uno, y
      // ofrecer un nivel que no se puede pagar es ofrecer un error.
      final levels = [
        for (final entry in (s.spellcasting?.slotsByLevel ?? const {}).entries)
          if (entry.value > 0) entry.key,
      ]..sort();
      if (levels.isEmpty) {
        _snack('No te quedan espacios de conjuro para invocarlo.');
        return;
      }
      final chosen = await _pickFromList<int>(
        title: 'Nivel del espacio',
        options: levels,
        label: (l) => 'Nivel $l',
        subtitle: (l) =>
            '${CombatOps.spellSlotsRemaining(_c.combat, s.spellcasting!, l)}'
            ' de ${s.spellcasting!.slotsByLevel[l]} disponibles',
      );
      if (chosen == null) return;
      spellLevel = chosen;
    }

    final summoned = form;
    final level = spellLevel;
    _mutateCombat(
      () => CombatOps.summonCompanion(
        _c.combat,
        option,
        summoned,
        _companionVars(s, spellLevel: level),
      ),
    );
    _snack('${summoned.name} invocado.');
  }

  /// Diálogo de una sola elección. Devuelve null si se cancela.
  Future<T?> _pickFromList<T>({
    required String title,
    required List<T> options,
    required String Function(T) label,
    String Function(T)? subtitle,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        // `maxFinite` deja que el diálogo imponga su propio ancho. Fijar 360
        // desbordaba en un teléfono angosto, y el familiar abre acá con sus 24
        // formas: es el selector más grande de la app.
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final option in options)
                ListTile(
                  title: Text(label(option)),
                  subtitle: subtitle == null ? null : Text(subtitle(option)),
                  onTap: () => Navigator.of(dialogContext).pop(option),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _companionInstance(
    ComputedSheet s,
    CompanionOption option,
    CompanionInstance instance,
  ) {
    final form = option.form(instance.creatureId);
    // Una forma que el catálogo ya no tiene (contenido cambiado bajo los pies
    // de una ficha guardada) se muestra como lo que es, con la salida a mano.
    if (form == null) {
      return ListTile(
        title: Text(instance.creatureId),
        subtitle: const Text('Esta criatura ya no está en el catálogo.'),
        trailing: IconButton(
          tooltip: 'Despedir',
          icon: const Icon(Icons.close),
          onPressed: () => _mutateCombat(
            () => CombatOps.dismissCompanion(_c.combat, instance),
          ),
        ),
      );
    }

    final resolved = form.resolve(
      _companionVars(s, spellLevel: instance.spellLevel),
    );
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ratio = resolved.maxHp == 0
        ? 0.0
        : instance.currentHp / resolved.maxHp;
    final destroyed = instance.currentHp <= 0;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  resolved.name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 17),
                ),
              ),
              if (instance.spellLevel > 0)
                GoldPill('Espacio de nivel ${instance.spellLevel}'),
              const SizedBox(width: 8),
              Text(
                'CA ${resolved.armorClass}',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
          Text(
            [
              resolved.kind,
              resolved.speed,
            ].where((t) => t.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${instance.currentHp} / ${resolved.maxHp} PG',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  color: destroyed ? muted : pal.crimson,
                ),
              ),
              const SizedBox(width: 8),
              if (instance.tempHp > 0) GoldPill('+${instance.tempHp} temp'),
              if (destroyed)
                Text('Destruido', style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              backgroundColor: pal.plaque,
              valueColor: AlwaysStoppedAnimation(pal.crimson),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: pal.crimson,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _mutateCombat(() {
                  CombatOps.damageCompanion(instance, _companionAmount);
                  _companionAmountCtrl.clear();
                }),
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('Daño'),
              ),
              OutlinedButton.icon(
                onPressed: () => _mutateCombat(() {
                  CombatOps.healCompanion(
                    instance,
                    resolved.maxHp,
                    _companionAmount,
                  );
                  _companionAmountCtrl.clear();
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Curar'),
              ),
              OutlinedButton(
                onPressed: () => _mutateCombat(() {
                  CombatOps.setCompanionTempHp(instance, _companionAmount);
                  _companionAmountCtrl.clear();
                }),
                child: const Text('PG temp'),
              ),
              OutlinedButton.icon(
                onPressed: () => _mutateCombat(
                  () => CombatOps.dismissCompanion(_c.combat, instance),
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Despedir'),
              ),
            ],
          ),
          if (resolved.senses.isNotEmpty || resolved.defenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                resolved.senses,
                resolved.defenses,
              ].where((t) => t.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ],
          for (final trait in resolved.traits)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${trait.name}. ',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    TextSpan(text: trait.description),
                  ],
                ),
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          for (final action in resolved.actions) _companionAction(action),
          const SizedBox(height: 4),
          Divider(color: pal.hairline),
          _conditionChips(instance.conditions),
        ],
      ),
    );
  }

  Widget _companionAction(ResolvedCreatureAction a) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final damage = [
      if (a.damage != null) a.damage!,
      if (a.damageType != null) DamageType.labelFor(a.damageType!),
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (damage.isNotEmpty)
                      Text(
                        damage,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    if (a.reach.isNotEmpty)
                      Text(
                        a.reach,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    if (a.reaction) const GoldPill('Reacción'),
                  ],
                ),
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    a.description,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          if (a.isAttack)
            Text(
              _signed(a.attackBonus!),
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
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
        child: _conditionChips(_c.combat.conditions),
      ),
    );
  }

  /// Los chips operan sobre el conjunto que se les pasa, no sobre el del
  /// personaje: los compañeros invocados llevan condiciones propias y la lista
  /// de estados es la misma para todos.
  Widget _conditionChips(Set<String> target) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _conditions.entries.map((e) {
        final active = target.contains(e.key);
        return Tooltip(
          message: e.value.description,
          waitDuration: const Duration(milliseconds: 400),
          child: FilterChip(
            label: Text(e.value.label),
            selected: active,
            onSelected: (v) => _mutateCombat(() {
              if (v) {
                target.add(e.key);
              } else {
                target.remove(e.key);
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
