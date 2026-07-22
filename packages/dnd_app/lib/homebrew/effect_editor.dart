import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_widgets.dart';

const _skills = [
  'acrobatics', 'animal-handling', 'arcana', 'athletics', 'deception',
  'history', 'insight', 'intimidation', 'investigation', 'medicine',
  'nature', 'perception', 'performance', 'persuasion', 'religion',
  'sleight-of-hand', 'stealth', 'survival',
];

/// Descripción legible de un efecto, para listarlo en el editor.
String describeEffect(Effect e) => switch (e) {
      AbilityScoreBonusEffect(:final ability, :final amount) =>
        '${ability.abbr} ${amount >= 0 ? '+$amount' : '$amount'}',
      SkillProficiencyEffect(:final skill) => 'Competencia: $skill',
      SavingThrowProficiencyEffect(:final ability) =>
        'Salvación: ${ability.abbr}',
      ResistanceEffect(:final damageType) => 'Resistencia: $damageType',
      DarkvisionEffect(:final range) => 'Visión en la oscuridad: $range ft',
      SpeedBonusEffect(:final feet) => 'Velocidad +$feet ft',
      SetSpeedEffect(:final feet) => 'Velocidad = $feet ft',
      ArmorClassBonusEffect(:final amount) => 'CA +$amount',
      BonusMaxHpPerLevelEffect(:final perLevel) => 'PG máx +$perLevel por nivel',
      BonusMaxHpFlatEffect(:final amount) => 'PG máx +$amount',
      PassiveTraitEffect(:final name) => 'Pasiva: $name',
      WeaponMasterySlotsEffect(:final count) => 'Maestrías de arma: $count',
      ExtraAttackEffect(:final extra) => 'Ataque adicional +$extra',
      _ => e.toJson()['type'].toString(),
    };

/// Editor de una lista de [Effect]. Permite agregar tipos comunes y quitarlos.
class EffectEditor extends StatefulWidget {
  final List<Effect> effects;
  final VoidCallback onChanged;
  const EffectEditor({super.key, required this.effects, required this.onChanged});

  @override
  State<EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<EffectEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.effects.isEmpty)
          Text('Sin efectos.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          DenseRows(children: [
            for (final entry in widget.effects.asMap().entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(describeEffect(entry.value))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => widget.effects.removeAt(entry.key));
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ),
          ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Agregar efecto'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final effect = await showDialog<Effect>(
      context: context,
      builder: (_) => const _AddEffectDialog(),
    );
    if (effect != null) {
      setState(() => widget.effects.add(effect));
      widget.onChanged();
    }
  }
}

enum _Kind {
  abilityBonus('Bonus a característica'),
  skillProf('Competencia en habilidad'),
  saveProf('Competencia en salvación'),
  resistance('Resistencia a daño'),
  darkvision('Visión en la oscuridad'),
  speed('Bonus de velocidad'),
  acBonus('Bonus a CA'),
  hpPerLevel('PG máx por nivel'),
  passive('Rasgo pasivo');

  final String label;
  const _Kind(this.label);
}

class _AddEffectDialog extends StatefulWidget {
  const _AddEffectDialog();
  @override
  State<_AddEffectDialog> createState() => _AddEffectDialogState();
}

class _AddEffectDialogState extends State<_AddEffectDialog> {
  _Kind _kind = _Kind.abilityBonus;
  Ability _ability = Ability.strength;
  String _skill = _skills.first;
  final _amountCtrl = TextEditingController(text: '1');
  final _textCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _textCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Effect? _build() => switch (_kind) {
        _Kind.abilityBonus =>
          AbilityScoreBonusEffect(ability: _ability, amount: _amount),
        _Kind.skillProf => SkillProficiencyEffect(_skill),
        _Kind.saveProf => SavingThrowProficiencyEffect(_ability),
        _Kind.resistance => _textCtrl.text.trim().isEmpty
            ? null
            : ResistanceEffect(_textCtrl.text.trim()),
        _Kind.darkvision => DarkvisionEffect(_amount),
        _Kind.speed => SpeedBonusEffect(_amount),
        _Kind.acBonus => ArmorClassBonusEffect(_amount),
        _Kind.hpPerLevel => BonusMaxHpPerLevelEffect(_amount),
        _Kind.passive => _textCtrl.text.trim().isEmpty
            ? null
            : PassiveTraitEffect(
                name: _textCtrl.text.trim(), description: _descCtrl.text.trim()),
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar efecto'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<_Kind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                  labelText: 'Tipo', border: OutlineInputBorder()),
              items: _Kind.values
                  .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                  .toList(),
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 12),
            ..._fields(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final e = _build();
            if (e != null) Navigator.of(context).pop(e);
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  List<Widget> _fields() {
    switch (_kind) {
      case _Kind.abilityBonus:
        return [_abilityDropdown(), const SizedBox(height: 8), _amountField()];
      case _Kind.saveProf:
        return [_abilityDropdown()];
      case _Kind.skillProf:
        return [
          DropdownButtonFormField<String>(
            initialValue: _skill,
            decoration: const InputDecoration(
                labelText: 'Habilidad', border: OutlineInputBorder()),
            items: _skills
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _skill = v ?? _skill),
          ),
        ];
      case _Kind.resistance:
        return [
          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
                labelText: 'Tipo de daño (p.ej. fuego)',
                border: OutlineInputBorder()),
          ),
        ];
      case _Kind.darkvision:
      case _Kind.speed:
      case _Kind.acBonus:
      case _Kind.hpPerLevel:
        return [_amountField()];
      case _Kind.passive:
        return [
          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
                labelText: 'Nombre del rasgo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Descripción', border: OutlineInputBorder()),
          ),
        ];
    }
  }

  Widget _abilityDropdown() => DropdownButtonFormField<Ability>(
        initialValue: _ability,
        decoration: const InputDecoration(
            labelText: 'Característica', border: OutlineInputBorder()),
        items: Ability.values
            .map((a) => DropdownMenuItem(value: a, child: Text(a.abbr)))
            .toList(),
        onChanged: (v) => setState(() => _ability = v ?? _ability),
      );

  Widget _amountField() => TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
            labelText: 'Valor', border: OutlineInputBorder()),
      );
}
