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
            border: Border.all(
              color: state == CharacterSaveState.error
                  ? Theme.of(context).colorScheme.error
                  : pal.hairline,
            ),
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

/// Etiqueta de personaje sin puntos de golpe.
///
/// Va junto al nombre y no en un rincón: es lo primero que hay que saber de esa
/// tarjeta. El retrato atenuado y la barra vacía dicen lo mismo, para que el
/// estado no dependa de un solo indicador ni del color.
class _FallenBadge extends StatelessWidget {
  final double scale;
  const _FallenBadge({required this.scale});

  @override
  Widget build(BuildContext context) {
    final crimson = context.palette.crimson;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: crimson.withAlpha(140)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.heart_broken, size: 11 * scale, color: crimson),
          SizedBox(width: 4 * scale),
          Text(
            'CAÍDO',
            style: TextStyle(
              fontSize: 9.5 * scale,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: crimson,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una celda de la tira de estadísticas del pie de la tarjeta (CA, velocidad,
/// iniciativa). Cifras tabulares, para que tres tarjetas en fila alineen sus
/// números en vez de bailar según el ancho de cada dígito.
class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  /// Unidad, en chico y atenuada detrás del valor («30 pies»).
  final String? suffix;
  final IconData? icon;

  /// Lo que lee un lector de pantalla: el rótulo abreviado no se entiende
  /// dicho en voz alta.
  final String semantics;
  final double scale;

  const _StatCell({
    required this.label,
    required this.value,
    required this.semantics,
    required this.scale,
    this.suffix,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final k = scale;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10 * k, 8 * k, 8 * k, 9 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alto fijo para la línea del rótulo: el ícono de CA es más alto
            // que el texto y sin esto esa celda crece, con lo que los
            // separadores de la tira dejan de alinear con las otras dos.
            SizedBox(
              height: 14 * k,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 11 * k, color: pal.gold),
                    SizedBox(width: 4 * k),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5 * k,
                        letterSpacing: 0.7,
                        color: pal.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2 * k),
            Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (suffix case final unit?)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontSize: 11 * k,
                        fontWeight: FontWeight.normal,
                        color: pal.textMuted,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22 * k,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gris para el retrato de un caído: cada canal de color pasa a la luminancia
/// del píxel y el alfa queda intacto.
///
/// Es una matriz y no `ColorFilter.mode(grey, BlendMode.saturation)`, que hace
/// lo mismo con el color pero deja opaco lo que era transparente: el medallón
/// es un círculo dentro de una caja cuadrada, así que ese modo le dibujaba
/// alrededor el cuadrado gris de la caja.
const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

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

    final fallen = _isFallen(c);
    final ratio = s.maxHp == 0 ? 0.0 : hp / s.maxHp;
    // Un cuarto de los PG: a partir de ahí el rótulo lo dice con todas las
    // letras, en vez de dejarlo librado a lo corta que se ve la barra. Sin
    // parpadeo: es información, no una alarma.
    final critical = !fallen && ratio <= 0.25;
    final (hpLabel, hpIcon) = switch ((fallen, critical)) {
      (true, _) => ('SIN PUNTOS DE GOLPE', Icons.heart_broken),
      (_, true) => ('PG CRÍTICOS', Icons.warning_amber_rounded),
      _ => ('PUNTOS DE GOLPE', null),
    };

    Widget medallion = ClassMedallion(
      klass: klassObj,
      portraitKey: portrait,
      fallback: c.name.characters.first,
      size: 76 * k,
    );
    if (fallen) {
      medallion = Opacity(
        opacity: 0.55,
        child: ColorFiltered(colorFilter: _grayscale, child: medallion),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 120)),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
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
        // El filete de la clase llega hasta el borde: sin recortar, sus
        // esquinas se salen del radio de la tarjeta.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                children: [
                  // Va posicionado y no como primera columna de una fila: en
                  // el arrastre la tarjeta se dibuja sin alto acotado, y una
                  // fila estirada ahí no tiene contra qué estirarse.
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: ColoredBox(color: fallen ? pal.hairline : accent),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16 * k),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            medallion,
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
                                            color: fallen
                                                ? muted
                                                : scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (fallen) ...[
                                        SizedBox(width: 7 * k),
                                        _FallenBadge(scale: k),
                                      ],
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
                                  SizedBox(height: 7 * k),
                                  // Nivel y trasfondo como badges y no como
                                  // medallón aparte: son dos datos del mismo
                                  // rango, y el medallón le disputaba el sitio
                                  // al retrato.
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      GoldPill(
                                        'Nivel ${c.level}',
                                        highlighted: !fallen,
                                      ),
                                      if (background case final bg?)
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: 190 * k,
                                          ),
                                          child: GoldPill(
                                            bg,
                                            highlighted: false,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 40 * k,
                              child: PopupMenuButton<String>(
                                tooltip: 'Acciones de ${c.name}',
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 18 * k,
                                  color: muted,
                                ),
                                onSelected: (v) {
                                  if (v == 'favorite') {
                                    widget.onToggleFavorite();
                                  }
                                  if (v == 'move-before') {
                                    widget.onMoveBefore?.call();
                                  }
                                  if (v == 'move-after') {
                                    widget.onMoveAfter?.call();
                                  }
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
                                  // El arrastre queda como atajo, pero el orden
                                  // no puede depender de él: con teclado o
                                  // lector de pantalla no hay forma de
                                  // arrastrar nada.
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
                            if (hpIcon != null) ...[
                              Icon(hpIcon, size: 13 * k, color: pal.crimson),
                              SizedBox(width: 5 * k),
                            ],
                            Expanded(
                              child: Text(
                                hpLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5 * k,
                                  letterSpacing: 1,
                                  fontWeight: hpIcon == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: hpIcon == null
                                      ? pal.textMuted
                                      : pal.crimson,
                                ),
                              ),
                            ),
                            SizedBox(width: 6 * k),
                            Text(
                              '$hp',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 13 * k,
                                height: 1,
                                color: pal.crimson,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              ' / ${s.maxHp}',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 13 * k,
                                height: 1,
                                color: pal.textMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * k),
                        // Sin PG la barra queda vacía y con el borde en
                        // carmesí: un relleno de ancho cero no se distingue de
                        // uno que no se dibujó.
                        Container(
                          height: 9 * k,
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: pal.plaque,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: fallen || critical
                                  ? pal.crimson.withAlpha(140)
                                  : pal.hairline,
                            ),
                          ),
                          child: fallen
                              ? null
                              : ThinBar(
                                  ratio: ratio,
                                  color: pal.crimson,
                                  track: pal.plaque,
                                ),
                        ),
                        SizedBox(height: 12 * k),
                        IntrinsicHeight(
                          child: Container(
                            decoration: BoxDecoration(
                              color: pal.plaque,
                              border: Border.all(color: pal.hairline),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _StatCell(
                                    label: 'CA',
                                    value: '${s.armorClass}',
                                    icon: Icons.shield,
                                    semantics:
                                        'Clase de armadura: ${s.armorClass}',
                                    scale: k,
                                  ),
                                ),
                                Container(width: 1, color: pal.hairline),
                                Expanded(
                                  child: _StatCell(
                                    label: 'VEL',
                                    value: '${s.speed}',
                                    suffix: ' pies',
                                    semantics: 'Velocidad: ${s.speed} pies',
                                    scale: k,
                                  ),
                                ),
                                Container(width: 1, color: pal.hairline),
                                Expanded(
                                  child: _StatCell(
                                    label: 'INIC',
                                    value: _signed(s.initiative),
                                    semantics:
                                        'Iniciativa: ${_signed(s.initiative)}',
                                    scale: k,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
