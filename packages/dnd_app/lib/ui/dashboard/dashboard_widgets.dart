part of '../dashboard_screen.dart';

class _SaveStatusIndicator extends StatelessWidget {
  final CharactersController controller;

  const _SaveStatusIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final state = controller.saveState;
    final (icon, label, color) = switch (state) {
      CharacterSaveState.saving => (Icons.sync, 'Guardando…', pal.gold),
      CharacterSaveState.error => (
        Icons.error_outline,
        'Error al guardar',
        Theme.of(context).colorScheme.error,
      ),
      CharacterSaveState.saved => (
        Icons.cloud_done_outlined,
        'Guardado',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Estado del guardado: $label',
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 180)),
        child: Container(
          key: ValueKey(state),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Tarjeta
// ----------------------------------------------------------------------------

/// Envoltorio que hace arrastrable una tarjeta para reordenar el roster.
///
/// Se arma con [Draggable]/[DragTarget] en vez de con un paquete de grilla
/// reordenable: es lo que hace falta acá (soltar sobre otra tarjeta la mueve a
/// esa posición) y no agrega una dependencia para eso.
///
/// El arrastre arranca con pulsación larga, no con el primer movimiento: la
/// tarjeta entera ya es un botón que abre la ficha, y en una pantalla táctil
/// desplazar la grilla no puede terminar moviendo personajes de lugar.
class _ReorderableCard extends StatefulWidget {
  final String id;
  final void Function(String draggedId) onDropped;
  final double cardWidth;
  final Widget child;

  const _ReorderableCard({
    required this.id,
    required this.onDropped,
    required this.cardWidth,
    required this.child,
  });

  @override
  State<_ReorderableCard> createState() => _ReorderableCardState();
}

class _ReorderableCardState extends State<_ReorderableCard> {
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
      builder: (context, candidate, rejected) {
        return LongPressDraggable<String>(
          data: widget.id,
          // La grilla mide las celdas: sin acotar el feedback, la tarjeta
          // arrastrada se dibuja con restricciones sin límite y revienta.
          feedback: SizedBox(
            width: widget.cardWidth,
            child: Opacity(opacity: 0.85, child: widget.child),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovering ? pal.gold : Colors.transparent,
                width: 2,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Tarjeta de personaje: identidad arriba (retrato, nombre, especie·clase,
/// trasfondo y nivel) y los datos de combate abajo (PG, CA, velocidad,
/// iniciativa), para no tener que abrir la ficha para verlos.
class _CharacterCard extends StatefulWidget {
  final Character character;
  final ComputedSheet sheet;
  final ContentRepository repo;

  /// Factor sobre las medidas base, según el ancho que la grilla le dio a esta
  /// tarjeta (ver `_grid`). 1.0 es el diseño original; por encima, todo crece
  /// en proporción para que en una ventana ancha el retrato y los rótulos no
  /// queden más chicos de lo que la pantalla permite.
  final double scale;

  /// Personaje fijado arriba del roster: se distingue por el borde y por la
  /// estrella junto al nombre. El borde solo no alcanza para quien no
  /// distingue bien los colores.
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  /// Reordenar sin arrastrar. Null en los extremos de la lista, donde no hay a
  /// dónde mover.
  final VoidCallback? onMoveBefore;
  final VoidCallback? onMoveAfter;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  const _CharacterCard({
    required this.character,
    required this.sheet,
    required this.repo,
    this.scale = 1.0,
    this.isFavorite = false,
    required this.onTap,
    required this.onToggleFavorite,
    this.onMoveBefore,
    this.onMoveAfter,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final s = widget.sheet;
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final klassObj = widget.repo.characterClass(c.classId);
    final klass = klassObj?.name ?? c.classId;
    final accent = classAccent(klassObj, pal.gold);
    final race = widget.repo.race(c.raceId)?.name ?? c.raceId;
    final background = widget.repo.background(c.backgroundId)?.name;
    final portrait = c.portraitPaths.isNotEmpty ? c.portraitPaths.first : null;
    final hp = c.combat.currentHp;
    final k = widget.scale;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 120)),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          // El favorito lleva el borde de acento y más grueso, para que se
          // distinga en reposo del resto y también de una tarjeta con el
          // puntero encima, que es dorada pero fina.
          border: Border.all(
            color: widget.isFavorite
                ? pal.gold
                : _hover
                ? pal.gold
                : pal.hairline,
            width: widget.isFavorite ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(70),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.all(16 * k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClassMedallion(
                        klass: klassObj,
                        portraitKey: portrait,
                        fallback: c.name.characters.first,
                        size: 76 * k,
                      ),
                      SizedBox(width: 14 * k),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (widget.isFavorite) ...[
                                  Icon(
                                    Icons.star,
                                    key: const ValueKey('favorite-star'),
                                    size: 15 * k,
                                    color: pal.gold,
                                  ),
                                  SizedBox(width: 5 * k),
                                ],
                                Flexible(
                                  child: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 18 * k,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  classIcon(klassObj),
                                  size: 14 * k,
                                  color: accent,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '$race · $klass',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5 * k,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (background != null) ...[
                              const SizedBox(height: 6),
                              GoldPill(background),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Medallion(fallback: '${c.level}', size: 40 * k),
                          SizedBox(height: 3 * k),
                          Text(
                            'NIVEL',
                            style: TextStyle(
                              fontSize: 8.5 * k,
                              letterSpacing: 1,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 32 * k,
                        child: PopupMenuButton<String>(
                          tooltip: 'Acciones de ${c.name}',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            size: 18 * k,
                            color: muted,
                          ),
                          onSelected: (v) {
                            if (v == 'favorite') widget.onToggleFavorite();
                            if (v == 'move-before') widget.onMoveBefore?.call();
                            if (v == 'move-after') widget.onMoveAfter?.call();
                            if (v == 'rename') widget.onRename();
                            if (v == 'export') widget.onExport();
                            if (v == 'delete') widget.onDelete();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'favorite',
                              child: Text(
                                widget.isFavorite
                                    ? 'Quitar de favorito'
                                    : 'Marcar como favorito',
                              ),
                            ),
                            // El arrastre queda como atajo, pero el orden no
                            // puede depender de él: con teclado o lector de
                            // pantalla no hay forma de arrastrar nada.
                            PopupMenuItem(
                              value: 'move-before',
                              enabled: widget.onMoveBefore != null,
                              child: const Text('Mover antes'),
                            ),
                            PopupMenuItem(
                              value: 'move-after',
                              enabled: widget.onMoveAfter != null,
                              child: const Text('Mover después'),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Renombrar'),
                            ),
                            const PopupMenuItem(
                              value: 'export',
                              child: Text('Exportar'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 1,
                    margin: EdgeInsets.symmetric(vertical: 12 * k),
                    color: pal.hairline,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Rótulo flexible: con 3 columnas la tarjeta es
                                // angosta y el valor nunca debe quedar tapado.
                                Expanded(
                                  child: Text(
                                    'PG',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5 * k,
                                      letterSpacing: 1,
                                      color: pal.textMuted,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6 * k),
                                Text(
                                  '$hp/${s.maxHp}',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13 * k,
                                    height: 1,
                                    color: pal.crimson,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5 * k),
                            ThinBar(
                              ratio: s.maxHp == 0 ? 0 : hp / s.maxHp,
                              color: pal.crimson,
                              track: pal.plaque,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShieldBadge('${s.armorClass}', height: 52 * k),
                      SizedBox(width: 10 * k),
                      SizedBox(
                        width: 56 * k,
                        child: StatPlaque(
                          label: 'Vel',
                          value: '${s.speed}',
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 10 * k),
                      SizedBox(
                        width: 56 * k,
                        child: StatPlaque(
                          label: 'Inic',
                          value: _signed(s.initiative),
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
