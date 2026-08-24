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
  // Después de las elecciones abiertas: las opciones de Pericia son las
  // habilidades en las que ya sos competente, y una dote recién elegida
  // (Habilidoso) puede sumar competencias. Cubre los dos tipos de cupo.
  proficiencies,
  features,
  // Antes de `spells` a propósito: el editor de conjuros oculta y poda lo que
  // ya está siempre preparado, y lo elegido acá entra en esa lista. Al revés,
  // el jugador prepararía a mano un conjuro que está por recibir gratis.
  spellChoices,
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
    // La misma regla que bloquea el paso, en un solo lugar: tenía una copia
    // que se olvidaba del +1 del don épico.
    if (!_asiComplete) return false;
    if (_pendingChoices > 0) return false;
    if (_pendingSpellChoices > 0) return false;
    return true;
  }

  /// El don épico elegido en este nivel, si concede "+1 a una característica a
  /// tu elección". Lo declaran los trece y ninguna otra dote, pero se pregunta
  /// por el efecto y no por la categoría: una dote homebrew que lo declare
  /// funciona igual.
  AbilityScoreChoiceEffect? get _boonAbilityChoice {
    if (!_isAsi || _asiKind != _AsiKind.feat || _featId == null) return null;
    return widget.repo
        .feat(_featId!)
        ?.effects
        .whereType<AbilityScoreChoiceEffect>()
        .firstOrNull;
  }

  Map<Ability, int> get _abilityIncreases {
    if (!_isAsi) return const {};
    // Tomar una dote normal no sube ninguna característica; un don épico sí, y
    // su aumento viaja en el mismo `AsiChoice` que la dote.
    if (_asiKind == _AsiKind.feat) {
      final boon = _boonAbilityChoice;
      if (boon == null || _abilityA == null) return const {};
      return {_abilityA!: boon.amount};
    }
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

  /// Competencias y Pericias resueltas en este nivel (null = sin cambios).
  /// Van todas en `Character.proficiencyChoices`, el mismo mapa que las
  /// competencias por dote, cada una con su propio groupId.
  Map<String, List<String>>? _newProficiencyChoices;

  Map<String, List<String>> get _effectiveProficiencyChoices =>
      _newProficiencyChoices ?? widget.character.proficiencyChoices;

  List<String> _proficiencyFor(String groupId) =>
      _effectiveProficiencyChoices[groupId] ?? const [];

  void _setProficiency(String groupId, List<String> ids) {
    final next = {
      for (final e in _effectiveProficiencyChoices.entries)
        e.key: List<String>.of(e.value),
    };
    if (ids.isEmpty) {
      next.remove(groupId);
    } else {
      next[groupId] = ids;
    }
    setState(() => _newProficiencyChoices = next);
  }

  /// Conjuros elegidos en este nivel (null = sin cambios). Van en
  /// `Character.spellChoices`, aparte de `spellIds`: no gastan cupo de
  /// preparados.
  Map<String, List<String>>? _newSpellChoices;

  Map<String, List<String>> get _effectiveSpellChoices =>
      _newSpellChoices ?? widget.character.spellChoices;

  List<String> _spellChoiceFor(String groupId) =>
      _effectiveSpellChoices[groupId] ?? const [];

  void _setSpellChoice(String groupId, List<String> ids) {
    final next = {
      for (final e in _effectiveSpellChoices.entries)
        e.key: List<String>.of(e.value),
    };
    if (ids.isEmpty) {
      next.remove(groupId);
    } else {
      next[groupId] = ids;
    }
    setState(() => _newSpellChoices = next);
  }

  List<SpellChoiceSlot>? _spellChoiceCache;
  String? _spellChoiceSig;

  /// Cupos de elección de conjuros al nivel nuevo. Se memoiza igual que
  /// [_proficiencyData]. La firma incluye lo ya elegido porque un conjuro
  /// tomado en un cupo sale del pozo del siguiente.
  List<SpellChoiceSlot> get _spellChoiceSlots {
    final sig = [
      _newLevel,
      _subclassId,
      _asiKind.name,
      _featId,
      _abilityA?.name,
      _abilityB?.name,
      _impMode.name,
      for (final e in _effectiveSpellChoices.entries)
        '${e.key}=${e.value.join(",")}',
    ].join('|');
    if (sig != _spellChoiceSig) {
      _spellChoiceCache = CharacterCompiler(
        widget.repo,
      ).compile(_buildUpdated()).spellChoiceSlots;
      _spellChoiceSig = sig;
    }
    return _spellChoiceCache!;
  }

  int get _pendingSpellChoices => _spellChoiceSlots.fold(
    0,
    (n, s) =>
        n + (s.count - _spellChoiceFor(s.groupId).length).clamp(0, s.count),
  );

  /// El paso aparece si falta elegir o si algún cupo se puede rehacer
  /// (Descubrimientos Mágicos se puede cambiar en cada nivel de Bardo).
  bool get _hasSpellChoices =>
      _pendingSpellChoices > 0 || _spellChoiceSlots.any((s) => s.replaceable);

  /// Cupos de competencia que el personaje **ya tenía antes** de esta subida.
  ///
  /// Se calcula una sola vez sobre el personaje sin tocar, y sirve para no
  /// arrastrar deuda vieja hasta acá: un cupo de nivel 1 que quedó sin resolver
  /// lo reclama el aviso de la ficha, que es informativo y deja seguir. Meterlo
  /// en el asistente lo convertiría en un bloqueo, y en este proyecto una
  /// advertencia nunca bloquea (ver `WarningSeverity` en el motor).
  ///
  /// La Pericia queda fuera de este filtro a propósito: ya se comportaba así
  /// antes de que el paso cubriera las competencias, y cambiarlo de paso sería
  /// una segunda modificación escondida en esta.
  late final Set<String> _oldProficiencyGroups = CharacterCompiler(widget.repo)
      .compile(widget.character)
      .proficiencyChoiceSlots
      .map((s) => s.groupId)
      .toSet();

  ({List<ProficiencyChoiceSlot> slots, Set<String> fixed})? _proficiencyCache;
  String? _proficiencySig;

  /// Cupos de competencia y de Pericia al nivel nuevo, más las competencias que
  /// el personaje ya tiene por otra vía. Se memoiza por el mismo motivo que
  /// [_choiceSlots]: `_steps` corre en cada build y compilar la ficha no es
  /// gratis. La firma incluye lo ya elegido porque una habilidad tomada sale de
  /// las opciones del otro cupo, y la dote porque Habilidoso puede sumar la
  /// competencia que habilita una Pericia nueva.
  ///
  /// Van juntos los dos tipos de cupo, y no solo la Pericia como hasta ahora,
  /// porque hay rasgos que conceden competencia lisa **por encima de nivel 1**:
  /// Conocimiento Primigenio del Bárbaro, Estudiante de la Guerra del Maestro
  /// de Batalla y las Herramientas del Oficio de las cinco subclases del
  /// Artífice, todos a nivel 3. Antes ninguno se preguntaba acá y el jugador
  /// tenía que ir a buscarlos al aviso de la ficha.
  ({List<ProficiencyChoiceSlot> slots, Set<String> fixed})
  get _proficiencyData {
    final sig = [
      _newLevel,
      _subclassId,
      _asiKind.name,
      _featId,
      _abilityA?.name,
      _abilityB?.name,
      _impMode.name,
      for (final e in _effectiveProficiencyChoices.entries)
        '${e.key}=${e.value.join(",")}',
    ].join('|');
    if (sig != _proficiencySig) {
      final sheet = CharacterCompiler(widget.repo).compile(_buildUpdated());
      // Lo que ya se tiene bloquea un cupo normal. Se descuenta lo elegido en
      // estos mismos cupos: si no, la opción recién marcada se bloquearía sola
      // y no se podría desmarcar.
      final fixed = {...sheet.skillProficiencies, ...sheet.toolProficiencies};
      for (final ids in _effectiveProficiencyChoices.values) {
        fixed.removeAll(ids);
      }
      _proficiencyCache = (
        slots: [
          for (final s in sheet.proficiencyChoiceSlots)
            if (!_oldProficiencyGroups.contains(s.groupId)) s,
          ...sheet.expertiseChoiceSlots,
        ],
        fixed: fixed,
      );
      _proficiencySig = sig;
    }
    return _proficiencyCache!;
  }

  List<ProficiencyChoiceSlot> get _proficiencySlots => _proficiencyData.slots;

  int get _pendingProficiency => _proficiencySlots.fold(
    0,
    (n, s) =>
        n + (s.count - _proficiencyFor(s.groupId).length).clamp(0, s.count),
  );

  /// El paso aparece solo si falta elegir: un cupo ya resuelto no se re-pregunta
  /// en cada subida (ni la competencia ni la Pericia son re-elegibles por
  /// regla).
  bool get _hasProficiencyChoices => _pendingProficiency > 0;

  /// Si todo lo que falta elegir es Pericia. Decide el rótulo y el texto del
  /// paso: un cupo ya resuelto no debería cambiarle el nombre.
  bool get _pendingAreAllExpertise => _proficiencySlots
      .where((s) => _proficiencyFor(s.groupId).length < s.count)
      .every((s) => s.expertise);

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
      if (_hasProficiencyChoices)
        _LevelUpStep(
          _LevelUpStepKind.proficiencies,
          // El rótulo sigue a lo que falta, no a lo que hay: si lo único
          // pendiente es Pericia, decir "Competencias" mandaría a buscar otra
          // cosa. Mismo criterio que el título del diálogo de la ficha.
          _pendingAreAllExpertise ? 'Pericia' : 'Competencias',
          Icons.star,
        ),
      if (_gainedFeatures().isNotEmpty)
        const _LevelUpStep(
          _LevelUpStepKind.features,
          'Rasgos',
          Icons.workspace_premium,
        ),
      if (_hasSpellChoices)
        const _LevelUpStep(
          _LevelUpStepKind.spellChoices,
          'Conjuros a elección',
          Icons.auto_fix_high,
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
    if (_asiKind == _AsiKind.feat) {
      if (_featId == null) return false;
      // Un don épico no está completo con la dote sola: falta decir a qué
      // característica va su +1.
      return _boonAbilityChoice == null || _abilityA != null;
    }
    if (_abilityA == null) return false;
    return _impMode == _ImproveMode.plusTwo || _abilityB != null;
  }

  bool _isStepComplete(_LevelUpStepKind kind) => switch (kind) {
    _LevelUpStepKind.hitPoints =>
      _hpMethod == _HpMethod.average || _rolledHp != null,
    _LevelUpStepKind.subclass => !_needsSubclass || _subclassId != null,
    _LevelUpStepKind.abilityScore => _asiComplete,
    _LevelUpStepKind.featureChoices => _pendingChoices == 0,
    _LevelUpStepKind.proficiencies => _pendingProficiency == 0,
    _LevelUpStepKind.spellChoices => _pendingSpellChoices == 0,
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
    _LevelUpStepKind.abilityScore
        when _boonAbilityChoice != null && _abilityA == null =>
      'Elegí a qué característica va el +1 del don épico.',
    _LevelUpStepKind.featureChoices when _pendingChoices > 0 =>
      _pendingChoices == 1
          ? 'Te falta una elección para continuar.'
          : 'Te faltan $_pendingChoices elecciones para continuar.',
    _LevelUpStepKind.proficiencies when _pendingProficiency > 0 => switch ((
      _pendingProficiency,
      _pendingAreAllExpertise,
    )) {
      (1, true) => 'Elegí una habilidad para tu Pericia.',
      (final n, true) => 'Elegí $n habilidades para tu Pericia.',
      (1, false) => 'Te falta una competencia para continuar.',
      (final n, false) => 'Te faltan $n competencias para continuar.',
    },
    _LevelUpStepKind.spellChoices when _pendingSpellChoices > 0 =>
      _pendingSpellChoices == 1
          ? 'Te falta elegir un conjuro para continuar.'
          : 'Te faltan $_pendingSpellChoices conjuros para continuar.',
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
        // `abilityIncreases` va vacío para una dote normal y trae el +1 del
        // don épico cuando corresponde: es el único caso en que un `AsiChoice`
        // lleva dote y aumento a la vez.
        asiChoices.add(
          AsiChoice(
            level: _newLevel,
            featId: _featId,
            abilityIncreases: _abilityIncreases,
          ),
        );
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
      proficiencyChoices: _newProficiencyChoices,
      spellChoices: _newSpellChoices,
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
                      duration: context.motion(
                        const Duration(milliseconds: 240),
                      ),
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
