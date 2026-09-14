part of '../sheet_screen.dart';

/// La pestaña **Diario**: el lado creativo del personaje, que hasta ahora era
/// un campo de notas libre y nada más.
///
/// Dos piezas con jerarquías distintas a propósito. El **trasfondo** está
/// siempre —aunque esté vacío, donde dice «Origen desconocido»— porque todo
/// personaje viene de algún lado; las **entradas** son opcionales y se acomodan
/// arrastrando, sin orden impuesto por la fecha.
///
/// Nada de acá es una regla: no llega al `ComputedSheet` ni cambia un número.
extension _SheetDiarySection on _SheetScreenState {
  Widget _buildDiario() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_backgroundCard(), const SizedBox(height: 16), _entriesCard()],
  );

  // ------------------------------------------------------------- Trasfondo

  Widget _backgroundCard() {
    final pal = context.palette;
    final vacio = _c.background.trim().isEmpty;
    return sheetCard(
      icon: Icons.auto_stories_outlined,
      title: 'Trasfondo',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Importar un .md',
            onPressed: _importBackground,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            color: pal.textMuted,
          ),
          IconButton(
            tooltip: 'Exportar como .md',
            // Sin trasfondo no hay archivo que bajar, y un botón que descarga
            // un archivo vacío es peor que uno apagado.
            onPressed: vacio ? null : _exportBackground,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            color: pal.textMuted,
          ),
          IconButton(
            tooltip: _editingBackground
                ? 'Terminar de editar'
                : 'Editar el trasfondo',
            onPressed: () => _setEditingBackground(!_editingBackground),
            icon: Icon(
              _editingBackground ? Icons.check : Icons.edit_outlined,
              size: 18,
            ),
            color: pal.gold,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: _editingBackground
            ? _backgroundEditor()
            : vacio
            ? _backgroundEmpty()
            : _MarkdownText(_c.background),
      ),
    );
  }

  Widget _backgroundEditor() {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _backgroundCtrl,
          minLines: 10,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'De dónde viene, qué dejó atrás, qué le debe a quién…',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          // Se escribe sobre el mismo personaje y se autoguarda con `touch`,
          // igual que hacían las notas: producir un `Character` nuevo por cada
          // tecla recompilaría la ficha entera mientras alguien escribe.
          onChanged: (v) {
            _c.background = v;
            ctrl.touch(_c);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Acepta Markdown: # para títulos, **negrita**, *itálica* y - para '
          'viñetas.',
          style: TextStyle(fontSize: 12, color: pal.textMuted),
        ),
      ],
    );
  }

  /// El trasfondo vacío **no esconde la tarjeta**: dice que no se sabe de dónde
  /// viene, que es una afirmación sobre el personaje y no sobre la aplicación.
  Widget _backgroundEmpty() {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Origen desconocido',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: pal.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Todavía nadie escribió de dónde viene ${_c.name}. Podés escribirlo '
          'acá, o traer un .md que ya tengas afuera.',
          style: TextStyle(fontSize: 13, height: 1.5, color: pal.textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _setEditingBackground(true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Escribir el trasfondo'),
            ),
            OutlinedButton.icon(
              onPressed: _importBackground,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importar .md'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importBackground() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md'],
        withData: true,
        dialogTitle: 'Elegir un archivo .md',
      );
    } catch (e) {
      if (mounted) _snack('No se pudo abrir el archivo: $e');
      return;
    }
    final bytes = picked?.files.singleOrNull?.bytes;
    if (bytes == null || !mounted) return; // el usuario canceló

    // Reemplazar un trasfondo ya escrito es destructivo y no se puede deshacer,
    // así que se pregunta. Con la tarjeta vacía no hay nada que perder.
    if (_c.background.trim().isNotEmpty) {
      final pal = context.palette;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          icon: Icons.warning_amber_rounded,
          iconColor: pal.crimson,
          title: 'Reemplazar el trasfondo',
          content: const Text(
            'Lo que hay escrito se pierde y queda en su lugar el contenido del '
            'archivo. No hay forma de recuperarlo.',
          ),
          actions: [
            DialogAction(
              'Cancelar',
              keyHint: 'Esc',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            DialogAction(
              'Reemplazar',
              primary: true,
              color: pal.crimson,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final String texto;
    try {
      texto = utf8.decode(bytes);
    } catch (_) {
      // Un .md no es cualquier cosa renombrada: si no es UTF-8, meterlo en la
      // ficha dejaría el trasfondo ilegible y guardado.
      _snack('El archivo no parece texto en UTF-8.');
      return;
    }
    _adoptBackground(texto);
    _snack('Trasfondo importado.');
  }

  void _exportBackground() {
    browser.downloadBytes(
      utf8.encode(_c.background),
      fileName: '${_fileSlug(_c.name)}-trasfondo.md',
      mimeType: 'text/markdown',
    );
  }

  /// Nombre de archivo sin acentos raros ni separadores: lo que se baja tiene
  /// que poder guardarse en cualquier sistema de archivos.
  String _fileSlug(String name) {
    final limpio = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final recortado = limpio.replaceAll(RegExp(r'^-+|-+$'), '');
    return recortado.isEmpty ? 'personaje' : recortado;
  }

  // -------------------------------------------------------------- Entradas

  Widget _entriesCard() {
    final pal = context.palette;
    final entradas = _c.diary;
    return sheetCard(
      icon: Icons.grid_view_outlined,
      title: 'Entradas',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entradas.isEmpty ? '—' : '${entradas.length}',
            style: TextStyle(
              fontSize: 12,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            tooltip: 'Agregar una entrada',
            onPressed: () => _editEntry(null),
            icon: const Icon(Icons.add, size: 19),
            color: pal.gold,
          ),
        ],
      ),
      child: entradas.isEmpty
          ? AppEmptyState(
              icon: Icons.photo_library_outlined,
              message:
                  'El diario de ${_c.name} todavía está en blanco.\n'
                  'Sumá arte, una historia corta, una manía — lo que te guste '
                  'de este personaje.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _editEntry(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar entrada'),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _entriesGrid(entradas),
            ),
    );
  }

  /// La grilla, armada a mano con filas y no con un `GridView`: esto vive
  /// adentro del `ListView` de la ficha, y un scroll del mismo eje adentro de
  /// otro se queda sin alto y revienta al dibujar.
  Widget _entriesGrid(List<DiaryEntry> entradas) {
    return LayoutBuilder(
      builder: (context, box) {
        final columnas = box.maxWidth >= 760
            ? 3
            : box.maxWidth >= 520
            ? 2
            : 1;
        final filas = <Widget>[];
        for (var i = 0; i < entradas.length; i += columnas) {
          final fila = entradas.skip(i).take(columnas).toList();
          filas.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columnas; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(
                    child: c < fila.length
                        // Alto fijo para que las tarjetas de una fila midan lo
                        // mismo sin pedir `IntrinsicHeight`, que mide dos veces
                        // cada hijo.
                        ? SizedBox(height: 236, child: _entrySlot(fila[c]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              filas[i],
            ],
          ],
        );
      },
    );
  }

  /// Una tarjeta arrastrable. Mismo trato que el roster del dashboard: el
  /// arrastre arranca con **pulsación larga** —la tarjeta entera ya es un
  /// botón, y en pantalla táctil desplazar la grilla no puede terminar
  /// reordenando el diario—, el hueco queda al 30 % y el destino se marca con
  /// filete oro de 2 px.
  Widget _entrySlot(DiaryEntry entrada) {
    return _DiaryDragSlot(
      id: entrada.entryId,
      onDropped: (fromId) => _moveEntry(fromId, entrada.entryId),
      child: _entryCard(entrada),
    );
  }

  Widget _entryCard(DiaryEntry e) {
    final pal = context.palette;
    final (icono, _) = _entryVisual(e.kind);
    return Material(
      color: pal.plaque,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openEntry(e),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 14, color: pal.gold),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      e.title.isEmpty ? 'Sin título' : e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Expanded(child: _entryPreview(e)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _entryDates(e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: pal.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: pal.textMuted.withValues(alpha: 0.75),
                    semanticLabel: 'Mantené apretado para reordenar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryPreview(DiaryEntry e) {
    final pal = context.palette;
    switch (e.kind) {
      case DiaryEntryKind.image:
        final key = e.imageKey;
        if (key == null) {
          return Text(
            'Sin imagen.',
            style: TextStyle(fontSize: 12.5, color: pal.textMuted),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.expand(
            child: Image.network(
              PortraitImage.urlFor(key, width: 512),
              fit: BoxFit.cover,
              // Una imagen borrada del almacén no puede romper la pestaña.
              errorBuilder: (_, _, _) => ColoredBox(
                color: pal.hairline.withValues(alpha: 0.25),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 22,
                    color: pal.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      case DiaryEntryKind.link:
        return Text(
          e.body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: pal.gold),
        );
      case DiaryEntryKind.text:
        return Text(
          e.body,
          maxLines: 7,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: pal.textMuted),
        );
    }
  }

  (IconData, String) _entryVisual(DiaryEntryKind kind) => switch (kind) {
    DiaryEntryKind.text => (Icons.notes, 'Texto'),
    DiaryEntryKind.image => (Icons.image_outlined, 'Imagen'),
    DiaryEntryKind.link => (Icons.link, 'Enlace'),
  };

  /// «12/03», o «12/03 · editada 02/04» cuando se tocó después. Sin fecha —la
  /// entrada que vino de las notas viejas— no se inventa ninguna.
  String _entryDates(DiaryEntry e) {
    final creada = e.createdAt;
    if (creada == null) return '';
    final tocada = e.updatedAt;
    final base = _shortDate(creada);
    if (tocada == null || !tocada.isAfter(creada)) return base;
    return '$base · editada ${_shortDate(tocada)}';
  }

  String _shortDate(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }

  void _moveEntry(String fromId, String toId) {
    if (fromId == toId) return;
    final lista = [..._c.diary];
    final desde = lista.indexWhere((e) => e.entryId == fromId);
    final hasta = lista.indexWhere((e) => e.entryId == toId);
    if (desde < 0 || hasta < 0) return;
    lista.insert(hasta, lista.removeAt(desde));
    _replace(_c.copyWith(diary: lista));
  }

  // ----------------------------------------------------------- Los modales

  /// Modo lectura. Editar sale de acá y no de la grilla: la tarjeta es chica y
  /// un lápiz ahí competiría con el toque que abre la entrada.
  Future<void> _openEntry(DiaryEntry e) async {
    final pal = context.palette;
    final (icono, _) = _entryVisual(e.kind);
    final editar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icono,
        title: e.title.isEmpty ? 'Sin título' : e.title,
        // 560 y no 480: el cuerpo puede ser una imagen, que con la medida de
        // lectura de un párrafo queda innecesariamente chica.
        width: 560,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_entryDates(e) case final fechas when fechas.isNotEmpty) ...[
              Text(
                fechas,
                style: TextStyle(
                  fontSize: 12,
                  color: pal.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _entryBody(e),
          ],
        ),
        actions: [
          DialogAction(
            'Cerrar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Editar',
            primary: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (editar == true && mounted) await _editEntry(e);
  }

  Widget _entryBody(DiaryEntry e) {
    final pal = context.palette;
    switch (e.kind) {
      case DiaryEntryKind.image:
        final key = e.imageKey;
        if (key == null) return const Text('Esta entrada no tiene imagen.');
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            PortraitImage.urlFor(key),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('La imagen ya no está en el almacén.'),
          ),
        );
      case DiaryEntryKind.link:
        return SelectableText(
          e.body,
          style: TextStyle(fontSize: 14, height: 1.55, color: pal.gold),
        );
      case DiaryEntryKind.text:
        return SelectableText(
          e.body,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    }
  }

  /// Alta y edición. [existente] en null es una entrada nueva.
  Future<void> _editEntry(DiaryEntry? existente) async {
    final resultado = await showDialog<_DiaryEditResult>(
      context: context,
      builder: (ctx) => _DiaryEntryDialog(
        entry: existente,
        api: ctrl.api,
        characterId: _c.id,
      ),
    );
    if (resultado == null || !mounted) return;

    if (resultado.borrar && existente != null) {
      await _deleteEntry(existente);
      return;
    }
    final guardada = resultado.entrada;
    if (guardada == null) return;

    final lista = [..._c.diary];
    final i = lista.indexWhere((e) => e.entryId == guardada.entryId);
    if (i >= 0) {
      lista[i] = guardada;
    } else {
      lista.add(guardada);
    }
    _replace(_c.copyWith(diary: lista));
  }

  Future<void> _deleteEntry(DiaryEntry e) async {
    final pal = context.palette;
    final tieneImagen = e.kind == DiaryEntryKind.image && e.imageKey != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: 'Borrar la entrada',
        content: Text(
          '«${e.title.isEmpty ? 'Sin título' : e.title}» se va del diario'
          '${tieneImagen ? ', y la imagen que subiste se borra con ella' : ''}. '
          'No hay forma de recuperarla.',
        ),
        actions: [
          DialogAction(
            'Cancelar',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Borrar',
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _replace(
      _c.copyWith(
        diary: [
          for (final otra in _c.diary)
            if (otra.entryId != e.entryId) otra,
        ],
      ),
    );
    final key = e.imageKey;
    if (key == null) return;
    try {
      await ctrl.api.deletePortrait(key);
    } catch (_) {
      // La entrada ya se fue de la ficha, que es lo que se pidió. Un blob que
      // queda es basura barata: la cascada de borrar el personaje se la lleva.
    }
  }
}

/// Resultado del editor: la entrada guardada, o el pedido de borrarla.
typedef _DiaryEditResult = ({DiaryEntry? entrada, bool borrar});

/// Envoltorio que hace arrastrable una tarjeta del diario para reordenarla.
///
/// Copia deliberada del que usa el roster del dashboard (`dashboard_widgets`):
/// soltar sobre otra tarjeta la mueve a esa posición, y eso es todo lo que hace
/// falta acá tampoco. Se escribe de nuevo en vez de compartirse porque aquel
/// mide celdas de una grilla con ancho propio y este vive en una fila elástica.
class _DiaryDragSlot extends StatefulWidget {
  final String id;
  final void Function(String fromId) onDropped;
  final Widget child;

  const _DiaryDragSlot({
    required this.id,
    required this.onDropped,
    required this.child,
  });

  @override
  State<_DiaryDragSlot> createState() => _DiaryDragSlotState();
}

class _DiaryDragSlotState extends State<_DiaryDragSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.id,
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onDropped(details.data);
      },
      onMove: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onLeave: (_) => setState(() => _hovering = false),
      builder: (context, candidate, rejected) => LongPressDraggable<String>(
        data: widget.id,
        // La fila reparte el ancho: sin acotar el feedback, la tarjeta
        // arrastrada se dibuja sin restricciones y revienta.
        feedback: SizedBox(
          width: 300,
          height: 236,
          child: Opacity(opacity: 0.85, child: widget.child),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? pal.gold : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// El editor de una entrada, con su propio estado.
///
/// Widget con estado y no un `AppDialog` armado en línea por lo mismo que
/// `showTextPromptDialog`: los controladores tienen que vivir exactamente lo
/// que vive el diálogo.
class _DiaryEntryDialog extends StatefulWidget {
  final DiaryEntry? entry;
  final ApiClient api;
  final String characterId;

  const _DiaryEntryDialog({
    required this.entry,
    required this.api,
    required this.characterId,
  });

  @override
  State<_DiaryEntryDialog> createState() => _DiaryEntryDialogState();
}

class _DiaryEntryDialogState extends State<_DiaryEntryDialog> {
  late final _titleCtrl = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late final _bodyCtrl = TextEditingController(text: widget.entry?.body ?? '');
  late DiaryEntryKind _kind = widget.entry?.kind ?? DiaryEntryKind.text;
  late String? _imageKey = widget.entry?.imageKey;

  bool _subiendo = false;
  String? _error;

  static const _extensiones = ['png', 'jpg', 'jpeg', 'webp'];

  bool get _puedeGuardar =>
      !_subiendo &&
      _titleCtrl.text.trim().isNotEmpty &&
      (_kind != DiaryEntryKind.image || _imageKey != null);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensiones,
        withData: true,
        dialogTitle: 'Elegir una imagen',
      );
      final bytes = picked?.files.singleOrNull?.bytes;
      if (bytes == null) return; // el usuario canceló
      // Reusa el almacén de retratos: ya valida tipo y tamaño, y el borrado del
      // personaje ya se lleva sus imágenes.
      //
      // ponytail: cambiar la imagen de una entrada deja la anterior en el
      // almacén. Se la lleva la cascada al borrar el personaje; si alguna vez
      // molesta el espacio, borrarla acá es una línea.
      final key = await widget.api.savePortrait(
        characterId: widget.characterId,
        bytes: bytes,
      );
      if (mounted) setState(() => _imageKey = key);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo subir la imagen: $e');
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _guardar() {
    final ahora = DateTime.now();
    final previa = widget.entry;
    final entrada =
        (previa ??
                DiaryEntry(
                  entryId: 'diary-${ahora.microsecondsSinceEpoch}',
                  createdAt: ahora,
                ))
            .copyWith(
              kind: _kind,
              title: _titleCtrl.text.trim(),
              body: _kind == DiaryEntryKind.image ? '' : _bodyCtrl.text.trim(),
              imageKey: _kind == DiaryEntryKind.image ? _imageKey : null,
              // La fecha de modificación solo tiene sentido si hubo una anterior:
              // en una entrada nueva las dos serían la misma y la tarjeta diría
              // «editada» de algo recién escrito.
              updatedAt: previa == null ? null : ahora,
            );
    Navigator.pop(context, (entrada: entrada, borrar: false));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final esNueva = widget.entry == null;
    return AppDialog(
      icon: esNueva ? Icons.add : Icons.edit_outlined,
      title: esNueva ? 'Nueva entrada' : 'Editar entrada',
      width: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
            // El botón de guardar depende de que haya título.
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Eyebrow('Tipo de entrada'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in DiaryEntryKind.values)
                ChoiceChip(
                  label: Text(switch (kind) {
                    DiaryEntryKind.text => 'Texto',
                    DiaryEntryKind.image => 'Imagen',
                    DiaryEntryKind.link => 'Enlace',
                  }),
                  avatar: Icon(switch (kind) {
                    DiaryEntryKind.text => Icons.notes,
                    DiaryEntryKind.image => Icons.image_outlined,
                    DiaryEntryKind.link => Icons.link,
                  }, size: 16),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_kind == DiaryEntryKind.image)
            ..._imagenControles(pal)
          else
            TextField(
              controller: _bodyCtrl,
              minLines: _kind == DiaryEntryKind.link ? 1 : 5,
              maxLines: _kind == DiaryEntryKind.link ? 1 : null,
              keyboardType: _kind == DiaryEntryKind.link
                  ? TextInputType.url
                  : TextInputType.multiline,
              decoration: InputDecoration(
                labelText: _kind == DiaryEntryKind.link ? 'Enlace' : 'Texto',
                hintText: _kind == DiaryEntryKind.link
                    ? 'https://…'
                    : 'Lo que quieras contar de este personaje…',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          if (_error case final mensaje?) ...[
            const SizedBox(height: 12),
            Text(mensaje, style: TextStyle(fontSize: 12.5, color: pal.crimson)),
          ],
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(context),
        ),
        if (!esNueva)
          DialogAction(
            'Borrar',
            color: pal.crimson,
            // El borrado lo confirma la pestaña: este diálogo solo lo pide.
            onPressed: () =>
                Navigator.pop(context, (entrada: null, borrar: true)),
          ),
        DialogAction(
          'Guardar',
          primary: true,
          onPressed: _puedeGuardar ? _guardar : null,
        ),
      ],
    );
  }

  List<Widget> _imagenControles(AppPalette pal) {
    final key = _imageKey;
    return [
      if (key != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            PortraitImage.urlFor(key, width: 512),
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_subiendo)
        const AppBusyLabel('Subiendo la imagen…')
      else
        OutlinedButton.icon(
          onPressed: _elegirImagen,
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: Text(key == null ? 'Elegir imagen' : 'Cambiar imagen'),
        ),
      const SizedBox(height: 10),
      Text(
        'PNG, JPEG o WEBP. Mismo límite de tamaño que los retratos.',
        style: TextStyle(fontSize: 12, color: pal.textMuted),
      ),
    ];
  }
}

/// Markdown del trasfondo, con lo que un trasfondo usa y nada más.
///
/// ponytail: subconjunto a mano en vez de una dependencia. Entiende títulos
/// (`#`, `##`, `###`), viñetas (`-`, `*`), párrafos separados por una línea en
/// blanco, y **negrita** e *itálica* dentro de la línea. No entiende enlaces,
/// código, citas, tablas ni listas anidadas: el día que haga falta alguna de
/// esas, la salida es `flutter_markdown_plus` y tirar esta clase.
///
/// `flutter_markdown` está discontinuado, así que sumarlo hoy sería estrenar
/// deuda en vez de evitarla.
class _MarkdownText extends StatelessWidget {
  final String source;

  const _MarkdownText(this.source);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final cuerpo = Theme.of(context).colorScheme.onSurfaceVariant;
    final bloques = <Widget>[];

    void separar() {
      if (bloques.isNotEmpty) bloques.add(const SizedBox(height: 10));
    }

    final parrafo = <String>[];
    void cerrarParrafo() {
      if (parrafo.isEmpty) return;
      separar();
      bloques.add(
        Text.rich(
          _inline(parrafo.join(' '), cuerpo),
          style: TextStyle(fontSize: 14, height: 1.65, color: cuerpo),
        ),
      );
      parrafo.clear();
    }

    for (final cruda in source.split('\n')) {
      final linea = cruda.trimRight();
      final limpia = linea.trimLeft();

      if (limpia.isEmpty) {
        cerrarParrafo();
        continue;
      }
      if (limpia.startsWith('### ') ||
          limpia.startsWith('## ') ||
          limpia.startsWith('# ')) {
        cerrarParrafo();
        final nivel = limpia.startsWith('### ')
            ? 3
            : limpia.startsWith('## ')
            ? 2
            : 1;
        separar();
        bloques.add(
          Text(
            limpia.substring(nivel + 1).trim(),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: switch (nivel) {
                1 => 17,
                2 => 15.5,
                _ => 14.5,
              },
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
        continue;
      }
      if (limpia.startsWith('- ') || limpia.startsWith('* ')) {
        cerrarParrafo();
        separar();
        bloques.add(
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 9),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _inline(limpia.substring(2).trim(), cuerpo),
                    style: TextStyle(fontSize: 14, height: 1.55, color: cuerpo),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      parrafo.add(limpia);
    }
    cerrarParrafo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bloques,
    );
  }

  /// `**negrita**` e `*itálica*`. Un asterisco suelto se deja tal cual: en un
  /// trasfondo es más probable que sea puntuación que un énfasis a medio
  /// escribir.
  static TextSpan _inline(String texto, Color color) {
    final hijos = <TextSpan>[];
    final patron = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var cursor = 0;
    for (final m in patron.allMatches(texto)) {
      if (m.start > cursor) {
        hijos.add(TextSpan(text: texto.substring(cursor, m.start)));
      }
      final negrita = m.group(1);
      hijos.add(
        TextSpan(
          text: negrita ?? m.group(2),
          style: negrita != null
              ? const TextStyle(fontWeight: FontWeight.w600)
              : const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
      cursor = m.end;
    }
    if (cursor < texto.length) {
      hijos.add(TextSpan(text: texto.substring(cursor)));
    }
    return TextSpan(children: hijos);
  }
}
