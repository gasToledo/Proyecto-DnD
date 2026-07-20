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
  late final Set<String> _cantrips = {...widget.character.cantripIds};
  late final Set<String> _spells = {...widget.character.spellIds};

  Spellcasting get _sc => widget.spellcasting;
  bool get _prepared => _sc.preparation == SpellPreparation.prepared;

  int get _maxSlotLevel =>
      _sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);

  @override
  Widget build(BuildContext context) {
    final all = widget.repo.spellsForList(_sc.spellList);
    final cantrips = all.where((s) => s.isCantrip).toList();
    final leveled =
        all.where((s) => !s.isCantrip && s.level <= _maxSlotLevel).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar conjuros')),
      body: PageBody(
        children: [
          if (_sc.cantripsKnown > 0) ...[
            Eyebrow('Trucos (${_cantrips.length}/${_sc.cantripsKnown})'),
            const SizedBox(height: 6),
            _chips(
              options: cantrips,
              selected: _cantrips,
              max: _sc.cantripsKnown,
              label: (s) => s.name,
            ),
            const SizedBox(height: 20),
          ],
          Eyebrow(_prepared
              ? 'Conjuros preparados (${_spells.length}/${_sc.preparedCount})'
              : 'Conjuros conocidos (${_spells.length})'),
          Text('Hasta nivel $_maxSlotLevel.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _chips(
            options: leveled,
            selected: _spells,
            max: _prepared ? _sc.preparedCount : 9999,
            label: (s) => '${s.name} (Nv ${s.level})',
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

  Widget _chips({
    required List<Spell> options,
    required Set<String> selected,
    required int max,
    required String Function(Spell) label,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((s) {
        final isSel = selected.contains(s.id);
        final full = selected.length >= max;
        return FilterChip(
          label: Text(label(s)),
          selected: isSel,
          onSelected: (!isSel && full)
              ? null
              : (v) => setState(() {
                    if (v) {
                      selected.add(s.id);
                    } else {
                      selected.remove(s.id);
                    }
                  }),
        );
      }).toList(),
    );
  }
}
