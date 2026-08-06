part of '../sheet_screen.dart';

extension _SheetGeneralSection on _SheetScreenState {
  // ------------------------------------------------------------- Personaje

  Widget _buildPersonaje() {
    final s = sheet;
    final warnings = CharacterValidator(repo).validate(_c);
    final choiceSlots = s.proficiencyChoiceSlots;
    // Lo pendiente ya sale como advertencia con su propio bot\u00f3n; ac\u00e1 queda
    // s\u00f3lo lo que el motor no reporta, que es poder cambiar lo ya elegido.
    final canReplace = choiceSlots.any(
      (slot) => slot.replaceable && slot.pending == 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canReplace) ...[
          sheetCard(
            icon: Icons.handyman,
            title: 'Competencia reemplazable',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Este rasgo permite cambiar la elecci\u00f3n.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _resolveProficiencyChoices,
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (warnings.isNotEmpty) ...[
          sheetCard(
            icon: Icons.warning_amber,
            title: 'Advertencias',
            child: DenseRows(
              children: [
                for (final w in warnings)
                  ListTile(
                    dense: true,
                    // Lo pendiente (info) no es una ficha rota: distinguirlo
                    // evita que una elecci\u00f3n por hacer parezca un error.
                    leading: Icon(
                      w.severity == WarningSeverity.info
                          ? Icons.info_outline
                          : Icons.warning_amber,
                      color: w.severity == WarningSeverity.info
                          ? context.palette.gold
                          : context.palette.crimson,
                    ),
                    title: Text(w.message),
                    trailing: switch (_resolverFor(w.code)) {
                      final resolver? => TextButton(
                        onPressed: resolver,
                        child: const Text('Resolver'),
                      ),
                      _ => null,
                    },
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

  /// El editor que resuelve una advertencia, o `null` si no hay ninguno.
  ///
  /// El mapeo vive acá y no en el motor: `code` ya es el identificador estable
  /// —lo fijan los tests del motor— y agregarle un campo sería un segundo
  /// identificador paralelo, con el motor opinando sobre pantallas que no
  /// conoce. Un código nuevo simplemente no trae botón hasta que se le escriba
  /// uno.
  ///
  /// Cada editor resuelve **todas** las instancias de su tipo, así que no hace
  /// falta saber cuál advertencia disparó el botón.
  VoidCallback? _resolverFor(String code) => switch (code) {
    'size_pending' || 'size_invalid' => _resolveSize,
    // Un linaje ausente, inexistente o de otra especie se arregla igual:
    // eligiendo uno válido. Si la especie no ofrece ninguno no hay qué elegir.
    'lineage_pending' || 'lineage_missing' || 'lineage_wrong_race'
        when repo.lineagesForRace(_c.raceId).isNotEmpty =>
      _resolveLineage,
    'species_spellcasting_ability_pending' => _resolveSpeciesAbility,
    'feature_choice_pending' => _resolveFeatureChoices,
    // El mismo código también sale cuando sobran competencias sin rasgo que
    // las conceda: ahí no hay nada que elegir y el diálogo saldría vacío.
    'proficiency_choice_count' when sheet.proficiencyChoiceSlots.isNotEmpty =>
      _resolveProficiencyChoices,
    _ => null,
  };

  Future<void> _resolveProficiencyChoices() async {
    final initial = sheet.proficiencyChoiceSlots;
    final choices = <String, List<String>>{
      for (final slot in initial) slot.groupId: List.of(slot.chosen),
    };

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewCharacter = _c.copyWith(
            chosenProficiencies: const [],
            proficiencyChoices: choices,
          );
          final preview = CharacterCompiler(repo).compile(previewCharacter);
          final slots = preview.proficiencyChoiceSlots;
          final fixed = <String>{
            ...preview.skillProficiencies,
            ...preview.toolProficiencies,
          };
          for (final selected in choices.values) {
            fixed.removeAll(selected);
          }

          bool complete() => slots.every((slot) {
            final selected = choices[slot.groupId] ?? const <String>[];
            return selected.length == slot.count &&
                selected.every(slot.options.contains);
          });

          return AlertDialog(
            title: const Text('Elegir competencias'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Las opciones que ya ten\u00e9s por otra v\u00eda quedan bloqueadas.',
                    ),
                    const SizedBox(height: 16),
                    for (final slot in slots) ...[
                      Text(
                        slot.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${choices[slot.groupId]?.length ?? 0}/${slot.count}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in slot.options)
                            Builder(
                              builder: (context) {
                                final selected =
                                    choices[slot.groupId]?.contains(id) ??
                                    false;
                                final selectedElsewhere = choices.entries
                                    .where((entry) => entry.key != slot.groupId)
                                    .expand((entry) => entry.value)
                                    .contains(id);
                                final locked =
                                    !selected &&
                                    (fixed.contains(id) || selectedElsewhere);
                                return FilterChip(
                                  label: Text(
                                    slot.skills.contains(id)
                                        ? Skill.labelFor(id)
                                        : toolProficiencyLabel(id),
                                  ),
                                  selected: selected,
                                  onSelected: locked
                                      ? null
                                      : (value) => setDialogState(() {
                                          final current =
                                              choices[slot.groupId] ??= [];
                                          if (!value) {
                                            current.remove(id);
                                          } else if (current.length <
                                              slot.count) {
                                            current.add(id);
                                          }
                                        }),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: complete()
                    ? () => Navigator.pop(dialogContext, choices)
                    : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    _replace(
      _c.copyWith(chosenProficiencies: const [], proficiencyChoices: result),
    );
  }

  /// Diálogo de una sola elección sobre una lista corta. Tocar una opción
  /// confirma: con una sola decisión, un botón "Guardar" sobra.
  Future<T?> _pickOne<T>({
    required String title,
    required String hint,
    required List<T> options,
    required String Function(T) label,
    required T? current,
  }) => showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(label(option)),
                  selected: option == current,
                  onSelected: (_) => Navigator.pop(dialogContext, option),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );

  Future<void> _resolveSize() async {
    final options = repo.race(_c.raceId)?.sizeOptions ?? const <String>[];
    if (options.isEmpty) return;
    final picked = await _pickOne<String>(
      title: 'Elegir tamaño',
      hint:
          'Esta especie abarca cuerpos de tamaños distintos: elegí el de tu '
          'personaje.',
      options: options,
      label: (size) => size,
      current: _c.chosenSize,
    );
    if (picked == null || !mounted) return;
    _replace(_c.copyWith(chosenSize: picked));
  }

  Future<void> _resolveLineage() async {
    final options = repo.lineagesForRace(_c.raceId);
    if (options.isEmpty) return;
    final current = options.where((l) => l.id == _c.lineageId).firstOrNull;
    final picked = await _pickOne<Lineage>(
      title: 'Elegir linaje',
      hint: 'El linaje decide los rasgos que aporta la especie.',
      options: options,
      label: (lineage) => lineage.name,
      current: current,
    );
    if (picked == null || !mounted) return;
    // La aptitud mágica no se limpia: los tres linajes que lanzan conjuros
    // ofrecen las mismas opciones, así que borrarla sólo obligaría a elegir de
    // nuevo lo mismo. Si el linaje nuevo la necesita y falta, la advertencia
    // correspondiente aparece con su propio botón.
    _replace(_c.copyWith(lineageId: picked.id));
  }

  Future<void> _resolveSpeciesAbility() async {
    final picked = await _pickOne<Ability>(
      title: 'Elegir aptitud mágica',
      hint: 'Se usa para la CD y los ataques de los conjuros del linaje.',
      options: const [Ability.intelligence, Ability.wisdom, Ability.charisma],
      label: (ability) => ability.label,
      current: _c.speciesSpellcastingAbility,
    );
    if (picked == null || !mounted) return;
    _replace(_c.copyWith(speciesSpellcastingAbility: picked));
  }

  /// Resuelve las elecciones abiertas pendientes (Estilo de Combate,
  /// Invocaciones Sobrenaturales…) sin recrear el personaje.
  ///
  /// Las opciones son dotes de la categoría que nombra cada slot y los
  /// prerrequisitos los evalúa el validador del motor, igual que en la creación
  /// y en la subida de nivel.
  Future<void> _resolveFeatureChoices() async {
    final validator = CharacterValidator(repo);
    final choices = <String, List<String>>{
      for (final slot in sheet.featureChoiceSlots)
        slot.groupId: List.of(_c.featureChoices[slot.groupId] ?? const []),
    };

    // Los grupos que no se editan acá se conservan: el motor no limpia solo las
    // elecciones huérfanas y borrarlas sería perder datos del jugador.
    Character withChoices(Map<String, List<String>> edited) =>
        _c.copyWith(featureChoices: {..._c.featureChoices, ...edited});

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = withChoices(choices);
          final previewSheet = CharacterCompiler(repo).compile(preview);
          final slots = previewSheet.featureChoiceSlots;

          bool complete() => slots.every(
            (slot) => (choices[slot.groupId] ?? const []).length >= slot.count,
          );

          return AlertDialog(
            title: const Text('Elegir rasgos'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slot in slots) ...[
                      Text(
                        slot.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Builder(
                        builder: (context) {
                          final chosen = choices[slot.groupId] ??= [];
                          final options = repo
                              .featsByCategory(slot.featCategory)
                              .where(
                                (f) =>
                                    chosen.contains(f.id) ||
                                    validator.unmetFeatPrerequisite(
                                          f,
                                          preview,
                                          previewSheet,
                                        ) ==
                                        null,
                              )
                              .toList();
                          if (options.isEmpty) {
                            return Text(
                              'No hay opciones disponibles todavía.',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          }
                          // ponytail: el `Set` no representa una opción
                          // repetible tomada dos veces. Acá sólo se completan
                          // huecos; para repetir está la subida de nivel, que
                          // sí lleva contador.
                          final selected = chosen.toSet();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${chosen.length}/${slot.count}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              CappedChipSelect(
                                options: {
                                  for (final f in options) f.id: f.name,
                                },
                                selected: selected,
                                max: slot.count,
                                onChanged: () => setDialogState(
                                  () =>
                                      choices[slot.groupId] = selected.toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: complete()
                    ? () => Navigator.pop(dialogContext, choices)
                    : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    _replace(withChoices(result));
  }

  Widget _identityCard() {
    final pal = context.palette;
    final bg = repo.background(_c.backgroundId)?.name ?? '—';
    final creatureType = repo.race(_c.raceId)?.creatureType ?? '—';
    final rows = <(String, String)>[
      ('Alineamiento', _c.alignment?.label ?? '—'),
      ('Tipo de criatura', creatureType),
      // El tamaño resuelto lo da la ficha compilada, no la especie: las que
      // dejan elegir traen ahí sólo el valor por defecto.
      ('Tamaño', sheet.size),
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
    // Los ids viajan en inglés porque son la clave estable del contenido; la
    // traducción la tiene el motor. Un id de arma concreta (el estoque del
    // Bardo) no está en esa tabla: lo resuelve el catálogo.
    final labels = <String>[
      for (final id in s.armorProficiencies) armorTrainingLabel(id),
      for (final id in s.weaponProficiencies)
        repo.weapon(id)?.name ?? weaponProficiencyLabel(id),
      for (final id in s.toolProficiencies) toolProficiencyLabel(id),
    ]..sort(compareContentNames);
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
    // 108 alcanza para las placas numéricas. Tamaño es la única cuyo valor es
    // una palabra ("Mediano" a Georgia 24 no entra) y por eso pide más ancho.
    Widget box(Widget child, {double width = 108}) =>
        SizedBox(width: width, child: child);
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
        box(StatPlaque(label: 'Tamaño', value: s.size), width: 152),
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
