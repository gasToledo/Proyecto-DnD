import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

/// Editor corto de la identidad de una campaña.
///
/// [Campaign] ya guarda la premisa y el estado. Este diálogo los expone junto
/// al nombre para que el tablero pueda distinguir una mesa activa de una vieja
/// sin inventar otro modelo exclusivo de la UI.
Future<Campaign?> showCampaignEditorDialog(
  BuildContext context, {
  required Campaign current,
  required String title,
}) {
  return showDialog<Campaign>(
    context: context,
    builder: (context) => _CampaignEditorDialog(current: current, title: title),
  );
}

class _CampaignEditorDialog extends StatefulWidget {
  final Campaign current;
  final String title;

  const _CampaignEditorDialog({required this.current, required this.title});

  @override
  State<_CampaignEditorDialog> createState() => _CampaignEditorDialogState();
}

class _CampaignEditorDialogState extends State<_CampaignEditorDialog> {
  late final _nameController = TextEditingController(text: widget.current.name);
  late final _premiseController = TextEditingController(
    text: widget.current.premise,
  );
  late CampaignState _state = widget.current.state;

  @override
  void dispose() {
    _nameController.dispose();
    _premiseController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      widget.current.copyWith(
        name: name,
        premise: _premiseController.text.trim(),
        state: _state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la campaña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _premiseController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Premisa',
                hintText: 'El conflicto que pone esta historia en marcha…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CampaignState>(
              initialValue: _state,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final state in CampaignState.values)
                  DropdownMenuItem(value: state, child: Text(state.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _state = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
