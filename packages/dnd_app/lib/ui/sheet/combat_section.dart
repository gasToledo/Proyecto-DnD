part of '../sheet_screen.dart';

extension _SheetCombatSection on _SheetScreenState {
  // -------------------------------------------------------------- Combate

  Widget _buildCombat() {
    final s = sheet;
    final hasSpells = s.spellcasting != null || s.innateSpells.isNotEmpty;
    return responsiveColumns([
      [
        _hpCard(s),
        _defenseCard(s),
        _restResourcesCard(s),
        // Cansancio e Inspiración van con los descansos y no con las
        // condiciones: el botón de descanso largo, que está acá al lado, es
        // justo lo que mueve a los dos.
        _stateCard(s),
      ],
      [
        if (s.attacks.isNotEmpty) _attacksCard(s),
        if (s.wildShape != null) _wildShapeCard(s),
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
            // Wrap y no Row con Spacer: el número a 40px más "/ NN PG" más la
            // píldora de temporales no entran en un teléfono angosto, y la
            // píldora aparece sola apenas algo da PG temporales (la Forma
            // Salvaje, el Cañón Protector). Acá baja de línea en vez de
            // desbordar, igual que en el bloque de compañeros.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              runSpacing: 4,
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
                  '/ ${s.maxHp} PG',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    color: muted,
                  ),
                ),
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
    Widget group(Widget marks, Widget button) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [marks, const SizedBox(width: 8), button],
    );
    // Wrap y no Row: los seis círculos más los dos botones no entran en el
    // ancho de un teléfono, y es justo la fila que se mira con el personaje a
    // 0 PG. Si no entran en una línea, éxitos y fallos se apilan.
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        group(
          _statePips(combat.deathSuccesses, 3, context.palette.gold),
          OutlinedButton(
            onPressed: () => _mutateCombat(() {
              final r = CombatOps.recordDeathSave(_c.combat, success: true);
              if (r == 'stable') _snack('¡Estabilizado!');
            }),
            child: const Text('+Éxito'),
          ),
        ),
        group(
          _statePips(combat.deathFailures, 3, context.palette.crimson),
          OutlinedButton(
            onPressed: () => _mutateCombat(() {
              final r = CombatOps.recordDeathSave(_c.combat, success: false);
              if (r == 'dead') _snack('El personaje ha muerto.');
            }),
            child: const Text('+Fallo'),
          ),
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
    // Se leen antes para poder contar en el aviso lo que efectivamente cambió:
    // `longRest` muta el estado in situ, así que después ya no hay con qué
    // comparar.
    final cansancioPrevio = _c.combat.exhaustion;
    final teniaInspiracion = _c.combat.heroicInspiration;

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
        grantsHeroicInspiration: s.heroicInspirationOnLongRest,
      ),
    );

    // Los objetos mágicos se recargan al amanecer, no con el descanso: van
    // aparte porque viven en la mochila y no en el estado de combate, y por eso
    // se escriben con `_replace` y no con `_mutateCombat`.
    final (conCargas, objetosRecargados) = InventoryOps.rechargeAtDawn(
      _c,
      repo,
    );
    if (objetosRecargados > 0) _replace(conCargas);

