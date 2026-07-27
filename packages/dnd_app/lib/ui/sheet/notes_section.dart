part of '../sheet_screen.dart';

extension _SheetNotesSection on _SheetScreenState {
  // ---------------------------------------------------------------- Notas

  Widget _buildNotes() {
    return PageBody(
      children: [
        const Eyebrow('Notas del personaje'),
        TextField(
          controller: _notesCtrl,
          minLines: 12,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Historia, objetivos, recordatorios de la mesa…',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _c.notes = v;
            ctrl.touch(_c);
          },
        ),
      ],
    );
  }

  Widget _chips(List<String> labels) => labels.isEmpty
      ? const Text('—')
      : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.map((l) => Chip(label: Text(l))).toList(),
        );
}
