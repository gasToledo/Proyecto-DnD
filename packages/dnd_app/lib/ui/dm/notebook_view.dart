import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// El Cuaderno de campaña: qué pasó en cada capítulo.
///
/// Cada capítulo es una tarjeta plegable y solo se abre el que está en marcha.
/// Se eligió así sobre una línea de tiempo corrida porque una campaña larga
/// haría crecer la pantalla sin techo, y sobre separar registro de notas
/// porque una nota escrita después de un combate se lee al lado de ese
/// combate.
///
/// Adentro conviven dos clases de entrada, y la diferencia se ve sin ningún
/// cartel que la explique:
///
/// - Lo que **escribió la app** (combates cerrados) va sobre `plaque`, que en
///   este sistema siempre se hunde: es el registro y no se corrige.
/// - Lo que **escribió el DM** (las notas) va sobre `surface`, con su menú de
///   editar y borrar.
///
/// Tiene estado propio —qué capítulos están abiertos y qué se buscó— por lo
/// mismo que `BestiaryView`: es estado de pantalla y nadie más arriba lo
/// necesita. Los datos, en cambio, llegan cargados desde afuera.
class NotebookView extends StatefulWidget {
  final List<Chapter> chapters;
  final Notebook? notebook;
  final bool loading;
  final Object? error;

  final VoidCallback onRetry;
  final void Function(Note note) onEditNote;
  final void Function(Note note) onDeleteNote;

  const NotebookView({
    super.key,
    required this.chapters,
    required this.notebook,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onEditNote,
    required this.onDeleteNote,
  });

  @override
  State<NotebookView> createState() => _NotebookViewState();
}

/// Una entrada del cuaderno, sea de la app o del DM. Existe para poder
/// ordenarlas juntas por fecha dentro de un capítulo.
typedef _Entry = ({DateTime? at, Note? note, EncounterLog? log});

