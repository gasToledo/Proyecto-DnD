import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'add_monster_dialog.dart';
import 'combatant_tags_dialog.dart';

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

  final VoidCallback onRetry;
  final void Function(String memberId, String name, int initiative) onAddPlayer;
  final void Function(Creature creature, int count, {bool rollHp}) onAddMonster;

  /// [delta] es lo que cambia: negativo es daño, positivo es cura. El
  /// clampeo a `0..maxHp` lo hace `Encounter.withHp`, no esta pantalla.
  final void Function(String combatantId, int delta) onAdjustHp;
  final void Function(String combatantId) onRemoveCombatant;

  /// Reemplaza los efectos anotados de un combatiente.
  final void Function(String combatantId, List<String> tags) onSetTags;

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
    required this.onSetTags,
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
                const Text(
                  'Armando la mesa',
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
          standing.playersUp,
          standing.players,
          'La mesa',
        ),
        const SizedBox(width: 12),
        side(
          Icons.pets,
          pal.crimson,
          standing.monstersUp,
          standing.monsters,
          'Enemigos',
        ),
      ],
    );
  }

  /// El número con el que pegan los −/+ de todas las filas, escrito una sola
  /// vez. También es un `Wrap`: el rótulo baja solo cuando la barra se angosta.
  Widget _quickAmount(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        _columnLabel(context, 'Golpe rápido'),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        for (final n in const [1, 5, 10])
          ActionChip(
            label: Text('$n'),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              _amountController.text = '$n';
            }),
          ),
      ],
    );
  }

  Widget _encounterActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showAddMonsterDialog(context, widget.repo);
            if (picked != null) {
              widget.onAddMonster(
                picked.creature,
                picked.count,
                rollHp: picked.rollHp,
              );
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Sumar monstruo'),
        ),
        // Icono + texto y sin carmesí: un banderín rojo suelto se leía como
        // "rendirse". Terminar el combate es el final normal de un encuentro,
        // no una acción de peligro — el carmesí queda para el botón de
        // confirmar, que sí descarta el orden de turnos.
        OutlinedButton.icon(
          onPressed: () => _confirmClose(context),
          icon: const Icon(Icons.done_all),
          label: const Text('Terminar combate'),
        ),
      ],
    );
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
              repo: widget.repo,
              preparing: current.isPreparing,
              columns: columns,
              amount: () => _amount,
              onAdjustHp: (delta) => widget.onAdjustHp(combatant.id, delta),
              onRemove: () => widget.onRemoveCombatant(combatant.id),
              onSetTags: (tags) => widget.onSetTags(combatant.id, tags),
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
  Creature? _currentCreature(Encounter current) {
    final combatant = current.current;
    if (combatant == null || combatant.kind != CombatantKind.monster) {
      return null;
    }
    final id = combatant.creatureId;
    return id == null ? null : widget.repo.creature(id);
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

  /// El perfil del monstruo que tiene el turno, con la misma anatomía que el
  /// Bestiario — es literalmente el mismo widget, ver [creatureProfileBody].
  ///
  /// Arriba del perfil van iniciativa, PG y CA, que **no** son del catálogo
  /// sino de esta mesa: los PG bajan a golpes y el máximo del libro dejaría de
  /// ser cierto en el primer ataque.
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
    if (creature == null) {
      return AppEmptyState(
        icon: Icons.person_outline,
        message: combatant.kind == CombatantKind.player
            ? 'Le toca a ${combatant.name}, y su ficha la lleva quien lo '
                  'juega.'
            : 'No hay perfil cargado para ${combatant.name}.',
        actions: const [],
      );
    }

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
              creature.name,
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 19),
            ),
            SourceBadge(creature.source),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          creature.kind,
          style: TextStyle(fontSize: 12, color: pal.textMuted),
        ),
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
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatPlaque(
                  dense: true,
                  label: 'Puntos de golpe',
                  value: '${combatant.currentHp}/${combatant.maxHp}',
                  valueColor: pal.crimson,
                  footer: combatant.maxHp <= 0
                      ? null
                      : ThinBar(
                          ratio: combatant.currentHp / combatant.maxHp,
                          color: pal.crimson,
                          track: Theme.of(context).colorScheme.surface,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              StatPlaque(dense: true, label: 'CA', value: creature.ac),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...creatureProfileBody(context, creature, dense: true),
      ],
    );
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
  _Standing _standing(Encounter current) {
    final players = [
      for (final c in current.combatants)
        if (c.kind == CombatantKind.player) c,
    ];
    final monsters = [
      for (final c in current.combatants)
        if (c.kind == CombatantKind.monster) c,
    ];

    bool playerIsDown(Combatant combatant) {
      final member = widget.members
          .where((m) => m.memberId == combatant.memberId)
          .firstOrNull;
      // Sin la ficha a la vista no se asume nada: mejor no avisar que avisar
      // de una derrota que no pasó.
      if (member == null) return false;
      return member.character.combat.currentHp <= 0;
    }

    return _Standing(
      players: players.length,
      playersUp: players.where((c) => !playerIsDown(c)).length,
      monsters: monsters.length,
      monstersUp: monsters.where((c) => !c.isDown).length,
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
    final monstersWiped = standing.monsters > 0 && standing.monstersUp == 0;
    final playersWiped = standing.players > 0 && standing.playersUp == 0;
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
          Text(
            preparing ? 'Todavía no están en la mesa' : 'Se sumaron tarde',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
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
                    child: Text(
                      preparing ? 'Sumar a la mesa' : 'Sumar a la iniciativa',
                    ),
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
    widget.onCloseEncounter(discard: choice == _CloseKind.discard);
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
  final int players;
  final int playersUp;
  final int monsters;
  final int monstersUp;

  const _Standing({
    required this.players,
    required this.playersUp,
    required this.monsters,
    required this.monstersUp,
  });
}

/// Una fila de la planilla: un jugador (solo lectura, PG en vivo) o un
/// monstruo (con el único control de escritura de toda la fase).
class _CombatantRow extends StatelessWidget {
  final Combatant combatant;
  final bool active;
  final bool acted;
  final CampaignMember? member;
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

  const _CombatantRow({
    required this.combatant,
    required this.active,
    required this.acted,
    required this.member,
    required this.repo,
    required this.preparing,
    required this.columns,
    required this.amount,
    required this.onAdjustHp,
    required this.onRemove,
    required this.onSetTags,
  });

  bool get _isPlayer => combatant.kind == CombatantKind.player;

  /// Los PG de la fila, de la fuente que corresponda: los del monstruo son del
  /// encuentro, los del jugador de su ficha real.
  (int, int)? _hp() {
    if (!_isPlayer) {
      return combatant.maxHp > 0
          ? (combatant.currentHp, combatant.maxHp)
          : null;
    }
    final m = member;
    if (m == null) return null;
    final sheet = CharacterCompiler(repo).compile(m.character);
    return (m.character.combat.currentHp, sheet.maxHp);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final hp = _hp();

    final row = Container(
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

    return acted ? Opacity(opacity: .62, child: row) : row;
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
    return Column(
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
  }

  Widget _identity(BuildContext context) {
    final pal = context.palette;
    final creature = combatant.creatureId == null
        ? null
        : repo.creature(combatant.creatureId!);
    final meta = combatant.isDown
        ? 'Caído · se salta su turno'
        : _isPlayer
        ? _playerMeta()
        : _monsterMeta(creature);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (!_isPlayer) ...[
              Icon(Icons.pets, size: 14, color: pal.textMuted),
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
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
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
        ],
      ],
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
    final klass = repo.characterClass(c.classId)?.name ?? c.classId;
    final level = CharacterCompiler(repo).compile(c).level;
    return '$race · $klass nv $level';
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
        Text(
          '$current/$max',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: pal.crimson,
            fontFeatures: const [FontFeature.tabularFigures()],
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
    final ac = _isPlayer
        ? (member == null
              ? null
              : '${CharacterCompiler(repo).compile(member!.character).armorClass}')
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
          else ...[
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
            tooltip: 'Sacar de la mesa',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
