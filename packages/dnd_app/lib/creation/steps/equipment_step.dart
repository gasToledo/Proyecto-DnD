part of '../creation_wizard.dart';

class _EquipmentStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _EquipmentStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    draft.pruneEquipment();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StartingEquipmentSection(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Equipo puesto'),
        const SizedBox(height: 12),
        _ReceivedEquipmentSection(draft: draft, onChanged: onChanged),
        _WeaponGripSection(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Conjuros'),
        const SizedBox(height: 12),
        // Va antes de la magia de clase: lo elegido acá queda siempre preparado
        // y sale del pozo de abajo, así que preguntarlo después haría que el
        // jugador preparase un conjuro que está por recibir gratis.
        //
        // Fuera de `draft.isCaster` a propósito: un rasgo puede conceder
        // conjuros a un personaje que no lanza por clase.
        _SpellChoicesSection(draft: draft, onChanged: onChanged),
        if (draft.isCaster)
          _SpellsSection(draft: draft, onChanged: onChanged)
        else
          const _NoSpellsNotice(),
      ],
    );
  }
}

class _StartingEquipmentSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _StartingEquipmentSection({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeader(title: 'Equipo inicial'),
      const SizedBox(height: 12),
      _optionPicker(
        'Clase',
        draft.klass?.startingEquipment ?? const [],
        draft.classEquipmentOptionId,
        (id) {
          draft.classEquipmentOptionId = id;
          draft.pruneEquipment();
          onChanged();
        },
      ),
      const SizedBox(height: 12),
      _optionPicker(
        'Trasfondo',
        draft.background?.startingEquipment ?? const [],
        draft.backgroundEquipmentOptionId,
        (id) {
          draft.backgroundEquipmentOptionId = id;
          draft.pruneEquipment();
          onChanged();
        },
      ),
      for (final (:key, :grant) in draft.selectedEquipmentGrants)
        if (grant.isChoice) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('equipment-choice-$key'),
            initialValue:
                grant.chooseFromItemIds.contains(draft.equipmentChoices[key])
                ? draft.equipmentChoices[key]
                : null,
            decoration: const InputDecoration(labelText: 'Elegí un objeto'),
            items: [
              for (final id in grant.chooseFromItemIds)
                DropdownMenuItem(
                  value: id,
                  child: Text(draft.repo.catalogEntry(id)?.name ?? id),
                ),
            ],
            onChanged: (id) {
              if (id != null) draft.equipmentChoices[key] = id;
              draft.pruneEquipment();
              onChanged();
            },
          ),
        ],
      if (draft.startingInventory.isNotEmpty ||
          draft.startingCoins.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          [
            ...draft.startingInventory.map((e) {
              final name = draft.repo.catalogEntry(e.itemId)?.name ?? e.itemId;
              return e.quantity == 1 ? name : '$name ×${e.quantity}';
            }),
            ...draft.startingCoins.entries.map(
              (e) => '${e.value} ${coinLabels[e.key]}',
            ),
          ].join(' · '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ],
  );

  Widget _optionPicker(
    String label,
    List<StartingEquipmentOption> options,
    String? selected,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('starting-equipment-${label.toLowerCase()}'),
    initialValue: options.any((e) => e.id == selected) ? selected : null,
    decoration: InputDecoration(labelText: 'Opción de $label'),
    items: [
      for (final option in options)
        DropdownMenuItem(value: option.id, child: Text(option.label)),
    ],
    onChanged: changed,
  );
}

