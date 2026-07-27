part of '../sheet_screen.dart';

extension _SheetNotesSection on _SheetScreenState {
  // ---------------------------------------------------------------- Notas

  Widget _buildNotes() {
    return sheetCard(
      icon: Icons.edit_note,
      title: 'Notas del personaje',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
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
      ),
    );
  }
}
