import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'add_monster_dialog.dart';

/// Cómo termina un combate: archivado en el registro de la campaña, o
/// descartado sin dejar rastro.
enum _CloseKind { save, discard }

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
  final void Function(String memberId, String name, int initiative) onAddPlayer;
  final void Function(Creature creature, int count) onAddMonster;

  /// [delta] es lo que cambia: negativo es daño, positivo es cura. El
  /// clampeo a `0..maxHp` lo hace `Encounter.withHp`, no esta pantalla.
  final void Function(String combatantId, int delta) onAdjustHp;
  final void Function(String combatantId) onRemoveCombatant;

  /// Termina el combate. Con `discard: true` no queda registro — ver
  /// [_confirmClose].
  final void Function({bool discard}) onCloseEncounter;

  const EncounterView({
    super.key,
    required this.repo,
    required this.encounter,
    required this.loading,
    required this.error,
    required this.members,
    required this.onRetry,
    required this.onAddPlayer,
    required this.onAddMonster,
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
        actions: const [],
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
        if (_sideWipedBanner(context, current) case final banner?) ...[
          const SizedBox(height: 16),
          banner,
        ],
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
        // Wrap y no Row: con tres botones con texto, una ventana angosta los
        // desbordaba en una sola línea que no podía partirse.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
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
            // Icono + texto y sin carmesí: un banderín rojo suelto se leía
            // como "rendirse". Terminar el combate es el final normal de un
            // encuentro, no una acción de peligro — el carmesí queda para el
            // botón de confirmar, que sí descarta el orden de turnos.
            OutlinedButton.icon(
              onPressed: () => _confirmClose(context),
              icon: const Icon(Icons.done_all),
              label: const Text('Terminar combate'),
            ),
          ],
        ),
      ],
    );
  }

  /// Aviso de que un bando se quedó sin nadie en pie, con la salida a mano.
  ///
  /// Vive acá y no en [Encounter] porque hace falta cruzar dos fuentes: los
  /// PG de los monstruos, que sí están en el encuentro, y los de los
  /// jugadores, que viven en su ficha real y llegan por [members]. Partir la
  /// cuenta en dos lugares sería peor que tenerla entera donde están los dos
  /// datos.
  ///
  /// Es un cartel y no un diálogo a propósito: los PG de los jugadores se
  /// releen cada 5 s, y un modal que se abre solo podría saltar justo encima
  /// de lo que el DM está tipeando. Avisa y espera.
  Widget? _sideWipedBanner(BuildContext context, Encounter current) {
    final players = [
      for (final c in current.combatants)
        if (c.kind == CombatantKind.player) c,
    ];
    final monsters = [
      for (final c in current.combatants)
        if (c.kind == CombatantKind.monster) c,
    ];

    bool playerIsDown(Combatant combatant) {
      final member = members
          .where((m) => m.memberId == combatant.memberId)
          .firstOrNull;
      // Sin la ficha a la vista no se asume nada: mejor no avisar que avisar
      // de una derrota que no pasó.
      if (member == null) return false;
      return member.character.combat.currentHp <= 0;
    }

    final monstersWiped =
        monsters.isNotEmpty && monsters.every((c) => c.isDown);
    final playersWiped = players.isNotEmpty && players.every(playerIsDown);
    if (!monstersWiped && !playersWiped) return null;

    final message = switch ((monstersWiped, playersWiped)) {
      (true, true) => 'No queda nadie en pie.',
      (true, false) => 'No queda ningún enemigo en pie.',
      _ => 'No queda ningún personaje en pie.',
    };

    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: pal.gold),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 18, color: pal.gold),
              const SizedBox(width: 8),
              Text('$message ¿Damos el encuentro por terminado?'),
            ],
          ),
          FilledButton.icon(
            onPressed: () => _confirmClose(context),
            icon: const Icon(Icons.done_all),
            label: const Text('Terminar combate'),
          ),
        ],
      ),
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

  /// Pregunta cómo termina el combate: archivándolo o descartándolo.
  ///
  /// Las dos salidas viven en el mismo diálogo porque es exactamente el
  /// momento en que se decide, y un cuarto botón en la barra la haría más
  /// difícil de leer sin ganar nada. El descarte no se llama "cancelar" a
  /// propósito: en esta app "Cancelar" ya significa "cerrar este diálogo" en
  /// todos lados, y usar la misma palabra para una acción irreversible sería
  /// pedir un clic equivocado.
  Future<void> _confirmClose(BuildContext context) async {
    final pal = context.palette;
    final choice = await showDialog<_CloseKind>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar combate'),
        content: const Text(
          'Se borra el orden de turnos en los dos casos. Si lo terminás queda '
          'un registro liviano de lo que pasó (sin PG ni daños: eso lo lleva '
          'cada jugador en su ficha). Si lo descartás no queda nada, como si '
          'nunca hubiera empezado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(ctx).pop(_CloseKind.discard),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Descartar sin guardar'),
            style: TextButton.styleFrom(foregroundColor: pal.crimson),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(_CloseKind.save),
            icon: const Icon(Icons.done_all),
            label: const Text('Terminar y guardar'),
            style: FilledButton.styleFrom(backgroundColor: pal.crimson),
          ),
        ],
      ),
    );
    if (choice == null) return;
    onCloseEncounter(discard: choice == _CloseKind.discard);
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
