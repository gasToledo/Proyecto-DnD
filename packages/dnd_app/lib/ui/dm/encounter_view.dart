import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'add_monster_dialog.dart';
import 'combatant_tags_dialog.dart';
import 'npcs/npc_shared.dart';

/// Cómo termina un combate: archivado en el registro de la campaña, o
/// descartado sin dejar rastro.
enum _CloseKind { save, discard }

/// Las dos solapas de la columna derecha.
enum _PanelTab { turno, efectos }

/// Ancho de la columna derecha. Fijo, como el panel lateral de la app: lo que
/// no entra se recorta, no se encoge.
const double _kPanelWidth = 300;

/// Ancho de contenido a partir del cual la columna derecha va **al lado** de
/// la planilla. Debajo se apila abajo, que es peor pero entra.
const double _kPanelBesideWidth = 1040;

/// Ancho de planilla a partir del cual las filas mantienen sus columnas. Por
/// debajo cada fila se parte en dos líneas: preferimos eso a un scroll
/// horizontal, que en una mesa se pierde justo cuando hay apuro.
const double _kColumnsWidth = 780;

// Las columnas de la planilla, en un solo lugar: el encabezado y las filas se
// miden con las mismas constantes o dejan de alinear a la primera edición.
const double _kIniWidth = 46;
const double _kHpWidth = 128;
const double _kAcWidth = 40;
const double _kTagsWidth = 160;
const double _kActionsWidth = 168;
const double _kColGap = 12;

/// El combate de una campaña: iniciativa, turnos y los PG de los monstruos.
///
/// Los datos son todos del padre (`_CampaignDetailState`), que ya necesita
/// saber en todo momento si hay un combate abierto para decidir si sondea los
/// PG de los jugadores cada 5 s. El estado propio de acá es **solo de
/// interfaz** y no vale la pena subirlo: el número que reparten los −/+ y qué
/// solapa está abierta.
class EncounterView extends StatefulWidget {
  final ContentRepository repo;
  final Encounter? encounter;
  final bool loading;
  final Object? error;

  /// Los personajes de la mesa, para mostrar sus PG en vivo (referencia viva:
  /// si el jugador se los anota, el DM lo ve sin que nadie escriba su ficha)
  /// y para ofrecer sumarlos a la iniciativa.
  final List<CampaignMember> members;

  /// Los PNJ de la campaña con su estado. El diálogo de sumar los ofrece, y
  /// el turno de un PNJ muestra de acá lo que el DM necesita para jugarlo:
  /// cómo habla y su trasfondo.
  final List<CampaignNpcEntry> npcs;

  /// La biblioteca entera, que se pide recién al abrir el diálogo de sumar:
  /// es lo único que la necesita.
  final Future<List<NpcEntry>> Function() loadNpcLibrary;

  final VoidCallback onRetry;
  final void Function(String memberId, String name, int initiative) onAddPlayer;
  final void Function(
    Creature creature,
    int count, {
    bool rollHp,
    CombatantSide side,
  })
  onAddMonster;

  /// [initiative] es 0 mientras se arma la mesa; con el combate andando es lo
  /// que el DM cargó a mano, igual que la de un jugador que llega tarde.
  final void Function(AddNpcChoice choice, int initiative) onAddNpc;
  final void Function(String combatantId, CombatantSide side) onSetSide;

  /// Convierte a un monstruo de la mesa en un PNJ llamado [name].
  final void Function(String combatantId, String name) onConvertToNpc;

  /// [delta] es lo que cambia: negativo es daño, positivo es cura. El
  /// clampeo a `0..maxHp` lo hace `Encounter.withHp`, no esta pantalla.
  final void Function(String combatantId, int delta) onAdjustHp;
  final void Function(String combatantId) onRemoveCombatant;

  /// Reemplaza los efectos anotados de un combatiente.
  final void Function(String combatantId, List<String> tags) onSetTags;

  /// Corrige la iniciativa de alguien que ya está en el orden.
  final void Function(String combatantId, int initiative) onSetInitiative;

  /// Termina el combate. Con `discard: true` no queda registro — ver
  /// [_confirmClose]. [deadNpcIds] son los PNJ que el DM marcó muertos.
  final void Function({bool discard, Set<String> deadNpcIds}) onCloseEncounter;

  const EncounterView({
    super.key,
    required this.repo,
    required this.encounter,
    required this.loading,
    required this.error,
    required this.members,
    required this.npcs,
    required this.loadNpcLibrary,
    required this.onRetry,
    required this.onAddPlayer,
    required this.onAddMonster,
    required this.onAddNpc,
    required this.onSetSide,
    required this.onConvertToNpc,
    required this.onAdjustHp,
    required this.onRemoveCombatant,
    required this.onSetTags,
    required this.onSetInitiative,
    required this.onCloseEncounter,
  });

  @override
  State<EncounterView> createState() => _EncounterViewState();
}

class _EncounterViewState extends State<EncounterView> {
  /// El número que reparten los −/+ de **todas** las filas.
  ///
  /// Antes había un campito por fila y era el mismo número tipeado muchas
  /// veces: un ataque hace el mismo daño al goblin que le pega que al que
  /// tiene al lado. Se escribe una vez arriba y se reparte donde haga falta.
  final _amountController = TextEditingController(text: '1');

