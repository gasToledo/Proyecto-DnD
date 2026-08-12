part of '../creation_wizard.dart';

// ----------------------------------------------------------------------------
// Pasos
// ----------------------------------------------------------------------------

/// Tarjeta de elección: ícono en recuadro, nombre y línea de sabor. Es el
/// patrón compartido por los pasos de Especie, Clase y Trasfondo.
class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  /// Procedencia de la opción. Se muestra debajo del subtítulo: el título ya usa
  /// una sola línea con ellipsis en 228 px y un badge en línea lo comprimiría.
  final ContentSource? source;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 228,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: context.motion(const Duration(milliseconds: 120)),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? accent : pal.hairline,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? accent : pal.goldSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? scheme.onPrimary : accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (source != null) ...[
                        const SizedBox(height: 6),
                        SourceBadge(source!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla fluida de [_ChoiceCard].
class _ChoiceGrid extends StatelessWidget {
  final List<Widget> children;
  const _ChoiceGrid({required this.children});
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 12, runSpacing: 12, children: children);
}

/// Ancho a partir del cual Especie, Clase y Trasfondo se muestran en dos
/// columnas. Por debajo se vuelve al apilado (grilla arriba, detalle abajo):
/// con la lista y el panel lado a lado en poco ancho no entra ninguno de los
/// dos.
const _splitMinWidth = 900.0;
const _splitListWidth = 300.0;

/// Lo que se le descuenta al alto del paso para dejar la lista: el rótulo de
/// sección que va encima y un respiro abajo.
const _splitListChrome = 74.0;

/// Piso y techo del alto de la lista. El piso evita una lista de dos ítems en
/// una ventana muy baja; el techo, que en un monitor vertical la columna quede
/// absurdamente larga.
const _splitListMinHeight = 320.0;
const _splitListMaxHeight = 1400.0;

/// Alto de la lista si no se pudo medir el paso (fuera del wizard, en tests).
const _splitListFallbackHeight = 520.0;

/// Alto real disponible para el contenido de un paso. Lo publica el shell del
/// wizard, que es el único que lo conoce: el paso se dibuja dentro de un
/// `SingleChildScrollView` y ahí el alto máximo ya es infinito.
class _StepViewport extends InheritedWidget {
  final double height;
  const _StepViewport({required this.height, required super.child});

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StepViewport>()?.height;

  @override
  bool updateShouldNotify(_StepViewport old) => old.height != height;
}

/// Lista angosta a la izquierda, detalle ancho a la derecha. Es el patrón
/// compartido por los pasos de Especie, Clase y Trasfondo.
class _SplitSelect extends StatelessWidget {
  final List<Widget> options;

  /// Panel de la opción elegida, o null si todavía no hay ninguna.
  final Widget? detail;

  /// Qué decir en el panel vacío mientras no haya selección.
  final String emptyHint;

  const _SplitSelect({
    required this.options,
    required this.detail,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _splitMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChoiceGrid(children: options),
              if (detail != null) ...[const SizedBox(height: 18), detail!],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _splitListWidth,
              child: _OptionColumn(options: options),
            ),
            const SizedBox(width: 20),
            Expanded(child: detail ?? _EmptyDetail(hint: emptyHint)),
          ],
        );
      },
    );
  }
}

/// Llave de la columna de opciones del modo dividido (especie, clase,
/// trasfondo). Solo la usan las pruebas, para scrollear la lista correcta.
const optionColumnKey = Key('option-column');

/// Las opciones apiladas una por fila, con scroll propio.
class _OptionColumn extends StatefulWidget {
  final List<Widget> options;
  const _OptionColumn({required this.options});

  @override
  State<_OptionColumn> createState() => _OptionColumnState();
}

class _OptionColumnState extends State<_OptionColumn> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La lista ocupa el alto del paso, no una cifra fija: con un tope chico
    // sobraba media ventana vacía. Si hay pocas opciones el ListView encoge
    // igual (shrinkWrap), así que esto es techo, no alto impuesto.
    final viewport = _StepViewport.maybeOf(context);
    final maxHeight = viewport == null
        ? _splitListFallbackHeight
        : (viewport - _splitListChrome).clamp(
            _splitListMinHeight,
            _splitListMaxHeight,
          );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: ListView(
          // La lista es perezosa: una opción del medio no está construida hasta
          // que se scrollea. La llave le da a las pruebas un asidero estable
          // para scrollear **esta** lista, y no la del paso o la del detalle.
          key: optionColumnKey,
          controller: _scroll,
          primary: false,
          shrinkWrap: true,
          padding: const EdgeInsets.only(right: 12),
          children: [
            for (final option in widget.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // Tight: anula el ancho natural de _ChoiceCard para que ocupe
                // la columna entera.
                child: SizedBox(width: double.infinity, child: option),
              ),
          ],
        ),
      ),
    );
  }
}

/// Marca de agua del panel derecho mientras no hay nada elegido.
class _EmptyDetail extends StatelessWidget {
  final String hint;
  const _EmptyDetail({required this.hint});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app_outlined, size: 30, color: pal.textMuted),
          const SizedBox(height: 10),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: pal.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Paso 1 · Especie. Elección + rasgos de la especie elegida. Las habilidades y
/// la dote de origen se eligen más adelante, en Aptitudes.
