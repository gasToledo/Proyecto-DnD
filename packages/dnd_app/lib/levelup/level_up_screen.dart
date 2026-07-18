import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'level_up_summary_screen.dart';

enum _HpMethod { average, roll }

enum _AsiKind { improve, feat }

enum _ImproveMode { plusTwo, plusOneTwo }

/// Wizard de subida de nivel (manual, brief §3.D). Elige PG, resuelve el ASI
/// si corresponde, muestra los rasgos ganados y devuelve el personaje
/// actualizado. Los rasgos fijos de clase los aplica solo el compilador al
/// subir el nivel; aquí solo se capturan las decisiones del jugador.
class LevelUpScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final void Function(Character updated) onDone;
  const LevelUpScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.onDone,
  });

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  late final CharacterClass? _klass = widget.repo.characterClass(widget.character.classId);
  late final int _newLevel = widget.character.level + 1;
  late final int _hitDie = _klass?.hitDie ?? 10;
  late final bool _isAsi = _klass?.isAsiLevel(_newLevel) ?? false;

  _HpMethod _hpMethod = _HpMethod.average;
  int? _rolledHp;

  _AsiKind _asiKind = _AsiKind.improve;
  _ImproveMode _impMode = _ImproveMode.plusTwo;
  Ability? _abilityA;
  Ability? _abilityB;
  String? _featId;

  int get _hpGain =>
      _hpMethod == _HpMethod.average ? averageHitDie(_hitDie) : (_rolledHp ?? 0);

  bool get _canConfirm {
    if (_hpMethod == _HpMethod.roll && _rolledHp == null) return false;
    if (_isAsi) {
      if (_asiKind == _AsiKind.improve) {
        if (_abilityA == null) return false;
        if (_impMode == _ImproveMode.plusOneTwo && _abilityB == null) return false;
      } else {
        if (_featId == null) return false;
      }
    }
    return true;
  }

  Map<Ability, int> get _abilityIncreases {
    if (!_isAsi || _asiKind != _AsiKind.improve) return const {};
    if (_impMode == _ImproveMode.plusTwo) {
      return {?_abilityA: 2};
    }
    final m = <Ability, int>{};
    if (_abilityA != null) m[_abilityA!] = 1;
    if (_abilityB != null) m[_abilityB!] = (m[_abilityB!] ?? 0) + 1;
    return m;
  }

  void _confirm() {
    final c = widget.character;
    final asiChoices = List<AsiChoice>.of(c.asiChoices);
    final featIds = List<String>.of(c.featIds);

    if (_isAsi) {
      if (_asiKind == _AsiKind.improve) {
        asiChoices.add(AsiChoice(level: _newLevel, abilityIncreases: _abilityIncreases));
      } else {
        asiChoices.add(AsiChoice(level: _newLevel, featId: _featId));
        featIds.add(_featId!);
      }
    }

    final updated = c.copyWith(
      level: _newLevel,
      hpPerLevel: [...c.hpPerLevel, _hpGain],
      asiChoices: asiChoices,
      featIds: featIds,
    );

    final compiler = CharacterCompiler(widget.repo);
    final before = compiler.compile(c);
    final after = compiler.compile(updated);

    // Sube los PG actuales por el incremento del máximo (se comparte el
    // CombatState por referencia vía copyWith).
    final delta = after.maxHp - before.maxHp;
    updated.combat.currentHp =
        (updated.combat.currentHp + delta).clamp(0, after.maxHp);

    widget.onDone(updated);

    // Muestra el resumen de lo ganado, reemplazando este wizard.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LevelUpSummaryScreen(
          level: _newLevel,
          diff: diffSheets(before, after),
          newFeatures: _klass?.featuresAt(_newLevel) ?? const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newFeatures = _klass?.featuresAt(_newLevel) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('Subir a nivel $_newLevel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('Puntos de golpe (dado d$_hitDie)'),
          SegmentedButton<_HpMethod>(
            segments: [
              ButtonSegment(
                  value: _HpMethod.average,
                  label: Text('Promedio (${averageHitDie(_hitDie)})')),
              const ButtonSegment(value: _HpMethod.roll, label: Text('Tirar')),
            ],
            selected: {_hpMethod},
            onSelectionChanged: (s) => setState(() {
              _hpMethod = s.first;
              _rolledHp = null;
            }),
          ),
          if (_hpMethod == _HpMethod.roll)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(
                        () => _rolledHp = Dice().rollHitDie(_hitDie)),
                    icon: const Icon(Icons.casino),
                    label: const Text('Tirar dado'),
                  ),
                  const SizedBox(width: 12),
                  if (_rolledHp != null)
                    Text('Resultado: $_rolledHp',
                        style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('PG ganados: +$_hpGain (más tu mod. de CON)',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          if (_isAsi) _buildAsi() else const SizedBox.shrink(),
          if (newFeatures.isNotEmpty) ...[
            const SizedBox(height: 8),
            _label('Rasgos ganados a nivel $_newLevel'),
            ...newFeatures.map((f) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(f.name),
                    subtitle: f.description.isEmpty ? null : Text(f.description),
                  ),
                )),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _canConfirm ? _confirm : null,
            icon: const Icon(Icons.check),
            label: Text('Confirmar nivel $_newLevel'),
          ),
        ),
      ),
    );
  }

  Widget _buildAsi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Mejora de característica (nivel $_newLevel)'),
        SegmentedButton<_AsiKind>(
          segments: const [
            ButtonSegment(
                value: _AsiKind.improve, label: Text('Mejorar características')),
            ButtonSegment(value: _AsiKind.feat, label: Text('Tomar dote')),
          ],
          selected: {_asiKind},
          onSelectionChanged: (s) => setState(() => _asiKind = s.first),
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
                value: _ImproveMode.plusOneTwo, label: Text('+1 a dos')),
          ],
          selected: {_impMode},
          onSelectionChanged: (s) => setState(() {
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
                onChanged: (a) => setState(() => _abilityA = a),
              ),
            ),
            if (_impMode == _ImproveMode.plusOneTwo) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _abilityDropdown(
                  label: '+1',
                  value: _abilityB,
                  exclude: _abilityA,
                  onChanged: (a) => setState(() => _abilityB = a),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFeatPicker() {
    final feats =
        widget.repo.feats.values.where((f) => f.category == 'general').toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: feats
          .map((f) => ChoiceChip(
                label: Text(f.name),
                selected: _featId == f.id,
                onSelected: (_) => setState(() => _featId = f.id),
              ))
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
          labelText: label, border: const OutlineInputBorder(), isDense: true),
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );
}