  _PanelTab _tab = _PanelTab.turno;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return AppErrorView(
        message: 'No se pudo leer el combate.',
        details: '${widget.error}',
        onRetry: widget.onRetry,
      );
    }
    if (widget.loading) {
      return const Center(child: AppBusyLabel('Cargando el combate…'));
    }
    final current = widget.encounter;
    if (current == null) {
      return AppEmptyState(
        icon: Icons.local_fire_department_outlined,
        message: 'No hay ningún combate en curso.',
        actions: const [],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Mientras se arma la mesa no hay turno que leer ni ronda que contar:
        // la columna derecha no tendría nada que mostrar.
        final panel = current.isPreparing ? null : _panel(context, current);
        final beside = panel != null && box.maxWidth >= _kPanelBesideWidth;
        final ledgerWidth = beside
            ? box.maxWidth - _kPanelWidth - 16 - 48
            : box.maxWidth - 48;

        final ledger = _ledgerChildren(
          context,
          current,
          columns: ledgerWidth >= _kColumnsWidth,
        );

        if (!beside) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              ...ledger,
              if (panel != null) ...[const SizedBox(height: 16), panel],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 24),
                children: ledger,
              ),
            ),
            SizedBox(
              width: _kPanelWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 24),
                children: [panel],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- La columna de la planilla -------------------------------------------

  List<Widget> _ledgerChildren(
    BuildContext context,
    Encounter current, {
    required bool columns,
  }) {
    final pal = context.palette;
    final unadded = [
      for (final m in widget.members)
        if (!current.combatants.any((c) => c.memberId == m.memberId)) m,
    ];

    return [
      _controlBar(context, current),
      if (_sideWipedBanner(context, current) case final banner?) ...[
        const SizedBox(height: 12),
        banner,
      ],
      const SizedBox(height: 12),
      if (current.combatants.isEmpty)
        Text(
          'Todavía no hay nadie en el orden. Sumá jugadores o un monstruo '
          'para arrancar.',
          style: TextStyle(color: pal.textMuted),
        )
      else
        _ledger(context, current, columns: columns),
      if (unadded.isNotEmpty) ...[
        const SizedBox(height: 12),
        _pendingPlayers(context, unadded, preparing: current.isPreparing),
      ],
    ];
  }

  /// La barra de arriba: en qué momento va el combate y con qué número pegan
  /// los −/+ de las filas.
  Widget _controlBar(BuildContext context, Encounter current) {
    final pal = context.palette;

    if (current.isPreparing) {
      return _plaque(
        context,
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
                // «Combate» y no «mesa»: en el resto del Modo DM la mesa es el
                // grupo de jugadores de la campaña, y acá se hablaba de «los
                // que no están en la mesa» refiriéndose a esos mismos.
                const Text(
                  'Armando el combate',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20),
                ),
                const SizedBox(height: 3),
                Text(
                  'Todavía nadie tiró iniciativa, y a los jugadores no les '
                  'aparece nada en su ficha.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ],
            ),
            _encounterActions(context),
          ],
        ),
      );
    }

    final standing = _standing(current);
    final turn = current.combatants.indexWhere(
      (c) => c.id == current.current?.id,
    );

    // Un solo `Wrap` y no `Row` + `Expanded`: los botones son hijos sin flex,
    // así que un `Row` se los mide con ancho infinito, se quedan con lo que
    // pidan y al `Expanded` le sobra la miseria que reste — de ahí salían
    // desbordes de la barra en ventanas que sobraban de anchas. Acá cada grupo
    // se mide contra el ancho real de la barra y baja de línea cuando no entra.
    return _plaque(
      context,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _columnLabel(context, 'Ronda'),
              const SizedBox(width: 9),
              Text(
                '${current.round}',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  height: 1,
                  color: pal.gold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          _divider(context),
          Text(
            'Turno ${turn < 0 ? 1 : turn + 1} de '
            '${current.combatants.length}',
            style: TextStyle(
              fontSize: 12.5,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _divider(context),
          _standingCounts(context, standing),
          _divider(context),
          _quickAmount(context),
          _encounterActions(context),
        ],
      ),
    );
  }

  /// Cuántos quedan en pie de cada lado.
  ///
  /// Es el mismo dato que dispara [_sideWipedBanner], pero a la vista todo el
  /// tiempo: enterarse de cómo va la pelea recién cuando termina llegaba
  /// tarde.
  Widget _standingCounts(BuildContext context, _Standing standing) {
    final pal = context.palette;
    Widget side(IconData icon, Color color, int up, int total, String what) {
      return Semantics(
        label: '$what: $up de $total en pie',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              '$up/$total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _columnLabel(context, 'En pie'),
        const SizedBox(width: 12),
        side(
          Icons.shield_outlined,
          pal.verdant,
          standing.alliesUp,
          standing.allies,
          'Aliados',
        ),
        const SizedBox(width: 12),
        side(
          Icons.pets,
          pal.crimson,
          standing.enemiesUp,
          standing.enemies,
          'Enemigos',
        ),
        // Aparte y sin «en pie»: un neutral no gana ni pierde la pelea, y
        // sumarlo a un bando haría mentir al aviso de bando vencido.
        if (standing.neutrals > 0) ...[
          const SizedBox(width: 12),
          Text(
            standing.neutrals == 1
                ? '1 neutral'
                : '${standing.neutrals} neutrales',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ],
      ],
    );
  }

  /// El número con el que pegan los −/+ de todas las filas, escrito una sola
  /// vez. También es un `Wrap`: el rótulo baja solo cuando la barra se angosta.
  ///
  /// Se llamaba «Golpe rápido», que decía la mitad: el mismo número lo usa el
  /// botón de curar. Y un rótulo de dos palabras en cuerpo 10 no alcanza para
  /// contar que la cifra es de toda la mesa y no de una fila, así que eso lo
  /// dice la etiqueta accesible del campo, que es donde se pregunta.
  Widget _quickAmount(BuildContext context) {
    const explicacion =
        'Es el número que aplican los botones de dañar y curar de cualquier '
        'fila. Vale para todo el combate.';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        _columnLabel(context, 'Daño o curación'),
        SizedBox(
          width: 56,
          child: Tooltip(
            message: explicacion,
            child: Semantics(
              label: 'Daño o curación. $explicacion',
              textField: true,
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
          ),
        ),
        // Un «5» suelto no dice nada dicho en voz alta, y son atajos del campo
        // de al lado y no una cantidad más.
        for (final n in const [1, 5, 10])
          ActionChip(
            label: Text('$n'),
            tooltip: 'Poner $n',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              _amountController.text = '$n';
            }),
          ),
      ],
    );
  }

  Widget _encounterActions(BuildContext context) {
    final preparing = widget.encounter?.isPreparing ?? false;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: const Text('Sumar al combate'),
        ),
        // Mientras se arma no hay nada que terminar: «Terminar combate» antes
        // de empezarlo no se entendía, y un registro de un combate que no se
        // jugó no le sirve a nadie. La salida es descartarlo.
        if (preparing)
          OutlinedButton.icon(
            onPressed: () => _confirmDiscard(context),
            icon: const Icon(Icons.close),
            label: const Text('Descartar combate'),
          )
        // Icono + texto y sin carmesí: un banderín rojo suelto se leía como
        // "rendirse". Terminar el combate es el final normal de un encuentro,
        // no una acción de peligro — el carmesí queda para el botón de
        // confirmar, que sí descarta el orden de turnos.
        else
          OutlinedButton.icon(
            onPressed: () => _confirmClose(context),
            icon: const Icon(Icons.done_all),
            label: const Text('Terminar combate'),
          ),
      ],
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final pal = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: '¿Descartar el combate?',
        content: const Text(
          'Todavía no empezó: se borra lo que armaste y no queda registro.',
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          DialogAction(
            'Descartar',
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onCloseEncounter(discard: true, deadNpcIds: const {});
  }

  Future<void> _add(BuildContext context) async {
    final encounter = widget.encounter;
    if (encounter == null) return;
    final picked = await showAddCombatantDialog(
      context,
      repo: widget.repo,
      campaignNpcs: widget.npcs,
      npcIdsInEncounter: {for (final c in encounter.combatants) ?c.npcId},
      loadLibrary: widget.loadNpcLibrary,
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case AddMonsterChoice(:final creature, :final count, :final rollHp):
        widget.onAddMonster(creature, count, rollHp: rollHp, side: picked.side);
      case AddNpcChoice():
        // Con el combate andando, la iniciativa del PNJ se dice en voz alta
        // como la de un jugador: la tirada automática es solo del bestiario.
        var initiative = 0;
        if (!encounter.isPreparing) {
          final value = await showTextPromptDialog(
            context,
            title: 'Iniciativa de ${picked.npc.name}',
            label: 'Lo que sacó',
            keyboardType: TextInputType.number,
          );
          final parsed = value == null ? null : int.tryParse(value.trim());
          if (parsed == null) return;
          initiative = parsed;
        }
        widget.onAddNpc(picked, initiative);
    }
  }

  CampaignNpcEntry? _npcEntry(Combatant combatant) {
    final id = combatant.npcId;
    if (id == null) return null;
    return widget.npcs.where((e) => e.npc.id == id).firstOrNull;
  }

  Widget _ledger(
    BuildContext context,
    Encounter current, {
    required bool columns,
  }) {
    final pal = context.palette;
    final currentId = current.current?.id;
    final turnIndex = current.combatants.indexWhere((c) => c.id == currentId);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (columns) ...[
            _ledgerHeader(context),
            Divider(height: 1, color: pal.hairline),
          ],
          for (final (i, combatant) in current.combatants.indexed) ...[
            if (i > 0) Divider(height: 1, color: pal.hairline),
            _CombatantRow(
              // Por combatiente y no por posición: la fila guarda el destello
              // de PG y la marca de turno, y al ordenar por iniciativa o sacar
              // a alguien no pueden pasarse al vecino.
              key: ValueKey(combatant.id),
              combatant: combatant,
              active: !current.isPreparing && combatant.id == currentId,
              // Los que ya jugaron esta ronda se atenúan: siguen siendo
              // tocables (a un goblin que ya actuó se le pega igual), pero
              // dejan de competir por la mirada con los que faltan.
              acted: !current.isPreparing && turnIndex >= 0 && i < turnIndex,
              member: combatant.memberId == null
                  ? null
                  : widget.members
                        .where((m) => m.memberId == combatant.memberId)
                        .firstOrNull,
              npc: _npcEntry(combatant),
              repo: widget.repo,
              preparing: current.isPreparing,
              columns: columns,
              amount: () => _amount,
              onAdjustHp: (delta) => widget.onAdjustHp(combatant.id, delta),
              onRemove: () => widget.onRemoveCombatant(combatant.id),
              onSetTags: (tags) => widget.onSetTags(combatant.id, tags),
              onSetSide: (side) => widget.onSetSide(combatant.id, side),
              onConvertToNpc: () => _convertToNpc(context, combatant),
              onEditInitiative: () => _editInitiative(context, combatant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ledgerHeader(BuildContext context) {
    final pal = context.palette;
    Widget cell(String text, double? width, {TextAlign? align}) {
      final label = Text(
        text.toUpperCase(),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          color: pal.textMuted,
        ),
      );
      return width == null
          ? Expanded(child: label)
          : SizedBox(width: width, child: label);
    }

    return Container(
      color: pal.plaque,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          cell('Inic', _kIniWidth, align: TextAlign.center),
          const SizedBox(width: _kColGap),
          cell('Combatiente', null),
          const SizedBox(width: _kColGap),
          cell('Puntos de golpe', _kHpWidth),
          const SizedBox(width: _kColGap),
          cell('CA', _kAcWidth, align: TextAlign.center),
          const SizedBox(width: _kColGap),
          cell('Efectos', _kTagsWidth),
          const SizedBox(width: _kColGap),
          cell('Daño o cura', _kActionsWidth, align: TextAlign.right),
        ],
      ),
    );
  }

  // --- La columna derecha ---------------------------------------------------

  /// El monstruo del turno, resuelto contra el catálogo.
  ///
  /// Devuelve null cuando le toca a un jugador (su ficha no es del DM) o
  /// cuando el combatiente es homebrew borrado del catálogo desde que entró a
  /// la mesa: en los dos casos no hay perfil que mostrar y la solapa lo dice.
  ///
  /// Un PNJ con bloque propio usa **su** bloque, que es una copia y no la
  /// criatura del catálogo: el DM puede haberlo retocado.
  Creature? _currentCreature(Encounter current) {
    final combatant = current.current;
    if (combatant == null) return null;
    return switch (combatant.kind) {
      CombatantKind.npc => _npcEntry(combatant)?.npc.block,
      CombatantKind.player => null,
      CombatantKind.monster => switch (combatant.creatureId) {
        final id? => widget.repo.creature(id),
        null => null,
      },
    };
  }

  Widget _panel(BuildContext context, Encounter current) {
    final pal = context.palette;
    final effects = [
      for (final c in current.combatants)
        for (final tag in c.tags) (combatant: c, tag: tag),
    ];

    return Container(
      // La llave la usan las pruebas para mirar **adentro** de la columna: los
      // mismos nombres están también en la planilla, y sin acotar se enganchan
      // los de la fila.
      key: const ValueKey('combate-panel'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _tabButton(
                context,
                _PanelTab.turno,
                'Del turno',
                Icons.pets_outlined,
              ),
              _tabButton(
                context,
                _PanelTab.efectos,
                'Efectos',
                Icons.label_outline,
                count: effects.length,
              ),
            ],
          ),
          Divider(height: 1, color: pal.hairline),
          Padding(
            padding: const EdgeInsets.all(14),
            child: switch (_tab) {
              _PanelTab.turno => _turnPanel(context, current),
              _PanelTab.efectos => _effectsPanel(context, effects),
            },
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    BuildContext context,
    _PanelTab tab,
    String label,
    IconData icon, {
    int? count,
  }) {
    final pal = context.palette;
    final active = _tab == tab;
    // La solapa activa lleva subrayado **y** color **y** negrita: quien no
    // distingue el oro del gris tiene que poder saber cuál está abierta.
    return Expanded(
      child: InkWell(
        key: ValueKey('combate-solapa-${tab.name}'),
        onTap: () => setState(() => _tab = tab),
        child: Container(
          height: 41,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? pal.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? pal.gold : pal.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? pal.gold
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: pal.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// El perfil del que tiene el turno, con la misma anatomía que el
  /// Bestiario — es literalmente el mismo widget, ver [creatureProfileBody].
  ///
  /// Arriba del perfil van iniciativa, PG y CA, que **no** son del catálogo
  /// sino de esta mesa: los PG bajan a golpes y el máximo del libro dejaría de
  /// ser cierto en el primer ataque.
  ///
  /// El turno de un PNJ suma lo que hace falta para **jugarlo** y no está en
  /// ningún bloque: cómo habla, su trasfondo a un toque, y el bando, que un
  /// neutral puede cambiar justo en su turno.
  Widget _turnPanel(BuildContext context, Encounter current) {
    final pal = context.palette;
    final combatant = current.current;
    if (combatant == null) {
      return const AppEmptyState(
        icon: Icons.hourglass_empty,
        message: 'Todavía no le toca a nadie.',
        actions: [],
      );
    }
    final creature = _currentCreature(current);
    final npc = _npcEntry(combatant);
    final isNpc = combatant.kind == CombatantKind.npc;
    if (combatant.kind == CombatantKind.player ||
        (!isNpc && creature == null)) {
      return AppEmptyState(
        icon: Icons.person_outline,
        message: combatant.kind == CombatantKind.player
            ? 'Le toca a ${combatant.name}, y su ficha la lleva quien lo '
                  'juega.'
            : 'No hay perfil cargado para ${combatant.name}.',
        actions: const [],
      );
    }

    final ac = isNpc
        ? (npc == null ? null : npcArmorClass(npc.npc, npc.sheet, widget.repo))
        : creature?.ac;
    final subtitle = isNpc
        ? (npc == null ? 'PNJ' : npcTypeLine(npc.npc, npc.sheet, widget.repo))
        : creature!.kind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le toca ahora',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w500,
            color: pal.verdant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              // Del monstruo, el nombre del libro: «Goblin 3» es un rótulo de
              // la mesa y el perfil de abajo es el del goblin.
              isNpc ? combatant.name : creature!.name,
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 19),
            ),
            if (!isNpc) SourceBadge(creature!.source),
          ],
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(fontSize: 12, color: pal.textMuted)),
        const SizedBox(height: 12),
        if (combatant.canChangeSide)
          SideSelector(
            side: combatant.side,
            label: 'Bando de ${combatant.name}',
            onChanged: (side) => widget.onSetSide(combatant.id, side),
          )
        else
          Text(
            'Neutral · sin estadísticas',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        if (npc != null && npc.npc.speech.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const Eyebrow('Cómo habla'),
          Text(
            npc.npc.speech,
            style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4),
          ),
        ],
        if (npc != null && npc.npc.background.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _showBackground(context, npc.npc),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Trasfondo'),
          ),
        ],
        const SizedBox(height: 12),
        // `IntrinsicHeight` y no `crossAxisAlignment: stretch`: la tira vive
        // adentro de una lista que crece, así que estirar al alto disponible
        // pide alto infinito y rompe la pasada de layout. Igualar al más alto
        // —la placa de PG, que lleva la barra— es lo que se quería.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatPlaque(
                dense: true,
                label: 'Inic',
                value: '${combatant.initiative}',
                semantics: 'Iniciativa: ${combatant.initiative}',
              ),
              if (combatant.maxHp > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: StatPlaque(
                    dense: true,
                    label: 'Puntos de golpe',
                    value: '${combatant.currentHp}/${combatant.maxHp}',
                    valueColor: pal.crimson,
                    footer: ThinBar(
                      ratio: combatant.currentHp / combatant.maxHp,
                      color: pal.crimson,
                      track: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ],
              if (ac != null && ac.isNotEmpty) ...[
                const SizedBox(width: 8),
                StatPlaque(
                  dense: true,
                  label: 'CA',
                  value: ac,
                  semantics: 'Clase de armadura: $ac',
                ),
              ],
            ],
          ),
        ),
        if (creature != null) ...[
          const SizedBox(height: 16),
          ...creatureProfileBody(context, widget.repo, creature, dense: true),
        ],
      ],
    );
  }

  /// El trasfondo en un diálogo y no desplegado en la columna: suele ser
  /// largo, y la columna del turno se lee de un vistazo entre dos jugadores.
  Future<void> _showBackground(BuildContext context, Npc npc) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Trasfondo de ${npc.name}',
        content: Text(npc.background, style: const TextStyle(height: 1.45)),
        actions: [
          DialogAction(
            'Cerrar',
            keyHint: 'Esc',
            primary: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _convertToNpc(BuildContext context, Combatant combatant) async {
    final name = await showTextPromptDialog(
      context,
      title: 'Convertir en PNJ',
      label: 'Nombre del PNJ',
      current: combatant.name,
      textCapitalization: TextCapitalization.words,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    widget.onConvertToNpc(combatant.id, trimmed);
  }

  /// Todos los efectos anotados de la mesa, juntos.
  ///
  /// La mitad de lo que hay que recordar en una ronda está repartido en filas
  /// que además se mueven de lugar cuando entra alguien: verlos en una sola
  /// lista es lo que evita que se pase el veneno de turno.
  Widget _effectsPanel(
    BuildContext context,
    List<({Combatant combatant, String tag})> effects,
  ) {
    final pal = context.palette;
    if (effects.isEmpty) {
      return const AppEmptyState(
        icon: Icons.label_outline,
        message:
            'Nadie tiene efectos anotados. Se anotan desde la fila de '
            'cada combatiente.',
        actions: [],
      );
    }
    return DenseRows(
      children: [
        for (final effect in effects)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(effect.tag, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        effect.combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: pal.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  // Distinto del tooltip de la chip de la fila a propósito:
                  // el mismo efecto se puede sacar desde dos lugares y dos
                  // botones con el mismo rótulo no se distinguirían al leerlos.
                  tooltip: 'Sacar «${effect.tag}» de ${effect.combatant.name}',
                  onPressed: () => widget.onSetTags(effect.combatant.id, [
                    for (final t in effect.combatant.tags)
                      if (t != effect.tag) t,
                  ]),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Carteles y diálogos --------------------------------------------------

  /// Cuántos quedan en pie de cada lado, cruzando las dos fuentes de PG.
  ///
  /// Vive acá y no en [Encounter] porque hace falta cruzar dos: los PG de los
  /// monstruos, que sí están en el encuentro, y los de los jugadores, que
  /// viven en su ficha real y llegan por [EncounterView.members].
  ///
  /// Los bandos mandan, no el tipo: un lobo aliado cuenta con la mesa y un
  /// PNJ que traiciona pasa a contar con los enemigos. Los neutrales se
  /// cuentan aparte y no entran a ningún «en pie».
  _Standing _standing(Encounter current) {
    bool isDown(Combatant combatant) {
      if (combatant.kind != CombatantKind.player) return combatant.isDown;
      final member = widget.members
          .where((m) => m.memberId == combatant.memberId)
          .firstOrNull;
      // Sin la ficha a la vista no se asume nada: mejor no avisar que avisar
      // de una derrota que no pasó.
      if (member == null) return false;
      return member.character.combat.currentHp <= 0;
    }

    List<Combatant> of(CombatantSide side) => [
      for (final c in current.combatants)
        if (c.side == side) c,
    ];
    final allies = of(CombatantSide.ally);
    final enemies = of(CombatantSide.enemy);

    return _Standing(
      allies: allies.length,
      alliesUp: allies.where((c) => !isDown(c)).length,
      enemies: enemies.length,
      enemiesUp: enemies.where((c) => !isDown(c)).length,
      neutrals: of(CombatantSide.neutral).length,
    );
  }

  /// Aviso de que un bando se quedó sin nadie en pie, con la salida a mano.
  ///
  /// Es un cartel y no un diálogo a propósito: los PG de los jugadores se
  /// releen cada 5 s, y un modal que se abre solo podría saltar justo encima
  /// de lo que el DM está tipeando. Avisa y espera.
  Widget? _sideWipedBanner(BuildContext context, Encounter current) {
    // Todavía no peleó nadie. Sin esto, armar una mesa con los jugadores
    // todavía a 0 PG de la sesión anterior anunciaría una derrota que no pasó.
    if (current.isPreparing) return null;

    final standing = _standing(current);
    final enemiesWiped = standing.enemies > 0 && standing.enemiesUp == 0;
    final alliesWiped = standing.allies > 0 && standing.alliesUp == 0;
    if (!enemiesWiped && !alliesWiped) return null;

    final message = switch ((enemiesWiped, alliesWiped)) {
      (true, true) => 'No queda nadie en pie.',
      (true, false) => 'No queda ningún enemigo en pie.',
      _ => 'No queda ningún aliado en pie.',
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
              // Flexible y no suelto: el cartel convive con la columna
              // derecha, y ahí el aviso más largo no entra en una línea.
              Flexible(
                child: Text('$message ¿Damos el encuentro por terminado?'),
              ),
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

  /// Los jugadores de la mesa que todavía no entraron al orden.
  ///
  /// Mientras se arma entran de un toque, sin iniciativa: la tirada es de
  /// todos juntos al empezar. Si el combate ya arrancó, el que se suma tarde
  /// sí tiene que decir qué sacó.
  Widget _pendingPlayers(
    BuildContext context,
    List<CampaignMember> unadded, {
    required bool preparing,
  }) {
    final pal = context.palette;
    return _plaque(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  preparing
                      ? 'Todavía no están en el combate'
                      : 'Se sumaron tarde',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ),
              // Lo habitual es que pelee la mesa entera: de a uno eran tantos
              // toques como jugadores. Solo mientras se arma, porque después
              // cada uno necesita su iniciativa.
              if (preparing && unadded.length > 1)
                TextButton(
                  onPressed: () {
                    for (final member in unadded) {
                      widget.onAddPlayer(
                        member.memberId,
                        member.character.name,
                        0,
                      );
                    }
                  },
                  child: const Text('Sumar a todos'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final member in unadded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      member.character.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => preparing
                        ? widget.onAddPlayer(
                            member.memberId,
                            member.character.name,
                            0,
                          )
                        : _promptInitiative(context, member),
                    child: Text(preparing ? 'Sumar' : 'Sumar a la iniciativa'),
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
    widget.onAddPlayer(member.memberId, member.character.name, initiative);
  }

  Future<void> _editInitiative(
    BuildContext context,
    Combatant combatant,
  ) async {
    final value = await showTextPromptDialog(
      context,
      title: 'Iniciativa de ${combatant.name}',
      label: 'Iniciativa',
      current: '${combatant.initiative}',
      keyboardType: TextInputType.number,
    );
    final initiative = value == null ? null : int.tryParse(value);
    if (initiative == null || initiative == combatant.initiative) return;
    widget.onSetInitiative(combatant.id, initiative);
  }

  /// Pregunta cómo termina el combate: archivándolo o descartándolo.
  ///
  /// Las dos salidas viven en el mismo diálogo porque es exactamente el
  /// momento en que se decide, y un cuarto botón en la barra la haría más
  /// difícil de leer sin ganar nada. El descarte no se llama "cancelar" a
  /// propósito: en esta app "Cancelar" ya significa "cerrar este diálogo" en
  /// todos lados, y usar la misma palabra para una acción irreversible sería
  /// pedir un clic equivocado.
  ///
  /// Los PNJ que quedaron a 0 PG se listan para marcar cuáles murieron, y
  /// **ninguno viene marcado**: caer no es morir, y un villano que el DM
  /// quería de vuelta no puede quedar muerto por no destildar una casilla. Lo
  /// marcado solo se aplica al guardar; descartar es como si nunca hubiera
  /// pasado.
  Future<void> _confirmClose(BuildContext context) async {
    final pal = context.palette;
    final fallen = [
      for (final c in widget.encounter?.combatants ?? const <Combatant>[])
        if (c.kind == CombatantKind.npc && c.npcId != null && c.isDown) c,
    ];
    final dead = <String>{};
    final choice = await showDialog<_CloseKind>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: Icons.warning_amber_rounded,
          iconColor: pal.crimson,
          title: 'Terminar combate',
          // El carmesí queda para el camino irreversible y nada más. Terminar
          // guardando conserva el registro, así que va en verde heráldico: es
          // la salida esperada del combate, no una pérdida.
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se borra el orden de turnos en los dos casos. Si lo terminás '
                'queda un registro liviano de lo que pasó (sin PG ni daños: eso '
                'lo lleva cada jugador en su ficha). Si lo descartás no queda '
                'nada, como si nunca hubiera empezado.',
              ),
              if (fallen.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Eyebrow('¿Alguno murió?'),
                Text(
                  'Quedaron a 0 PG. Los que marques pasan a muertos en esta '
                  'campaña al terminar y guardar.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
                for (final c in fallen)
                  CheckboxListTile(
                    value: dead.contains(c.npcId),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(c.name),
                    subtitle: Text(c.side.label),
                    onChanged: (v) => setDialogState(() {
                      v == true ? dead.add(c.npcId!) : dead.remove(c.npcId);
                    }),
                  ),
              ],
            ],
          ),
          actions: [
            DialogAction(
              'Cancelar',
              keyHint: 'Esc',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            DialogAction(
              'Descartar sin guardar',
              color: pal.crimson,
              onPressed: () => Navigator.of(ctx).pop(_CloseKind.discard),
            ),
            DialogAction(
              'Terminar y guardar',
              primary: true,
              color: pal.verdant,
              onPressed: () => Navigator.of(ctx).pop(_CloseKind.save),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final discard = choice == _CloseKind.discard;
    widget.onCloseEncounter(
      discard: discard,
      deadNpcIds: discard ? const {} : dead,
    );
  }

  // --- Piezas chicas --------------------------------------------------------

  Widget _plaque(BuildContext context, {required Widget child}) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _columnLabel(BuildContext context, String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w500,
      color: context.palette.textMuted,
    ),
  );

  Widget _divider(BuildContext context) =>
      Container(width: 1, height: 26, color: context.palette.hairline);
}

/// Cuántos quedan en pie de cada lado. Ver `_EncounterViewState._standing`.
class _Standing {
  final int allies;
  final int alliesUp;
  final int enemies;
  final int enemiesUp;
  final int neutrals;

  const _Standing({
    required this.allies,
    required this.alliesUp,
    required this.enemies,
    required this.enemiesUp,
    required this.neutrals,
  });
}

/// Una fila de la planilla: un jugador (solo lectura, PG en vivo) o un
/// monstruo (con el único control de escritura de toda la fase).
/// Desplaza la planilla lo justo para que la fila que acaba de tomar el turno
/// quede a la vista.
///
/// Con una docena de combatientes en una laptop, «Siguiente turno» podía
/// dejar la marca fuera de pantalla, y el DM tenía que ir a buscar a quién le
/// tocaba. Solo se mueve si la fila estaba afuera: pedir las dos políticas es
/// seguro porque la que no hace falta no desplaza nada, y así el paso de la
/// última fila a la primera también sube.
class _RevealWhenActive extends StatefulWidget {
  final bool active;
  final Widget child;
  const _RevealWhenActive({required this.active, required this.child});

  @override
  State<_RevealWhenActive> createState() => _RevealWhenActiveState();
}

class _RevealWhenActiveState extends State<_RevealWhenActive> {
  @override
  void didUpdateWidget(_RevealWhenActive old) {
    super.didUpdateWidget(old);
    if (!widget.active || old.active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final duration = context.motion(const Duration(milliseconds: 200));
      for (final policy in const [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(
          context,
          duration: duration,
          curve: Curves.easeOut,
          alignmentPolicy: policy,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CombatantRow extends StatelessWidget {
  final Combatant combatant;
  final bool active;
  final bool acted;
  final CampaignMember? member;

  /// El PNJ de la fila, si es uno y sigue en la campaña.
  final CampaignNpcEntry? npc;
  final ContentRepository repo;

  /// Mientras se arma la mesa no hay iniciativa que mostrar.
  final bool preparing;

  /// Con las columnas de la planilla, o partida en dos líneas.
  final bool columns;

  /// El número del golpe rápido, leído al tocar y no al construir: el DM lo
  /// cambia arriba sin que las filas se reconstruyan.
  final int Function() amount;

  final void Function(int delta) onAdjustHp;
  final VoidCallback onRemove;
  final void Function(List<String> tags) onSetTags;
  final ValueChanged<CombatantSide> onSetSide;
  final VoidCallback onConvertToNpc;
  final VoidCallback onEditInitiative;

  const _CombatantRow({
    super.key,
    required this.combatant,
    required this.active,
    required this.acted,
    required this.member,
    required this.npc,
    required this.repo,
    required this.preparing,
    required this.columns,
    required this.amount,
    required this.onAdjustHp,
    required this.onRemove,
    required this.onSetTags,
    required this.onSetSide,
    required this.onConvertToNpc,
    required this.onEditInitiative,
  });

  bool get _isPlayer => combatant.kind == CombatantKind.player;

  /// Fichas compiladas de los jugadores, por identidad de personaje.
  ///
  /// Cada fila compilaba la ficha entera tres veces por build (PG, nivel y
  /// CA), y la planilla se reconstruye con cada golpe y con el sondeo de 5 s.
  /// La identidad alcanza: entre un sondeo y el siguiente la ficha de un
  /// jugador no cambia, y cada sondeo trae personajes nuevos. `Expando` no
  /// retiene a los viejos.
  static final _sheets = Expando<ComputedSheet>();

  /// La ficha del jugador de esta fila, o null si no es un jugador de la mesa.
  ComputedSheet? get _playerSheet {
    final c = member?.character;
    if (c == null) return null;
    return _sheets[c] ??= CharacterCompiler(repo).compile(c);
  }

  /// Los PG de la fila, de la fuente que corresponda: los del monstruo son del
  /// encuentro, los del jugador de su ficha real.
  (int, int)? _hp() {
    if (!_isPlayer) {
      return combatant.maxHp > 0
          ? (combatant.currentHp, combatant.maxHp)
          : null;
    }
    final m = member;
    final sheet = _playerSheet;
    if (m == null || sheet == null) return null;
    return (m.character.combat.currentHp, sheet.maxHp);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final hp = _hp();

    // El turno pasa de una fila a la siguiente con la misma duración que el
    // cambio de estado del guardado: sin eso, en una planilla larga la marca
    // salta y el ojo tiene que volver a buscarla.
    final switchDuration = context.motion(const Duration(milliseconds: 180));
    final row = AnimatedContainer(
      duration: switchDuration,
      // El turno se marca con una barra al filo de la fila y con la palabra
      // TURNO bajo la iniciativa: en una planilla, un borde entero alrededor
      // de una fila rompe la grilla que la hace legible.
      decoration: BoxDecoration(
        color: active ? pal.goldSoft : null,
        border: Border(
          left: BorderSide(
            color: active ? pal.verdant : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(11, 9, 14, 9),
      child: columns
          ? _columnsLayout(context, hp)
          : _stackedLayout(context, hp),
    );

    return _RevealWhenActive(
      active: active,
      child: AnimatedOpacity(
        duration: switchDuration,
        opacity: acted ? .62 : 1,
        child: row,
      ),
    );
  }

  Widget _columnsLayout(BuildContext context, (int, int)? hp) {
    return Row(
      children: [
        SizedBox(width: _kIniWidth, child: _initiative(context)),
        const SizedBox(width: _kColGap),
        Expanded(child: _identity(context)),
        const SizedBox(width: _kColGap),
        SizedBox(width: _kHpWidth, child: _hpCell(context, hp)),
        const SizedBox(width: _kColGap),
        SizedBox(width: _kAcWidth, child: _acCell(context)),
        const SizedBox(width: _kColGap),
        SizedBox(width: _kTagsWidth, child: _tags(context)),
        const SizedBox(width: _kColGap),
        _actions(context),
      ],
    );
  }

  /// Sin ancho para las columnas, la fila se parte: identidad arriba, PG y
  /// efectos abajo. Los controles se quedan a la derecha, donde estaban.
  Widget _stackedLayout(BuildContext context, (int, int)? hp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _kIniWidth, child: _initiative(context)),
        const SizedBox(width: _kColGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _identity(context)),
                  const SizedBox(width: 8),
                  _acCell(context),
                ],
              ),
              if (hp != null) ...[
                const SizedBox(height: 6),
                _hpCell(context, hp),
              ],
              if (combatant.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                _tags(context),
              ],
            ],
          ),
        ),
        const SizedBox(width: _kColGap),
        _actions(context),
      ],
    );
  }

  Widget _initiative(BuildContext context) {
    final pal = context.palette;
    final marker = switch (true) {
      _ when preparing => null,
      _ when combatant.isDown => ('Salta', pal.crimson),
      _ when active => ('Turno', pal.verdant),
      _ when acted => ('Actuó', pal.textMuted),
      _ => null,
    };
    final cell = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          // Mientras se arma nadie tiró: un cero se leería como una tirada
          // malísima en vez de como «todavía no».
          preparing ? '—' : '${combatant.initiative}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: active ? 19 : 17,
            fontWeight: FontWeight.w700,
            height: 1,
            color: active ? pal.verdant : pal.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (marker case (final text, final color)) ...[
          const SizedBox(height: 3),
          Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
    if (preparing) return cell;
    // Tocable para corregir: un número mal tipeado al tirar, o el de un
    // jugador que lo cantó distinto, no tiene otro lugar donde arreglarse.
    return Tooltip(
      message: 'Corregir iniciativa',
      child: InkWell(
        onTap: onEditInitiative,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: cell,
        ),
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final pal = context.palette;
    final creature = combatant.creatureId == null
        ? null
        : repo.creature(combatant.creatureId!);
    final npcEntry = npc;
    final meta = combatant.isDown
        ? 'Caído · se salta su turno'
        : _isPlayer
        ? _playerMeta()
        : npcEntry != null
        ? npcTypeLine(npcEntry.npc, npcEntry.sheet, repo)
        : _monsterMeta(creature);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (!_isPlayer) ...[
              Icon(
                combatant.kind == CombatantKind.npc
                    ? Icons.person_outline
                    : Icons.pets,
                size: 14,
                color: pal.textMuted,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                combatant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  decoration: combatant.isDown
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
        // El bando va abajo, con los datos, y no al lado del nombre: en la
        // planilla la columna de identidad mide unos 150 px, y la pill le
        // dejaba al nombre la mitad — «Guerrer…» no se distinguía del
        // hobgoblin. El resumen de ataque se recorta antes; entero está en el
        // panel del turno.
        if (meta.isNotEmpty || !_isPlayer) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (!_isPlayer) ...[_sidePill(context), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: combatant.isDown
                        ? pal.crimson
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// El bando como pill con texto, y el menú de la fila colgado de ella.
  ///
  /// Los jugadores no la llevan: son siempre aliados y una pill repetida en
  /// cada uno sería ruido. En el resto el texto dice el bando aunque no se
  /// distingan los colores. Tocarla cambia el bando —en cualquier momento, no
  /// solo en el turno de ese combatiente— y, en un monstruo, ofrece
  /// convertirlo en PNJ: es el mismo gesto de «este no es un goblin más».
  Widget _sidePill(BuildContext context) {
    final pal = context.palette;
    final color = combatantSideColor(combatant.side, pal);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        combatant.side.label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
    if (!combatant.canChangeSide) {
      return Tooltip(message: 'Sin estadísticas: neutral fijo', child: pill);
    }
    final isMonster = combatant.kind == CombatantKind.monster;
    return PopupMenuButton<Object>(
      tooltip: 'Bando de ${combatant.name}',
      onSelected: (value) =>
          value is CombatantSide ? onSetSide(value) : onConvertToNpc(),
      itemBuilder: (context) => [
        for (final side in CombatantSide.values)
          CheckedPopupMenuItem<Object>(
            value: side,
            checked: side == combatant.side,
            child: Text(side.label),
          ),
        if (isMonster) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<Object>(
            value: 'convertir',
            child: Text('Convertir en PNJ…'),
          ),
        ],
      ],
      child: pill,
    );
  }

  /// «Especie · Clase nv N», igual que la tarjeta del roster. Sale del
  /// catálogo y no del `ComputedSheet` por la misma razón que allá: son
  /// nombres de contenido, no reglas calculadas.
  String _playerMeta() {
    final m = member;
    if (m == null) return '';
    final c = m.character;
    final race = repo.race(c.raceId)?.name ?? c.raceId;
    final classIds = <String>[];
    for (final id in c.classHistory) {
      if (!classIds.contains(id)) classIds.add(id);
    }
    final klass = classIds
        .map(
          (id) => '${repo.characterClass(id)?.name ?? id} ${c.classLevel(id)}',
        )
        .join(' · ');
    return '$race · $klass · nv ${c.totalLevel}';
  }

  /// Lo que el DM necesita de un monstruo sin abrir nada: con qué pega.
  String _monsterMeta(Creature? creature) {
    if (creature == null) return '';
    final attack = creature.actions
        .where((a) => a.attackBonus != null)
        .firstOrNull;
    if (attack == null) return creature.kind;
    return [
      '${attack.name} +${attack.attackBonus}',
      if (attack.damage != null)
        [
          attack.damage!,
          if (attack.damageType != null)
            DamageType.labelFor(attack.damageType!),
        ].join(' '),
      if (attack.reach.isNotEmpty) attack.reach,
    ].join(' · ');
  }

  Widget _hpCell(BuildContext context, (int, int)? hp) {
    final pal = context.palette;
    if (hp == null) return const SizedBox.shrink();
    final (current, max) = hp;
    if (max <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChangeFlash(
          value: current,
          child: Text(
            '$current/$max',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: pal.crimson,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 5),
        ThinBar(ratio: current / max, color: pal.crimson, track: pal.plaque),
      ],
    );
  }

  Widget _acCell(BuildContext context) {
    final creature = combatant.creatureId == null
        ? null
        : repo.creature(combatant.creatureId!);
    final npcEntry = npc;
    final ac = _isPlayer
        ? _playerSheet?.armorClass.toString()
        : npcEntry != null
        ? npcArmorClass(npcEntry.npc, npcEntry.sheet, repo)
        : creature?.ac;
    if (ac == null || ac.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Clase de armadura: $ac',
      excludeSemantics: true,
      child: Text(
        ac,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// Los efectos anotados. Se sacan de a uno desde acá: en la ronda en que se
  /// termina un veneno, abrir el diálogo para destildarlo sería un rodeo.
  Widget _tags(BuildContext context) {
    if (combatant.tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in combatant.tags)
          InputChip(
            label: Text(tag),
            visualDensity: VisualDensity.compact,
            onDeleted: () => onSetTags([
              for (final t in combatant.tags)
                if (t != tag) t,
            ]),
            deleteButtonTooltipMessage: 'Sacar «$tag»',
          ),
      ],
    );
  }

  /// Los controles de la fila, en un ancho fijo para las dos disposiciones:
  /// cuatro `IconButton` no entran en cualquier sobrante, y con la caja fija
  /// el encabezado de la planilla puede alinear con ellos.
  /// Los controles de la fila, en un ancho fijo para las dos disposiciones:
  /// cuatro `IconButton` no entran en cualquier sobrante, y con la caja fija
  /// el encabezado de la planilla puede alinear con ellos.
  ///
  /// Van compactos (40 px y no los 48 de Material) porque son cuatro en una
  /// fila de planilla: al tamaño de siempre no entran, y agrandar la columna
  /// se lo come al nombre del combatiente, que es lo que se lee primero.
  Widget _actions(BuildContext context) {
    final pal = context.palette;
    return SizedBox(
      width: _kActionsWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isPlayer)
            // El DM no escribe la ficha de otra cuenta: donde iría el control
            // de PG va el motivo por el que no está.
            Expanded(
              child: Text(
                'en su ficha',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: pal.textMuted),
              ),
            )
          // Sin PG no hay nada que bajar ni subir: el tabernero tiene turno,
          // pero no barra de vida.
          else if (!combatant.isStatless) ...[
            IconButton(
              tooltip: 'Dañar',
              visualDensity: VisualDensity.compact,
              onPressed: () => onAdjustHp(-amount()),
              icon: Icon(Icons.remove_circle_outline, color: pal.crimson),
            ),
            IconButton(
              tooltip: 'Curar',
              visualDensity: VisualDensity.compact,
              onPressed: () => onAdjustHp(amount()),
              icon: Icon(Icons.add_circle_outline, color: pal.verdant),
            ),
          ],
          IconButton(
            tooltip: 'Efectos',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final tags = await showCombatantTagsDialog(
                context,
                name: combatant.name,
                current: combatant.tags,
              );
              if (tags != null) onSetTags(tags);
            },
            icon: Icon(
              combatant.tags.isEmpty ? Icons.label_outline : Icons.label,
              color: combatant.tags.isEmpty ? null : pal.gold,
            ),
          ),
          IconButton(
            tooltip: 'Sacar del combate',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
