import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_widgets.dart';

/// Editor de trucos y conjuros preparados/conocidos. Se abre desde la ficha:
/// un lanzador preparado (Mago) re-prepara tras cada descanso largo, así que la
/// selección no queda congelada en la creación.
class SpellEditScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final Spellcasting spellcasting;
  final void Function(List<String> cantrips, List<String> spells) onSave;

  const SpellEditScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.spellcasting,
    required this.onSave,
  });

  @override
  State<SpellEditScreen> createState() => _SpellEditScreenState();
}

class _SpellEditScreenState extends State<SpellEditScreen> {
  /// Ids de conjuros que ya concede un rasgo y por eso no deben ocupar un cupo
  /// de truco ni de preparado. Son dos casos distintos con la misma
  /// consecuencia acá: el conjuro **innato** (linaje, dote de origen), que
  /// además trae un uso gratis, y el **siempre preparado** de una subclase,
  /// que se lanza con los espacios normales.
  late final Set<String> _grantedSpellIds = () {
    final sheet = CharacterCompiler(widget.repo).compile(widget.character);
    return {
      for (final s in sheet.innateSpells) s.spellId,
      ...sheet.alwaysPreparedSpellIds,
    };
  }();

  // Una ficha guardada antes de que la selección los excluyera puede traerlos
  // elegidos: se podan al abrir para devolver el cupo desperdiciado, en vez de
  // quedar atrapados en la selección sin chip que los saque.
  late final Set<String> _cantrips = {...widget.character.cantripIds}
    ..removeAll(_grantedSpellIds);
  late final Set<String> _spells = {...widget.character.spellIds}
    ..removeAll(_grantedSpellIds);

  Spellcasting get _sc => widget.spellcasting;
  bool get _prepared => _sc.preparation == SpellPreparation.prepared;

  int get _maxSlotLevel =>
      _sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);

  @override
  Widget build(BuildContext context) {
    final all = widget.repo.spellsForList(_sc.spellList);
    final grantedSpellIds = _grantedSpellIds;
    final cantrips = all
        .where((s) => s.isCantrip && !grantedSpellIds.contains(s.id))
        .toList();
    final grantedCantrips = all.any(
      (s) => s.isCantrip && grantedSpellIds.contains(s.id),
    );
    final leveled = all
        .where(
          (s) =>
              !s.isCantrip &&
              s.level <= _maxSlotLevel &&
              !grantedSpellIds.contains(s.id),
        )
        .toList();
    final grantedLeveledNames = [
      for (final s in all)
        if (!s.isCantrip && grantedSpellIds.contains(s.id)) s.name,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Editar conjuros')),
      body: PageBody(
        children: [
          if (_sc.cantripsKnown > 0) ...[
            Eyebrow('Trucos (${_cantrips.length}/${_sc.cantripsKnown})'),
            if (grantedCantrips) ...[
              const SizedBox(height: 4),
              Text(
                'Los trucos que ya tenés por otro rasgo no '
                'aparecen acá: no ocupan un cupo de truco de clase.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            CappedChipSelect(
              options: {for (final s in cantrips) s.id: s.name},
              selected: _cantrips,
              max: _sc.cantripsKnown,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
          ],
          Eyebrow(
            _prepared
                ? 'Conjuros preparados (${_spells.length}/${_sc.preparedCount})'
                : 'Conjuros conocidos (${_spells.length})',
          ),
          Text(
            'Hasta nivel $_maxSlotLevel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (grantedLeveledNames.isNotEmpty)
            Text(
              'Ya tenés ${grantedLeveledNames.join(', ')} siempre preparado '
              'por otro rasgo: no ocupa un cupo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          CappedChipSelect(
            options: {
              for (final s in leveled) s.id: '${s.name} (Nv ${s.level})',
            },
            selected: _spells,
            max: _prepared ? _sc.preparedCount : 9999,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () {
              widget.onSave(_cantrips.toList(), _spells.toList());
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}
