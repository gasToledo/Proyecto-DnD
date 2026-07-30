part of 'level_up_screen.dart';

extension _LevelUpSections on _LevelUpScreenState {
  Widget _buildStep(_LevelUpStepKind kind) => switch (kind) {
    _LevelUpStepKind.overview => _buildOverviewStep(),
    _LevelUpStepKind.hitPoints => _buildHitPointsStep(),
    _LevelUpStepKind.subclass => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LevelUpIntro(
          eyebrow: 'Elegís vos',
          title: 'Tu camino dentro de la clase',
          body:
              'La subclase define nuevos rasgos y decisiones para los próximos '
              'niveles. Revisá cada opción antes de continuar.',
        ),
        const SizedBox(height: 22),
        _buildSubclassSection(),
      ],
    ),
    _LevelUpStepKind.abilityScore => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LevelUpIntro(
          eyebrow: 'Elegís vos',
          title: 'Mejora tu personaje',
          body:
              'Aumentá tus características o elegí una dote. La decisión se '
              'previsualiza antes de modificar la ficha.',
        ),
        const SizedBox(height: 22),
        _buildAsi(),
      ],
    ),
    _LevelUpStepKind.features => _buildFeaturesStep(),
    _LevelUpStepKind.spells => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: 'Magia',
          title: 'Tus conjuros a nivel $_newLevel',
          body:
              'Revisá los espacios y la cantidad de conjuros preparados. '
              'Podés actualizar tu selección sin salir de la subida de nivel.',
        ),
        const SizedBox(height: 18),
        _buildSpellSection(),
      ],
    ),
    _LevelUpStepKind.review => _buildReviewStep(),
  };

  Widget _buildOverviewStep() {
    final features = _gainedFeatures();
    final choices = <Widget>[
      if (_needsSubclass)
        const _LevelUpCard(
          icon: Icons.shield,
          title: 'Elegir subclase',
          body: 'Define la especialización del personaje y sus rasgos futuros.',
          tag: 'ELEGÍS VOS',
        ),
      if (_isAsi)
        const _LevelUpCard(
          icon: Icons.trending_up,
          title: 'Mejora o dote',
          body: 'Repartí una mejora de características o incorporá una dote.',
          tag: 'ELEGÍS VOS',
        ),
      if (_hasSpellcasting)
        const _LevelUpCard(
          icon: Icons.auto_stories,
          title: 'Revisar conjuros',
          body: 'Comprobá tus espacios y actualizá los conjuros preparados.',
          tag: 'OPCIONAL',
        ),
    ];
    final automatic = <Widget>[
      _LevelUpCard(
        icon: Icons.favorite,
        title: 'Puntos de golpe',
        body:
            'Sumás el resultado de tu dado d$_hitDie y tu modificador de '
            'Constitución.',
        tag: 'AUTOMÁTICO',
      ),
      if (features.isNotEmpty)
        _LevelUpCard(
          icon: Icons.workspace_premium,
          title: features.length == 1
              ? features.single.name
              : '${features.length} rasgos de clase',
          body: features.map((feature) => feature.name).join(' · '),
          tag: 'AUTOMÁTICO',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 142,
                height: 142,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.plaque,
                  border: Border.all(color: context.palette.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: context.palette.gold.withAlpha(45),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NIVEL',
                      style: TextStyle(
                        color: context.palette.gold,
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      '$_newLevel',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 62,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.character.name} está listo para crecer',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 28),
              ),
              const SizedBox(height: 7),
              Text(
                'Primero revisaremos qué cambia automáticamente y después '
                'resolveremos tus decisiones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Eyebrow('Cambios automáticos'),
        _responsiveCards(automatic),
        if (choices.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Eyebrow('Decisiones de esta subida'),
          _responsiveCards(choices),
        ],
      ],
    );
  }

  Widget _responsiveCards(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _buildHitPointsStep() {
    final compiler = CharacterCompiler(widget.repo);
    final before = compiler.compile(widget.character);
    final after = compiler.compile(_buildUpdated());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: 'Paso automático',
          title: 'Más puntos de golpe',
          body:
              'Elegí el promedio seguro o tirá tu dado de golpe d$_hitDie. '
              'La Constitución se aplica automáticamente al compilar la ficha.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final picker = _LevelUpCard(
              icon: Icons.casino,
              title: 'Dado de golpe d$_hitDie',
              body: _hpMethod == _HpMethod.roll && _rolledHp == null
                  ? 'Todavía no hay un resultado.'
                  : 'Ganancia base del nivel: +$_hpGain PG.',
              trailing: Text(
                _hpMethod == _HpMethod.roll && _rolledHp == null
                    ? '—'
                    : '$_hpGain',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 30,
                  color: context.palette.gold,
                ),
              ),
            );
            final preview = _LevelUpCard(
              icon: Icons.favorite,
              title: 'PG máximos',
              body:
                  'La revisión final incorporará también cualquier rasgo o '
                  'mejora de Constitución elegida después.',
              trailing: Text(
                '${before.maxHp} → ${after.maxHp}',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  color: context.palette.crimson,
                ),
              ),
            );
            return Column(
              children: [
                if (compact) ...[
                  picker,
                  const SizedBox(height: 12),
                  preview,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: picker),
                      const SizedBox(width: 14),
                      Expanded(child: preview),
                    ],
                  ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_HpMethod>(
                    segments: [
                      ButtonSegment(
                        value: _HpMethod.average,
                        icon: const Icon(Icons.balance),
                        label: Text('Promedio (${averageHitDie(_hitDie)})'),
                      ),
                      const ButtonSegment(
                        value: _HpMethod.roll,
                        icon: Icon(Icons.casino),
                        label: Text('Tirar'),
                      ),
                    ],
                    selected: {_hpMethod},
                    onSelectionChanged: (selection) => _updateState(() {
                      _hpMethod = selection.first;
                      _rolledHp = null;
                    }),
                  ),
                ),
                if (_hpMethod == _HpMethod.roll) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _updateState(
                        () => _rolledHp = Dice().rollHitDie(_hitDie),
                      ),
                      icon: const Icon(Icons.casino),
                      label: Text(
                        _rolledHp == null ? 'Tirar el dado' : 'Volver a tirar',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturesStep() {
    final features = _gainedFeatures();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: 'Automático',
          title: 'Rasgos ganados a nivel $_newLevel',
          body:
              'Estos rasgos provienen de tu clase y subclase. Se aplicarán '
              'automáticamente cuando confirmes la subida.',
        ),
        const SizedBox(height: 20),
        DenseRows(
          children: [
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 20,
                      color: context.palette.gold,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.name,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (feature.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              feature.description,
                              style: TextStyle(
                                height: 1.5,
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final compiler = CharacterCompiler(widget.repo);
    final before = compiler.compile(widget.character);
    final updated = _buildUpdated();
    final after = compiler.compile(updated);
    final diff = diffSheets(before, after);
    final beforeResources = {
      for (final resource in before.resources) resource.id: resource,
    };
    final resourceRows = <Widget>[];
    for (final resource in after.resources) {
      final previous = beforeResources[resource.id];
      if (previous?.max == resource.max) continue;
      resourceRows.add(
        _ReviewRow(
          icon: Icons.bolt,
          label: resource.name,
          note: 'Recurso de clase',
          before: '${previous?.max ?? 0}',
          after: '${resource.max}',
        ),
      );
    }
    final beforeSpells = before.spellcasting;
    final afterSpells = after.spellcasting;
    final beforeSlots = _slotSummary(beforeSpells?.slotsByLevel ?? const {});
    final afterSlots = _slotSummary(afterSpells?.slotsByLevel ?? const {});
    final rows = <Widget>[
      _ReviewRow(
        icon: Icons.military_tech,
        label: 'Nivel',
        note: _klass?.name ?? widget.character.classId,
        before: '${widget.character.level}',
        after: '$_newLevel',
      ),
      _ReviewRow(
        icon: Icons.favorite,
        label: 'Puntos de golpe máximos',
        note: '+${diff.hpGained} en esta subida',
        before: '${before.maxHp}',
        after: '${after.maxHp}',
      ),
      if (diff.proficiencyBonusChanged)
        _ReviewRow(
          icon: Icons.verified,
          label: 'Bonificador de competencia',
          note: 'Se aplica a todas las competencias relevantes',
          before: '+${diff.proficiencyBonusFrom}',
          after: '+${diff.proficiencyBonusTo}',
        ),
      ...resourceRows,
      if (beforeSlots != afterSlots)
        _ReviewRow(
          icon: Icons.diamond_outlined,
          label: 'Espacios de conjuro',
          note: 'Por nivel de conjuro',
          before: beforeSlots,
          after: afterSlots,
        ),
      if (beforeSpells?.preparedCount != afterSpells?.preparedCount)
        _ReviewRow(
          icon: Icons.menu_book,
          label: 'Conjuros preparados',
          note: 'Capacidad del repertorio',
          before: '${beforeSpells?.preparedCount ?? 0}',
          after: '${afterSpells?.preparedCount ?? 0}',
        ),
      if (beforeSpells?.cantripsKnown != afterSpells?.cantripsKnown)
        _ReviewRow(
          icon: Icons.flare,
          label: 'Trucos',
          note: 'Se lanzan sin gastar espacios',
          before: '${beforeSpells?.cantripsKnown ?? 0}',
          after: '${afterSpells?.cantripsKnown ?? 0}',
        ),
      if (diff.extraAttacksGained > 0)
        _ReviewRow(
          icon: Icons.sports_martial_arts,
          label: 'Ataques por acción',
          note: 'Ataque Adicional',
          before: '${before.attacksPerAction}',
          after: '${after.attacksPerAction}',
        ),
      if (diff.weaponMasterySlotsGained > 0)
        _ReviewRow(
          icon: Icons.gavel,
          label: 'Maestrías de armas',
          note: 'Opciones disponibles',
          before: '${before.weaponMasterySlots}',
          after: '${after.weaponMasterySlots}',
        ),
      if (_needsSubclass && _subclassId != null)
        _ReviewRow(
          icon: Icons.shield,
          label: 'Subclase',
          note: 'Nueva especialización',
          before: '—',
          after: widget.repo.subclass(_subclassId!)?.name ?? _subclassId!,
        ),
      if (_isAsi)
        _ReviewRow(
          icon: _asiKind == _AsiKind.feat
              ? Icons.workspace_premium
              : Icons.trending_up,
          label: _asiKind == _AsiKind.feat ? 'Dote' : 'Características',
          note: _asiKind == _AsiKind.feat
              ? 'Nueva capacidad'
              : 'Mejora permanente',
          before: '—',
          after: _asiReviewLabel(),
        ),
      if (_newCantrips != null || _newSpells != null)
        _ReviewRow(
          icon: Icons.auto_stories,
          label: 'Conjuros preparados',
          note: 'Selección actualizada',
          before:
              '${widget.character.cantripIds.length + widget.character.spellIds.length}',
          after: '${updated.cantripIds.length + updated.spellIds.length}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: 'Revisión final',
          title: 'Así queda ${widget.character.name}',
          body:
              'Revisá los cambios antes de escribirlos en la ficha. Podés '
              'volver a cualquier paso disponible desde la barra superior.',
        ),
        const SizedBox(height: 20),
        DenseRows(children: rows),
        if (_gainedFeatures().isNotEmpty) ...[
          const SizedBox(height: 22),
          const Eyebrow('Rasgos incorporados'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feature in _gainedFeatures()) GoldPill(feature.name),
            ],
          ),
        ],
      ],
    );
  }

  String _asiReviewLabel() {
    if (_asiKind == _AsiKind.feat) {
      return widget.repo.feat(_featId!)?.name ?? _featId!;
    }
    return _abilityIncreases.entries
        .map((entry) => '${entry.key.abbr} +${entry.value}')
        .join(' · ');
  }

  String _slotSummary(Map<int, int> slots) {
    if (slots.isEmpty) return '—';
    final entries = slots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => 'Nv${entry.key} ×${entry.value}').join(' · ');
  }

  Widget _buildSubclassSection() {
    if (!_needsSubclass) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('Subclase (nivel $_newLevel)'),
        const SizedBox(height: 8),
        for (final s in _subclassOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _updateState(() => _subclassId = s.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _subclassId == s.id
                      ? context.palette.goldSoft
                      : context.palette.plaque,
                  border: Border.all(
                    color: _subclassId == s.id
                        ? context.palette.gold
                        : context.palette.hairline,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _subclassId == s.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _subclassId == s.id ? context.palette.gold : muted,
                    ),
                    const SizedBox(width: 10),
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SourceBadge(s.source),
                            ],
                          ),
                          if (s.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              s.description,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Sección de conjuros del nivel nuevo (solo para lanzadores): muestra los
  /// espacios y cupos al nuevo nivel, marca los niveles de espacio recién
  /// abiertos y permite preparar/aprender conjuros sin salir de la subida.
  Widget _buildSpellSection() {
    final compiler = CharacterCompiler(widget.repo);
    final after = compiler.compile(_buildUpdated()).spellcasting;
    if (after == null) return const SizedBox.shrink();
    final before = compiler.compile(widget.character).spellcasting;
    final beforeLevels = before?.slotsByLevel.keys.toSet() ?? const <int>{};

    final slots = after.slotsByLevel.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final prepared = _newCantrips != null || _newSpells != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Eyebrow('Conjuros a nivel $_newLevel'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in slots)
              _SlotBadge(
                level: e.key,
                count: e.value,
                isNew: !beforeLevels.contains(e.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            'Preparás ${after.preparedCount} conjuros',
            if (after.cantripsKnown > 0) '${after.cantripsKnown} trucos',
          ].join(' · '),
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openSpellPrep(after),
          icon: Icon(prepared ? Icons.check : Icons.auto_stories, size: 18),
          label: Text(prepared ? 'Conjuros actualizados' : 'Preparar conjuros'),
        ),
      ],
    );
  }

  void _openSpellPrep(Spellcasting sc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpellEditScreen(
          character: _buildUpdated(),
          repo: widget.repo,
          spellcasting: sc,
          onSave: (cantrips, spells) => _updateState(() {
            _newCantrips = cantrips;
            _newSpells = spells;
          }),
        ),
      ),
    );
  }

  Widget _buildAsi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('Mejora de característica (nivel $_newLevel)'),
        SegmentedButton<_AsiKind>(
          segments: const [
            ButtonSegment(
              value: _AsiKind.improve,
              label: Text('Mejorar características'),
            ),
            ButtonSegment(value: _AsiKind.feat, label: Text('Tomar dote')),
          ],
          selected: {_asiKind},
          onSelectionChanged: (s) => _updateState(() => _asiKind = s.first),
        ),
        const SizedBox(height: 12),
        if (_asiKind == _AsiKind.improve)
          _buildImprove()
        else
          _buildFeatPicker(),
      ],
    );
  }

  Widget _buildImprove() {
    final compiler = CharacterCompiler(widget.repo);
    final before = compiler.compile(widget.character);
    final after = compiler.compile(_buildUpdated());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_ImproveMode>(
          segments: const [
            ButtonSegment(value: _ImproveMode.plusTwo, label: Text('+2 a una')),
            ButtonSegment(
              value: _ImproveMode.plusOneTwo,
              label: Text('+1 a dos'),
            ),
          ],
          selected: {_impMode},
          onSelectionChanged: (s) => _updateState(() {
            _impMode = s.first;
            _abilityB = null;
          }),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 430
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ability in Ability.values)
                  SizedBox(
                    width: width,
                    child: _LevelUpCard(
                      icon: Icons.add_circle_outline,
                      title: ability.label,
                      body:
                          '${before.abilityScores[ability] ?? 0} → '
                          '${after.abilityScores[ability] ?? before.abilityScores[ability] ?? 0}',
                      tag: _abilityIncreases[ability] == null
                          ? 'SIN CAMBIOS'
                          : '+${_abilityIncreases[ability]}',
                      selected: _abilityIncreases.containsKey(ability),
                      onTap: () => _selectAbility(ability),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          _impMode == _ImproveMode.plusTwo
              ? 'Elegí una característica para sumar 2 puntos.'
              : 'Elegí dos características distintas para sumar 1 punto a cada una.',
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _selectAbility(Ability ability) {
    _updateState(() {
      if (_impMode == _ImproveMode.plusTwo) {
        _abilityA = ability;
        _abilityB = null;
        return;
      }
      if (_abilityA == ability) {
        _abilityA = _abilityB;
        _abilityB = null;
      } else if (_abilityB == ability) {
        _abilityB = null;
      } else if (_abilityA == null) {
        _abilityA = ability;
      } else {
        _abilityB = ability;
      }
    });
  }

  Widget _buildFeatPicker() {
    // Los prerrequisitos se evalúan sobre el personaje tal como quedará al
    // nuevo nivel: las marcas mayores exigen nivel 4, y a nivel 3 el personaje
    // todavía no lo tiene aunque esté subiendo justo a ese nivel.
    final target = _buildUpdated(withFeat: false);
    final sheet = CharacterCompiler(widget.repo).compile(target);
    final validator = CharacterValidator(widget.repo);
    final held = validator.heldFeatIds(target);

    // No se puede repetir una dote ya tomada salvo que sea repetible (2024).
    // Se mide contra `held`, que incluye la dote de origen del trasfondo y el
    // estilo de combate, no solo `featIds`: con el catálogo oficial no hay
    // solapamiento porque acá solo se ofrecen dotes generales, pero un
    // trasfondo homebrew puede conceder cualquiera.
    final allFeats =
        widget.repo.feats.values
            .where((f) => f.category == 'general')
            // "Mejora de Característica" ya es la opción hermana de este
            // selector y necesita registrar sus puntuaciones, no un featId.
            .where((f) => f.id != 'ability-score-improvement')
            .where((f) => f.repeatable || !held.contains(f.id))
            .where((f) {
              final group = f.effectiveExclusiveGroup;
              return group == null ||
                  !held.any(
                    (id) =>
                        id != f.id &&
                        widget.repo.feat(id)?.effectiveExclusiveGroup == group,
                  );
            })
            // Las reglas viven en el motor: la UI solo esconde lo inelegible.
            .where(
              (f) =>
                  validator.unmetFeatPrerequisite(
                    f,
                    target,
                    sheet,
                    held: held,
                  ) ==
                  null,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (allFeats.isEmpty) {
      return Text(
        'No quedan dotes disponibles.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final query = _featQuery.trim().toLowerCase();
    final feats = query.isEmpty
        ? allFeats
        : allFeats
              .where(
                (feat) =>
                    feat.name.toLowerCase().contains(query) ||
                    featSummary(feat).toLowerCase().contains(query),
              )
              .toList();
    final selected = _featId == null
        ? null
        : allFeats.where((f) => f.id == _featId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Buscar dote',
            hintText: 'Nombre o efecto',
            border: const OutlineInputBorder(),
            suffixText: '${feats.length} disponibles',
          ),
          onChanged: (value) => _updateState(() => _featQuery = value),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final list = SizedBox(
              height: 410,
              child: feats.isEmpty
                  ? Center(
                      child: Text(
                        'Ninguna dote coincide con “$_featQuery”.',
                        style: TextStyle(color: context.palette.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: feats.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final feat = feats[index];
                        return _LevelUpCard(
                          icon: Icons.workspace_premium,
                          title: feat.name,
                          body: featSummary(feat),
                          selected: _featId == feat.id,
                          trailing: SourceBadge(feat.source),
                          onTap: () => _updateState(() => _featId = feat.id),
                        );
                      },
                    ),
            );
            final detail = selected != null
                ? _FeatDetail(selected)
                : _LevelUpCard(
                    icon: Icons.touch_app,
                    title: 'Elegí una dote',
                    body:
                        'Cada dote cambia cómo se juega el personaje. '
                        'Seleccioná una para revisar su efecto completo.',
                  );
            if (!wide) {
              return Column(
                children: [list, const SizedBox(height: 14), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                const SizedBox(width: 16),
                SizedBox(width: 320, child: detail),
              ],
            );
          },
        ),
      ],
    );
  }
}
