import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

/// Escribir o corregir una nota del Cuaderno.
///
/// Devuelve la nota con los campos cargados, o `null` si se canceló. No guarda
/// nada: quien la abre decide si es alta o edición, igual que
/// `showChapterEditorDialog`.
///
/// El capítulo se elige acá adentro y arranca en el que esté en marcha. Es lo
/// que habilita preparar un capítulo que todavía no se jugó sin salir del
/// cuaderno.
Future<Note?> showNoteEditorDialog(
  BuildContext context, {
  required Note current,
  required List<Chapter> chapters,
  required String title,
}) {
  return showDialog<Note>(
    context: context,
    builder: (ctx) =>
        _NoteEditorDialog(current: current, chapters: chapters, title: title),
  );
}

class _NoteEditorDialog extends StatefulWidget {
  final Note current;
  final List<Chapter> chapters;
  final String title;

  const _NoteEditorDialog({
    required this.current,
    required this.chapters,
    required this.title,
  });

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.current.title,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.current.body,
  );
  late String _chapterId = widget.current.chapterId;

  @override
  void initState() {
    super.initState();
    // Sin esto el diálogo no se reconstruye al tipear y «Guardar» se queda
    // apagado para siempre: `TextField` con controlador no llama a `setState`
    // por su cuenta.
    _title.addListener(_onTitleChanged);
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _chapterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Capítulo'),
                items: [
                  for (final chapter in widget.chapters)
                    DropdownMenuItem(
                      value: chapter.id,
                      child: Text(
                        '${chapter.name} · ${chapter.state.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _chapterId = v ?? _chapterId),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  // El título es campo aparte y no la primera línea del texto
                  // porque es lo que se ve con la nota plegada y al buscar.
                  helperText: 'Es lo que se ve en el listado y al buscar.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  alignLabelWithHint: true,
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
        FilledButton.icon(
          // Misma regla que hace cumplir el servidor: sin título no se guarda.
          onPressed: _title.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  widget.current.copyWith(
                    chapterId: _chapterId,
                    title: _title.text.trim(),
                    body: _body.text.trim(),
                  ),
                ),
          icon: const Icon(Icons.check),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
