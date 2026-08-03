import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/creation_draft_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'creation_draft.dart';

part 'steps/aptitudes_step.dart';
part 'steps/choice_widgets.dart';
part 'steps/details_step.dart';
part 'steps/equipment_step.dart';
part 'steps/race_class_background_steps.dart';
part 'steps/scores_step.dart';
part 'steps/selection_widgets.dart';
part 'steps/summary_step.dart';

String _draftDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Ícono de cada paso en el stepper.
const _stepIcons = {
  CreationStep.raza: Icons.groups,
  CreationStep.clase: Icons.military_tech,
  CreationStep.trasfondo: Icons.history_edu,
  CreationStep.puntuaciones: Icons.tune,
  CreationStep.aptitudes: Icons.checklist,
  CreationStep.equipo: Icons.backpack,
  CreationStep.detalles: Icons.edit_note,
  CreationStep.resumen: Icons.verified,
};

/// Ancho a partir del cual se muestra el panel lateral de progreso.
const _kWideBreakpoint = 900.0;

/// Wizard de creación (reglas 2024). Ocho pasos fijos con stepper: se puede
/// volver a cualquier paso ya completo, pero nunca saltear uno pendiente.
class CreationWizard extends StatefulWidget {
  final ContentRepository repo;
  final void Function(Character) onCreate;
  final CreationDraftStore? draftStore;
  const CreationWizard({
    super.key,
    required this.repo,
    required this.onCreate,
    this.draftStore,
  });

  @override
  State<CreationWizard> createState() => _CreationWizardState();
}

class _CreationWizardState extends State<CreationWizard> {
  late CreationDraft d;
  CreationStep _step = CreationStep.raza;
  bool _hasProgress = false;
  bool _allowPop = false;
  bool _confirmingClose = false;
  bool _loadingDraft = false;
  Timer? _draftDebounce;
  Future<void> _draftWrites = Future<void>.value();

  static const _steps = CreationStep.values;
  bool get _isLast => _step == _steps.last;