    final partes = <String>['PG al máximo y recursos recargados'];
    if (cansancioPrevio > 0) {
      partes.add('cansancio a nivel ${_c.combat.exhaustion}');
    }
    if (!teniaInspiracion && _c.combat.heroicInspiration) {
      partes.add('ganaste Inspiración Heroica');
    }
    if (objetosRecargados > 0) {
      partes.add(
        objetosRecargados == 1
            ? '1 objeto mágico recuperó cargas'
            : '$objetosRecargados objetos mágicos recuperaron cargas',
      );
    }
    _snack('Descanso largo: ${partes.join('; ')}.');
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
                    // El alcance sale del catálogo y no del ataque: un
                    // ataque de Forma Salvaje o de un compañero no tiene arma
                    // del catálogo detrás y entonces no muestra ninguno.
                    if (repo.weapon(a.baseWeaponId)?.rangeLabel case final r?)
                      Text(
                        'Alcance $r',
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

  // --------------------------------------------------------- Forma Salvaje

  /// Aviso de que la ficha que estás mirando no es la tuya. Vive en la
  /// cabecera, arriba de las placas, para que se vea desde cualquier pestaña.
  Widget _wildShapeBanner(Creature beast) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: pal.gold),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.pets, size: 18, color: pal.gold),
          const SizedBox(width: 8),
          Expanded(child: Text('Transformado en ${beast.name}')),
          TextButton(
            onPressed: () =>
                _mutateCombat(() => CombatOps.leaveWildShape(_c.combat)),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Widget _wildShapeCard(ComputedSheet s) {
    final slot = s.wildShape!;
    final beast = wildShapeForm;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final uses = s.resources
        .where((r) => r.id == CombatOps.wildShapeResourceId)
        .firstOrNull;

    return sheetCard(
      icon: Icons.pets,
      title: 'Forma Salvaje',
      trailing: TextButton.icon(
        onPressed: () => _editWildShapeForms(slot),
        icon: const Icon(Icons.edit, size: 16),
        label: const Text('Anotar'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                if (uses != null) 'Usos: ${_resourceLeft(uses)} de ${uses.max}',
                'Formas: ${slot.chosen.length} de ${slot.count}',
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            if (beast != null) ...[
              const SizedBox(height: 12),
              _wildShapeBanner(beast),
              // Los ataques de la bestia ya están en la tarjeta Ataques por el
              // overlay; acá van los rasgos, que no tienen otro lugar.
              for (final trait in beast.traits)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
            ] else if (slot.chosen.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Todavía no anotaste ninguna forma.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              )
            else
              for (final form in slot.chosen) _wildShapeForm(s, form),
          ],
        ),
      ),
    );
  }

  Widget _wildShapeForm(ComputedSheet s, Creature form) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(form.name),
                Text(
                  '${form.kind} · CA ${form.ac} · ${form.speed}',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _enterWildShape(s, form),
            child: const Text('Transformarse'),
          ),
        ],
      ),
    );
  }

  void _enterWildShape(ComputedSheet s, Creature form) {
    // Se pregunta al motor y no se mira el recurso acá: quién puede
    // transformarse es una regla, y duplicarla en la pantalla es tenerla mal
    // en un lado.
    var ok = false;
    _mutateCombat(() {
      ok = CombatOps.enterWildShape(_c.combat, s, form);
    });
    _snack(
      ok
          ? 'Te transformaste en ${form.name}: +${s.level} PG temporales.'
          : 'No te quedan usos de Forma Salvaje.',
    );
  }

  /// Elige las formas anotadas. Son hasta ocho sobre un pozo de sesenta y pico,
  /// así que van en una lista con casillas y no en chips como las competencias.
  Future<void> _editWildShapeForms(WildShapeSlot slot) async {
    final chosen = [for (final b in slot.chosen) b.id];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Formas conocidas (${chosen.length}/${slot.count})'),
          content: SizedBox(
            width: double.maxFinite,
            // Alto fijo: el pozo tiene decenas de bestias y sin esto el
            // diálogo intenta crecer hasta pasarse de la pantalla.
            height: 420,
            child: ListView(
              children: [
                for (final beast in slot.options)
                  CheckboxListTile(
                    dense: true,
                    value: chosen.contains(beast.id),
                    // Con el cupo lleno, lo no elegido se bloquea en vez de
                    // desalojar en silencio a otra forma.
                    onChanged:
                        chosen.length >= slot.count &&
                            !chosen.contains(beast.id)
                        ? null
                        : (value) => setDialogState(() {
                            if (value ?? false) {
                              chosen.add(beast.id);
                            } else {
                              chosen.remove(beast.id);
                            }
                          }),
                    title: Text(beast.name),
                    subtitle: Text('${beast.kind} · CA ${beast.ac}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(chosen),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    _replace(_c.copyWith(wildShapeForms: result));
  }

  Widget _companionsCard(ComputedSheet s) {
    return sheetCard(
      icon: Icons.pets,
      title: 'Compañeros',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // El campo solo aparece con algo invocado: sin compañeros en juego
            // no manda a nada, y un "Cantidad" suelto arriba de un botón
            // "Invocar" se lee como si fuera la cantidad a invocar.
            if (_c.combat.companions.isNotEmpty)
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _companionAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de PG',
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

  int _resourceLeft(CharacterResource r) =>
      r.max - (_c.combat.resourceUsage[r.id] ?? 0);

  /// El recurso de lanzamiento gratis del conjuro que invoca a [option], si el
  /// personaje lo tiene y le quedan usos. Null si no hay ninguno.
  ///
  /// Lo arma el compilador a partir de un `grantSpell` con usos limitados: es
  /// el Corcel Fiel del Paladín, que lanza Hallar Corcel una vez por descanso
  /// largo sin pagar espacio.
  CharacterResource? _freeCastFor(ComputedSheet s, CompanionOption option) {
    if (option.spellId == null) return null;
    final id = innateSpellResourceId(option.spellId!);
    for (final r in s.resources) {
      if (r.id == id) return _resourceLeft(r) > 0 ? r : null;
    }
    return null;
  }

  /// Diálogo de sí o no. Devuelve false si se cancela o se cierra.
  Future<bool> _confirmDialog(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Invocar igual'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Pide la forma y el nivel de espacio que hagan falta, e invoca.
  Future<void> _summonCompanion(ComputedSheet s, CompanionOption option) async {
    // Invocar con el cupo lleno reemplaza al más viejo, así que se avisa antes
    // de que el jugador gaste un espacio: perder el compañero que ya estaba en
    // la mesa no puede ser algo que se descubra después de pagar.
    final active = [
      for (final i in _c.combat.companions)
        if (i.optionId == option.id) i,
    ];
    if (active.length >= option.maxActive) {
      final going = option.form(active.first.creatureId)?.name ?? option.name;
      final confirmed = await _confirmDialog(
        option.maxActive == 1 ? 'Ya tenés uno en juego' : 'Llegaste al máximo',
        option.maxActive == 1
            ? 'Invocar otro hace desaparecer a $going, con los puntos de golpe '
                  'que tenga.'
            : 'Ya tenés ${option.maxActive}. Invocar otro hace desaparecer al '
                  'más viejo, $going.',
      );
      if (!confirmed) return;
    }

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

    // Lanzamiento gratis que concede un rasgo (el Corcel Fiel del Paladín),
    // con sus usos sin gastar. Se lanza al nivel base del conjuro.
    final free = _freeCastFor(s, option);

    var spellLevel = 0;
    var castsFree = false;
    if (option.scalesWithSpellLevel) {
      // El pozo son los niveles con espacios disponibles, desde el nivel del
      // conjuro para arriba: ofrecer un nivel que no se puede pagar es ofrecer
      // un error, y ofrecer uno por debajo del conjuro da un compañero con los
      // números al revés. El uso gratis va primero, que es como se gasta.
      final choices =
          <({int level, bool free})>[
            if (free != null) (level: option.minSpellLevel, free: true),
            for (final level in (s.spellcasting?.slotsByLevel ?? const {}).keys)
              // `slotsByLevel` es el máximo, no lo que queda: filtrar por ahí
              // dejaba invocar con espacios ya gastados.
              if (level >= option.minSpellLevel &&
                  CombatOps.spellSlotsRemaining(
                        _c.combat,
                        s.spellcasting!,
                        level,
                      ) >
                      0)
                (level: level, free: false),
          ]..sort(
            (a, b) => a.free == b.free
                ? a.level.compareTo(b.level)
                : (a.free ? -1 : 1),
          );

      if (choices.isEmpty) {
        _snack('No te quedan espacios de nivel ${option.minSpellLevel} o más.');
        return;
      }
      final chosen = await _pickFromList<({int level, bool free})>(
        title: 'Cómo lo invocás',
        options: choices,
        label: (c) => c.free ? 'Sin gastar espacio' : 'Nivel ${c.level}',
        subtitle: (c) => c.free
            ? '${free!.name}: quedan ${_resourceLeft(free)} de ${free.max}'
            : '${CombatOps.spellSlotsRemaining(_c.combat, s.spellcasting!, c.level)}'
                  ' de ${s.spellcasting!.slotsByLevel[c.level]} disponibles',
      );
      if (chosen == null) return;
      spellLevel = chosen.level;
      castsFree = chosen.free;
    }

    final summoned = form;
    final level = spellLevel;
    final spell = option.spellId == null ? null : repo.spell(option.spellId!);
    // Solo gasta espacio si se eligió un nivel y no se usó el lanzamiento
    // gratis. El familiar y los que concede un rasgo no pasan por acá: el
    // primero se lanza como ritual y los otros no son conjuros.
    final spendsSlot = level > 0 && s.spellcasting != null && !castsFree;
    final concentrates = spell?.concentration ?? false;
    final brokeConcentration =
        concentrates && _c.combat.concentratingOn != null;

    _mutateCombat(() {
      if (spendsSlot) {
        CombatOps.spendSpellSlot(_c.combat, s.spellcasting!, level);
      }
      if (castsFree) {
        _c.combat.resourceUsage[free!.id] =
            (_c.combat.resourceUsage[free.id] ?? 0) + 1;
      }
      CombatOps.summonCompanion(
        _c.combat,
        option,
        summoned,
        _companionVars(s, spellLevel: level),
        concentration: concentrates,
        concentratingOn: spell?.name ?? '',
      );
    });

    // Que la invocación te haya gastado un espacio o cortado otro conjuro no
    // puede ser una sorpresa que se descubra después mirando otra tarjeta.
    final notes = [
      if (spendsSlot) 'gastaste un espacio de nivel $level',
      if (castsFree) 'sin gastar espacio, por ${free!.name}',
      if (brokeConcentration)
        'perdiste la concentración anterior'
      else if (concentrates)
        'quedás concentrado en él',
    ];
    _snack(
      notes.isEmpty
          ? '${summoned.name} invocado.'
          : '${summoned.name} invocado: ${notes.join('; ')}.',
    );
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
              const SizedBox(width: 8),
              Text(
                'CA ${resolved.armorClass}',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
          // Las marcas van en su propia línea y no al lado del nombre: en una
          // columna angosta, nombre + dos píldoras + CA no entran.
          if (instance.spellLevel > 0 || instance.concentration)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (instance.spellLevel > 0)
                    GoldPill('Espacio de nivel ${instance.spellLevel}'),
                  // Que se vaya al cortar la concentración tiene que estar
                  // escrito en el compañero, no solo en la tarjeta de Conjuros.
                  if (instance.concentration) const GoldPill('Concentración'),
                ],
              ),
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
                  color: pal.crimson,
                ),
              ),
              const SizedBox(width: 8),
              if (instance.tempHp > 0) GoldPill('+${instance.tempHp} temp'),
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
                onPressed: () {
                  final destroyed = CombatOps.damageCompanion(
                    _c.combat,
                    instance,
                    _companionAmount,
                  );
                  _mutateCombat(() => _companionAmountCtrl.clear());
                  // Desaparecer sin decir nada se lee como un error de la app.
                  if (destroyed) _snack('${resolved.name} fue destruido.');
                },
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

  Widget _companionAction(ResolvedCreatureAction a) => CreatureActionRow(
    name: a.name,
    description: a.description,
    attackBonus: a.isAttack ? _signed(a.attackBonus!) : null,
    damage: a.damage,
    damageType: a.damageType,
    reach: a.reach,
    tag: a.kind == CreatureActionKind.action ? null : a.kind.label,
  );

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

  /// Tira de círculos llenos/vacíos para un contador chico.
  ///
  /// Sale de `_deathSaves` y la comparte el Cansancio. `UsagePips` no sirve
  /// para ninguno de los dos: pinta los llenos en oro —que se lee como "algo
  /// bueno que todavía te queda"— y su etiqueta accesible habla de "usos
  /// disponibles", que acá sería mentira. Un nivel de cansancio no es un uso
  /// disponible.
  Widget _statePips(int filled, int total, Color color, {String? semantics}) {
    final marks = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        total,
        (i) => Icon(
          i < filled ? Icons.circle : Icons.circle_outlined,
          color: color,
          size: 20,
        ),
      ),
    );
    return semantics == null
        ? marks
        : Semantics(label: semantics, excludeSemantics: true, child: marks);
  }

  /// Cansancio e Inspiración Heroica, en una sola tarjeta.
  ///
  /// Van juntos y no en dos tarjetas porque son los dos contadores chicos que
  /// modifican **cómo tirás**, y una tarjeta plegable por cada casillero sería
  /// más cromo que información. Comparten fila con los descansos porque el
  /// botón de descanso largo es justo lo que mueve a los dos: baja un nivel de
  /// cansancio y, si tenés el rasgo, devuelve la inspiración.
  Widget _stateCard(ComputedSheet s) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final n = _c.combat.exhaustion;
    final tiene = _c.combat.heroicInspiration;

    return sheetCard(
      icon: Icons.monitor_heart_outlined,
      title: 'Estado',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Cansancio'),
            const SizedBox(height: 6),
            // Wrap y no Row: los seis círculos más los dos botones no entran en
            // el ancho de un teléfono, igual que en las salvaciones de muerte.
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statePips(
                  n,
                  maxExhaustionLevel,
                  pal.crimson,
                  semantics: 'Cansancio: nivel $n de $maxExhaustionLevel',
                ),
                // El "−" es lo bueno acá y el "+" lo malo, al revés que en un
                // recurso: por eso los tooltips dicen la dirección en vez de
                // "Usar" y "Restaurar".
                SpendRecoverButtons(
                  spendTooltip: 'Bajar un nivel de cansancio',
                  recoverTooltip: 'Subir un nivel de cansancio',
                  onSpend: n <= 0
                      ? null
                      : () => _mutateCombat(() => _c.combat.exhaustion = n - 1),
                  onRecover: n >= maxExhaustionLevel
                      ? null
                      : () {
                          _mutateCombat(() => _c.combat.exhaustion = n + 1);
                          if (n + 1 >= maxExhaustionLevel) {
                            showAppMessage(
                              context,
                              'Cansancio nivel $maxExhaustionLevel: tu '
                              'personaje muere.',
                              tone: AppMessageTone.error,
                            );
                          }
                        },
                ),
              ],
            ),
            if (n >= 1)
              Text(
                'Los números de la ficha ya vienen con −${2 * n} en pruebas, '
                'salvaciones, ataques e iniciativa, y la velocidad con '
                '−${5 * n} pies. No lo restes otra vez. También le entra a las '
                'salvaciones de muerte, que no llevan número.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            if (n >= maxExhaustionLevel)
              // Color más ícono más texto: el color nunca es el único que
              // carga el significado.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: pal.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nivel $maxExhaustionLevel: tu personaje muere. La '
                        'ficha no lo aplica ni te toca los PG — esa decisión '
                        'es de la mesa.',
                        style: TextStyle(fontSize: 12, color: pal.crimson),
                      ),
                    ),
                  ],
                ),
              ),
            const SectionRule(),
            const Eyebrow('Inspiración Heroica'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Acá el oro de `UsagePips` significa lo correcto —algo bueno
                // que tenés— y con `max: 1` queda una sola estrella, que es la
                // forma exacta de la regla.
                UsagePips(
                  max: 1,
                  filled: tiene ? 1 : 0,
                  filledIcon: Icons.star,
                  emptyIcon: Icons.star_border,
                ),
                // El Wrap ya separa: no hace falta un SizedBox entre medio.
                if (s.heroicInspirationOnLongRest)
                  const GoldPill('La ganás al descansar'),
                SpendRecoverButtons(
                  spendTooltip: 'Gastar la Inspiración Heroica',
                  recoverTooltip: 'Marcar que la tenés',
                  onSpend: !tiene
                      ? null
                      : () => _mutateCombat(
                          () => _c.combat.heroicInspiration = false,
                        ),
                  onRecover: tiene
                      ? null
                      : () => _mutateCombat(
                          () => _c.combat.heroicInspiration = true,
                        ),
                ),
              ],
            ),
            Text(
              'Se gasta para repetir cualquier dado inmediatamente después de '
              'tirarlo, y hay que usar el resultado nuevo. Nunca más de una.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
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
      children: conditions.entries.map((e) {
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
