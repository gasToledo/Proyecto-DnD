import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'bestiary_view.dart';
import 'npcs/npc_shared.dart';

/// Lo que se eligió sumar al combate.
sealed class AddCombatantChoice {
  const AddCombatantChoice();
}

/// Un monstruo del bestiario, en [count] copias.
class AddMonsterChoice extends AddCombatantChoice {
  final Creature creature;
  final int count;
  final bool rollHp;
  final CombatantSide side;

  const AddMonsterChoice({
    required this.creature,
    required this.count,
    required this.rollHp,
    required this.side,
  });
}

/// Un PNJ. [fromLibrary] es que todavía no estaba en la campaña: al sumarlo
/// entra también a ella. [revive] es que estaba muerto y el DM marcó que
/// volvió.
class AddNpcChoice extends AddCombatantChoice {
  final Npc npc;
  final Character? sheet;
  final CombatantSide side;
  final bool fromLibrary;
  final bool revive;

  const AddNpcChoice({
    required this.npc,
    required this.sheet,
    required this.side,
    required this.fromLibrary,
    required this.revive,
  });
}

/// «Sumar al combate»: PNJ de la campaña (y de la biblioteca) o monstruos del
/// bestiario, con su bando.
///
/// Un PNJ **no tiene bando por defecto**: el mismo puede ser aliado hoy y
/// enemigo la sesión que viene, así que el botón no se habilita hasta que el
/// DM lo elige. Un monstruo sí arranca en enemigo, que es lo esperable. Un PNJ
/// sin estadísticas entra fijo como neutral: sin PG no puede contar para
/// ningún bando.
Future<AddCombatantChoice?> showAddCombatantDialog(
  BuildContext context, {
  required ContentRepository repo,
  required List<CampaignNpcEntry> campaignNpcs,
  required Set<String> npcIdsInEncounter,
  required Future<List<NpcEntry>> Function() loadLibrary,
}) {
  return showDialog<AddCombatantChoice>(
    context: context,
    builder: (_) => _AddCombatantDialog(
      repo: repo,
      campaignNpcs: campaignNpcs,
      npcIdsInEncounter: npcIdsInEncounter,
      loadLibrary: loadLibrary,
    ),
  );
}

enum _Tab { npcs, bestiary }

/// Un PNJ elegible: de la campaña (con su estado) o de la biblioteca.
typedef _NpcOption = ({
  Npc npc,
  Character? sheet,
  NpcStatus? status,
  bool fromLibrary,
});

class _AddCombatantDialog extends StatefulWidget {
  final ContentRepository repo;
  final List<CampaignNpcEntry> campaignNpcs;
  final Set<String> npcIdsInEncounter;
  final Future<List<NpcEntry>> Function() loadLibrary;

  const _AddCombatantDialog({
    required this.repo,
    required this.campaignNpcs,
    required this.npcIdsInEncounter,
    required this.loadLibrary,
  });

  @override
  State<_AddCombatantDialog> createState() => _AddCombatantDialogState();
}

class _AddCombatantDialogState extends State<_AddCombatantDialog> {
  // Abre en PNJ si la campaña tiene alguno: es lo que más se suma a mitad de
  // una historia. Sin PNJ, el bestiario de siempre.
  late _Tab _tab = widget.campaignNpcs.isEmpty ? _Tab.bestiary : _Tab.npcs;

  String _query = '';

  // --- Bestiario
  Creature? _creature;
  int _count = 1;

  /// Si los PG de cada copia se tiran en vez de usar el promedio del libro.
  ///
  /// Arranca apagado: el promedio es lo que manda el libro y es lo que se
  /// quiere para un jefe, que tiene que aguantar lo que el DM planeó. Tirar es
  /// para los minions, donde seis goblins con los mismos PG se notan.
  bool _rollHp = false;
  CombatantSide _monsterSide = CombatantSide.enemy;

