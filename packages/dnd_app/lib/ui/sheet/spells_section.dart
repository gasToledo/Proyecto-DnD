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
            ..sort((a, b) => compareContentNames(a.name, b.name)));
    final spells = sc == null
        ? <Spell>[]
        : (_c.spellIds.map((id) => repo.spell(id)).whereType<Spell>().toList()
            ..sort(
              (a, b) => a.level != b.level
                  ? a.level.compareTo(b.level)
                  : compareContentNames(a.name, b.name),
            ));

    // Siempre preparados por un rasgo (subclase del Artífice, Conjuros de
    // Juramento). Se lanzan con los espacios normales, así que van con los
    // demás conjuros de clase y no con los innatos.
    final alwaysPrepared =
        sheetArg.alwaysPreparedSpellIds
            .map((id) => repo.spell(id))
            .whereType<Spell>()
            .toList()
          ..sort(
            (a, b) => a.level != b.level
                ? a.level.compareTo(b.level)
                : compareContentNames(a.name, b.name),
          );

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
                    child: StatPlaque(
                      label: 'CD SALV.',
                      value: '${sc.saveDc}',
                      semantics:
                          'Clase de dificultad de las salvaciones contra tus '
                          'conjuros: ${sc.saveDc}',
                    ),
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
                    // La placa muestra la abreviatura porque el ancho es un
                    // tercio de la fila; dicha en voz alta no se entiende.
                    child: StatPlaque(
                      label: 'APTITUD',
                      value: sc.ability.abbr,
                      semantics: 'Aptitud mágica: ${sc.ability.label}',
                    ),
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

            if ([
              ...cantrips,
              ...spells,
              ...alwaysPrepared,
            ].any((s) => s.actionType != SpellActionType.longer)) ...[
              const SizedBox(height: 12),
              const ActionTypeLegend(),
            ],

            if (sheet.innateSpells.isNotEmpty) ...[
              if (sc != null) const SizedBox(height: 20),
              // No solo de especie: desde las invocaciones del Brujo también
              // los concede una elección abierta.
              const Eyebrow('Conjuros de rasgos'),
              const SizedBox(height: 6),
              DenseRows(
                children: [
                  for (final innate in sheet.innateSpells)
                    _innateSpellRow(innate),
                ],
              ),
            ],

            // Transformado no podés lanzar, salvo que un rasgo lo levante
            // (Conjurar como Bestia). El nivel al que eso pasa lo declara el
            // contenido, no este `if`.
            if (wildShapeForm case final beast?
                when !(sheetArg.wildShape?.canCast ?? false)) ...[
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
                    Icon(Icons.block, size: 18, color: pal.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En forma de ${beast.name} no podés lanzar conjuros.',
                      ),
                    ),
                  ],
                ),
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

            if (alwaysPrepared.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Eyebrow('Siempre preparados'),
              const SizedBox(height: 6),
              Text(
                'Los concede un rasgo y no ocupan cupo: se lanzan con tus '
                'espacios de conjuro como cualquier preparado.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              DenseRows(
                children: [for (final s in alwaysPrepared) _spellRow(s)],
              ),
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
                alwaysPrepared.isEmpty &&
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
      InnateSpellUse.oncePerShortRest => '1/descanso corto',
      InnateSpellUse.proficiencyBonusPerLongRest =>
        'Competencia/descanso largo',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: spell == null
                  ? null
                  : () => _showSpellDialog(spell, innate: innate),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (spell != null &&
                          spell.actionType != SpellActionType.longer) ...[
                        ActionTypeIcon(spell.actionType),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          innate.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
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
          if (innate.isReplaceable)
            IconButton(
              onPressed: () => _openInnateCantripPicker(innate),
              icon: const Icon(Icons.swap_horiz, size: 20),
              tooltip: 'Cambiar tras un descanso largo',
            ),
          if (spell?.concentration == true)
            TextButton(
              key: ValueKey('concentrate-innate-${innate.spellId}'),
              onPressed: () => _concentrate(innate.name),
              child: const Text('Concentrar'),
            ),
        ],
      ),
    );
  }

  /// Empieza a concentrarse en [spell].
  ///
  /// Concentrarse en otro conjuro corta el anterior, y
  /// `CombatOps.startConcentration` se lleva a los compañeros que lo sostenían.
  /// El botón lo hacía en silencio: un espíritu invocado desaparecía de la
  /// ficha sin que nada lo dijera. La invocación ya avisaba lo mismo; este
  /// camino no podía ser el que no.
  Future<void> _concentrate(String spell) async {
    final previous = _c.combat.concentratingOn;
    // Volver a tocar el conjuro en que ya te concentrás no cambia nada en la
    // mesa, pero para el motor sí: despediría a lo que ese mismo conjuro
    // sostiene.
    if (previous == spell) return;

    final dependents = [
      for (final i in _c.combat.companions)
        if (i.concentration) repo.creature(i.creatureId)?.name ?? i.creatureId,
    ];
    final leaving = dependents.join(', ');
    final goes = dependents.length == 1 ? 'se va' : 'se van';

    // Perder un compañero se pregunta antes; cambiar de conjuro sin nada que
    // dependa de él solo se avisa después, igual que en la invocación.
    if (dependents.isNotEmpty) {
      final ok = await _confirmDialog(
        'Cortar la concentración',
        'Concentrarte en $spell termina '
            '${previous ?? 'tu concentración actual'}, y con ella $goes '
            '$leaving.',
        confirmLabel: 'Concentrar igual',
      );
      if (!ok || !mounted) return;
    }

    _mutateCombat(() => CombatOps.startConcentration(_c.combat, spell));
    if (previous != null) {
      _snack(
        dependents.isEmpty
            ? 'Te concentrás en $spell: dejaste $previous.'
            : 'Te concentrás en $spell: dejaste $previous y $goes $leaving.',
      );
    }
  }

  /// Cambia un truco innato que el rasgo declara reemplazable (Alto Elfo, Don
  /// Feérico del Khoravar).
  ///
  /// Las opciones salen de las listas que declara el rasgo, acotadas al nivel
  /// del truco original: la regla es cambiar un truco por otro truco, no por un
  /// conjuro. La elección se guarda contra `grantedSpellId` —el conjuro del
  /// contenido— para que volver al original sea sacar la entrada.
  void _openInnateCantripPicker(InnateSpell innate) {
    final granted = repo.spell(innate.grantedSpellId);
    final options =
        <String, Spell>{
            for (final listId in innate.replaceableFrom)
              for (final spell in repo.spellsForList(listId))
                if (spell.level == innate.level) spell.id: spell,
          }.values.toList()
          // El del rasgo primero y el resto alfabético: volver al original es la
          // acción más frecuente y en una lista de más de treinta trucos quedaba
          // enterrada donde cayera por nombre.
          ..sort((a, b) {
            if (a.id == innate.grantedSpellId) return -1;
            if (b.id == innate.grantedSpellId) return 1;
            return compareContentNames(a.name, b.name);
          });

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Cambiar ${granted?.name ?? innate.grantedSpellId}',
        width: 420,
        scrollable: false,
        content: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Al terminar un descanso largo podés cambiarlo por otro truco '
                'de ${_listNames(innate.replaceableFrom)}.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RadioGroup<String>(
                  groupValue: innate.spellId,
                  onChanged: (id) {
                    if (id != null) _setInnateCantrip(innate, id);
                    Navigator.of(dialogContext).pop();
                  },
                  child: ListView(
                    children: [
                      for (final spell in options)
                        RadioListTile<String>(
                          value: spell.id,
                          title: Text(spell.name),
                          subtitle: spell.id == innate.grantedSpellId
                              ? const Text('El del rasgo')
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          DialogAction(
            'Cerrar',
            primary: true,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  /// Guarda el reemplazo. Volver al truco del rasgo **borra** la entrada en vez
  /// de escribirla apuntando a sí misma, para que el mapa no acumule ruido.
  void _setInnateCantrip(InnateSpell innate, String spellId) {
    final choices = Map<String, String>.from(_c.innateCantripChoices);
    if (spellId == innate.grantedSpellId) {
      choices.remove(innate.grantedSpellId);
    } else {
      choices[innate.grantedSpellId] = spellId;
    }
    _replace(_c.copyWith(innateCantripChoices: choices));
  }

  /// Nombres de las listas de las que se puede tomar el reemplazo, para el
  /// texto del diálogo ("la lista de Mago", "Clérigo, Druida o Mago").
  String _listNames(List<String> classIds) {
    final names = [
      for (final id in classIds) repo.characterClass(id)?.name ?? id,
    ];
    if (names.length == 1) return 'la lista de ${names.single}';
    return '${names.sublist(0, names.length - 1).join(", ")} o ${names.last}';
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
                            if (s.actionType != SpellActionType.longer) ...[
                              ActionTypeIcon(s.actionType),
                              const SizedBox(width: 6),
                            ],
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
              key: ValueKey('concentrate-${s.id}'),
              onPressed: () => _concentrate(s.name),
              child: const Text('Concentrar'),
            ),
        ],
      ),
    );
  }

  /// Detalle de un conjuro. [innate] llega cuando lo concede un rasgo: esos se
  /// lanzan con la característica que fija el rasgo, que puede no ser la de la
  /// clase, así que los números tienen que salir de ahí y no de `spellcasting`.
  void _showSpellDialog(Spell s, {InnateSpell? innate}) {
    final sc = sheet.spellcasting;
    final ability = innate?.ability ?? sc?.ability;
    final attackBonus = innate?.attackBonus ?? sc?.attackBonus;
    final saveDc = innate?.saveDc ?? sc?.saveDc;

    showSpellDetailsDialog(
      context,
      s,
      contextTitle: ability == null ? '' : 'Con este personaje',
      contextText: ability == null
          ? ''
          : 'Lanzás con ${ability.label} '
                '(${_signed(sheet.abilityModifiers[ability]!)}). '
                'Ataque de conjuro ${_signed(attackBonus!)} · '
                'CD de salvación $saveDc.',
    );
  }
}
