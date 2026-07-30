part of '../creation_wizard.dart';

class _EquipmentStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _EquipmentStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = draft.repo;
    final armors = repo.armor.values.where((a) => !a.isShield).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Armadura'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final cols = (box.maxWidth / 236).floor().clamp(1, 4);
            final w = (box.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: w,
                  child: _ChoiceCard(
                    icon: Icons.no_accounts,
                    title: 'Sin armadura',
                    subtitle: 'CA 10 + DES',
                    accent: pal.gold,
                    selected: draft.equippedArmorId == null,
                    onTap: () {
                      draft.equippedArmorId = null;
                      onChanged();
                    },
                  ),
                ),
                for (final a in armors)
                  SizedBox(
                    width: w,
                    child: _ChoiceCard(
                      icon: Icons.shield_moon,
                      title: a.name,
                      subtitle:
                          'CA ${a.baseAc} · '
                          '${_armorCategoryLabel(a.category)}',
                      accent: pal.gold,
                      selected: draft.equippedArmorId == a.id,
                      onTap: () {
                        draft.equippedArmorId = a.id;
                        onChanged();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _ShieldToggle(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Armas equipadas'),
        const SizedBox(height: 12),
        _WeaponSelect(
          weapons: repo.weapons.values.toList(),
          selected: draft.weaponIds,
          onToggle: (id) {
            if (!draft.weaponIds.remove(id)) draft.weaponIds.add(id);
            onChanged();
          },
          onClear: () {
            draft.weaponIds.clear();
            onChanged();
          },
        ),
        if (draft.weaponIds.length > 1) ...[
          const SizedBox(height: 10),
          const _TwoWeaponNotice(),
        ],
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Conjuros'),
        const SizedBox(height: 12),
        if (draft.isCaster)
          _SpellsSection(draft: draft, onChanged: onChanged)
        else
          const _NoSpellsNotice(),
      ],
    );
  }
}

/// Aviso al equipar más de un arma. La ficha lista un ataque por arma, pero
/// todavía no aplica la regla 2024 de combate con dos armas (arma Ligera,
/// ataque de mano secundaria como acción adicional y sin sumar el modificador
/// al daño salvo con el estilo de combate correspondiente). Sin este cartel el
/// segundo ataque se lee como si ya estuviera resuelto, y en la mesa no lo está.
class _TwoWeaponNotice extends StatelessWidget {
  const _TwoWeaponNotice();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: pal.goldSoft,
        border: Border.all(color: pal.gold),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: pal.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'La ficha va a mostrar un ataque por cada arma equipada, pero '
              'todavía no aplica sola la regla de combate con dos armas: el '
              'ataque de la mano secundaria es una acción adicional, exige un '
              'arma Ligera y no suma tu modificador al daño salvo que tengas '
              'el estilo de combate Combate con Dos Armas. Ajustalo en la mesa.',
              style: TextStyle(fontSize: 12, color: pal.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Escudo: es una elección aparte de la armadura (suma +2 CA).
class _ShieldToggle extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ShieldToggle({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final on = draft.shieldEquipped;
    return Material(
      color: on ? pal.goldSoft : scheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () {
          draft.shieldEquipped = !on;
          onChanged();
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: on ? pal.gold : pal.hairline),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield,
                size: 20,
                color: on ? pal.gold : pal.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Escudo (+2 CA)',
                  style: TextStyle(
                    fontSize: 14,
                    color: on ? pal.gold : scheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: on,
                onChanged: (v) {
                  draft.shieldEquipped = v;
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ),
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

class _SpellsSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellsSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sc = draft.spellcasting;
    if (sc == null) return const SizedBox.shrink();
    final all = draft.repo.spellsForList(sc.spellList);
    final maxLevel = sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final cantrips = all.where((s) => s.isCantrip).toList();
    final leveled = all
        .where((s) => !s.isCantrip && s.level <= maxLevel)
        .toList();
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
