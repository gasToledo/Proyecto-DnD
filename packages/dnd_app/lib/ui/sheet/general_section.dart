part of '../sheet_screen.dart';

extension _SheetGeneralSection on _SheetScreenState {
  // ------------------------------------------------------------- Personaje

  Widget _buildPersonaje() {
    final s = sheet;
    final warnings = CharacterValidator(repo).validate(_c);
    // Lo pendiente ya sale como advertencia con su propio bot\u00f3n; ac\u00e1 queda
    // s\u00f3lo lo que el motor no reporta, que es poder cambiar lo ya elegido.
    final canReplace = <(String, IconData, VoidCallback)>[
      if (s.proficiencyChoiceSlots.any(
        (slot) => slot.replaceable && slot.pending == 0,
      ))
        (
          'Competencia reemplazable',
          Icons.handyman,
          _resolveProficiencyChoices,
        ),
      // `FeatureChoiceSlot` no lleva `chosen`: es declarativo y lo elegido vive
      // en el personaje, as\u00ed que lo completo se cuenta desde ah\u00ed.
      if (s.featureChoiceSlots.any(
        (slot) =>
            slot.replaceable &&
            (_c.featureChoices[slot.groupId]?.length ?? 0) >= slot.count,
      ))
        ('Elecci\u00f3n reemplazable', Icons.style, _resolveFeatureChoices),
      if (s.spellChoiceSlots.any(
        (slot) => slot.replaceable && slot.pending == 0,
      ))
        ('Conjuros reemplazables', Icons.auto_fix_high, _resolveSpellChoices),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, icon, onPressed) in canReplace) ...[
          sheetCard(
            icon: icon,
            title: title,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Este rasgo permite cambiar la elecci\u00f3n.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onPressed,
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
          [
            _identityCard(),
            _abilitiesCard(s),
            _proficienciesCard(s),
            _languagesCard(s),
          ],
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
    'feat_spellcasting_ability_pending' => _resolveFeatAbilities,
    'feature_choice_pending' => _resolveFeatureChoices,
    'spell_choice_pending' => _resolveSpellChoices,
    // Todos los avisos de idiomas los arregla el mismo editor: los del origen
    // y los que deja elegir un rasgo se muestran juntos, que es como el
    // jugador los piensa.
    'language_choice_pending' ||
    'language_choice_pending_feature' ||
    'too_many_languages' ||
    'language_duplicate' ||
    'language_universal_chosen' ||
    'language_not_standard' => _resolveLanguages,
    // El mismo código también sale cuando sobran competencias sin rasgo que
    // las conceda: ahí no hay nada que elegir y el diálogo saldría vacío.
    // El mismo aviso cubre la Pericia, que viaja en su propia lista.
    'proficiency_choice_count'
        when sheet.proficiencyChoiceSlots.isNotEmpty ||
            sheet.expertiseChoiceSlots.isNotEmpty =>
      _resolveProficiencyChoices,
    // La mochila no se arregla con un diálogo: hay que decidir qué se suelta o
    // qué se dessintoniza, y eso se hace mirando la lista entera.
    'encumbered' ||
    'attunement_over_limit' => () => _selectTab(_SheetTab.inventario),
    _ => null,
  };

  Future<void> _resolveProficiencyChoices() async {
    final initial = [
      ...sheet.proficiencyChoiceSlots,
      ...sheet.expertiseChoiceSlots,
    ];
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
          final slots = [
            ...preview.proficiencyChoiceSlots,
            ...preview.expertiseChoiceSlots,
          ];
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
            title: Text(
              slots.isNotEmpty && slots.every((s) => s.expertise)
                  ? 'Elegir Pericia'
                  : 'Elegir competencias',
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Las opciones que ya ten\u00e9s por otra v\u00eda quedan '
                      'bloqueadas. En los cupos de Pericia es al rev\u00e9s: '
                      'solo se ofrecen las habilidades en las que ya sos '
                      'competente, y duplic\u00e1s el bonificador en ellas.',
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
                                // En un cupo de Pericia, tener la competencia
                                // es el requisito para elegirla: `fixed` no
                                // debe bloquear. Lo elegido en otro cupo sí,
                                // en los dos casos.
                                final locked =
                                    !selected &&
                                    ((!slot.expertise && fixed.contains(id)) ||
                                        selectedElsewhere);
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

  /// Aptitud mágica de las dotes que la dejan elegir (Iniciado en la Magia,
  /// Marcas Dracónicas). Se resuelven de a una, en el orden en que la ficha
  /// las lista, igual que el resto de los editores de esta pantalla.
  Future<void> _resolveFeatAbilities() async {
    final validator = CharacterValidator(repo);
    for (final id in validator.heldFeatIds(_c)) {
      final feat = repo.feat(id);
      if (feat == null || feat.spellcastingAbilityOptions.isEmpty) continue;
      if (_c.featSpellcastingAbilities.containsKey(id)) continue;
      final picked = await _pickOne<Ability>(
        title: 'Aptitud mágica de ${feat.name}',
        hint: 'Se usa para la CD y los ataques de los conjuros de esta dote.',
        options: feat.spellcastingAbilityOptions,
        label: (ability) => ability.label,
        current: null,
      );
      if (picked == null || !mounted) return;
      _replace(
        _c.copyWith(
          featSpellcastingAbilities: {
            ..._c.featSpellcastingAbilities,
            id: picked,
          },
        ),
      );
    }
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
                              .featureChoiceOptions(slot)
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

  /// Editor de los conjuros que un rasgo deja elegir y quedan siempre
  /// preparados (Conjuros Característicos, Descubrimientos Mágicos).
  ///
  /// El pozo lo entrega la ficha compilada ya filtrado, así que acá no se
  /// vuelve a interpretar ningún criterio. La ficha se recompila en cada toque
  /// porque un conjuro tomado en un cupo sale del pozo del siguiente.
  Future<void> _resolveSpellChoices() async {
    final choices = <String, List<String>>{
      for (final slot in sheet.spellChoiceSlots)
        slot.groupId: List.of(slot.chosen),
    };

    // Los grupos que no se editan acá se conservan, igual que en
    // `_resolveFeatureChoices`.
    Character withChoices(Map<String, List<String>> edited) =>
        _c.copyWith(spellChoices: {..._c.spellChoices, ...edited});

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewSheet = CharacterCompiler(
            repo,
          ).compile(withChoices(choices));
          final slots = previewSheet.spellChoiceSlots;

          bool complete() => slots.every(
            (slot) => (choices[slot.groupId] ?? const []).length >= slot.count,
          );

          return AlertDialog(
            title: const Text('Elegir conjuros'),
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
                          if (slot.options.isEmpty) {
                            return Text(
                              'No hay conjuros disponibles para este rasgo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          }
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
                                  for (final id in slot.options)
                                    if (repo.spell(id) case final s?)
                                      id: s.isCantrip
                                          ? '${s.name} (truco)'
                                          : '${s.name} (Nv ${s.level})',
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

  /// Editor de idiomas: los dos del origen y los que deja elegir un rasgo.
  ///
  /// Van en un solo diálogo porque para el jugador son lo mismo —qué habla su
  /// personaje— aunque el motor los guarde por separado según de dónde salgan.
  Future<void> _resolveLanguages() async {
    final origen = {..._c.languages};
    final porRasgo = <String, List<String>>{
      for (final slot in sheet.languageChoiceSlots)
        slot.groupId: List.of(slot.chosen),
    };

    Character conIdiomas() => _c.copyWith(
      languages: origen.toList(),
      languageChoices: {..._c.languageChoices, ...porRasgo},
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Se recompila en cada toque: un idioma tomado en el origen sale del
          // pozo del cupo de rasgo, y al revés.
          final preview = CharacterCompiler(repo).compile(conIdiomas());
          final cupo = Language.originChoiceCount;
          final completo =
              origen.length == cupo &&
              preview.languageChoiceSlots.every((s) => s.pending == 0);

          return AlertDialog(
            title: const Text('Elegir idiomas'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todo personaje sabe ${Language.labelFor(Language.universal.id)}, '
                      'que no ocupa una elección.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'De tu origen (${origen.length}/$cupo)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    CappedChipSelect(
                      options: {
                        for (final l in Language.originChoices) l.id: l.label,
                      },
                      selected: origen,
                      max: cupo,
                      onChanged: () => setDialogState(() {}),
                    ),
                    for (final slot in preview.languageChoiceSlots) ...[
                      const SizedBox(height: 18),
                      Text(
                        '${slot.name} '
                        '(${(porRasgo[slot.groupId] ?? const []).length}/${slot.count})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final sel = {...?porRasgo[slot.groupId]};
                          return CappedChipSelect(
                            options: {
                              for (final id in slot.options)
                                id: Language.labelFor(id),
                            },
                            selected: sel,
                            max: slot.count,
                            onChanged: () => setDialogState(
                              () => porRasgo[slot.groupId] = sel.toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: completo
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    _replace(conIdiomas());
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

  Widget _languagesCard(ComputedSheet s) {
    // Común primero, que lo sabe todo personaje; el resto por nombre. Se
    // ordena por etiqueta y no por id para que salga alfabético en español.
    final labels = [
      for (final id in s.languages)
        if (id != Language.universal.id) Language.labelFor(id),
    ]..sort(compareContentNames);
    return sheetCard(
      icon: Icons.translate,
      title: 'Idiomas',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _chips([Language.labelFor(Language.universal.id), ...labels]),
      ),
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
    final expertise = s.expertiseSkills.contains(skill.id);
    // La cuenta vive en la ficha, no acá: es el mismo método que usa la
    // Percepción pasiva, así que la Pericia no puede llegar a una y no a otra.
    final mod = s.skillModifier(skill.id);
    final color = proficient ? pal.gold : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Con Pericia el punto lleva un anillo, para distinguirla de la
          // competencia simple sin depender solo del número.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: proficient ? pal.gold : pal.hairline,
              shape: BoxShape.circle,
              border: expertise ? Border.all(color: pal.gold, width: 3) : null,
            ),
          ),
          SizedBox(width: expertise ? 4 : 10),
          Expanded(
            child: Text(
              expertise ? '${skill.label} ··' : skill.label,
              style: TextStyle(
                color: color,
                fontWeight: expertise ? FontWeight.w600 : null,
              ),
            ),
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
            // Toque en vez de tooltip: el tooltip en el celular casi no se
            // descubre, y este es justo el número que hay que poder explicar
            // en la mesa cuando el DM pregunta de dónde sale.
            child: InkWell(
              onTap: () => _showAbilityBreakdown(s, a[i]),
              borderRadius: BorderRadius.circular(12),
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

  /// Explica de dónde sale una característica y qué tiradas dependen de ella.
  ///
  /// Existe por un caso concreto de mesa: el DM preguntó por qué Inteligencia
  /// daba +7 y la ficha mostraba el resultado pero no el camino. Cada línea es
  /// una suma verificable, no un número suelto.
  void _showAbilityBreakdown(ComputedSheet s, Ability ability) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final score = s.abilityScores[ability]!;
    final mod = s.abilityModifiers[ability]!;
    final bonuses = s.bonusesFor(ability);
    final sc = s.spellcasting;

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: strong ? null : muted,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              color: strong ? pal.gold : null,
            ),
          ),
        ],
      ),
    );

    // Solo las habilidades en las que sos competente. Las demás tiran con el
    // modificador pelado, que ya está arriba: listarlas todas eran seis líneas
    // repitiendo el mismo número en una pantalla de celular.
    // Un aporte de Orden Divina o Primordial también hace que la habilidad
    // deje de tirar con el modificador pelado, aunque no haya competencia.
    final skills = [
      for (final sk in Skill.values)
        if (sk.ability == ability &&
            (s.skillProficiencies.contains(sk.id) ||
                s.expertiseSkills.contains(sk.id) ||
                s.skillBonuses.containsKey(sk.id)))
          sk,
    ];

    _infoDialog(
      ability.label,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ability.description,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          const Eyebrow('De dónde sale'),
          line('Asignada en la creación', '${s.baseAbilityScore(ability)}'),
          for (final b in bonuses)
            line(
              b.source.isEmpty ? 'Otro rasgo' : b.source,
              '${b.amount >= 0 ? '+' : ''}${b.amount}',
            ),
          const Divider(height: 16),
          line('Puntuación', '$score', strong: true),
          line('Modificador', _signed(mod), strong: true),

          const SizedBox(height: 16),
          const Eyebrow('Qué se tira con esto'),
          line(
            'Salvación'
            '${s.savingThrowProficiencies.contains(ability) ? ' (competente)' : ''}',
            _signed(s.savingThrow(ability)),
          ),
          for (final sk in skills) ...[
            line(
              '${sk.label}'
              '${s.expertiseSkills.contains(sk.id) ? ' (pericia)' : ''}',
              _signed(s.skillModifier(sk.id)),
            ),
            for (final b in s.skillBonuses[sk.id] ?? const <SkillBonus>[])
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: line('incluye ${_signed(b.amount)} de ${b.source}', ''),
              ),
          ],
          if (skills.isEmpty) line('Pruebas de característica', _signed(mod)),
          if (sc != null && sc.ability == ability) ...[
            line('Ataque con conjuros', _signed(sc.attackBonus)),
            line('CD de salvación', '${sc.saveDc}'),
          ],
          const SizedBox(height: 10),
          Text(
            'Competencia +${s.proficiencyBonus} a nivel ${s.level}, ya incluida '
            'arriba. Solo se listan las habilidades en las que sos competente: '
            'el resto tira con el modificador pelado (${_signed(mod)}).',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
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
