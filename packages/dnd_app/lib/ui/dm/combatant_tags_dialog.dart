import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../conditions.dart';

/// Qué le está pasando a un combatiente, para que el DM no se olvide a mitad
/// de una ronda.
///
/// Las 14 condiciones del libro se ofrecen como atajo, pero el tag es **texto
/// libre**: la mitad de lo que hay que recordar en un combate no es una
/// condición oficial. «Envenenado» sale de la lista; «marcado por el pícaro» y
/// «concentrando en Bendición» hay que poder escribirlos.
///
/// Devuelve la lista final, o `null` si se canceló. Normalizar —sin repetidos,
/// sin vacíos— es responsabilidad de `Encounter.withTags`, no de acá.
Future<List<String>?> showCombatantTagsDialog(
  BuildContext context, {
  required String name,
  required List<String> current,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _TagsDialog(name: name, current: current),
  );
}

class _TagsDialog extends StatefulWidget {
  final String name;
  final List<String> current;

  const _TagsDialog({required this.name, required this.current});

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late final List<String> _tags = [...widget.current];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Las condiciones oficiales se comparan por su etiqueta y no por su id: lo
  /// que se guarda es lo que se muestra, así que un tag escrito a mano que
  /// diga «Envenenado» es el mismo que el del atajo.
  bool _has(String label) =>
      _tags.any((t) => t.toLowerCase() == label.toLowerCase());

  void _toggle(String label) => setState(() {
    if (_has(label)) {
      _tags.removeWhere((t) => t.toLowerCase() == label.toLowerCase());
    } else {
      _tags.add(label);
    }
  });

  void _addTyped() {
    final text = _controller.text.trim();
    if (text.isEmpty || _has(text)) {
      _controller.clear();
      return;
    }
    setState(() => _tags.add(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    // Lo escrito a mano va aparte: las condiciones oficiales ya se ven
    // marcadas abajo, y repetirlas acá haría que cada una apareciera dos veces.
    final libres = [
      for (final tag in _tags)
        if (!conditions.values.any(
          (c) => c.label.toLowerCase() == tag.toLowerCase(),
        ))
          tag,
    ];

    return AlertDialog(
      title: Text('Efectos de ${widget.name}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Anotar un efecto',
                        hintText: 'Marcado por el pícaro…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addTyped(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Anotar',
                    onPressed: _addTyped,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              if (libres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in libres)
                      InputChip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                        deleteButtonTooltipMessage: 'Sacar «$tag»',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const Eyebrow('Condiciones del libro'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final condition in conditions.values)
                    Tooltip(
                      message: condition.description,
                      waitDuration: const Duration(milliseconds: 400),
                      child: FilterChip(
                        label: Text(condition.label),
                        selected: _has(condition.label),
                        onSelected: (_) => _toggle(condition.label),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Los efectos son tuyos: al jugador no le llega nada, se lo '
                'decís en la mesa.',
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_tags),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
