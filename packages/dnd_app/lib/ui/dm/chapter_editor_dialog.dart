import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Editor de un capítulo: nombre, descripción y si otorga nivel.
///
/// Es un diálogo propio y no `showTextPromptDialog` porque ese resuelve un solo
/// campo y acá hacen falta tres. Devuelve el capítulo con los cambios, o `null`
/// si se canceló.
///
/// Sirve para crear y para editar: [current] es el capítulo que se está
/// tocando, y quien llama decide si mandarlo a `createChapter` o a
/// `upsertChapter`. El **estado no se edita acá** — se cambia con las acciones
/// de la lista (Empezar, Cerrar), que son las que tienen consecuencias.
Future<Chapter?> showChapterEditorDialog(
  BuildContext context, {
  required Chapter current,
  required String title,
}) {
  return showDialog<Chapter>(
    context: context,
    builder: (context) => _ChapterEditorDialog(current: current, title: title),
  );
}

class _ChapterEditorDialog extends StatefulWidget {
  final Chapter current;
  final String title;

  const _ChapterEditorDialog({required this.current, required this.title});

  @override
  State<_ChapterEditorDialog> createState() => _ChapterEditorDialogState();
}

class _ChapterEditorDialogState extends State<_ChapterEditorDialog> {
  late final _nameController = TextEditingController(text: widget.current.name);
  late final _summaryController = TextEditingController(
    text: widget.current.summary,
  );
  late bool _grantsLevel = widget.current.grantsLevel;

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      widget.current.copyWith(
        name: name,
        summary: _summaryController.text.trim(),
        grantsLevel: _grantsLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del capítulo',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _summaryController,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Qué pasa en este tramo de la historia…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // No es una recompensa que la app reparta: al cerrar el capítulo
            // solo se les avisa. Subir de nivel lo hace cada jugador desde su
            // propia ficha, y conviene que el DM lo sepa antes de marcarlo.
            CheckboxListTile(
              value: _grantsLevel,
              onChanged: (value) =>
                  setState(() => _grantsLevel = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Al cerrarlo, suben de nivel'),
              subtitle: Text(
                'Se les avisa. La subida la hace cada jugador en su ficha.',
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              ),
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
