import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../ui/spell_edit_screen.dart';
import 'level_up_summary_screen.dart';

part 'level_up_sections.dart';
part 'level_up_widgets.dart';

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
  late final CharacterClass? _klass = widget.repo.characterClass(
    widget.character.classId,
  );
  late final int _newLevel = widget.character.level + 1;
  late final int _hitDie = _klass?.hitDie ?? 10;
  late final bool _isAsi = _klass?.isAsiLevel(_newLevel) ?? false;

  /// Este nivel debe elegir subclase: se alcanza el nivel de subclase de la
  /// clase y aún no hay una elegida.
  late final bool _needsSubclass =
      _klass != null &&
      widget.character.subclassId == null &&
      _newLevel >= _klass.subclassLevel;
  late final List<Subclass> _subclassOptions = _needsSubclass
      ? widget.repo.subclassesForClass(widget.character.classId)
      : const [];
  String? _subclassId;

  _HpMethod _hpMethod = _HpMethod.average;
  int? _rolledHp;

  _AsiKind _asiKind = _AsiKind.improve;
  _ImproveMode _impMode = _ImproveMode.plusTwo;
  Ability? _abilityA;
  Ability? _abilityB;
  String? _featId;

  int get _hpGain => _hpMethod == _HpMethod.average
      ? averageHitDie(_hitDie)
      : (_rolledHp ?? 0);

  bool get _canConfirm {
    if (_hpMethod == _HpMethod.roll && _rolledHp == null) return false;
    if (_needsSubclass && _subclassId == null) return false;
    if (_isAsi) {
      if (_asiKind == _AsiKind.improve) {
        if (_abilityA == null) return false;
        if (_impMode == _ImproveMode.plusOneTwo && _abilityB == null) {
          return false;
        }
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

  // Conjuros re-elegidos en este nivel (null = sin cambios respecto al actual).
  List<String>? _newCantrips;
  List<String>? _newSpells;

  void _updateState(VoidCallback update) => setState(update);

  /// Construye el personaje tal como quedará tras confirmar (nivel, ASI/dote,
  /// PG y conjuros re-preparados). Se usa para confirmar y para previsualizar
  /// el lanzamiento al nuevo nivel.
  Character _buildUpdated() {
    final c = widget.character;
    final asiChoices = List<AsiChoice>.of(c.asiChoices);
    final featIds = List<String>.of(c.featIds);

    if (_isAsi) {
      if (_asiKind == _AsiKind.improve) {
        asiChoices.add(
          AsiChoice(level: _newLevel, abilityIncreases: _abilityIncreases),
        );
      } else if (_featId != null) {
        // La dote solo se agrega si ya se eligió: `_buildUpdated` corre en cada
        // build (previsualización de conjuros), incluso antes de elegir dote.
        asiChoices.add(AsiChoice(level: _newLevel, featId: _featId));
        featIds.add(_featId!);
      }
    }

    return c.copyWith(
      level: _newLevel,
      // Si se eligió subclase en esta subida se fija; si no, se conserva la
      // actual (pasar null solo ocurre por debajo del nivel de subclase).
      subclassId: _subclassId ?? c.subclassId,
      hpPerLevel: [...c.hpPerLevel, _hpGain],
      asiChoices: asiChoices,
      featIds: featIds,
      cantripIds: _newCantrips,
      spellIds: _newSpells,
    );
  }

  /// Rasgos ganados exactamente en el nuevo nivel: los de clase más, si hay
  /// subclase (elegida ahora o antes), los de subclase.
  List<ClassFeature> _gainedFeatures() {
    final feats = <ClassFeature>[...?_klass?.featuresAt(_newLevel)];
    final subId = _subclassId ?? widget.character.subclassId;
    if (subId != null) {
      final sub = widget.repo.subclass(subId);
      if (sub != null && sub.classId == widget.character.classId) {
        feats.addAll(sub.featuresAt(_newLevel));
      }
    }
    return feats;
  }

  void _confirm() {
    final c = widget.character;
    final updated = _buildUpdated();

    final compiler = CharacterCompiler(widget.repo);
    final before = compiler.compile(c);
    final after = compiler.compile(updated);

    // Sube los PG actuales por el incremento del máximo (se comparte el
    // CombatState por referencia vía copyWith).
    final delta = after.maxHp - before.maxHp;
    updated.combat.currentHp = (updated.combat.currentHp + delta).clamp(
      0,
      after.maxHp,
    );

    widget.onDone(updated);

    // Muestra el resumen de lo ganado, reemplazando este wizard.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LevelUpSummaryScreen(
          level: _newLevel,
          diff: diffSheets(before, after),
          newFeatures: _gainedFeatures(),
        ),
      ),
    );
  }

  /// Paso de elección de subclase (solo al alcanzar el nivel de subclase).
  @override
  Widget build(BuildContext context) {
    final newFeatures = _gainedFeatures();
    return Scaffold(
      appBar: AppBar(title: Text('Subir a nivel $_newLevel')),
      body: PageBody(
        children: [
          Eyebrow('Puntos de golpe (dado d$_hitDie)'),
          SegmentedButton<_HpMethod>(
            segments: [
              ButtonSegment(
                value: _HpMethod.average,
                label: Text('Promedio (${averageHitDie(_hitDie)})'),
              ),
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
                    onPressed: () =>
                        setState(() => _rolledHp = Dice().rollHitDie(_hitDie)),
                    icon: const Icon(Icons.casino),
                    label: const Text('Tirar dado'),
                  ),
                  const SizedBox(width: 12),
                  if (_rolledHp != null)
                    Text(
                      'Resultado: $_rolledHp',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        color: context.palette.gold,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'PG ganados: +$_hpGain (más tu mod. de CON)',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildSubclassSection(),
          if (_isAsi) _buildAsi() else const SizedBox.shrink(),
          if (newFeatures.isNotEmpty) ...[
            const SizedBox(height: 8),
            Eyebrow('Rasgos ganados a nivel $_newLevel'),
            DenseRows(
              children: [
                for (final f in newFeatures)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (f.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            f.description,
                            style: TextStyle(
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
          ],
          _buildSpellSection(),
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
}
