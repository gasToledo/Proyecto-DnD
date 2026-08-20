import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/api_models.dart';
import '../../data/campaigns_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../theme/class_visuals.dart';
import '../pending_events_gate.dart';
import '../portrait_image.dart';
import 'campaign_editor_dialog.dart';
import 'chapter_editor_dialog.dart';
import 'chapters_view.dart';
import 'encounter_view.dart';

/// El otro sombrero de la misma cuenta.
///
/// No es un rol ni un permiso que quede prendido: se entra cuando se dirige y
/// se sale volviendo atrás. Quien dirige en una mesa puede ser jugador en otra
/// sin necesitar una segunda cuenta, que era el punto de que esto sea una
/// puerta y no un estado.
class DmModeScreen extends StatefulWidget {
  final ApiClient api;
  final ContentRepository repo;

  const DmModeScreen({super.key, required this.api, required this.repo});

  @override
  State<DmModeScreen> createState() => _DmModeScreenState();
}

class _DmModeScreenState extends State<DmModeScreen> {
  static const double _wideBreakpoint = 900;

  late final CampaignsController _campaigns = CampaignsController(widget.api);
  Campaign? _selected;
  Object? _loadError;

  Campaign? get _effectiveSelection =>
      _campaigns.campaigns
          .where((campaign) => campaign.id == _selected?.id)
          .firstOrNull ??
      _campaigns.campaigns
          .where((campaign) => campaign.state == CampaignState.active)
          .firstOrNull ??
      _campaigns.campaigns.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _campaigns.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      await _campaigns.load();
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _createCampaign() async {
    final draft = await showCampaignEditorDialog(
      context,
      current: const Campaign(id: 'draft', name: ''),
      title: 'Nueva campaña',
    );
    if (draft == null || !mounted) return;
    try {
      final created = await _campaigns.create(
        draft.name,
        premise: draft.premise,
        state: draft.state,
      );
      if (!mounted) return;
      setState(() => _selected = created);
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  Future<void> _editCampaign(Campaign campaign) async {
    final updated = await showCampaignEditorDialog(
      context,
      current: campaign,
      title: 'Editar campaña',
    );
    if (updated == null || !mounted) return;
    try {
      await _campaigns.update(updated);
      if (mounted) setState(() => _selected = updated);
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  Future<void> _deleteCampaign(Campaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar campaña'),
        content: Text(
          'Se borra «${campaign.name}» y se sueltan los personajes que los '
          'jugadores le compartieron. Las fichas no se tocan: siguen siendo '
          'de sus dueños.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar campaña'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _campaigns.delete(campaign.id);
      if (mounted) setState(() => _selected = null);
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                _sidebar(context),
                Expanded(child: _content(context)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Modo DM'),
            actions: [
              IconButton(
                tooltip: 'Nueva campaña',
                onPressed: _createCampaign,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(child: _sidebar(context, inDrawer: true)),
          ),
          body: _content(context),
        );
      },
    );
  }

  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final active = _campaigns.campaigns
        .where((campaign) => campaign.state == CampaignState.active)
        .toList();
    final paused = _campaigns.campaigns
        .where((campaign) => campaign.state == CampaignState.paused)
        .toList();
    final finished = _campaigns.campaigns
        .where((campaign) => campaign.state == CampaignState.finished)
        .toList();
    return Container(
      width: inDrawer ? null : 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: pal.gold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo DM',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _campaigns,
              builder: (context, _) => ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (active.isNotEmpty) ...[
                    const _CampaignGroupLabel('En curso'),
                    for (final campaign in active)
                      _campaignNavItem(context, campaign, inDrawer: inDrawer),
                  ],
                  if (paused.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _CampaignGroupLabel('En pausa'),
                    for (final campaign in paused)
                      _campaignNavItem(context, campaign, inDrawer: inDrawer),
                  ],
                  if (finished.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: ValueKey(
                          'finished-${_effectiveSelection?.state == CampaignState.finished ? _effectiveSelection?.id : 'none'}',
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        childrenPadding: EdgeInsets.zero,
                        initiallyExpanded: finished.any(
                          (campaign) => campaign.id == _effectiveSelection?.id,
                        ),
                        title: const _CampaignGroupLabel('Terminadas'),
                        children: [
                          for (final campaign in finished)
                            _campaignNavItem(
                              context,
                              campaign,
                              inDrawer: inDrawer,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _createCampaign,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva campaña'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('exit-dm-mode'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Volver a mis personajes'),
          ),
        ],
      ),
    );
  }

  Widget _campaignNavItem(
    BuildContext context,
    Campaign campaign, {
    required bool inDrawer,
  }) {
    return appNavItem(
      context,
      icon: Icons.menu_book_outlined,
      label: campaign.name,
      active: campaign.id == _effectiveSelection?.id,
      onTap: () {
        setState(() => _selected = campaign);
        if (inDrawer) Navigator.of(context).pop();
      },
    );
  }

  Widget _content(BuildContext context) {
    if (_loadError != null) {
      return AppErrorView(
        message: 'No se pudieron cargar tus campañas.',
        details: '$_loadError',
        onRetry: _load,
      );
    }
    return ListenableBuilder(
      listenable: _campaigns,
      builder: (context, _) {
        if (_campaigns.loadFailedOffline) {
          return AppErrorView(
            icon: Icons.cloud_off,
            message: 'No hay conexión con el servidor.',
            hint: 'Tus campañas están a salvo; solo no se pueden leer ahora.',
            onRetry: _load,
          );
        }
        if (_campaigns.isLoading && _campaigns.campaigns.isEmpty) {
          return const Center(child: AppBusyLabel('Cargando campañas…'));
        }
        if (_campaigns.campaigns.isEmpty) {
          return _DmOnboardingState(onCreate: _createCampaign);
        }

        // Al entrar no hay nada elegido: se abre la primera en vez de mostrar
        // un panel vacío que obligue a un clic sin decisión detrás.
        final campaign = _effectiveSelection!;

        return _CampaignDetail(
          key: ValueKey(campaign.id),
          campaign: campaign,
          api: widget.api,
          repo: widget.repo,
          onEdit: () => _editCampaign(campaign),
          onDelete: () => _deleteCampaign(campaign),
        );
      },
    );
  }
}

class _CampaignGroupLabel extends StatelessWidget {
  final String text;

  const _CampaignGroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 7),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: context.palette.textMuted,
      ),
    ),
  );
}

