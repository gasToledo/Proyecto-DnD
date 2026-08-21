import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// La tirada de iniciativa de toda la mesa, de una.
///
/// Es la transición de armar el combate a jugarlo: hasta acá los combatientes
/// no tenían iniciativa y el jugador no veía nada, y al confirmar arranca la
/// ronda 1.
///
/// **A los monstruos les llega el número ya tirado** (d20 + su modificador,
/// una tirada por copia) y el DM lo puede corregir; a los jugadores les llega
/// en blanco, porque el número lo cantan ellos desde la mesa. Todos los
/// valores son el **final** —dado más modificador—, que es lo que se dice en
/// voz alta.
///
/// Devuelve `{id del combatiente: iniciativa}`, o `null` si se canceló.
Future<Map<String, int>?> showRollInitiativeDialog(
  BuildContext context, {
  required List<Combatant> combatants,
  required Map<String, int> suggested,
}) {
  return showDialog<Map<String, int>>(
    context: context,
    builder: (context) =>
        _RollInitiativeDialog(combatants: combatants, suggested: suggested),
  );
}

class _RollInitiativeDialog extends StatefulWidget {
  final List<Combatant> combatants;
  final Map<String, int> suggested;

  const _RollInitiativeDialog({
    required this.combatants,
    required this.suggested,
  });

  @override
  State<_RollInitiativeDialog> createState() => _RollInitiativeDialogState();
}

class _RollInitiativeDialogState extends State<_RollInitiativeDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final c in widget.combatants)
      c.id: TextEditingController(
        text: widget.suggested[c.id] == null ? '' : '${widget.suggested[c.id]}',
      ),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Solo entran los que tienen un número escrito. Uno en blanco se queda con
  /// la iniciativa que ya tenía, que al armar la mesa es cero: va último, y el
  /// DM lo corrige cuando el jugador llegue.
  Map<String, int> get _values => {
    for (final entry in _controllers.entries)
      entry.key: ?int.tryParse(entry.value.text.trim()),
  };

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final players = [
      for (final c in widget.combatants)
        if (c.kind == CombatantKind.player) c,
    ];
    final monsters = [
      for (final c in widget.combatants)
        if (c.kind == CombatantKind.monster) c,
    ];

    return AlertDialog(
      title: const Text('Tirar iniciativa'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, box) {
              // Los dos bandos lado a lado cuando entran, apilados cuando no.
              // El corte lo decide el ancho real del diálogo, no la ventana.
              final wide = box.maxWidth >= 520;
              final columns = [
                _side(context, 'La mesa', players, vacio: 'Nadie de la mesa.'),
                _side(
                  context,
                  'Los monstruos',
                  monsters,
                  vacio: 'Ningún monstruo.',
                ),
              ];
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: columns[0]),
                        const SizedBox(width: 20),
                        Expanded(child: columns[1]),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        columns[0],
                        const SizedBox(height: 20),
                        columns[1],
                      ],
                    );
            },
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            'Al confirmar arranca la ronda 1.',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_values),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Empezar'),
        ),
      ],
    );
  }

  Widget _side(
    BuildContext context,
    String title,
    List<Combatant> combatants, {
    required String vacio,
  }) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Eyebrow(title),
        if (combatants.isEmpty)
          Text(vacio, style: TextStyle(fontSize: 13, color: pal.textMuted))
        else
          for (final combatant in combatants)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      combatant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: ValueKey('initiative-${combatant.id}'),
                      controller: _controllers[combatant.id],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      // Un menos adelante y nada más: una Destreza baja resta.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