class _NotebookViewState extends State<NotebookView> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Capítulos abiertos. `null` hasta el primer build: recién ahí se sabe cuál
  /// está en marcha, que es el que arranca abierto.
  Set<String>? _expanded;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _open {
    return _expanded ??= {
      for (final c in widget.chapters)
        if (c.state == ChapterState.active) c.id,
    };
  }

  bool _matches(String text) =>
      _query.trim().isEmpty ||
      foldForSearch(text).contains(foldForSearch(_query.trim()));

  /// Las entradas de un capítulo, de la más vieja a la más nueva: el cuaderno
  /// se lee como un diario. Las que no traen fecha van primero, en el orden en
  /// que las devolvió el servidor.
  List<_Entry> _entriesOf(String? chapterId, Notebook notebook) {
    final entries = <_Entry>[
      for (final note in notebook.notes)
        if (note.chapterId == chapterId &&
            (_matches(note.title) || _matches(note.body)))
          (at: note.updatedAt, note: note, log: null),
      for (final log in notebook.encounterLogs)
        if (log.chapterId == chapterId && _matches(_logTitle(log)))
          (at: log.endedAt, note: null, log: log),
    ];
    entries.sort((a, b) {
      if (a.at == null || b.at == null) return a.at == null ? -1 : 1;
      return a.at!.compareTo(b.at!);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return AppErrorView(
        message: 'No se pudo leer el cuaderno.',
        details: '${widget.error}',
        onRetry: widget.onRetry,
      );
    }
    if (widget.loading) {
      return const Center(child: AppBusyLabel('Cargando el cuaderno…'));
    }

    // Sin capítulos no hay dónde escribir: el cuaderno cuelga de ellos.
    if (widget.chapters.isEmpty) {
      return const AppEmptyState(
        icon: Icons.menu_book_outlined,
        message:
            'El cuaderno se ordena por capítulo, así que primero hay que '
            'crear uno. Desde Capítulos.',
      );
    }

    final notebook = widget.notebook ?? const Notebook();
    // Los combates archivados antes de que existiera el cuaderno, y los que se
    // jugaron sin ningún capítulo en marcha, no tienen dónde colgarse. Se
    // muestran aparte en vez de inventarles un capítulo.
    final loose = _entriesOf(null, notebook);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Buscar en el cuaderno',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        for (final chapter in widget.chapters)
          // Con una búsqueda puesta, un capítulo sin coincidencias no aporta
          // nada y se saca del listado entero. Filtrar acá y no adentro de la
          // tarjeta es lo que hace que realmente desaparezca: una tarjeta que
          // devuelve un hueco sigue estando en el árbol.
          if (_entriesOf(chapter.id, notebook) case final entries
              when !(_query.trim().isNotEmpty && entries.isEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChapterCard(
                key: ValueKey('notebook-chapter-${chapter.id}'),
                chapter: chapter,
                entries: entries,
                expanded: _open.contains(chapter.id),
                searching: _query.trim().isNotEmpty,
                onToggle: () => setState(() {
                  _open.contains(chapter.id)
                      ? _open.remove(chapter.id)
                      : _open.add(chapter.id);
                }),
                onEditNote: widget.onEditNote,
                onDeleteNote: (note) => _confirmDelete(context, note),
              ),
            ),
        if (loose.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Eyebrow('Sin capítulo'),
          const SizedBox(height: 8),
          Text(
            'Combates que se jugaron sin ningún capítulo en marcha.',
            style: TextStyle(fontSize: 13, color: context.palette.textMuted),
          ),
          const SizedBox(height: 10),
          for (final entry in loose)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EntryTile(
                entry: entry,
                onEdit: widget.onEditNote,
                onDelete: (note) => _confirmDelete(context, note),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar nota'),
        content: Text('Se borra «${note.title}» y no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar nota'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDeleteNote(note);
  }
}

String _logTitle(EncounterLog log) => log.monsters.isEmpty
    ? 'Combate'
    : 'Combate contra ${log.monsters.map((m) => m.name).join(', ')}';

/// Un capítulo del cuaderno: plegado muestra un resumen, abierto muestra sus
/// entradas.
class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final List<_Entry> entries;
  final bool expanded;

  /// Con una búsqueda activa el capítulo se abre solo: plegado escondería
  /// justo lo que se está buscando.
  final bool searching;

  final VoidCallback onToggle;
  final void Function(Note note) onEditNote;
  final void Function(Note note) onDeleteNote;

  const _ChapterCard({
    super.key,
    required this.chapter,
    required this.entries,
    required this.expanded,
    required this.searching,
    required this.onToggle,
    required this.onEditNote,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final isActive = chapter.state == ChapterState.active;
    final open = expanded || searching;

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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: isActive ? pal.gold : pal.textMuted,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text(
                            chapter.name,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 19,
                              color: isActive ? null : pal.textMuted,
                            ),
                          ),
                          GoldPill(chapter.state.label, highlighted: isActive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _summary(),
                        style: TextStyle(fontSize: 13, color: pal.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 14),
            if (entries.isEmpty)
              Text(
                'Todavía no hay nada anotado en este capítulo.',
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              )
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryTile(
                    entry: entry,
                    onEdit: onEditNote,
                    onDelete: onDeleteNote,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String _summary() {
    final notes = entries.where((e) => e.note != null).length;
    final fights = entries.where((e) => e.log != null).length;
    if (notes == 0 && fights == 0) return 'Sin entradas';
    return [
      if (notes > 0) notes == 1 ? '1 nota' : '$notes notas',
      if (fights > 0) fights == 1 ? '1 combate' : '$fights combates',
    ].join(' · ');
  }
}

/// Una entrada suelta: nota del DM o combate cerrado.
class _EntryTile extends StatelessWidget {
  final _Entry entry;
  final void Function(Note note) onEdit;
  final void Function(Note note) onDelete;

  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final note = entry.note;
    final log = entry.log;

    return Container(
      decoration: BoxDecoration(
        // La placa se hunde: lo que escribió la app, no el DM.
        color: note != null
            ? Theme.of(context).colorScheme.surface
            : pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(
              note != null
                  ? Icons.edit_outlined
                  : Icons.local_fire_department_outlined,
              size: 16,
              color: note != null ? pal.gold : pal.crimson,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note?.title ?? _logTitle(log!),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _stamp(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: pal.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    // Solo lo que escribió el DM se edita. Un combate pasó y no
                    // se corrige: no lleva menú.
                    if (note != null)
                      PopupMenuButton<_NoteAction>(
                        tooltip: 'Acciones de la nota',
                        icon: const Icon(Icons.more_horiz, size: 18),
                        padding: EdgeInsets.zero,
                        onSelected: (action) => switch (action) {
                          _NoteAction.edit => onEdit(note),
                          _NoteAction.delete => onDelete(note),
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _NoteAction.edit,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _NoteAction.delete,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline,
                                color: pal.crimson,
                              ),
                              title: Text(
                                'Borrar',
                                style: TextStyle(color: pal.crimson),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note?.body ?? _logBody(log!),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stamp() {
    final at = entry.at;
    if (at == null) return '';
    final rounds = entry.log == null
        ? ''
        : ' · ${entry.log!.rounds} ronda${entry.log!.rounds == 1 ? '' : 's'}';
    final days = DateTime.now().difference(at).inDays;
    final when = switch (days) {
      0 => 'hoy',
      1 => 'ayer',
      < 30 => 'hace $days días',
      _ => '${at.day}/${at.month}/${at.year}',
    };
    return '$when$rounds';
  }
}

enum _NoteAction { edit, delete }

/// Qué dice un combate cerrado. Deliberadamente grueso: el servidor nunca sabe
/// quién hizo cuánto daño, porque cada jugador anota sus propios PG.
String _logBody(EncounterLog log) {
  final who = log.players.isEmpty ? 'La mesa' : log.players.join(', ');
  if (log.monsters.isEmpty) return '$who peleó sin enemigos cargados.';
  final against = [
    for (final m in log.monsters)
      m.count == 1 ? m.name : '${m.count} ${m.name}',
  ].join(' y ');
  final fell = log.totalDefeated == 0
      ? 'No cayó ninguno.'
      : log.totalDefeated == log.totalMonsters
      ? 'Cayeron todos.'
      : 'Cayeron ${log.totalDefeated} de ${log.totalMonsters}.';
  return '$who contra $against. $fell';
}
