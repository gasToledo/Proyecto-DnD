import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// Los capítulos de una campaña: lo que se jugó, lo que se está jugando y lo
/// que viene.
///
/// Sin estado propio y totalmente controlada, igual que `EncounterView`: el
/// dueño del estado es `_CampaignDetailState`, que ya carga y recarga la lista.
/// Acá solo se pinta y se piden las acciones.
class ChaptersView extends StatelessWidget {
  final List<Chapter>? chapters;
  final bool loading;
  final Object? error;

  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final void Function(Chapter chapter) onEdit;
  final void Function(Chapter chapter) onStart;
  final void Function(Chapter chapter) onClose;
  final void Function(Chapter chapter) onDelete;

  const ChaptersView({
    super.key,
    required this.chapters,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCreate,
    required this.onEdit,
    required this.onStart,
    required this.onClose,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AppErrorView(
        message: 'No se pudieron leer los capítulos.',
        details: '$error',
        onRetry: onRetry,
      );
    }
    if (loading) {
      return const Center(child: AppBusyLabel('Cargando los capítulos…'));
    }
    final all = chapters ?? const <Chapter>[];
    if (all.isEmpty) {
      return AppEmptyState(
        icon: Icons.auto_stories_outlined,
        message:
            'Todavía no dividiste esta campaña en capítulos. Sirven para '
            'llevar por dónde va la historia.',
        actions: [
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo capítulo'),
          ),
        ],
      );
    }

    // Agrupados en el orden en que le importan al DM: lo que está pasando,
    // lo que viene, y al final lo ya jugado. Dentro de cada grupo, el orden
    // de alta que devuelve el servidor.
    List<Chapter> of(ChapterState state) => [
      for (final c in all)
        if (c.state == state) c,
    ];
    final active = of(ChapterState.active);
    final planned = of(ChapterState.planned);
    final completed = of(ChapterState.completed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo capítulo'),
          ),
        ),
        for (final group in [
          (state: ChapterState.active, items: active),
          (state: ChapterState.planned, items: planned),
          (state: ChapterState.completed, items: completed),
        ])
          if (group.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Eyebrow(group.state.label),
            const SizedBox(height: 8),
            for (final chapter in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChapterCard(
                  chapter: chapter,
                  onEdit: () => onEdit(chapter),
                  onStart: () => onStart(chapter),
                  onClose: () => _confirmClose(context, chapter),
                  onDelete: () => _confirmDelete(context, chapter),
                ),
              ),
          ],
      ],
    );
  }

  Future<void> _confirmClose(BuildContext context, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar capítulo'),
        content: Text(
          chapter.grantsLevel
              ? '«${chapter.name}» pasa a completado y a cada jugador de la '
                    'mesa le llega el aviso, con que puede subir de nivel. La '
                    'subida la hace cada uno en su ficha: la app no se la '
                    'aplica a nadie.'
              : '«${chapter.name}» pasa a completado y a cada jugador de la '
                    'mesa le llega el aviso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.done_all),
            label: const Text('Cerrar capítulo'),
          ),
        ],
      ),
    );
    if (confirmed == true) onClose(chapter);
  }

  Future<void> _confirmDelete(BuildContext context, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar capítulo'),
        content: Text(
          'Se borra «${chapter.name}» y lo que hayas escrito en él. A los '
          'jugadores no les llega nada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar capítulo'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete(chapter);
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const _ChapterCard({
    required this.chapter,
    required this.onEdit,
    required this.onStart,
    required this.onClose,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final isActive = chapter.state == ChapterState.active;
    final isDone = chapter.state == ChapterState.completed;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isActive ? pal.gold : pal.hairline,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  chapter.name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    // Lo ya jugado se apaga: sigue estando, pero no compite
                    // con lo que está pasando ahora.
                    color: isDone ? pal.textMuted : null,
                  ),
                ),
              ),
              if (chapter.grantsLevel) ...[
                const SizedBox(width: 8),
                const GoldPill('Sube de nivel'),
              ],
            ],
          ),
          if (chapter.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              chapter.summary,
              style: TextStyle(
                fontSize: 13,
                color: isDone ? pal.textMuted : null,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (chapter.state == ChapterState.planned)
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Empezar'),
                ),
              if (isActive)
                FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Cerrar capítulo'),
                ),
              if (!isDone)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Borrar'),
                style: TextButton.styleFrom(foregroundColor: pal.crimson),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
