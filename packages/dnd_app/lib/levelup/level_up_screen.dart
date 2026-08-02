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

enum _LevelUpStepKind {
  overview,
  hitPoints,
  subclass,
  abilityScore,
  // Va después del ASI a propósito: la cantidad de espacios puede venir de la
  // subclase recién elegida, y los prerrequisitos de una opción pueden depender
  // de la característica que sube el ASI de este mismo nivel.
  featureChoices,
  features,
  spells,
  review,
}

class _LevelUpStep {
  final _LevelUpStepKind kind;
  final String label;
  final IconData icon;

  const _LevelUpStep(this.kind, this.label, this.icon);
}

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
  String _featQuery = '';
  int _currentStep = 0;

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
    if (_pendingChoices > 0) return false;
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

  /// Elecciones abiertas re-resueltas en este nivel (null = sin cambios).
  Map<String, List<String>>? _newFeatureChoices;

  Map<String, List<String>> get _effectiveChoices =>
      _newFeatureChoices ?? widget.character.featureChoices;

  List<String> _choicesFor(String groupId) =>
      _effectiveChoices[groupId] ?? const [];

  void _setChoices(String groupId, List<String> ids) {
    final next = {
      for (final e in _effectiveChoices.entries)
        e.key: List<String>.of(e.value),
    };
    if (ids.isEmpty) {
      next.remove(groupId);
    } else {
      next[groupId] = ids;
    }
    setState(() => _newFeatureChoices = next);
  }

  List<FeatureChoiceSlot>? _slotCache;
  String? _slotSig;

  /// Elecciones abiertas al nivel nuevo. Se memoiza porque `_steps` corre en
  /// cada build y compilar la ficha no es gratis.
  List<FeatureChoiceSlot> get _choiceSlots {
    final sig = [
      _newLevel,
      _subclassId,
      _asiKind.name,
      _featId,
      _abilityA?.name,
      _abilityB?.name,
      _impMode.name,
    ].join('|');
    if (sig != _slotSig) {
      _slotCache = CharacterCompiler(
        widget.repo,
      ).compile(_buildUpdated()).featureChoiceSlots;
      _slotSig = sig;
    }
    return _slotCache!;
  }

  /// Cuántas elecciones faltan resolver. Solo esto bloquea el avance: revisar
  /// una elección ya hecha es opcional, como el paso de conjuros.
  int get _pendingChoices => _choiceSlots.fold(
    0,
    (n, s) => n + (s.count - _choicesFor(s.groupId).length).clamp(0, s.count),
  );

  /// El paso aparece si falta elegir algo o si algún grupo se puede revisar.
  /// Un grupo completo y no revisable (el Estilo de Combate, que se elige una
  /// vez) no vuelve a mostrarse en cada subida.
  bool get _hasFeatureChoices =>
      _pendingChoices > 0 || _choiceSlots.any((s) => s.replaceable);

  void _updateState(VoidCallback update) => setState(update);

  List<_LevelUpStep> get _steps {
    return [
      const _LevelUpStep(
        _LevelUpStepKind.overview,
        'Resumen',
        Icons.auto_awesome,
      ),
      const _LevelUpStep(
        _LevelUpStepKind.hitPoints,
        'Puntos de golpe',
        Icons.favorite,
      ),
      if (_needsSubclass)
        const _LevelUpStep(_LevelUpStepKind.subclass, 'Subclase', Icons.shield),
      if (_isAsi)
        const _LevelUpStep(
          _LevelUpStepKind.abilityScore,
          'Mejora o dote',
          Icons.trending_up,
        ),
      if (_hasFeatureChoices)
        const _LevelUpStep(
          _LevelUpStepKind.featureChoices,
          'Elecciones',
          Icons.style,
        ),
      if (_gainedFeatures().isNotEmpty)
        const _LevelUpStep(
          _LevelUpStepKind.features,
          'Rasgos',
          Icons.workspace_premium,
        ),
      if (_hasSpellcasting)
        const _LevelUpStep(
          _LevelUpStepKind.spells,
          'Conjuros',
          Icons.auto_stories,
        ),
      const _LevelUpStep(_LevelUpStepKind.review, 'Revisión', Icons.fact_check),
    ];
  }

  bool get _hasSpellcasting =>
      CharacterCompiler(widget.repo).compile(_buildUpdated()).spellcasting !=
      null;

  _LevelUpStep get _activeStep {
    final steps = _steps;
    final index = _currentStep.clamp(0, steps.length - 1);
    return steps[index];
  }

  bool get _asiComplete {
    if (!_isAsi) return true;
    if (_asiKind == _AsiKind.feat) return _featId != null;
    if (_abilityA == null) return false;
    return _impMode == _ImproveMode.plusTwo || _abilityB != null;
  }

  bool _isStepComplete(_LevelUpStepKind kind) => switch (kind) {
    _LevelUpStepKind.hitPoints =>
      _hpMethod == _HpMethod.average || _rolledHp != null,
    _LevelUpStepKind.subclass => !_needsSubclass || _subclassId != null,
    _LevelUpStepKind.abilityScore => _asiComplete,
    _LevelUpStepKind.featureChoices => _pendingChoices == 0,
    _ => true,
  };

  bool _canReachStep(int target) {
    if (target <= _currentStep) return true;
    final steps = _steps;
    for (var i = 0; i < target; i++) {
      if (!_isStepComplete(steps[i].kind)) return false;
    }
    return true;
  }

  void _goToStep(int index) {
    if (!_canReachStep(index)) return;
    setState(() => _currentStep = index);
  }

  void _continue() {
    final steps = _steps;
    final current = _currentStep.clamp(0, steps.length - 1);
    if (!_isStepComplete(steps[current].kind)) return;
    if (steps[current].kind == _LevelUpStepKind.review) {
      _confirm();
      return;
    }
    setState(() => _currentStep = (current + 1).clamp(0, steps.length - 1));
  }

  String? get _pendingMessage => switch (_activeStep.kind) {
    _LevelUpStepKind.hitPoints
        when _hpMethod == _HpMethod.roll && _rolledHp == null =>
      'Tirá el dado o elegí el promedio para continuar.',
    _LevelUpStepKind.subclass when _subclassId == null =>
      'Elegí una subclase para continuar.',
    _LevelUpStepKind.abilityScore
        when _asiKind == _AsiKind.improve && !_asiComplete =>
      'Completá la mejora de características.',
    _LevelUpStepKind.abilityScore when _featId == null =>
      'Elegí una dote para continuar.',
    _LevelUpStepKind.featureChoices when _pendingChoices > 0 =>
      _pendingChoices == 1
          ? 'Te falta una elección para continuar.'
          : 'Te faltan $_pendingChoices elecciones para continuar.',
    _ => null,
  };

  /// Construye el personaje tal como quedará tras confirmar (nivel, ASI/dote,
  /// PG y conjuros re-preparados). Se usa para confirmar y para previsualizar
  /// el lanzamiento al nuevo nivel.
  ///
  /// [withFeat] en false deja fuera la dote tentativa. El selector lo necesita
  /// para evaluar prerrequisitos: una dote que sube una característica no debe
  /// poder habilitarse a sí misma.
  Character _buildUpdated({bool withFeat = true}) {
    final c = widget.character;
    final asiChoices = List<AsiChoice>.of(c.asiChoices);
    final featIds = List<String>.of(c.featIds);

    if (_isAsi) {
      if (_asiKind == _AsiKind.improve) {
        asiChoices.add(
          AsiChoice(level: _newLevel, abilityIncreases: _abilityIncreases),
        );
      } else if (withFeat && _featId != null) {
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
      featureChoices: _newFeatureChoices,
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
    final steps = _steps;
    if (_currentStep >= steps.length) {
      _currentStep = steps.length - 1;
    }
    final active = steps[_currentStep];
    final complete = _isStepComplete(active.kind);
    final isReview = active.kind == _LevelUpStepKind.review;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subir a nivel $_newLevel'),
            Text(
              '${widget.character.name} · ${_klass?.name ?? widget.character.classId}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          _LevelBadge(from: widget.character.level, to: _newLevel),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return Column(
            children: [
              _LevelUpStepper(
                steps: steps,
                current: _currentStep,
                compact: compact,
                canReach: _canReachStep,
                onSelected: _goToStep,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1060),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: SingleChildScrollView(
                        key: ValueKey(active.kind),
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 30,
                          22,
                          compact ? 18 : 30,
                          28,
                        ),
                        child: _buildStep(active.kind),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: _LevelUpFooter(
          current: _currentStep,
          total: steps.length,
          pendingMessage: _pendingMessage,
          canContinue: complete && (!isReview || _canConfirm),
          isReview: isReview,
          level: _newLevel,
          onBack: _currentStep == 0
              ? null
              : () => setState(() => _currentStep--),
          onContinue: _continue,
        ),
      ),
    );
  }
}