class _ReceivedEquipmentSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ReceivedEquipmentSection({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final armor = [
      for (final id in draft.receivedItemIds) ?draft.repo.armorPiece(id),
    ];
    final weapons = [
      for (final id in draft.receivedItemIds) ?draft.repo.weapon(id),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in armor)
              FilterChip(
                label: Text(item.name),
                selected: item.isShield
                    ? draft.shieldEquipped
                    : draft.equippedArmorId == item.id,
                onSelected: (on) {
                  if (item.isShield) {
                    draft.shieldEquipped = on;
                  } else {
                    draft.equippedArmorId = on ? item.id : null;
                  }
                  onChanged();
                },
              ),
            for (final item in weapons)
              FilterChip(
                label: Text(item.name),
                selected: draft.weaponIds.contains(item.id),
                onSelected: (on) {
                  draft.weaponIds.remove(item.id);
                  if (on) draft.weaponIds.add(item.id);
                  onChanged();
                },
              ),
          ],
        ),
        if (armor.isEmpty && weapons.isEmpty)
          Text(
            'El paquete elegido no trae equipo para vestir o empuñar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Cómo se empuña cada arma elegida.
///
/// Solo aparecen los interruptores que el arma admite: Secundaria exige la
/// propiedad Ligera y A dos manos exige daño versátil. Antes acá había un
/// cartel avisando que la regla de dos armas no se aplicaba sola; ahora el
/// motor la aplica, así que lo que falta es decidir la mano.
class _WeaponGripSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _WeaponGripSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final grips = [
      for (final id in draft.weaponIds)
        if (draft.repo.weapon(id) case final w?)
          if (w.isLight || w.versatileDice != null) w,
    ];
    if (grips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Cómo las empuñás', style: Theme.of(context).textTheme.titleSmall),
        Text(
          'El ataque de mano secundaria es una acción adicional y no suma tu '
          'modificador al daño, salvo con el estilo Combate con Dos Armas.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        for (final w in grips)
          Row(
            children: [
              Expanded(child: Text(w.name)),
              if (w.isLight)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    key: ValueKey('off-hand-${w.id}'),
                    label: const Text('Secundaria'),
                    selected: draft.weaponOffHand[w.id] ?? false,
                    onSelected: (v) {
                      // Solo se empuña un arma en la secundaria.
                      draft.weaponOffHand
                        ..clear()
                        ..addAll(v ? {w.id: true} : const {});
                      onChanged();
                    },
                  ),
                ),
              if (w.versatileDice != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    key: ValueKey('two-handed-${w.id}'),
                    label: const Text('A dos manos'),
                    selected: draft.weaponTwoHanded[w.id] ?? false,
                    onSelected: (v) {
                      draft.weaponTwoHanded[w.id] = v;
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Cartel para clases que no lanzan conjuros.
class _NoSpellsNotice extends StatelessWidget {
  const _NoSpellsNotice();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 30, color: pal.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu clase no lanza conjuros',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Confiás en el acero y la maña. Seguí al próximo paso.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conjuros que un rasgo deja elegir y quedan siempre preparados.
///
/// Ninguna clase oficial declara uno a nivel 1 —el primero es Descubrimientos
/// Mágicos, a nivel 6—, así que en la práctica esto solo aparece con homebrew.
/// Va igual: si no estuviera, la creación sería el único lugar donde una
/// elección que el motor declara no se puede resolver.
class _SpellChoicesSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellChoicesSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Igual que en el paso de aptitudes: cambiar de clase o de trasfondo puede
    // vaciar un cupo, y una elección que dejó de calificar tiene que soltarse
    // acá y no quedar guardada sin chip que la saque.
    draft.pruneSpellChoices();
    final slots = draft.spellChoiceSlots;
    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slot in slots) ...[
          _SpellGroupHeader(
            title: slot.name,
            count: (draft.spellChoices[slot.groupId] ?? const []).length,
            cap: slot.count,
          ),
          const SizedBox(height: 6),
          Text(
            'No ocupan cupo de preparados.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final selected = {...?draft.spellChoices[slot.groupId]};
              return CappedChipSelect(
                options: {
                  for (final id in slot.options)
                    if (draft.repo.spell(id) case final s?)
                      id: s.isCantrip
                          ? '${s.name} (truco)'
                          : '${s.name} (Nv ${s.level})',
                },
                selected: selected,
                max: slot.count,
                onChanged: () {
                  draft.spellChoices[slot.groupId] = selected.toList();
                  onChanged();
                },
              );
            },
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _SpellsSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellsSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sc = draft.spellcasting;
    if (sc == null) return const SizedBox.shrink();
    final all = draft.repo.spellsForList(
      sc.spellList,
      extraSpellIds: draft.spellListAdditionIds,
    );
    final maxLevel = sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final grantedSpellIds = draft.grantedSpellIds;
    final cantrips = all
        .where((s) => s.isCantrip && !grantedSpellIds.contains(s.id))
        .toList();
    final grantedCantripNames = [
      for (final s in all)
        if (s.isCantrip && grantedSpellIds.contains(s.id)) s.name,
    ];
    final leveled = all
        .where(
          (s) =>
              !s.isCantrip &&
              s.level <= maxLevel &&
              !grantedSpellIds.contains(s.id),
        )
        .toList();
    final grantedLeveledNames = [
      for (final s in all)
        if (!s.isCantrip && grantedSpellIds.contains(s.id)) s.name,
    ];
    final prepared = sc.preparation == SpellPreparation.prepared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CD de salvación ${sc.saveDc} · Ataque de conjuro '
          '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus} (${sc.ability.abbr})',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (sc.cantripsKnown > 0) ...[
          const SizedBox(height: 18),
          _SpellGroupHeader(
            title: 'Trucos',
            count: draft.cantrips.length,
            cap: sc.cantripsKnown,
          ),
          if (grantedCantripNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ya tenés ${grantedCantripNames.join(', ')} por un rasgo de tu '
              'especie: no ocupa un cupo de truco de clase.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          _SpellChips(
            spells: cantrips,
            selected: draft.cantrips,
            max: sc.cantripsKnown,
            icon: Icons.auto_fix_high,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 20),
        _SpellGroupHeader(
          title: prepared ? 'Conjuros preparados' : 'Conjuros conocidos',
          count: draft.spells.length,
          cap: prepared ? sc.preparedCount : null,
        ),
        if (grantedLeveledNames.isNotEmpty)
          Text(
            'Ya tenés ${grantedLeveledNames.join(', ')} siempre preparado por '
            'otro rasgo: no ocupa un cupo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          'Podés preparar conjuros de hasta nivel $maxLevel.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _SpellChips(
          spells: leveled,
          selected: draft.spells,
          max: prepared ? sc.preparedCount : 999,
          icon: Icons.auto_stories,
          showLevel: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Título de un grupo de conjuros con su contador.
class _SpellGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final int? cap;
  const _SpellGroupHeader({
    required this.title,
    required this.count,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          cap == null ? '$count' : '$count / $cap',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
      ],
    );
  }
}

/// Conjuros como chips seleccionables, con tope.
class _SpellChips extends StatelessWidget {
  final List<Spell> spells;
  final Set<String> selected;
  final int max;
  final IconData icon;
  final bool showLevel;
  final VoidCallback onChanged;
  const _SpellChips({
    required this.spells,
    required this.selected,
    required this.max,
    required this.icon,
    required this.onChanged,
    this.showLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final full = selected.length >= max;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final s in spells)
          Builder(
            builder: (context) {
              final on = selected.contains(s.id);
              final enabled = on || !full;
              return Material(
                color: on ? pal.goldSoft : scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: enabled
                      ? () {
                          if (!selected.remove(s.id)) selected.add(s.id);
                          onChanged();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? pal.gold : pal.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: on
                              ? pal.gold
                              : enabled
                              ? scheme.onSurfaceVariant
                              : pal.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          showLevel ? '${s.name} (Nv ${s.level})' : s.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: on
                                ? pal.gold
                                : enabled
                                ? scheme.onSurface
                                : pal.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