  // --- PNJ
  late final Future<List<NpcEntry>> _library = widget.loadLibrary();
  _NpcOption? _npc;
  CombatantSide? _npcSide;
  bool _revive = false;

  bool get _npcIsStatless {
    final npc = _npc;
    return npc != null && npcMaxHp(npc.npc, npc.sheet, widget.repo) == 0;
  }

  AddCombatantChoice? get _choice {
    if (_tab == _Tab.bestiary) {
      final creature = _creature;
      if (creature == null) return null;
      return AddMonsterChoice(
        creature: creature,
        count: _count,
        // Sin fórmula en el catálogo no hay nada que tirar, y el interruptor
        // ni se ofrece: no puede quedar encendido de una criatura anterior.
        rollHp: _rollHp && creature.hitDice != null,
        side: _monsterSide,
      );
    }
    final npc = _npc;
    if (npc == null) return null;
    final side = _npcIsStatless ? CombatantSide.neutral : _npcSide;
    if (side == null) return null;
    return AddNpcChoice(
      npc: npc.npc,
      sheet: npc.sheet,
      side: side,
      fromLibrary: npc.fromLibrary,
      revive: _revive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    return AppDialog(
      title: 'Sumar al combate',
      width: 440,
      // El buscador trae su propia lista con alto acotado.
      scrollable: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Tab>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Tab.npcs, label: Text('PNJ')),
              ButtonSegment(value: _Tab.bestiary, label: Text('Bestiario')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() {
              _tab = s.single;
              _query = '';
            }),
          ),
          const SizedBox(height: 12),
          if (_tab == _Tab.bestiary)
            _creature == null
                ? _bestiarySearch(context)
                : _quantity(context, _creature!)
          else if (_npc == null)
            _npcSearch(context)
          else
            _npcDetail(context, _npc!),
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (_creature != null && _tab == _Tab.bestiary ||
            _npc != null && _tab == _Tab.npcs)
          DialogAction(
            'Sumar',
            primary: true,
            onPressed: choice == null
                ? null
                : () => Navigator.of(context).pop(choice),
          ),
      ],
    );
  }

  Widget _searchField(String label) => TextField(
    autofocus: true,
    decoration: InputDecoration(labelText: label),
    onChanged: (value) => setState(() => _query = value),
  );

  Widget _bestiarySearch(BuildContext context) {
    // La misma búsqueda que el Bestiario, sin tope: la lista es perezosa, y
    // cortar en 30 escondía criaturas sin decirlo. Los filtros de VD y el
    // orden se quedan en el Bestiario; acá se busca algo que ya se sabe cuál es.
    final results = filterCreatures(widget.repo.creaturesSorted, query: _query);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField('Buscar en el bestiario'),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: results.isEmpty
              ? const Center(child: Text('Sin resultados.'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final creature = results[i];
                    return ListTile(
                      key: ValueKey('add-bestiary-${creature.id}'),
                      title: Text(creature.name),
                      subtitle: Text(creature.kind),
                      trailing: creature.cr == null
                          ? null
                          : Text('VD ${challengeRatingLabel(creature.cr!)}'),
                      onTap: () => setState(() => _creature = creature),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _quantity(BuildContext context, Creature creature) => _MonsterQuantity(
    creature: creature,
    count: _count,
    rollHp: _rollHp,
    side: _monsterSide,
    onMore: () => setState(() => _count++),
    onLess: () => setState(() => _count--),
    onRollHp: (v) => setState(() => _rollHp = v),
    onSide: (v) => setState(() => _monsterSide = v),
    onChange: () => setState(() => _creature = null),
  );

  Widget _npcSearch(BuildContext context) {
    final pal = context.palette;
    final query = _query.trim().toLowerCase();
    bool matches(Npc npc) => npc.name.toLowerCase().contains(query);
    Widget tile(_NpcOption option) {
      final inTable = widget.npcIdsInEncounter.contains(option.npc.id);
      final dead = option.status == NpcStatus.dead;
      final subtitle = [
        if (dead) 'Muerto en esta campaña',
        npcTypeLine(option.npc, option.sheet, widget.repo),
        if (option.fromLibrary) 'al sumarlo, entra también a la campaña',
      ].join(' · ');
      return ListTile(
        enabled: !inTable,
        title: Text(option.npc.name),
        subtitle: Text(
          subtitle,
          style: dead ? TextStyle(color: pal.crimson) : null,
        ),
        trailing: inTable
            ? Text(
                'Ya está en la mesa',
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              )
            : null,
        onTap: inTable
            ? null
            : () => setState(() {
                _npc = option;
                _npcSide = null;
                _revive = false;
              }),
      );
    }

    final inCampaign = [
      for (final entry in widget.campaignNpcs)
        if (matches(entry.npc))
          (
            npc: entry.npc,
            sheet: entry.sheet,
            status: entry.status,
            fromLibrary: false,
          ),
    ];
    final linkedIds = {for (final e in widget.campaignNpcs) e.npc.id};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField('Buscar PNJ'),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: FutureBuilder<List<NpcEntry>>(
            future: _library,
            builder: (context, snapshot) {
              final fromLibrary = [
                for (final entry in snapshot.data ?? const <NpcEntry>[])
                  if (!linkedIds.contains(entry.npc.id) && matches(entry.npc))
                    (
                      npc: entry.npc,
                      sheet: entry.sheet,
                      status: null,
                      fromLibrary: true,
                    ),
              ];
              return ListView(
                children: [
                  const Eyebrow('En esta campaña'),
                  if (inCampaign.isEmpty)
                    Text('Ninguno.', style: TextStyle(color: pal.textMuted)),
                  for (final option in inCampaign) tile(option),
                  const SizedBox(height: 10),
                  const Eyebrow('De tu biblioteca · no están en esta campaña'),
                  if (snapshot.connectionState != ConnectionState.done)
                    const AppBusyLabel('Cargando tu biblioteca…')
                  else if (fromLibrary.isEmpty)
                    Text('Ninguno.', style: TextStyle(color: pal.textMuted)),
                  for (final option in fromLibrary) tile(option),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _npcDetail(BuildContext context, _NpcOption option) {
    final pal = context.palette;
    final statless = _npcIsStatless;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                option.npc.name,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _npc = null),
              child: const Text('Cambiar'),
            ),
          ],
        ),
        Text(
          npcTypeLine(option.npc, option.sheet, widget.repo),
          style: TextStyle(color: pal.textMuted),
        ),
        if (option.status == NpcStatus.dead) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            decoration: BoxDecoration(
              border: Border.all(color: pal.gold),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${option.npc.name} está muerto en esta campaña. Sumarlo '
                  'al combate no cambia eso.',
                ),
                CheckboxListTile(
                  value: _revive,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Volvió: marcarlo vivo otra vez'),
                  onChanged: (v) => setState(() => _revive = v ?? false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Eyebrow('¿De qué lado pelea?'),
        SideSelector(
          label: 'Bando',
          side: statless ? CombatantSide.neutral : _npcSide,
          onChanged: statless
              ? null
              : (side) => setState(() => _npcSide = side),
        ),
        const SizedBox(height: 8),
        Text(
          statless
              ? 'Sin estadísticas no tiene PG que bajar: entra neutral, con su '
                    'turno, y no cuenta para ningún bando.'
              : 'Sin valor por defecto: el mismo PNJ puede ser aliado hoy y '
                    'enemigo la sesión que viene. Un neutral tiene turno y puede '
                    'tomar partido durante el combate.',
          style: TextStyle(fontSize: 12, color: pal.textMuted),
        ),
      ],
    );
  }
}

/// Cantidad, PG y bando de un monstruo que se va a sumar.
///
/// Es la misma pieza en los dos lugares desde donde se suma —la solapa
/// Bestiario de «Sumar al combate» y el perfil del Bestiario— para que las
/// reglas de `dm-combat-sides` (enemigo por defecto, tirar PG solo si hay
/// dados) no puedan quedar cumplidas en uno y olvidadas en el otro.
///
/// Sin estado propio: lo lleva cada diálogo, que es quien arma la elección.
class _MonsterQuantity extends StatelessWidget {
  final Creature creature;
  final int count;
  final bool rollHp;
  final CombatantSide side;
  // Incrementos y no un valor absoluto: dos toques antes de redibujar tienen
  // que sumar dos, y un valor calculado con el `count` viejo sumaría uno.
  final VoidCallback onMore;
  final VoidCallback onLess;
  final ValueChanged<bool> onRollHp;
  final ValueChanged<CombatantSide> onSide;

  /// Volver a elegir criatura. Null donde la criatura ya viene dada.
  final VoidCallback? onChange;

  const _MonsterQuantity({
    required this.creature,
    required this.count,
    required this.rollHp,
    required this.side,
    required this.onMore,
    required this.onLess,
    required this.onRollHp,
    required this.onSide,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                creature.name,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 18),
              ),
            ),
            if (onChange != null)
              TextButton(onPressed: onChange, child: const Text('Cambiar')),
          ],
        ),
        Text(creature.kind, style: TextStyle(color: pal.textMuted)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Una copia menos',
              onPressed: count > 1 ? onLess : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            IconButton(
              tooltip: 'Una copia más',
              onPressed: onMore,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        // Solo se ofrece si el perfil trae los dados. Los que no los traen son
        // los compañeros de clase y las invocaciones, cuyos PG salen de una
        // fórmula y no de una tirada.
        if (DiceFormula.tryParse(creature.hitDice ?? '') case final formula?)
          CheckboxListTile(
            value: rollHp,
            onChanged: (v) => onRollHp(v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Tirar los PG de cada uno'),
            subtitle: Text(
              rollHp
                  ? 'Cada copia tira $formula por su cuenta.'
                  : 'Todas arrancan con ${creature.hp}, el promedio del libro.',
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            ),
          ),
        const SizedBox(height: 8),
        const Eyebrow('¿De qué lado pelea?'),
        SideSelector(label: 'Bando', side: side, onChanged: onSide),
      ],
    );
  }
}

/// Sumar [creature] al combate de [campaignName], con la criatura ya elegida.
///
/// Es la puerta del perfil del Bestiario: sin solapas ni buscador, porque la
/// criatura es la que se está mirando, y sin PNJ, que no son del catálogo.
Future<AddMonsterChoice?> showAddMonsterDialog(
  BuildContext context, {
  required Creature creature,
  required String campaignName,
}) {
  return showDialog<AddMonsterChoice>(
    context: context,
    builder: (_) =>
        _AddMonsterDialog(creature: creature, campaignName: campaignName),
  );
}

class _AddMonsterDialog extends StatefulWidget {
  final Creature creature;
  final String campaignName;

  const _AddMonsterDialog({required this.creature, required this.campaignName});

  @override
  State<_AddMonsterDialog> createState() => _AddMonsterDialogState();
}

class _AddMonsterDialogState extends State<_AddMonsterDialog> {
  int _count = 1;
  bool _rollHp = false;
  CombatantSide _side = CombatantSide.enemy;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Sumar al combate de ${widget.campaignName}',
      width: 440,
      content: _MonsterQuantity(
        creature: widget.creature,
        count: _count,
        rollHp: _rollHp,
        side: _side,
        onMore: () => setState(() => _count++),
        onLess: () => setState(() => _count--),
        onRollHp: (v) => setState(() => _rollHp = v),
        onSide: (v) => setState(() => _side = v),
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          'Sumar',
          primary: true,
          onPressed: () => Navigator.of(context).pop(
            AddMonsterChoice(
              creature: widget.creature,
              count: _count,
              rollHp: _rollHp && widget.creature.hitDice != null,
              side: _side,
            ),
          ),
        ),
      ],
    );
  }
}