class _DmOnboardingState extends StatelessWidget {
  final VoidCallback onCreate;

  const _DmOnboardingState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_moon_outlined, color: pal.gold, size: 32),
                const SizedBox(height: 16),
                const Text(
                  'Prepará tu primera mesa',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todavía no dirigís ninguna campaña. Este espacio reúne lo '
                  'que necesitás antes y durante la partida.',
                  style: TextStyle(color: pal.textMuted),
                ),
                const SizedBox(height: 22),
                const _OnboardingStep(
                  number: '1',
                  title: 'Creá la campaña',
                  detail: 'Poné nombre a la mesa y resumí su premisa.',
                ),
                const _OnboardingStep(
                  number: '2',
                  title: 'Sumá los personajes',
                  detail: 'Cada jugador te comparte su ficha con un código.',
                ),
                const _OnboardingStep(
                  number: '3',
                  title: 'Dirigí la sesión',
                  detail:
                      'Organizá capítulos y llevá la iniciativa del combate.',
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear campaña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final String number;
  final String title;
  final String detail;

  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pal.goldSoft,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                color: pal.gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12.5, color: pal.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que el DM ve de una campaña: quiénes juegan y cómo sumar a alguien.
class _CampaignDetail extends StatefulWidget {
  final Campaign campaign;
  final ApiClient api;
  final ContentRepository repo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CampaignDetail({
    super.key,
    required this.campaign,
    required this.api,
    required this.repo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CampaignDetail> createState() => _CampaignDetailState();
}

enum _CampaignSection { mesa, capitulos, combate }

enum _CampaignMenuAction { edit, delete }

class _CampaignDetailState extends State<_CampaignDetail> {
  List<CampaignMember>? _members;
  Object? _error;
  bool _busy = false;

  _CampaignSection _section = _CampaignSection.mesa;

  List<Chapter>? _chapters;
  bool _chaptersLoading = true;
  Object? _chaptersError;

  Encounter? _encounter;
  bool _encounterLoading = true;
  Object? _encounterError;

  /// Sondea los PG de los jugadores mientras haya combate abierto — no según
  /// qué sección esté mirando el DM, porque el vínculo es referencia viva y
  /// el jugador puede anotarse el daño con la pestaña de Mesa al frente.
  /// Se arranca/para acá y no en `EncounterView` para no tener dos copias del
  /// mismo "¿hay combate?" que puedan desalinearse.
  Timer? _memberPollTimer;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadChapters();
    _loadEncounter();
  }

  @override
  void dispose() {
    _memberPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _error = null);
    try {
      final members = await widget.api.listCampaignMembers(widget.campaign.id);
      if (mounted) setState(() => _members = members);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _addMember() async {
    final code = await showTextPromptDialog(
      context,
      title: 'Sumar personaje',
      label: 'Código que te pasó el jugador',
      // El código viaja en mayúsculas y el servidor lo normaliza igual, pero
      // verlo tal cual se dictó evita la duda de si se tipeó bien.
      textCapitalization: TextCapitalization.characters,
    );
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final member = await widget.api.addCampaignMember(
        campaignId: widget.campaign.id,
        code: code,
      );
      await _loadMembers();
      if (!mounted) return;
      showAppMessage(
        context,
        '${member.character.name} se sumó a ${widget.campaign.name}.',
        tone: AppMessageTone.success,
      );
      _checkEventsSoon();
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Vuelve a preguntar por avisos pendientes un rato después de una acción
  /// propia, para no taparle el cartel de confirmación de esa acción a la
  /// persona que la acaba de hacer.
  void _checkEventsSoon() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) checkPendingEvents(context, widget.api);
    });
  }

  Future<void> _removeMember(CampaignMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Echar personaje'),
        content: Text(
          '${member.character.name} sale de «${widget.campaign.name}» y dejás '
          'de ver su ficha. El personaje sigue siendo de su dueño y no se '
          'toca; puede volver con un código nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Echar personaje'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.deleteCampaignLink(member.memberId);
      await _loadMembers();
      if (mounted) {
        showAppMessage(context, '${member.character.name} salió de la mesa.');
        _checkEventsSoon();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  // --- Capítulos ----------------------------------------------------------

  Future<void> _loadChapters() async {
    setState(() {
      _chaptersLoading = true;
      _chaptersError = null;
    });
    try {
      final chapters = await widget.api.listChapters(widget.campaign.id);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _chaptersLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _chaptersError = error;
          _chaptersLoading = false;
        });
      }
    }
  }

  /// Envuelve una acción sobre capítulos: recarga la lista al terminar y
  /// muestra el mensaje del servidor si algo no se pudo. Los errores que
  /// importan acá llegan con texto propio y legible (dos capítulos en marcha,
  /// cerrar con un `PUT`), así que se muestran tal cual.
  Future<void> _chapterAction(Future<void> Function() action) async {
    try {
      await action();
      await _loadChapters();
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  Future<void> _createChapter() async {
    final draft = await showChapterEditorDialog(
      context,
      current: Chapter(id: _newId('chapter'), name: ''),
      title: 'Nuevo capítulo',
    );
    if (draft == null) return;
    await _chapterAction(
      () => widget.api.createChapter(widget.campaign.id, draft),
    );
  }

  Future<void> _editChapter(Chapter chapter) async {
    final edited = await showChapterEditorDialog(
      context,
      current: chapter,
      title: 'Editar capítulo',
    );
    if (edited == null) return;
    await _chapterAction(
      () => widget.api.upsertChapter(widget.campaign.id, edited),
    );
  }

  Future<void> _startChapter(Chapter chapter) => _chapterAction(
    () => widget.api.upsertChapter(
      widget.campaign.id,
      chapter.copyWith(state: ChapterState.active),
    ),
  );

  Future<void> _closeChapter(Chapter chapter) async {
    await _chapterAction(
      () => widget.api.closeChapter(widget.campaign.id, chapter.id),
    );
    if (mounted) {
      showAppMessage(
        context,
        'Se cerró «${chapter.name}». Les llega el aviso a los jugadores.',
        tone: AppMessageTone.success,
      );
    }
  }

  Future<void> _deleteChapter(Chapter chapter) => _chapterAction(
    () => widget.api.deleteChapter(widget.campaign.id, chapter.id),
  );

  // --- Combate ------------------------------------------------------------

  Future<void> _loadEncounter() async {
    setState(() {
      _encounterLoading = true;
      _encounterError = null;
    });
    try {
      final encounter = await widget.api.getEncounter(widget.campaign.id);
      if (!mounted) return;
      setState(() {
        _encounter = encounter;
        _encounterLoading = false;
      });
      _syncMemberPolling();
    } catch (error) {
      if (mounted) {
        setState(() {
          _encounterError = error;
          _encounterLoading = false;
        });
      }
    }
  }

  void _syncMemberPolling() {
    final shouldPoll = _encounter != null;
    if (shouldPoll && _memberPollTimer == null) {
      _memberPollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadMembers(),
      );
    } else if (!shouldPoll) {
      _memberPollTimer?.cancel();
      _memberPollTimer = null;
    }
  }

  Future<void> _saveEncounter(Encounter encounter) async {
    try {
      await widget.api.saveEncounter(widget.campaign.id, encounter);
      if (!mounted) return;
      setState(() => _encounter = encounter);
      _syncMemberPolling();
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  void _startEncounter() => _saveEncounter(Encounter(id: _newId('encounter')));

  void _addPlayerToEncounter(String memberId, String name, int initiative) {
    final encounter = _encounter ?? Encounter(id: _newId('encounter'));
    _saveEncounter(
      encounter.withCombatant(
        Combatant(
          id: _newId('c'),
          kind: CombatantKind.player,
          name: name,
          initiative: initiative,
          memberId: memberId,
        ),
      ),
    );
  }

  /// Tira una iniciativa independiente por copia (nunca la misma para todo el
  /// grupo) y numera los repetidos: "Goblin", "Goblin 2", "Goblin 3".
  void _addMonsters(Creature creature, int count) {
    var encounter = _encounter ?? Encounter(id: _newId('encounter'));
    final already = encounter.combatants
        .where((c) => c.creatureId == creature.id)
        .length;
    final resolved = creature.resolve(const CreatureVars({}));
    for (var i = 0; i < count; i++) {
      final n = already + i + 1;
      encounter = encounter.withCombatant(
        Combatant(
          id: _newId('c'),
          kind: CombatantKind.monster,
          name: n == 1 ? creature.name : '${creature.name} $n',
          initiative: rollInitiative(creature),
          creatureId: creature.id,
          currentHp: resolved.maxHp,
          maxHp: resolved.maxHp,
        ),
      );
    }
    _saveEncounter(encounter);
  }

  void _nextTurn() {
    final encounter = _encounter;
    if (encounter != null) _saveEncounter(encounter.next());
  }

  void _adjustCombatantHp(String combatantId, int delta) {
    final encounter = _encounter;
    if (encounter == null) return;
    final combatant = encounter.combatants
        .where((c) => c.id == combatantId)
        .firstOrNull;
    if (combatant == null) return;
    _saveEncounter(encounter.withHp(combatantId, combatant.currentHp + delta));
  }

  void _removeCombatant(String combatantId) {
    final encounter = _encounter;
    if (encounter != null) {
      _saveEncounter(encounter.withoutCombatant(combatantId));
    }
  }

  Future<void> _closeEncounter({bool discard = false}) async {
    try {
      await widget.api.endEncounter(widget.campaign.id, discard: discard);
      if (!mounted) return;
      setState(() => _encounter = null);
      _syncMemberPolling();
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final titleWidth = box.maxWidth >= 820
                ? box.maxWidth - 310
                : box.maxWidth;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 20,
                runSpacing: 16,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: titleWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            Text(
                              widget.campaign.name,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 28,
                              ),
                            ),
                            GoldPill(
                              widget.campaign.state.label,
                              highlighted:
                                  widget.campaign.state == CampaignState.active,
                            ),
                          ],
                        ),
                        if (widget.campaign.premise.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            widget.campaign.premise,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 16,
                          runSpacing: 7,
                          children: [
                            _CampaignMeta(
                              icon: Icons.groups_outlined,
                              text: _summary(),
                            ),
                            if (_activeChapter case final chapter?)
                              _CampaignMeta(
                                icon: Icons.auto_stories_outlined,
                                text: chapter.name,
                                highlighted: true,
                              ),
                            if (_encounter case final encounter?)
                              _CampaignMeta(
                                icon: Icons.local_fire_department_outlined,
                                text: 'Combate · ronda ${encounter.round}',
                                highlighted: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<_CampaignMenuAction>(
                        tooltip: 'Acciones de campaña',
                        onSelected: (action) {
                          switch (action) {
                            case _CampaignMenuAction.edit:
                              widget.onEdit();
                            case _CampaignMenuAction.delete:
                              widget.onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _CampaignMenuAction.edit,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar campaña'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _CampaignMenuAction.delete,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline,
                                color: pal.crimson,
                              ),
                              title: Text(
                                'Borrar campaña',
                                style: TextStyle(color: pal.crimson),
                              ),
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz),
                      ),
                      const SizedBox(width: 8),
                      _primaryAction(),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: AppBusyLabel('Sumando personaje…'),
          ),
        LayoutBuilder(
          builder: (context, box) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_CampaignSection>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _CampaignSection.mesa,
                    icon: box.maxWidth >= 600
                        ? const Icon(Icons.groups_outlined)
                        : null,
                    label: _SectionLabel(
                      text: 'Mesa',
                      badge: box.maxWidth >= 700 && _members != null
                          ? '${_members!.length}'
                          : null,
                    ),
                  ),
                  ButtonSegment(
                    value: _CampaignSection.capitulos,
                    icon: box.maxWidth >= 600
                        ? const Icon(Icons.auto_stories_outlined)
                        : null,
                    label: _SectionLabel(
                      text: 'Capítulos',
                      badge: box.maxWidth >= 700 && _chapters != null
                          ? '${_chapters!.length}'
                          : null,
                    ),
                  ),
                  ButtonSegment(
                    value: _CampaignSection.combate,
                    icon: box.maxWidth >= 600
                        ? const Icon(Icons.local_fire_department_outlined)
                        : null,
                    label: _SectionLabel(
                      text: 'Combate',
                      badge: box.maxWidth >= 700 && _encounter != null
                          ? 'En curso'
                          : null,
                      highlighted: _encounter != null,
                    ),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selection) =>
                    setState(() => _section = selection.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (_section) {
            _CampaignSection.mesa => _roster(context),
            _CampaignSection.capitulos => ChaptersView(
              chapters: _chapters,
              loading: _chaptersLoading,
              error: _chaptersError,
              onRetry: _loadChapters,
              onCreate: _createChapter,
              onEdit: _editChapter,
              onStart: _startChapter,
              onClose: _closeChapter,
              onDelete: _deleteChapter,
            ),
            _CampaignSection.combate => EncounterView(
              repo: widget.repo,
              encounter: _encounter,
              loading: _encounterLoading,
              error: _encounterError,
              members: _members ?? const [],
              onRetry: _loadEncounter,
              onAddPlayer: _addPlayerToEncounter,
              onAddMonster: _addMonsters,
              onAdjustHp: _adjustCombatantHp,
              onRemoveCombatant: _removeCombatant,
              onCloseEncounter: _closeEncounter,
            ),
          },
        ),
      ],
    );
  }

  Chapter? get _activeChapter => _chapters
      ?.where((chapter) => chapter.state == ChapterState.active)
      .firstOrNull;

  Widget _primaryAction() {
    return switch (_section) {
      _CampaignSection.mesa => FilledButton.icon(
        onPressed: _busy ? null : _addMember,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Sumar personaje'),
      ),
      _CampaignSection.capitulos => FilledButton.icon(
        onPressed: _chaptersLoading ? null : _createChapter,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo capítulo'),
      ),
      _CampaignSection.combate when _encounter == null => FilledButton.icon(
        onPressed: _encounterLoading ? null : _startEncounter,
        icon: const Icon(Icons.local_fire_department_outlined),
        label: const Text('Empezar combate'),
      ),
      _ => FilledButton.icon(
        onPressed: _encounter!.combatants.isEmpty ? null : _nextTurn,
        icon: const Icon(Icons.skip_next),
        label: const Text('Siguiente turno'),
      ),
    };
  }

  String _summary() {
    final count = _members?.length;
    if (count == null) return 'Cargando la mesa…';
    if (count == 0) return 'Todavía nadie compartió su personaje.';
    return count == 1
        ? '1 personaje en la mesa'
        : '$count personajes en la mesa';
  }

  Widget _roster(BuildContext context) {
    if (_error != null) {
      return AppErrorView(
        message: 'No se pudo leer la mesa.',
        details: '$_error',
        onRetry: _loadMembers,
      );
    }
    final members = _members;
    if (members == null) {
      return const Center(child: AppBusyLabel('Cargando la mesa…'));
    }
    if (members.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_add_alt,
        message:
            'Pedile a cada jugador que abra su personaje, toque Compartir y '
            'te pase el código.',
        actions: const [],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 136,
          ),
          itemCount: members.length,
          itemBuilder: (context, i) => _MemberCard(
            campaignId: widget.campaign.id,
            member: members[i],
            repo: widget.repo,
            onRemove: () => _removeMember(members[i]),
          ),
        );
      },
    );
  }
}