  @override
  void initState() {
    super.initState();
    d = CreationDraft(widget.repo);
    _loadingDraft = widget.draftStore != null;
    if (_loadingDraft) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      unawaited(_finish());
      return;
    }
    setState(() => _step = _steps[_step.index + 1]);
    _scheduleDraftSave();
  }

  void _back() {
    setState(() => _step = _steps[_step.index - 1]);
    _scheduleDraftSave();
  }

  void _goTo(CreationStep s) {
    if (!d.canGoTo(s)) return;
    setState(() => _step = s);
    _scheduleDraftSave();
  }

  Future<void> _finish() async {
    final character = d.build();
    // PG actuales al máximo al crear.
    final sheet = CharacterCompiler(widget.repo).compile(character);
    character.combat.currentHp = sheet.maxHp;
    await _clearDraft();
    if (!mounted) return;
    widget.onCreate(character);
    _closeWithoutPrompt();
  }

  /// Un cambio puede volver inalcanzable el paso actual (p.ej. cambiar de clase
  /// borra las maestrías ya elegidas): en ese caso se retrocede al primero que
  /// quedó pendiente en vez de dejar al usuario varado.
  void _refresh() {
    setState(() {
      _hasProgress = true;
      if (!d.canGoTo(_step)) _step = d.firstIncompleteStep;
    });
    _scheduleDraftSave();
  }

  Future<void> _loadDraft() async {
    final store = widget.draftStore;
    if (store == null) return;
    final snapshot = await store.load();
    if (!mounted) return;
    if (snapshot == null) {
      setState(() => _loadingDraft = false);
      if (store.recoveryIssues.isNotEmpty) {
        final recoveryPath = store.recoveryIssues.first.recoveryPath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showAppMessage(
            context,
            'El borrador no se pudo leer y fue apartado en: $recoveryPath',
            tone: AppMessageTone.error,
          );
        });
      }
      return;
    }
    setState(() => _loadingDraft = false);

    final resume =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Borrador encontrado'),
            content: Text(
              'Hay un personaje sin terminar, guardado el '
              '${_draftDate(snapshot.savedAt)}. ¿Querés continuarlo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Descartar borrador'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted) return;
    if (resume) {
      final restored = CreationDraft.fromJson(widget.repo, snapshot.data);
      setState(() {
        d = restored;
        _step = restored.canGoTo(snapshot.step)
            ? snapshot.step
            : restored.firstIncompleteStep;
        _hasProgress = true;
      });
    } else {
      await store.clear();
    }
  }

  void _scheduleDraftSave() {
    final store = widget.draftStore;
    if (store == null || !_hasProgress) return;
    _draftDebounce?.cancel();
    final step = _step;
    final data = d.toJson();
    _draftDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _enqueueDraftSave(step, data),
    );
  }

  void _enqueueDraftSave(CreationStep step, Map<String, dynamic> data) {
    final store = widget.draftStore;
    if (store == null) return;
    _draftWrites = _draftWrites
        .then((_) => store.save(step: step, data: data))
        .catchError((Object error) {
          if (!mounted) return;
          showAppMessage(
            context,
            'No se pudo guardar el borrador: $error',
            tone: AppMessageTone.error,
          );
        });
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    await _draftWrites;
    try {
      await widget.draftStore?.clear();
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo limpiar el borrador: $error',
          tone: AppMessageTone.error,
        );
      }
    }
  }

  Future<void> _requestClose() async {
    if (!_hasProgress) {
      _closeWithoutPrompt();
      return;
    }
    if (_confirmingClose) return;
    _confirmingClose = true;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Descartar este personaje?'),
            content: const Text(
              'Las elecciones realizadas en el asistente se perderán.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Seguir creando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
    _confirmingClose = false;
    if (discard && mounted) {
      await _clearDraft();
      if (mounted) _closeWithoutPrompt();
    }
  }

  void _closeWithoutPrompt() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDraft) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = d.pendingFor(_step);
    return PopScope(
      canPop: _allowPop || !_hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= _kWideBreakpoint;
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerAndStepper(context, wide),
                Expanded(
                  // El LayoutBuilder va afuera del scroll a propósito: adentro
                  // el alto disponible ya es infinito y no hay contra qué
                  // medir una lista que quiera ocupar lo que haya.
                  child: LayoutBuilder(
                    builder: (context, viewport) => _StepViewport(
                      height: viewport.maxHeight,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 20,
                          14,
                          wide ? 40 : 20,
                          8,
                        ),
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ),
                _footer(context, pending),
              ],
            );
            if (!wide) return SafeArea(child: main);
            return SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _progressPanel(context),
                  Expanded(child: main),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Shell
  // --------------------------------------------------------------------------

  Widget _progressPanel(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Fichas\n'),
                        TextSpan(
                          text: 'D&D 5e',
                          style: TextStyle(color: pal.gold),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      height: 1.1,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            decoration: BoxDecoration(
              color: pal.plaque,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow('Progreso'),
                const SizedBox(height: 8),
                ThinBar(
                  ratio: (_step.index + 1) / _steps.length,
                  color: pal.gold,
                  track: scheme.surface,
                ),
                const SizedBox(height: 9),
                Text(
                  'Paso ${_step.index + 1} de ${_steps.length}',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAndStepper(BuildContext context, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final pal = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 22, wide ? 40 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Crear personaje',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 26,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: _requestClose,
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  side: BorderSide(color: pal.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _stepper(context, compact: !wide),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext context, {required bool compact}) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (final s in _steps) {
      final active = s == _step;
      final done = s.index < _step.index && d.pendingFor(s).isEmpty;
      final reachable = d.canGoTo(s);
      final ring = active || done ? pal.gold : pal.hairline;
      final fill = active
          ? pal.gold
          : done
          ? pal.goldSoft
          : scheme.surface;
      final fg = active
          ? scheme.onPrimary
          : done
          ? pal.gold
          : pal.textMuted;
      children.add(
        Semantics(
          selected: active,
          button: true,
          enabled: reachable,
          label: '${s.label}, paso ${s.index + 1} de ${_steps.length}',
          child: Tooltip(
            message: reachable ? s.label : 'Completá los pasos anteriores',
            child: InkWell(
              onTap: reachable ? () => _goTo(s) : null,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fill,
                        border: Border.all(color: ring, width: 2),
                      ),
                      child: Icon(_stepIcons[s], size: 22, color: fg),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      s.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .4,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active
                            ? pal.gold
                            : done
                            ? scheme.onSurfaceVariant
                            : pal.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (s != _steps.last) {
        final connector = Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 22),
          color: s.index < _step.index ? pal.gold : pal.hairline,
        );
        children.add(
          compact
              ? SizedBox(width: 20, child: connector)
              : Expanded(child: connector),
        );
      }
    }
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    if (!compact) return row;
    return Semantics(
      label: 'Progreso de creación',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: row,
      ),
    );
  }

  Widget _footer(BuildContext context, List<String> pending) {
    final pal = context.palette;
    final blocked = pending.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          if (_step != _steps.first)
            OutlinedButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Atrás'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              blocked ? 'Falta: ${pending.join('  ·  ')}' : '',
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: blocked ? null : _next,
            icon: Icon(_isLast ? Icons.check : Icons.arrow_forward, size: 20),
            label: Text(_isLast ? 'Crear personaje' : 'Siguiente'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    CreationStep.raza => _RaceStep(draft: d, onChanged: _refresh),
    CreationStep.clase => _ClassStep(draft: d, onChanged: _refresh),
    CreationStep.trasfondo => _BackgroundStep(draft: d, onChanged: _refresh),
    CreationStep.puntuaciones => _ScoresStep(draft: d, onChanged: _refresh),
    CreationStep.aptitudes => _AptitudesStep(draft: d, onChanged: _refresh),
    CreationStep.equipo => _EquipmentStep(draft: d, onChanged: _refresh),
    CreationStep.detalles => _DetailsStep(draft: d, onChanged: _refresh),
    CreationStep.resumen => _SummaryStep(draft: d, repo: widget.repo),
  };
}
