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
    final name = await showTextPromptDialog(
      context,
      title: 'Nueva campaña',
      label: 'Nombre de la campaña',
    );
    if (name == null || !mounted) return;
    try {
      final created = await _campaigns.create(name);
      if (!mounted) return;
      setState(() => _selected = created);
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  Future<void> _renameCampaign(Campaign campaign) async {
    final name = await showRenameDialog(context, campaign.name);
    if (name == null || !mounted) return;
    final updated = campaign.copyWith(name: name);
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
                  for (final campaign in _campaigns.campaigns)
                    appNavItem(
                      context,
                      icon: Icons.menu_book_outlined,
                      label: campaign.name,
                      active: campaign.id == _selected?.id,
                      onTap: () {
                        setState(() => _selected = campaign);
                        if (inDrawer) Navigator.of(context).pop();
                      },
                    ),
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
          return AppEmptyState(
            icon: Icons.menu_book_outlined,
            message: 'Todavía no dirigís ninguna campaña.',
            actions: [
              FilledButton.icon(
                onPressed: _createCampaign,
                icon: const Icon(Icons.add),
                label: const Text('Crear campaña'),
              ),
            ],
          );
        }

        // Al entrar no hay nada elegido: se abre la primera en vez de mostrar
        // un panel vacío que obligue a un clic sin decisión detrás.
        final campaign =
            _campaigns.campaigns
                .where((c) => c.id == _selected?.id)
                .firstOrNull ??
            _campaigns.campaigns.first;

        return _CampaignDetail(
          key: ValueKey(campaign.id),
          campaign: campaign,
          api: widget.api,
          repo: widget.repo,
          onRename: () => _renameCampaign(campaign),
          onDelete: () => _deleteCampaign(campaign),
        );
      },
    );
  }
}

/// Lo que el DM ve de una campaña: quiénes juegan y cómo sumar a alguien.
class _CampaignDetail extends StatefulWidget {
  final Campaign campaign;
  final ApiClient api;
  final ContentRepository repo;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CampaignDetail({
    super.key,
    required this.campaign,
    required this.api,
    required this.repo,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_CampaignDetail> createState() => _CampaignDetailState();
}

enum _CampaignSection { mesa, combate }

class _CampaignDetailState extends State<_CampaignDetail> {
  List<CampaignMember>? _members;
  Object? _error;
  bool _busy = false;

  _CampaignSection _section = _CampaignSection.mesa;
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.campaign.name,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _summary(),
                    style: TextStyle(fontSize: 13, color: pal.textMuted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Renombrar campaña',
                    onPressed: widget.onRename,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Borrar campaña',
                    onPressed: widget.onDelete,
                    icon: Icon(Icons.delete_outline, color: pal.crimson),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _addMember,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Sumar personaje'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: AppBusyLabel('Sumando personaje…'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_CampaignSection>(
              segments: const [
                ButtonSegment(
                  value: _CampaignSection.mesa,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Mesa'),
                ),
                ButtonSegment(
                  value: _CampaignSection.combate,
                  icon: Icon(Icons.local_fire_department_outlined),
                  label: Text('Combate'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_section) {
            _CampaignSection.mesa => _roster(context),
            _CampaignSection.combate => EncounterView(
              repo: widget.repo,
              encounter: _encounter,
              loading: _encounterLoading,
              error: _encounterError,
              members: _members ?? const [],
              onRetry: _loadEncounter,
              onStart: _startEncounter,
              onAddPlayer: _addPlayerToEncounter,
              onAddMonster: _addMonsters,
              onNextTurn: _nextTurn,
              onAdjustHp: _adjustCombatantHp,
              onRemoveCombatant: _removeCombatant,
              onCloseEncounter: _closeEncounter,
            ),
          },
        ),
      ],
    );
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
        actions: [
          FilledButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Sumar personaje'),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _MemberCard(
        campaignId: widget.campaign.id,
        member: members[i],
        repo: widget.repo,
        onRemove: () => _removeMember(members[i]),
      ),
    );
  }
}

/// La ficha de un jugador, de un vistazo y en solo lectura.
///
/// Se compila igual que en el panel de personajes: el DM ve lo que el jugador
/// tiene ahora, porque el vínculo apunta a la ficha real y no a una copia.
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
      padding: const EdgeInsets.all(16),
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
                Text(
                  character.name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (race != null) race.name,
                    if (klass != null) klass.name,
                    'Nivel ${character.level}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'PG $currentHp/$maxHp',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pal.crimson,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'CA ${sheet.armorClass}',
                      style: const TextStyle(fontSize: 13),
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
          IconButton(
            tooltip: 'Echar a ${character.name}',
            onPressed: onRemove,
            icon: Icon(Icons.person_remove_outlined, color: pal.crimson),
          ),
        ],
      ),
    );
  }
}
