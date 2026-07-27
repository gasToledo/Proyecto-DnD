part of 'level_up_screen.dart';

extension _LevelUpSections on _LevelUpScreenState {
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _abilityDropdown(
                label: _impMode == _ImproveMode.plusTwo ? '+2' : '+1',
                value: _abilityA,
                exclude: _abilityB,
                onChanged: (a) => _updateState(() => _abilityA = a),
              ),
            ),
            if (_impMode == _ImproveMode.plusOneTwo) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _abilityDropdown(
                  label: '+1',
                  value: _abilityB,
                  exclude: _abilityA,
                  onChanged: (a) => _updateState(() => _abilityB = a),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFeatPicker() {
    // No se puede repetir una dote ya tomada salvo que sea repetible (2024).
    final taken = widget.character.featIds.toSet();
    final feats =
        widget.repo.feats.values
            .where((f) => f.category == 'general')
            .where((f) => f.repeatable || !taken.contains(f.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (feats.isEmpty) {
      return Text(
        'No quedan dotes disponibles.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: feats
          .map(
            (f) => ChoiceChip(
              label: Text(f.name),
              selected: _featId == f.id,
              onSelected: (_) => _updateState(() => _featId = f.id),
            ),
          )
          .toList(),
    );
  }

  Widget _abilityDropdown({
    required String label,
    required Ability? value,
    required Ability? exclude,
    required ValueChanged<Ability?> onChanged,
  }) {
    final options = Ability.values.where((a) => a != exclude).toList();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Ability>(
          isExpanded: true,
          value: options.contains(value) ? value : null,
          items: options
              .map((a) => DropdownMenuItem(value: a, child: Text(a.abbr)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