class _CampaignMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlighted;

  const _CampaignMeta({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final color = highlighted
        ? pal.gold
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? badge;
  final bool highlighted;

  const _SectionLabel({
    required this.text,
    this.badge,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (badge == null) return Text(text);
    final pal = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: highlighted ? pal.goldSoft : pal.plaque,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge!,
            style: TextStyle(
              fontSize: 10,
              color: highlighted ? pal.gold : pal.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// La ficha de un jugador, de un vistazo y en solo lectura.
///
/// Se compila igual que en el panel de personajes: el DM ve lo que el jugador
/// tiene ahora, porque el vínculo apunta a la ficha real y no a una copia.
enum _MemberMenuAction { remove }

class _MemberCard extends StatelessWidget {
  final String campaignId;
  final CampaignMember member;
  final ContentRepository repo;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.campaignId,
    required this.member,
    required this.repo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final character = member.character;
    final sheet = CharacterCompiler(repo).compile(character);
    final klass = repo.characterClass(character.classId);
    final race = repo.race(character.raceId);
    final maxHp = sheet.maxHp;
    final currentHp = character.combat.currentHp;
    final portraitKey = character.portraitPaths.firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClassMedallion(
            klass: klass,
            portraitKey: portraitKey,
            portraitUrlBase: portraitKey == null
                ? null
                : PortraitImage.urlForMember(
                    campaignId,
                    member.memberId,
                    portraitKey,
                  ),
            fallback: character.name.characters.firstOrNull ?? '?',
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GoldPill('Nivel ${character.level}', highlighted: false),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (race != null) race.name,
                    if (klass != null) klass.name,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
                const SizedBox(height: 11),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Puntos de golpe: $currentHp de $maxHp',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.favorite_outline,
                                  size: 14,
                                  color: pal.crimson,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'PG $currentHp/$maxHp',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ThinBar(
                              ratio: maxHp == 0 ? 0 : currentHp / maxHp,
                              color: pal.crimson,
                              track: pal.plaque,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ShieldBadge('${sheet.armorClass}', height: 40),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_MemberMenuAction>(
            tooltip: 'Acciones de ${character.name}',
            onSelected: (_) => onRemove(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MemberMenuAction.remove,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: pal.crimson,
                  ),
                  title: Text(
                    'Echar de la mesa',
                    style: TextStyle(color: pal.crimson),
                  ),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}
