import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// Editor de un capítulo: nombre, descripción y qué reparte al cerrarse.
///
/// Es un diálogo propio y no `showTextPromptDialog` porque ese resuelve un solo
/// campo y acá hacen falta varios. Devuelve el capítulo con los cambios, o `null`
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
  late final _goldController = TextEditingController(
    text: widget.current.grantsGold > 0 ? '${widget.current.grantsGold}' : '',
  );
  // Un ítem por línea: es la forma más corta de escribir una lista corta a
  // mano, sin un botón de "agregar" por cada renglón.
  late final _itemsController = TextEditingController(
    text: widget.current.grantsItems.join('\n'),
  );
  late bool _grantsLevel = widget.current.grantsLevel;

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _goldController.dispose();
    _itemsController.dispose();
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
        grantsGold: int.tryParse(_goldController.text.trim()) ?? 0,
        grantsItems: [
          for (final line in _itemsController.text.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ],
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
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              // Lo que sigue es lo que se reparte al cerrar, y nada de esto lo
              // aplica la app: al cerrar el capítulo solo se les avisa. Ni el
              // nivel ni la bolsa ni el inventario de un personaje los toca
              // nadie que no sea su jugador, así que conviene que el DM sepa
              // que está escribiendo un aviso y no una ficha.
              const Eyebrow('Al cerrarlo se llevan'),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _grantsLevel,
                onChanged: (value) =>
                    setState(() => _grantsLevel = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Un nivel'),
                subtitle: Text(
                  'La subida la hace cada jugador en su ficha.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _goldController,
                keyboardType: TextInputType.number,
                // Solo dígitos: así el campo no puede producir oro negativo y
                // no hace falta ningún mensaje de error explicándolo.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Oro para cada personaje',
                  hintText: '0',
                  helperText: 'Ya repartido: la app no divide el botín.',
                  suffixText: 'po',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _itemsController,
                minLines: 2,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ítems',
                  hintText: 'Uno por línea…',
                  helperText: 'Se los anota cada jugador en su inventario.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
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
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
