import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'add_monster_dialog.dart';

/// El combate de una campaña: iniciativa, turnos y los PG de los monstruos.
///
/// No tiene estado de red propio — el dueño es `_CampaignDetailState`, que ya
/// necesita saber en todo momento si hay un combate abierto (para decidir si
/// sondea los PG de los jugadores cada 5 s, sin importar qué pestaña esté
/// mirando el DM). Una segunda copia acá solo podría desalinearse con esa.
/// Esta pantalla es presentación más los diálogos que arman los datos antes
/// de mandarlos para arriba.
class EncounterView extends StatelessWidget {
  final ContentRepository repo;
  final Encounter? encounter;
  final bool loading;
  final Object? error;

  /// Los personajes de la mesa, para mostrar sus PG en vivo (referencia viva:
  /// si el jugador se los anota, el DM lo ve sin que nadie escriba su ficha)
  /// y para ofrecer sumarlos a la iniciativa.
  final List<CampaignMember> members;

  final VoidCallback onRetry;
  final VoidCallback onStart;
  final void Function(String memberId, String name, int initiative) onAddPlayer;
  final void Function(Creature creature, int count) onAddMonster;
  final VoidCallback onNextTurn;

  /// [delta] es lo que cambia: negativo es daño, positivo es cura. El
  /// clampeo a `0..maxHp` lo hace `Encounter.withHp`, no esta pantalla.
  final void Function(String combatantId, int delta) onAdjustHp;
  final void Function(String combatantId) onRemoveCombatant;
  final VoidCallback onCloseEncounter;

  const EncounterView({
    super.key,
    required this.repo,
    required this.encounter,
    required this.loading,
    required this.error,
    required this.members,
    required this.onRetry,
    required this.onStart,
    required this.onAddPlayer,
    required this.onAddMonster,
    required this.onNextTurn,
    required this.onAdjustHp,
    required this.onRemoveCombatant,
    required this.onCloseEncounter,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AppErrorView(
        message: 'No se pudo leer el combate.',
        details: '$error',
        onRetry: onRetry,
      );
    }
    if (loading) {
      return const Center(child: AppBusyLabel('Cargando el combate…'));
    }
    final current = encounter;
    if (current == null) {
      return AppEmptyState(
        icon: Icons.local_fire_department_outlined,
        message: 'No hay ningún combate en curso.',
        actions: [
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.local_fire_department_outlined),
            label: const Text('Empezar combate'),
          ),
        ],
      );
    }

    final unadded = [
      for (final m in members)
        if (!current.combatants.any((c) => c.memberId == m.memberId)) m,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        _header(context, current),
        if (unadded.isNotEmpty) ...[
          const SizedBox(height: 16),
          _pendingPlayers(context, unadded),
        ],
        const SizedBox(height: 16),
        if (current.combatants.isEmpty)
          Text(
            'Todavía no hay nadie en el orden. Sumá jugadores o un monstruo '
            'para arrancar.',
            style: TextStyle(color: context.palette.textMuted),
          )
        else
          for (final combatant in current.combatants)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CombatantTile(
                combatant: combatant,
                active: current.current?.id == combatant.id,
                member: combatant.memberId == null
                    ? null
                    : members
                          .where((m) => m.memberId == combatant.memberId)
                          .firstOrNull,
                repo: repo,
                onAdjustHp: (delta) => onAdjustHp(combatant.id, delta),
                onRemove: () => onRemoveCombatant(combatant.id),
              ),
            ),
      ],
    );
  }

  Widget _header(BuildContext context, Encounter current) {
    final pal = context.palette;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Text(
          'Ronda ${current.round}',
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 22),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showAddMonsterDialog(context, repo);
                if (picked != null) {
                  onAddMonster(picked.creature, picked.count);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Sumar monstruo'),
            ),
            const SizedBox(width: 8),
            if (current.combatants.isNotEmpty)
              FilledButton.icon(
                onPressed: onNextTurn,
                icon: const Icon(Icons.skip_next),
                label: const Text('Siguiente turno'),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cerrar combate',
              onPressed: () => _confirmClose(context),
              icon: Icon(Icons.flag_outlined, color: pal.crimson),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pendingPlayers(BuildContext context, List<CampaignMember> unadded) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Todavía no tiraron iniciativa',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
          const SizedBox(height: 8),
          for (final member in unadded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(member.character.name)),
                  TextButton(
                    onPressed: () => _promptInitiative(context, member),
                    child: const Text('Sumar a la iniciativa'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _promptInitiative(
    BuildContext context,
    CampaignMember member,
  ) async {
    final value = await showTextPromptDialog(
      context,
      title: 'Iniciativa de ${member.character.name}',
      label: 'Lo que tiró en la mesa',
      keyboardType: TextInputType.number,
    );
    final initiative = value == null ? null : int.tryParse(value.trim());
    if (initiative == null) return;
    onAddPlayer(member.memberId, member.character.name, initiative);
  }

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar combate'),
        content: const Text(
          'Se borra el orden de turnos. Queda un registro liviano de lo que '
          'pasó, sin PG ni daños: eso lo lleva cada jugador en su ficha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Cerrar combate'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onCloseEncounter();
  }
}

/// Una fila del orden de iniciativa: un jugador (solo lectura, PG en vivo) o
/// un monstruo (con el único control de escritura de toda la fase).
class _CombatantTile extends StatefulWidget {
  final Combatant combatant;
  final bool active;
  final CampaignMember? member;
  final ContentRepository repo;
  final void Function(int delta) onAdjustHp;
  final VoidCallback onRemove;

  const _CombatantTile({
    required this.combatant,
    required this.active,
    required this.member,
    required this.repo,
    required this.onAdjustHp,
    required this.onRemove,
  });

  @override
  State<_CombatantTile> createState() => _CombatantTileState();
}

class _CombatantTileState extends State<_CombatantTile> {
  final _amountController = TextEditingController(text: '1');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final combatant = widget.combatant;
    final isPlayer = combatant.kind == CombatantKind.player;

    int? currentHp;
    int? maxHp;
    if (isPlayer) {
      final member = widget.member;
      if (member != null) {
        final sheet = CharacterCompiler(widget.repo).compile(member.character);
        currentHp = member.character.combat.currentHp;
        maxHp = sheet.maxHp;
      }
    } else {
      currentHp = combatant.currentHp;
      maxHp = combatant.maxHp;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: widget.active ? pal.verdant : pal.hairline,
          width: widget.active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${combatant.initiative}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.active ? pal.verdant : pal.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      combatant.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                      ),
                    ),
                    if (combatant.isDown) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· caído, se salta su turno',
                        style: TextStyle(fontSize: 12, color: pal.textMuted),
                      ),
                    ],
                  ],
                ),
                if (currentHp != null && maxHp != null && maxHp > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'PG $currentHp/$maxHp',
                        style: TextStyle(fontSize: 12, color: pal.crimson),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ThinBar(
                          ratio: currentHp / maxHp,
                          color: pal.crimson,
                          track: pal.plaque,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!isPlayer) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            IconButton(
              tooltip: 'Dañar',
              onPressed: () => widget.onAdjustHp(-_amount),
              icon: Icon(Icons.remove_circle_outline, color: pal.crimson),
            ),
            IconButton(
              tooltip: 'Curar',
              onPressed: () => widget.onAdjustHp(_amount),
              icon: Icon(Icons.add_circle_outline, color: pal.verdant),
            ),
          ],
          IconButton(
            tooltip: 'Sacar de la mesa',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
