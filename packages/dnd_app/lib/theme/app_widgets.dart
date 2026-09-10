import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../ui/portrait_image.dart';
import 'app_theme.dart';

enum AppMessageTone { info, success, error }

void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageTone tone = AppMessageTone.info,
  Duration? duration,
}) {
  final scheme = Theme.of(context).colorScheme;
  final (icon, color) = switch (tone) {
    AppMessageTone.info => (Icons.info_outline, scheme.primary),
    AppMessageTone.success => (Icons.check_circle_outline, Colors.green),
    AppMessageTone.error => (Icons.error_outline, scheme.error),
  };
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration:
            duration ??
            (tone == AppMessageTone.error
                ? const Duration(seconds: 6)
                : const Duration(seconds: 3)),
        content: Semantics(
          liveRegion: true,
          label: message,
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
}

Widget appNavItem(
  BuildContext context, {
  required IconData icon,
  required String label,
  bool active = false,
  VoidCallback? onTap,

  /// Cifra al final de la fila (cuántas entradas tiene esa sección).
  ///
  /// Va en cifras tabulares porque los ítems se apilan: sin ancho fijo de
  /// dígito, la columna de números queda dentada y deja de leerse como una
  /// columna.
  String? count,
}) {
  final palette = context.palette;
  final foreground = active
      ? palette.gold
      : Theme.of(context).colorScheme.onSurfaceVariant;
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: active ? palette.goldSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        hoverColor: palette.plaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: foreground,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: active ? palette.gold : palette.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Preferencias de presentación del pie del panel lateral: idioma y tema.
///
/// Van juntas porque son lo mismo —cómo se ve y en qué se lee la aplicación—
/// y porque separadas cada una parecería un ajuste suelto entre las secciones
/// de navegación.
class DisplayPreferences extends StatelessWidget {
  final AppThemeController controller;
  const DisplayPreferences({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LanguageSelector(),
      const SizedBox(height: 8),
      ThemeModeSelector(controller: controller),
    ],
  );
}

/// Selector de idioma.
///
/// Está deshabilitado a propósito: la aplicación existe solo en español y no
/// hay traducción que ofrecer todavía. Se muestra igual —y no se esconde—
/// porque deja ver que el idioma es una preferencia prevista y no una
/// imposición, y porque el día que haya una segunda no cambia el layout del
/// panel. El tooltip dice por qué no se puede tocar, que es lo que un control
/// gris sin explicación no dice.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: 'Por ahora la aplicación está solo en español.',
      child: Semantics(
        label: 'Idioma: Español. Todavía no hay otros idiomas disponibles.',
        excludeSemantics: true,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.language, size: 16, color: muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Español',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 16, color: pal.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tema activo, como grupo de tres.
///
/// Grupo y no menú desplegable: son tres opciones excluyentes con un ícono
/// cada una, así que mostrarlas todas dice cuál está activa **y** qué otras
/// hay, sin abrir nada. Un menú obligaba a abrirlo para descubrir que existía
/// «Sistema». De paso, cada segmento es un objetivo táctil de 48 px, que el
/// botón anterior no alcanzaba.
class ThemeModeSelector extends StatelessWidget {
  final AppThemeController controller;
  const ThemeModeSelector({super.key, required this.controller});

  /// El orden es claro → sistema → oscuro: «Sistema» va al medio porque es el
  /// punto intermedio entre los otros dos, no una tercera opción suelta.
  static const _segments = [
    (
      mode: ThemeMode.light,
      icon: Icons.light_mode_outlined,
      label: 'Tema claro',
    ),
    (
      mode: ThemeMode.system,
      icon: Icons.desktop_windows_outlined,
      label: 'Seguir el tema del sistema',
    ),
    (
      mode: ThemeMode.dark,
      icon: Icons.dark_mode_outlined,
      label: 'Tema oscuro',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => SegmentedButton<ThemeMode>(
        segments: [
          for (final segment in _segments)
            ButtonSegment(
              value: segment.mode,
              icon: Icon(segment.icon, size: 18),
              // Sin esto los tres botones no tienen nombre: son solo íconos.
              tooltip: segment.label,
            ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => controller.choose(selection.first),
        // El tilde de seleccionado desplazaría el ícono que identifica cada
        // segmento; el fondo dorado ya marca cuál está activo.
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedBackgroundColor: pal.goldSoft,
          selectedForegroundColor: pal.gold,
          side: BorderSide(color: pal.hairline),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class AppBusyLabel extends StatelessWidget {
  final String label;
  final double indicatorSize;

  const AppBusyLabel(this.label, {super.key, this.indicatorSize = 18});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: indicatorSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

/// Pantalla de fallo: qué pasó, qué se puede hacer, y el detalle técnico
/// detrás de «Ver detalles».
///
/// El texto crudo de una excepción no le dice a nadie qué hacer, pero
/// esconderlo del todo deja sin nada que reportar cuando el problema no cede:
/// va plegado, no borrado.
class AppErrorView extends StatelessWidget {
  final IconData icon;

  /// Qué pasó, en castellano y sin jerga. Se anuncia como región viva.
  final String message;

  /// Qué se puede hacer al respecto, si hay algo además de reintentar.
  final String? hint;

  /// El error tal cual. Null cuando no hay ninguno que mostrar (p.ej. una
  /// petición que falló sin excepción legible).
  final Object? details;

  /// Null si la operación no es recuperable reintentando.
  final VoidCallback? onRetry;

  const AppErrorView({
    super.key,
    this.icon = Icons.error_outline,
    required this.message,
    this.hint,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: scheme.error),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(message, textAlign: TextAlign.center),
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 12),
                Theme(
                  // El divisor propio del ExpansionTile parte la caja en dos
                  // aunque esté plegada, y acá no separa nada.
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      'Ver detalles',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SelectableText(
                        '$details',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío: por qué no hay nada y qué se puede hacer al respecto.
///
/// Separa «no hay datos» de «no hay coincidencias»: el primero pide crear o
/// importar algo, el segundo solo cambiar la búsqueda, y confundirlos deja al
/// usuario buscando un botón que no corresponde.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final List<Widget> actions;
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ayuda breve, del ancho de su contenedor, para explicar un concepto justo
/// donde hay que decidir algo. Informa y nada más: no pide una acción, no es un
/// error y no se cierra.
///
/// Es el `_ManualHint` del paso de puntuaciones, que ya era esto mismo escrito
/// a mano. A propósito **no** trae botón de «Más información» ni diálogo de
/// detalle: mientras ninguna pantalla los pida son maquinaria sin uso, y una
/// ayuda que ocupa cuatro renglones no los necesita.
///
/// Va en `surface` con filete y sin sombra, como el resto: es una superficie
/// más del mismo nivel, no una tarjeta elevada de tutorial.
class AppHelpCallout extends StatelessWidget {
  /// Encabeza la ayuda cuando el concepto tiene nombre («Competencias»). Sin
  /// título el cuerpo arranca solo, que alcanza para una frase sola.
  final String? title;
  final String message;
  final IconData icon;
  const AppHelpCallout({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sin `semanticLabel`: el ícono acompaña al texto, que es el que
          // dice todo. Nombrarlo solo agrega «información» antes de cada ayuda.
          Icon(icon, size: 19, color: pal.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: pal.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuerpo de página centrado con ancho máximo, para que el contenido no se
/// estire de borde a borde en ventanas anchas de escritorio.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ListView(padding: padding, children: children),
    ),
  );
}

/// Una celda de la barra de acciones de [AppDialog].
///
/// [primary] es el verbo de la acción: va en negrita y, si no se le pasa color,
/// en oro. El resto de las celdas se leen como alternativas.
///
/// [keyHint] dibuja la tecla que dispara la celda, y **se pone solo cuando es
/// cierto**: `Esc` lo es siempre que el diálogo se abra con el
/// `barrierDismissible: true` de fábrica, porque de eso se encarga la ruta
/// modal; `↵` solo donde alguien lo ató (hoy, el campo de una línea de
/// [showTextPromptDialog]).
class DialogAction {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool primary;
  final String? keyHint;

  const DialogAction(
    this.label, {
    required this.onPressed,
    this.color,
    this.primary = false,
    this.keyHint,
  });
}

/// El molde de diálogo de la aplicación.
///
/// Es la placa del sistema —el filete y el radio los pone `dialogTheme`— con
/// dos decisiones que un tema no puede tomar:
///
/// 1. **La medida de lectura.** Sin tope, un `AlertDialog` con un párrafo largo
///    se estira hasta el ancho de la ventana y la línea se vuelve ilegible.
///    Los 480 px por defecto dan unos 66 caracteres.
/// 2. **La barra de acciones a lo ancho.** Celdas de 48 px sobre `plaque`,
///    separadas por filete, que llegan al borde del diálogo. Es lo que lo
///    distingue de una tarjeta cualquiera y lo que le da blancos táctiles del
///    mínimo de Material (§11.3) sin ocupar más alto.
///
/// El cuerpo scrollea solo y el pie queda fijo, así que sirve igual para tres
/// líneas que para el detalle de un conjuro.
///
/// [scrollable] en `false` para un cuerpo que ya resuelve su propio alto —una
/// lista con buscador, una columna con `Expanded`—: dos scrolls del mismo eje
/// uno adentro del otro dejan el de adentro sin alto y revientan en tiempo de
/// dibujo.
class AppDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;

  /// Lo que va al final de la línea del título, hoy siempre una `GoldPill` con
  /// el cupo (`2/3`). No es para acciones: el pie es el único lugar donde el
  /// diálogo ofrece algo que tocar.
  final Widget? titleTrailing;

  final Widget content;
  final List<DialogAction> actions;
  final double width;
  final bool scrollable;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor,
    this.titleTrailing,
    this.width = 480,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final dialogTheme = theme.dialogTheme;
    return Dialog(
      // El pie llega al borde: sin recorte se le escapan las esquinas del radio.
      clipBehavior: Clip.antiAlias,
      // `LayoutBuilder` y no `MediaQuery`: lo que hay que medir es lo que el
      // `Dialog` deja libre después de su margen, no la ventana.
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: width < constraints.maxWidth ? width : constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 17, color: iconColor ?? pal.gold),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: dialogTheme.titleTextStyle,
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 8),
                            titleTrailing!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: DefaultTextStyle(
                          style:
                              dialogTheme.contentTextStyle ??
                              theme.textTheme.bodyMedium!,
                          child: scrollable
                              ? SingleChildScrollView(child: content)
                              : content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _DialogActionBar(actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionBar extends StatelessWidget {
  final List<DialogAction> actions;

  const _DialogActionBar(this.actions);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final cells = <Widget>[];
    for (final action in actions) {
      if (cells.isNotEmpty) cells.add(Container(width: 1, color: pal.hairline));
      cells.add(Expanded(child: _cell(context, action)));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.hairline)),
      ),
      child: Material(
        color: pal.plaque,
        child: SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, DialogAction action) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final color =
        action.color ?? (action.primary ? pal.gold : scheme.onSurfaceVariant);
    return InkWell(
      onTap: action.onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          // Las celdas reparten el ancho en partes iguales, así que un rótulo
          // largo en un diálogo angosto se achica en vez de desbordar.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.keyHint != null) ...[
                  _KeyCap(action.keyHint!),
                  const SizedBox(width: 8),
                ],
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: action.primary
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: 0.1,
                    color: action.onPressed == null
                        ? color.withValues(alpha: 0.38)
                        : color,
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

/// La tecla dibujada al lado de un rótulo. Se lee por el filete: el relleno es
/// el mismo `plaque` de la barra a propósito, para que no compita con el texto.
class _KeyCap extends StatelessWidget {
  final String label;

  const _KeyCap(this.label);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, height: 1, color: pal.textMuted),
      ),
    );
  }
}

/// Diálogo de un solo campo de texto. Devuelve el valor recortado, o null si se
/// canceló o quedó vacío.
///
/// [allowEmpty] deja devolver la cadena vacía, que es lo que hace falta para
/// **borrar** un dato opcional (la nota de un objeto) en vez de dejarlo como
/// estaba.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String current = '',
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  bool allowEmpty = false,
  int maxLines = 1,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => _TextPromptDialog(
      title: title,
      label: label,
      current: current,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
    ),
  );
  if (result == null) return null;
  final trimmed = result.trim();
  return trimmed.isEmpty && !allowEmpty ? null : trimmed;
}

/// El diálogo es un widget con estado propio y no un `AlertDialog` armado en
/// línea porque el controlador tiene que vivir exactamente lo que vive el
/// campo. Liberarlo apenas vuelve `showDialog` lo mata mientras la ruta todavía
/// se está cerrando, y el `TextField` se reconstruye con un controlador ya
/// liberado.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String current;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.current,
    required this.keyboardType,
    required this.textCapitalization,
    required this.maxLines,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _ctrl = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    width: 420,
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      // Con varias líneas, Enter escribe un salto en vez de confirmar.
      onSubmitted: widget.maxLines == 1
          ? (v) => Navigator.pop(context, v)
          : null,
    ),
    actions: [
      DialogAction(
        'Cancelar',
        keyHint: 'Esc',
        onPressed: () => Navigator.pop(context),
      ),
      DialogAction(
        'Guardar',
        primary: true,
        // La tecla se dibuja solo donde el campo la ata de verdad.
        keyHint: widget.maxLines == 1 ? '↵' : null,
        onPressed: () => Navigator.pop(context, _ctrl.text),
      ),
    ],
  );
}

/// Diálogo para renombrar un personaje. Devuelve el nombre nuevo (recortado) o
/// null si se canceló o quedó vacío. Compartido entre la ficha y el dashboard.
Future<String?> showRenameDialog(BuildContext context, String current) =>
    showTextPromptDialog(
      context,
      title: 'Editar nombre',
      label: 'Nombre del personaje',
      current: current,
      textCapitalization: TextCapitalization.words,
    );

/// Rótulo tipo "eyebrow": mayúsculas, espaciado, apagado.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w500,
        color: context.palette.textMuted,
      ),
    ),
  );
}

/// Regla ornamental: línea dorada tenue con un rombo central.
class SectionRule extends StatelessWidget {
  const SectionRule({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line() => Expanded(child: Container(height: 1, color: p.hairline));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 7, height: 7, color: p.gold),
            ),
          ),
          line(),
        ],
      ),
    );
  }
}

/// Placa de estadística: rótulo + valor grande en serif.
class StatPlaque extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? footer;

  /// Variante compacta, para tarjetas densas (las cajas VEL/INIC del dashboard).
  final bool dense;

  /// Lo que lee un lector de pantalla, cuando «$label: $value» no se entiende
  /// dicho en voz alta: el rótulo puede venir abreviado («CA») y a veces el
  /// valor también («STR»). Mismo parámetro que ya tiene `_StatCell` en el
  /// dashboard; acá es opcional porque muchas placas ya se rotulan enteras.
  final String? semantics;
  const StatPlaque({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.footer,
    this.dense = false,
    this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: semantics ?? '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: p.plaque,
          borderRadius: BorderRadius.circular(dense ? 9 : 12),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dense ? 8.5 : 10,
                letterSpacing: dense ? 0.5 : 1.2,
                color: p.textMuted,
              ),
            ),
            SizedBox(height: dense ? 2 : 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: dense ? 16 : 24,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: valueColor ?? p.gold,
              ),
            ),
            if (footer != null) ...[SizedBox(height: dense ? 4 : 8), footer!],
          ],
        ),
      ),
    );
  }
}

/// Placa de la banda táctica de la ficha: rótulo con ícono arriba y la cifra
/// grande debajo, alineadas a la izquierda.
///
/// Convive con [StatPlaque] en vez de reemplazarla: la placa centrada en
/// Georgia sigue siendo la de las tiras cortas dentro de una tarjeta (carga,
/// sintonizados, CD de salvación). Esta es la de la banda que encabeza la
/// ficha, donde el rótulo puede llevar ícono y la cifra una unidad, y donde la
/// sans en negrita con cifras tabulares se lee mejor de un vistazo que el
/// serif: son números que se comparan entre placas, no títulos.
class StatTile extends StatelessWidget {
  final IconData? icon;
  final String label;

  /// Dato accesorio al final del rótulo (el porcentaje de PG). Va del otro
  /// lado de la fila, no pegado al rótulo, para que no se lea como parte de él.
  final String? labelTrailing;
  final String value;

  /// Lo que acompaña a la cifra en cuerpo chico y atenuado (« pies», «/ 29»).
  final String? suffix;
  final Color? valueColor;
  final Widget? footer;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.labelTrailing,
    this.suffix,
    this.valueColor,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$label: $value${suffix ?? ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: p.plaque,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: p.gold),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      color: p.textMuted,
                    ),
                  ),
                ),
                if (labelTrailing != null)
                  Text(
                    labelTrailing!,
                    style: TextStyle(
                      fontSize: 11,
                      color: p.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (suffix != null)
                    TextSpan(
                      text: suffix,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: p.textMuted,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

/// Barra fina (para PG dentro de una placa).
class ThinBar extends StatelessWidget {
  final double ratio;
  final Color color;
  final Color track;
  const ThinBar({
    super.key,
    required this.ratio,
    required this.color,
    required this.track,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    // La barra recorre el tramo en vez de saltar: al aplicar daño o curación,
    // ver de dónde a dónde fue es lo que hace legible el golpe. El número de
    // al lado ya está en su valor final desde el primer cuadro, así que la
    // información no depende de la animación. Sin `begin`, el primer dibujo no
    // anima: montar la ficha no llena las barras desde cero.
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: ratio.clamp(0.0, 1.0)),
      duration: context.motion(const Duration(milliseconds: 220)),
      curve: Curves.easeOut,
      builder: (context, value, _) => LinearProgressIndicator(
        value: value,
        minHeight: 5,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    ),
  );
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height * .62)
    ..lineTo(s.width * .5, s.height)
    ..lineTo(0, s.height * .62)
    ..lineTo(0, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// La CA dentro de una silueta de escudo con borde dorado.
class ShieldBadge extends StatelessWidget {
  final String value;

  /// Alto del escudo. El ancho y el número acompañan en proporción, para que
  /// el escudo no se deforme ni el número se salga del recorte.
  final double height;
  const ShieldBadge(this.value, {super.key, this.height = 52});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final k = height / 52;
    return Semantics(
      label: 'Clase de armadura: $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 46 * k,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipPath(
              clipper: _ShieldClipper(),
              child: Container(color: p.gold),
            ),
            Padding(
              padding: const EdgeInsets.all(1.5),
              child: ClipPath(
                clipper: _ShieldClipper(),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8 * k),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20 * k,
                        color: p.gold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plaqueta de característica: **el modificador es la cifra principal** y la
/// puntuación queda como dato de apoyo.
///
/// Al revés de como estaba. El número que se tira es el modificador; la
/// puntuación solo sirve para explicar de dónde sale y para los pocos rasgos
/// que la miran. Dejarla grande obligaba a hacer la cuenta mental en cada
/// tirada.
///
/// La salvación competente se **nombra** («SALV») en vez de insinuarse con un
/// punto en la esquina: un pip sin rótulo no dice qué marca, y el color solo no
/// alcanza. La altura de la plaqueta no depende de eso, así que las seis se
/// alinean tenga o no salvación cada una.
class AbilityPlaque extends StatelessWidget {
  /// La característica entera y no su abreviatura: la placa muestra «DES» pero
  /// el lector de pantalla tiene que decir «Destreza», y separarlo en dos
  /// parámetros deja que se contradigan.
  final Ability ability;
  final int score;
  final int modifier;
  final bool saveProficient;
  const AbilityPlaque({
    super.key,
    required this.ability,
    required this.score,
    required this.modifier,
    required this.saveProficient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mod = modifier >= 0 ? '+$modifier' : '$modifier';
    final abbr = ability.abbr;
    return Semantics(
      label:
          '${ability.label}: modificador $mod, puntuación $score'
          '${saveProficient ? ', competente en salvación' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
        decoration: BoxDecoration(
          color: p.plaque,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              abbr,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              mod,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Punt. $score',
              style: TextStyle(
                fontSize: 11,
                color: p.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            // Reserva el alto de la marca de salvación aunque no la haya: sin
            // esto las seis plaquetas quedan a distinta altura según quién sea
            // competente, que es ruido y no información.
            SizedBox(
              height: 13,
              child: saveProficient
                  // El escudo y las cuatro letras piden unos 52 px. Quien
                  // dispone la fila de plaquetas se encarga de que los haya,
                  // pero un ancho justo no puede desbordar: acá se achica.
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield, size: 9, color: p.gold),
                          const SizedBox(width: 3),
                          Text(
                            'SALV',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                              color: p.gold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Medallón de retrato: círculo con aro dorado. Muestra el retrato de
/// [portraitKey] o, si no hay, [fallback].
class Medallion extends StatelessWidget {
  /// Clave opaca del retrato (`Character.portraitPaths`), no una imagen ya
  /// resuelta: es este widget el que conoce el tamaño final en píxeles y por
  /// eso el único que puede pedir la miniatura del tamaño correcto (ver
  /// [PortraitImage.provider]).
  final String? portraitKey;
  final String fallback;
  final double size;

  /// Emblema para cuando no hay retrato: un ícono sobre un degradado de
  /// [emblemColor]. Si no se pasa, se cae a la inicial de [fallback].
  final IconData? emblemIcon;
  final Color? emblemColor;

  /// URL base (sin `?w=`) que reemplaza a [PortraitImage.urlFor] cuando el
  /// retrato no es de la propia cuenta — ver [PortraitImage.urlForMember].
  final String? portraitUrlBase;

  const Medallion({
    super.key,
    this.portraitKey,
    required this.fallback,
    this.size = 74,
    this.emblemIcon,
    this.emblemColor,
    this.portraitUrlBase,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasEmblem = portraitKey == null && emblemIcon != null;
    final accent = emblemColor ?? p.gold;

    // Los retratos se generan a 768 o 1024 px de lado (ver `portrait_provider`)
    // y este círculo mide menos de 100: dibujarlos
    // tal cual obliga a reducirlos unas diez veces en cada píxel, y no hay
    // calidad de filtro que lo salve. Con `low` el resultado sale dentado; con
    // `medium`, lavado. Son dos caras de lo mismo.
    //
    // La reducción hay que hacerla **una vez y bien**, y eso acá no se puede.
    // `ResizeImage` —que es lo que había antes— se lo encarga al decodificador,
    // pero la implementación web de `NetworkImage` no admite decodificar a un
    // tamaño dado (lo dice su documentación en el propio SDK) y el navegador es
    // la única plataforma que se publica: ese envoltorio no hacía nada. Se pide
    // la miniatura al servidor, que remuestrea por promedio de área y la
    // guarda; el navegador recibe algo del tamaño en que se va a dibujar.
    //
    // Se pide en píxeles físicos, redondeando al peldaño de arriba de la
    // escalera de anchos. El sobrante es como mucho un tercio, un reajuste
    // chico que `FilterQuality.medium` resuelve sin velo.
    //
    // El caso que esto no cubre es una imagen más ancha que alta: `BoxFit.cover`
    // recorta por el lado corto, así que ahí el alto queda por debajo del
    // círculo y se agranda un poco. Los retratos generados son cuadrados (768 o
    // 1024 de lado) y los subidos suelen ser verticales, así que es el caso
    // raro. Si aparece, la salida es recortar del lado del servidor, no pedir
    // de más acá.
    final key = portraitKey;
    final width = PortraitImage.thumbnailWidthFor(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );
    final base = portraitUrlBase;
    final source = key == null
        ? null
        : NetworkImage(
            base != null
                ? (width == null ? base : '$base?w=$width')
                : PortraitImage.urlFor(key, width: width),
          );

    return Semantics(
      image: true,
      label: key == null ? 'Emblema de $fallback' : 'Retrato de $fallback',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasEmblem ? null : p.plaque,
          gradient: hasEmblem
              ? RadialGradient(colors: [accent.withAlpha(70), p.plaque])
              : null,
          border: Border.all(color: hasEmblem ? accent : p.gold, width: 2),
          image: source == null
              ? null
              : DecorationImage(
                  image: source,
                  fit: BoxFit.cover,
                  // Ya decodificado cerca del tamaño final, acá queda un ajuste
                  // chico y `medium` alcanza.
                  filterQuality: FilterQuality.medium,
                  // El retrato viene de una petición de red (`PortraitImage`):
                  // un 404 (clave borrada) no debe tirar un error sin manejar,
                  // solo dejar el medallón sin imagen.
                  onError: (_, _) {},
                ),
        ),
        alignment: Alignment.center,
        child: key != null
            ? null
            : hasEmblem
            ? Icon(emblemIcon, size: size * .48, color: accent)
            : Text(
                fallback,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: size * .42,
                  color: p.gold,
                ),
              ),
      ),
    );
  }
}

/// Contenedor de filas densas con separadores (en vez de tarjetas sueltas).
class DenseRows extends StatelessWidget {
  final List<Widget> children;
  const DenseRows({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Multiselección de opciones con tope, mediante chips. Compartida por el
/// wizard de creación (habilidades, conjuros) y el editor de conjuros.
///
/// [disabled] marca opciones no seleccionables (p.ej. una habilidad ya tomada
/// por otro origen). Al alcanzar [max], las no seleccionadas quedan deshabilitadas.
class CappedChipSelect extends StatelessWidget {
  final Map<String, String> options; // id -> etiqueta
  final Set<String> selected;
  final int max;
  final VoidCallback onChanged;
  final Set<String> disabled;

  /// Abre el detalle de una opción sin elegirla. Existe para los conjuros: un
  /// nombre como «Rayo de Escarcha» no dice qué hace, y hasta ahora la única
  /// forma de averiguarlo era buscarlo afuera de la aplicación.
  ///
  /// Opcional porque no toda opción tiene detalle que mostrar: una competencia
  /// o un idioma se explican con su nombre.
  final ValueChanged<String>? onInfo;
  const CappedChipSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.max,
    required this.onChanged,
    this.disabled = const {},
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isSel = selected.contains(e.key);
        final blocked =
            (disabled.contains(e.key) || selected.length >= max) && !isSel;
        final info = onInfo;
        final chip = FilterChip(
          label: Text(e.value),
          selected: isSel,
          onSelected: blocked
              ? null
              : (v) {
                  if (v) {
                    if (selected.length >= max) return;
                    selected.add(e.key);
                  } else {
                    selected.remove(e.key);
                  }
                  onChanged();
                },
        );
        if (info == null) return chip;
        // El botón va **al lado** del chip y no adentro: `FilterChip` se queda
        // con todos los toques de su superficie —un `InkWell` en el rótulo no
        // llega a recibirlos—, y además dos blancos separados se ven como dos
        // cosas distintas, que es lo que son.
        //
        // Sigue vivo con el cupo lleno a propósito: es justo cuando más falta
        // poder mirar qué hace lo que todavía no elegiste.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            IconButton(
              onPressed: () => info(e.key),
              icon: const Icon(Icons.info_outline, size: 17),
              color: context.palette.textMuted,
              tooltip: 'Ver qué hace ${e.value}',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Tira de "pips" que muestra usos restantes sobre un máximo (recursos de clase,
/// espacios de conjuro). Los llenos van en oro; los gastados, atenuados.
class UsagePips extends StatelessWidget {
  final int max;
  final int filled;
  final IconData filledIcon;
  final IconData emptyIcon;
  final double size;
  const UsagePips({
    super.key,
    required this.max,
    required this.filled,
    required this.filledIcon,
    required this.emptyIcon,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      label: '$filled de $max usos disponibles',
      excludeSemantics: true,
      child: Wrap(
        children: List.generate(
          max,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < filled ? filledIcon : emptyIcon,
              size: size,
              color: i < filled ? pal.gold : pal.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Par de botones para gastar (–) y restaurar (+) un uso. `onSpend`/`onRecover`
/// nulos deshabilitan el botón correspondiente.
class SpendRecoverButtons extends StatelessWidget {
  final VoidCallback? onSpend;
  final VoidCallback? onRecover;
  final String spendTooltip;
  final String recoverTooltip;
  const SpendRecoverButtons({
    super.key,
    required this.onSpend,
    required this.onRecover,
    this.spendTooltip = 'Usar',
    this.recoverTooltip = 'Restaurar',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: spendTooltip,
          onPressed: onSpend,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          tooltip: recoverTooltip,
          onPressed: onRecover,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

/// Pill dorada suave.
class GoldPill extends StatelessWidget {
  final String text;

  /// En `false` usa un tono neutro en vez del dorado, para información
  /// secundaria que no debe competir con el contenido principal.
  final bool highlighted;
  const GoldPill(this.text, {super.key, this.highlighted = true});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? p.goldSoft : p.plaque,
        border: Border.all(color: p.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        // Una pill es de una línea por definición: un trasfondo largo se
        // recorta en vez de desbordar la tarjeta que la contiene.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: highlighted ? p.gold : p.textMuted,
        ),
      ),
    );
  }
}

/// Etiqueta visible de la procedencia de una opción del catálogo.
///
/// La distinción SRD / PHB no es cosmética: solo el contenido del SRD 5.2.1
/// está cubierto por la atribución CC BY 4.0. Y *Forge of the Artificer* es una
/// expansión aparte, que conviene reconocer antes de comprometer un personaje
/// con una de sus opciones.
///
/// Los dos SRD llevan **su número de versión y no su año**, porque "SRD" a
/// secas no dice cuál de los dos es y son ediciones distintas: 5.2.1 es el de
/// las reglas 2024, con las que juega la mesa, y 5.1 el de 2014. Que un rasgo
/// venga de uno o del otro cambia la regla, no solo la licencia.
String sourceLabel(ContentSource source) => switch (source) {
  ContentSource.srd2024 => 'SRD 5.2.1',
  ContentSource.phb2024 => 'PHB 2024',
  ContentSource.foa2025 => 'Forge 2025',
  ContentSource.srd2014 => 'SRD 5.1',
  ContentSource.homebrew => 'Propio',
};

/// Resumen legible de una dote. `Feat` no tiene descripción propia: lo que se
/// muestra sale de sus rasgos pasivos, y si no tiene ninguno, queda vacío.
///
/// Vive acá, y no en una pantalla, porque lo usan tanto el paso de dotes de la
/// creación como el selector de dote de la subida de nivel.
String featSummary(Feat feat) {
  final traits = feat.effects.whereType<PassiveTraitEffect>();
  if (traits.isEmpty) return '';
  return traits
      .map((t) => t.description.isEmpty ? t.name : t.description)
      .join(' ');
}

/// Detalle completo de una dote, para donde el resumen va recortado.
///
/// Separa los rasgos en vez de pegarlos como hace [featSummary]: ahí se unen
/// con un espacio y dos rasgos distintos terminan leyéndose como un párrafo
/// solo. Suma los aumentos de característica, que en las dotes de origen son
/// parte de la decisión y no aparecen en ningún rasgo.
///
/// No enumera el resto de los efectos —listas de conjuros, competencias,
/// recursos—: son maquinaria del motor y su consecuencia visible ya está
/// contada en el rasgo que la acompaña.
void showFeatDetailsDialog(BuildContext context, Feat feat) {
  final traits = feat.effects.whereType<PassiveTraitEffect>().toList();
  final bonuses = feat.effects.whereType<AbilityScoreBonusEffect>().toList();
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final muted = Theme.of(dialogContext).colorScheme.onSurfaceVariant;
      return AppDialog(
        title: feat.name,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final bonus in bonuses) ...[
              Text(
                '${bonus.ability.label} '
                '${bonus.amount >= 0 ? '+' : ''}${bonus.amount}',
                style: TextStyle(color: context.palette.gold),
              ),
              const SizedBox(height: 10),
            ],
            for (var i = 0; i < traits.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              if (traits[i].name.isNotEmpty) ...[
                Text(
                  traits[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                traits[i].description,
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          ],
        ),
        actions: [
          DialogAction(
            'Cerrar',
            keyHint: 'Esc',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

/// Ícono y color de un tipo de acción. Verde = acción, rojo = adicional,
/// ámbar = reacción; lo que tarda minutos u horas no lleva distintivo porque no
/// compite por la economía del turno.
///
/// Vive acá porque lo usan tanto la ficha como el selector de conjuros, y
/// porque el par ícono/color tiene que ser el mismo en los dos lados o la
/// leyenda deja de significar algo.
///
/// Los tres salen de Font Awesome y no de Material a propósito: Material no
/// tiene con qué representar "acción principal" (la espada es de FA Pro), y
/// mezclar familias en tres íconos que se leen juntos se nota. `handFist` es el
/// reemplazo de la espada.
({FaIconData icon, Color color, String label})? actionTypeBadge(
  SpellActionType type,
  AppPalette palette,
) => switch (type) {
  SpellActionType.action => (
    icon: FontAwesomeIcons.handFist,
    color: palette.verdant,
    label: 'Acción',
  ),
  SpellActionType.bonusAction => (
    icon: FontAwesomeIcons.circlePlus,
    color: palette.crimson,
    label: 'Acción adicional',
  ),
  SpellActionType.reaction => (
    icon: FontAwesomeIcons.bolt,
    color: palette.gold,
    label: 'Reacción',
  ),
  SpellActionType.longer => null,
};

/// Distintivo de tipo de acción para una fila de conjuro.
///
/// El `Tooltip` no es adorno: en el celular el color solo no alcanza (y con
/// daltonismo, menos), así que mantener el nombre a un toque largo es lo que
/// hace que el ícono sea legible sin memorizar la leyenda.
class ActionTypeIcon extends StatelessWidget {
  final SpellActionType type;
  final double size;
  const ActionTypeIcon(this.type, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final badge = actionTypeBadge(type, context.palette);
    if (badge == null) return const SizedBox.shrink();
    return Tooltip(
      message: badge.label,
      child: FaIcon(
        badge.icon,
        size: size,
        color: badge.color,
        semanticLabel: badge.label,
      ),
    );
  }
}

/// Leyenda de los tres íconos. Sin esto el color es adivinanza la primera vez.
class ActionTypeLegend extends StatelessWidget {
  const ActionTypeLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final type in [
          SpellActionType.action,
          SpellActionType.bonusAction,
          SpellActionType.reaction,
        ])
          if (actionTypeBadge(type, pal) case final badge?)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(badge.icon, size: 13, color: badge.color),
                const SizedBox(width: 4),
                Text(
                  badge.label,
                  style: TextStyle(fontSize: 11, color: pal.textMuted),
                ),
              ],
            ),
      ],
    );
  }
}

/// Abre el mismo detalle de conjuro desde la ficha o desde una criatura.
void showSpellDetailsDialog(
  BuildContext context,
  Spell spell, {
  String contextTitle = '',
  String contextText = '',
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: spell.name,
      // Más ancho que el molde por defecto: acá no hay un párrafo sino una
      // ficha con placas rotuladas, y a 480 se apilan de a una.
      width: 560,
      content: spellDetailsBody(
        dialogContext,
        spell,
        contextTitle: contextTitle,
        contextText: contextText,
      ),
      actions: [
        DialogAction(
          'Cerrar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

Widget spellDetailsBody(
  BuildContext context,
  Spell spell, {
  String contextTitle = '',
  String contextText = '',
}) {
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${spell.isCantrip ? "Truco" : "Nivel ${spell.level}"} · ${spell.school}',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (spell.actionType != SpellActionType.longer) ...[
            ActionTypeIcon(spell.actionType, size: 15),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: _spellDetailMeta(context, 'Lanzamiento', spell.castingTime),
          ),
        ],
      ),
      _spellDetailMeta(context, 'Alcance', spell.range),
      _spellDetailMeta(context, 'Componentes', spell.components),
      _spellDetailMeta(context, 'Duración', spell.duration),
      const SizedBox(height: 10),
      Text(spell.description),
      if (contextText.isNotEmpty) ...[
        const SizedBox(height: 14),
        Eyebrow(contextTitle),
        Text(contextText, style: TextStyle(fontSize: 12, color: muted)),
      ],
    ],
  );
}

Widget _spellDetailMeta(BuildContext context, String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

/// Una acción de criatura: nombre, daño, alcance y bono de ataque.
///
/// Vive acá y no en la ficha porque la pintan dos pantallas: los compañeros
/// invocados en `combat_section.dart` y los perfiles del Bestiario. Cuando
/// estaba escrita adentro de la ficha, la segunda copia habría quedado libre de
/// divergir de la primera.
///
/// Recibe primitivos y no un tipo del motor a propósito: los dos llamadores
/// tienen tipos distintos —la ficha resuelve las fórmulas contra el personaje
/// y trae `int`, el Bestiario lee el perfil crudo y trae `String`— y un tipo
/// común para dos campos sería una abstracción con una sola forma real.
class CreatureActionRow extends StatelessWidget {
  final String name;
  final String description;

  /// Ya con signo ("+7"), o null si la acción no es un ataque.
  final String? attackBonus;
  final String? damage;

  /// Id de [DamageType]; la fila lo traduce.
  final String? damageType;
  final String reach;

  /// Píldora al lado del daño ("Reacción", "Recarga 5-6").
  final String? tag;

  const CreatureActionRow({
    super.key,
    required this.name,
    this.description = '',
    this.attackBonus,
    this.damage,
    this.damageType,
    this.reach = '',
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final damageText = [
      ?damage,
      if (damageType != null) DamageType.labelFor(damageType!),
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (damageText.isNotEmpty)
                      Text(
                        damageText,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    if (reach.isNotEmpty)
                      Text(reach, style: TextStyle(color: muted, fontSize: 13)),
                    if (tag != null) GoldPill(tag!),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          if (attackBonus != null)
            Text(
              attackBonus!,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                color: context.palette.gold,
              ),
            ),
        ],
      ),
    );
  }
}

/// El valor de desafío se guarda como número para poder compararlo, pero se
/// imprime como lo escribe el libro: los fraccionarios con barra y el resto
/// como entero.
String challengeRatingLabel(num cr) {
  if (cr == 0.125) return '1/8';
  if (cr == 0.25) return '1/4';
  if (cr == 0.5) return '1/2';
  return cr == cr.roundToDouble() ? '${cr.round()}' : '$cr';
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// El encabezado de las legendarias lleva el presupuesto por ronda, que es la
/// forma en que lo imprime el libro y el dato que el DM necesita ahí mismo.
String _actionSectionLabel(CreatureActionKind kind, Creature c) {
  if (kind != CreatureActionKind.legendary) {
    return switch (kind) {
      CreatureActionKind.action => 'Acciones',
      CreatureActionKind.bonus => 'Acciones adicionales',
      CreatureActionKind.reaction => 'Reacciones',
      _ => 'Acciones',
    };
  }
  final uses = c.legendaryActionsPerRound;
  return uses == null
      ? 'Acciones legendarias'
      : 'Acciones legendarias · $uses por ronda';
}

/// Ancho a partir del cual el perfil se dispone en bandas horizontales.
///
/// Por debajo se apila todo: es la columna «Del turno» de Combate, que mide
/// 300 px fijos, y el Bestiario en un teléfono. El corte lo decide el ancho
/// medido y no el llamador, porque **las dos** pantallas pueden ser angostas y
/// antes sólo una lo declaraba.
const double _profileWideWidth = 520;

/// Medida de lectura de la prosa del perfil.
///
/// El panel del Bestiario mide unos 855 px, y sin tope la descripción de un
/// rasgo ocupaba la línea entera: más del doble de lo que se lee cómodo.
const double _profileProseWidth = 620;

/// Acota la prosa a [_profileProseWidth] sin centrarla.
Widget _prose(Widget child) => Align(
  alignment: Alignment.centerLeft,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _profileProseWidth),
    child: child,
  ),
);

/// Rótulo en versalita de las bandas del perfil.
Widget _profileLabel(BuildContext context, String text, {TextAlign? align}) =>
    Text(
      text.toUpperCase(),
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w500,
        color: context.palette.textMuted,
      ),
    );

/// Los sentidos sin la percepción pasiva, que arriba ya tiene su propia cifra.
///
/// El catálogo la escribe adentro de [Creature.senses] («…; Percepción pasiva
/// 12») y además la expone aparte, así que sin esto el perfil la dice dos
/// veces.
String _sensesWithoutPassive(Creature c) {
  if (c.passivePerceptionValue == null) return c.senses;
  return c.senses
      .replaceAll(RegExp(r'[;,]?\s*Percepción pasiva \d+'), '')
      .trim()
      .replaceAll(RegExp(r'[;,]$'), '')
      .trim();
}

/// Las defensas partidas en fragmentos, uno por chip.
///
/// ponytail: parte por «;» y muestra cada pedazo tal cual. **No** distingue una
/// resistencia de una inmunidad, que es lo que haría falta para pintarlas
/// distinto: eso pediría interpretar un texto libre que 367 criaturas escriben
/// de maneras distintas, y un parser que falla ensucia el perfil justo donde se
/// lo quería limpiar. Si algún día el catálogo separa resistencias, inmunidades
/// y condiciones en campos propios, acá se colorean sin tocar nada más.
List<String> _defenseFragments(String defenses) => [
  for (final part in defenses.split(';'))
    if (part.trim().isNotEmpty) part.trim(),
];

/// El perfil de una criatura del bloque de cifras para abajo: características,
/// datos de línea, atributos y acciones agrupadas por tipo.
///
/// Vive acá y no en el Bestiario porque lo leen **dos** pantallas: el
/// Bestiario, donde se consulta un monstruo, y Combate, donde el DM lee al que
/// tiene el turno sin salir de la mesa. Un segundo perfil escrito aparte se
/// habría desincronizado con el primero a la primera corrección de datos, que
/// en este catálogo pasa seguido.
///
/// Devuelve la lista de widgets y no un `Column` porque los dos llamadores lo
/// meten en un `ListView` propio, con su propio encabezado arriba: el nombre y
/// el tipo no van acá justamente porque cada pantalla los presenta distinto.
///
/// [dense] es la variante de columna angosta, y **saca CA y PG del bloque de
/// cifras**: en Combate esos dos los lleva el encuentro —los PG del monstruo
/// bajan a golpes— y repetir los del catálogo mostraría un máximo que ya no es
/// cierto.
List<Widget> creatureProfileBody(
  BuildContext context,
  ContentRepository repo,
  Creature c, {
  bool dense = false,
}) {
  // Un solo `LayoutBuilder` y no uno por banda: todas las piezas se apilan o se
  // acuestan juntas, y medir una vez evita que queden en desacuerdo.
  return [
    LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _profileWideWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _profileNumbers(context, c, dense: dense, wide: wide),
            const SizedBox(height: 18),
            _profileAbilities(context, c, wide: wide),
            const SizedBox(height: 18),
            _profileLines(context, c, wide: wide),
            ..._profileTraits(context, c),
            ..._profileActions(context, repo, c, wide: wide),
          ],
        );
      },
    ),
  ];
}

/// La banda de cifras: una sola placa partida en tramos, no una caja por dato.
///
/// Seis cajas sueltas pesaban lo mismo cada una, y no lo valen: la CA y los PG
/// se miran en cada ronda, la percepción pasiva casi nunca. Acá la jerarquía la
/// dan el color —los PG en carmesí, el desafío en oro— y el orden.
Widget _profileNumbers(
  BuildContext context,
  Creature c, {
  required bool dense,
  required bool wide,
}) {
  final pal = context.palette;
  // `semantics` solo donde el rótulo va abreviado por ancho: dicho en voz alta
  // «CA» no se entiende. Los demás ya se rotulan enteros y componen solos.
  final cells =
      <
        ({
          String label,
          String value,
          String? suffix,
          Color? color,
          String? semantics,
        })
      >[
        // En Combate la CA y los PG los lleva el encuentro, no el catálogo: el
        // máximo del libro deja de ser cierto en el primer golpe.
        if (!dense)
          (
            label: 'CA',
            value: c.ac,
            suffix: null,
            color: null,
            semantics: 'Clase de armadura: ${c.ac}',
          ),
        if (!dense)
          (
            label: 'Puntos de golpe',
            value: c.hp,
            suffix: wide ? c.hitDice : null,
            color: pal.crimson,
            semantics: null,
          ),
        // Tampoco la iniciativa: ahí ya está la tirada de esta mesa, que es la
        // que manda sobre el modificador impreso.
        if (!dense)
          (
            label: 'Iniciativa',
            value: _signed(c.initiativeModifier),
            suffix: null,
            color: null,
            semantics: null,
          ),
        if (c.cr != null)
          (
            label: 'Valor de desafío',
            value: challengeRatingLabel(c.cr!),
            suffix: null,
            color: pal.gold,
            semantics: null,
          ),
        if (c.passivePerceptionValue case final p?)
          (
            label: 'Perc. pasiva',
            value: '$p',
            suffix: null,
            color: null,
            semantics: 'Percepción pasiva: $p',
          ),
      ];
  if (cells.isEmpty) return const SizedBox.shrink();

  // La semántica va acá y no en cada layout: la banda ancha y la envuelta
  // arman la misma celda, y ponerla dos veces es dejar que se separen.
  Widget content(
    ({
      String label,
      String value,
      String? suffix,
      Color? color,
      String? semantics,
    })
    e,
  ) => Semantics(
    label:
        e.semantics ??
        '${e.label}: ${e.value}${e.suffix == null ? '' : ' ${e.suffix}'}',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _profileLabel(context, e.label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: e.color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (e.suffix != null) ...[
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  e.suffix!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  if (!wide) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in cells)
          SizedBox(
            width: 118,
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              decoration: BoxDecoration(
                color: pal.plaque,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pal.hairline),
              ),
              child: content(e),
            ),
          ),
      ],
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: pal.plaque,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: pal.hairline),
    ),
    // `IntrinsicHeight` y no `stretch` a secas: la banda vive adentro de una
    // lista que crece, y estirar al alto disponible pide alto infinito y rompe
    // la pasada de layout. Igualar al tramo más alto es lo que se quería, y es
    // lo que hace falta para que las divisiones lleguen de arriba abajo.
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: i == 0
                        ? BorderSide.none
                        : BorderSide(color: pal.hairline),
                  ),
                ),
                child: content(cells[i]),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Las seis características en una placa dividida, con la salvación adentro.
///
/// No reusa [AbilityPlaque] a propósito, y no es lo mismo con otra pinta: la de
/// la ficha marca **si** hay competencia, porque el número lo calcula el motor
/// y se lee en Salvaciones. Una criatura trae el modificador ya impreso, así
/// que acá se muestra el valor —«SALV +8»— y eso borra la fila «Salvaciones:
/// STR +8, INT +5…», que repetía lo mismo dos veces más abajo.
Widget _profileAbilities(
  BuildContext context,
  Creature c, {
  required bool wide,
}) {
  final pal = context.palette;

  Widget cell(Ability a, {required bool left, required bool top}) {
    final save = c.savingThrows[a];
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      decoration: BoxDecoration(
        border: Border(
          left: left ? BorderSide(color: pal.hairline) : BorderSide.none,
          top: top ? BorderSide(color: pal.hairline) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            a.abbr,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: pal.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _signed(c.abilityModifierFor(a)),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Punt. ${c.abilityScores[a] ?? 10}',
            style: TextStyle(
              fontSize: 10.5,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // Reserva el alto de la marca aunque no haya salvación: sin esto las
          // seis celdas quedan a distinta altura y eso es ruido, no dato.
          SizedBox(
            height: 16,
            child: save == null
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 9, color: pal.gold),
                        const SizedBox(width: 3),
                        Text(
                          'SALV ${_signed(save)}',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.4,
                            color: pal.gold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget band(List<Widget> children) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: pal.plaque,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: pal.hairline),
    ),
    child: Column(children: children),
  );

  // Mismo motivo que en la banda de cifras: adentro de una lista, `stretch`
  // solo pediría alto infinito.
  Widget fila(List<Widget> celdas) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: celdas,
    ),
  );

  final abilities = Ability.values;
  if (wide) {
    return band([
      fila([
        for (var i = 0; i < abilities.length; i++)
          Expanded(child: cell(abilities[i], left: i > 0, top: false)),
      ]),
    ]);
  }
  // Tres y tres: a 300 px, seis columnas dejan 44 px por característica y ahí
  // «SALV +8» ya no entra sin achicarse hasta lo ilegible.
  return band([
    for (var f = 0; f < 2; f++)
      fila([
        for (var col = 0; col < 3; col++)
          Expanded(
            child: cell(abilities[f * 3 + col], left: col > 0, top: f > 0),
          ),
      ]),
  ]);
}

/// Los datos de línea como lista de definición, no como «Etiqueta: valor».
///
/// Con el rótulo en su propia columna el ojo baja por el canal en vez de
/// buscar los dos puntos en cada renglón, y las defensas dejan de ser dos
/// puntos adentro de otros dos puntos.
Widget _profileLines(BuildContext context, Creature c, {required bool wide}) {
  final pal = context.palette;
  final sentidos = _sensesWithoutPassive(c);
  final defensas = _defenseFragments(c.defenses);

  final rows = <({String label, Widget value})>[
    if (c.speed.isNotEmpty)
      (label: 'Velocidad', value: _profileText(context, c.speed)),
    if (c.skills.isNotEmpty)
      (
        label: 'Habilidades',
        value: _profileText(
          context,
          [
            for (final e in c.skills.entries)
              '${e.key.label} ${_signed(e.value)}',
          ].join(', '),
        ),
      ),
    if (sentidos.isNotEmpty)
      (label: 'Sentidos', value: _profileText(context, sentidos)),
    if (c.languages.isNotEmpty)
      (label: 'Idiomas', value: _profileText(context, c.languages)),
    if (defensas.isNotEmpty)
      (
        label: 'Defensas',
        value: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final d in defensas) GoldPill(d, highlighted: false)],
        ),
      ),
  ];
  if (rows.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              top: i == 0 ? BorderSide.none : BorderSide(color: pal.hairline),
            ),
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _profileLabel(
                          context,
                          rows[i].label,
                          align: TextAlign.right,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _prose(rows[i].value)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileLabel(context, rows[i].label),
                    const SizedBox(height: 4),
                    rows[i].value,
                  ],
                ),
        ),
    ],
  );
}

Widget _profileText(BuildContext context, String value) =>
    Text(value, style: const TextStyle(fontSize: 13.5, height: 1.4));

List<Widget> _profileTraits(BuildContext context, Creature c) {
  if (c.traits.isEmpty) return const [];
  final pal = context.palette;
  return [
    const SizedBox(height: 22),
    // «Rasgos» y no «Atributos»: en esta aplicación los atributos son las seis
    // características, que están tres bandas más arriba.
    const Eyebrow('Rasgos'),
    for (final trait in c.traits)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _prose(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trait.name,
                style: TextStyle(fontWeight: FontWeight.w500, color: pal.gold),
              ),
              const SizedBox(height: 2),
              Text(
                trait.description,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: pal.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
  ];
}

/// Agrupadas por tipo y en el orden del libro: un perfil es un formato que el
/// DM reconoce de un vistazo, y cambiarlo cuesta más de lo que rinde.
List<Widget> _profileActions(
  BuildContext context,
  ContentRepository repo,
  Creature c, {
  required bool wide,
}) {
  final out = <Widget>[];
  for (final kind in CreatureActionKind.values) {
    final group = c.actions.where((a) => a.kind == kind).toList();
    if (group.isEmpty) continue;
    out.add(const SizedBox(height: 22));
    out.add(Eyebrow(_actionSectionLabel(kind, c)));
    for (var i = 0; i < group.length; i++) {
      out.add(
        _profileAction(context, repo, c, group[i], wide: wide, first: i == 0),
      );
    }
  }
  return out;
}

/// Una acción, con lo que se tira sacado de la prosa.
///
/// El daño era texto gris de 13 px y el único número destacado era el de
/// acertar, que es la mitad de la tirada. Acá acierto, daño y alcance van cada
/// uno en su placa rotulada, en cifras tabulares y del mismo tamaño.
Widget _profileAction(
  BuildContext context,
  ContentRepository repo,
  Creature creature,
  CreatureAction a, {
  required bool wide,
  required bool first,
}) {
  final pal = context.palette;
  final damageText = [
    ?a.damage,
    if (a.damageType != null) DamageType.labelFor(a.damageType!),
  ].join(' ');

  Widget plaque(String label, String value, {Color? color, double width = 0}) =>
      SizedBox(
        width: width == 0 ? null : width,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: pal.plaque,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _profileLabel(context, label, align: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );

  final name = Text(
    a.name,
    style: const TextStyle(fontWeight: FontWeight.w500),
  );
  final description = a.description.isEmpty || a.spellcasting != null
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            a.description,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: pal.textMuted),
          ),
        );

  // Sin bonificador de ataque no hay nada que poner en las placas: son las
  // acciones que se resuelven por texto (ataque múltiple, un aliento con su
  // salvación), y ahí la prosa es el contenido.
  final hasNumbers = a.attackBonus != null;

  Widget body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      name,
      ?description,
      if (a.spellcasting case final spellcasting?)
        _creatureSpellcasting(context, repo, creature, spellcasting),
    ],
  );

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: Border(
        top: first ? BorderSide.none : BorderSide(color: pal.hairline),
      ),
    ),
    child: !hasNumbers
        ? _prose(body)
        : wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _prose(body)),
              const SizedBox(width: 16),
              plaque(
                'Acierto',
                '+${a.attackBonus}',
                color: pal.gold,
                width: 74,
              ),
              if (damageText.isNotEmpty) ...[
                const SizedBox(width: 8),
                plaque('Daño', damageText, width: 150),
              ],
              if (a.reach.isNotEmpty) ...[
                const SizedBox(width: 8),
                plaque('Alcance', a.reach, width: 86),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  plaque('Acierto', '+${a.attackBonus}', color: pal.gold),
                  if (damageText.isNotEmpty) plaque('Daño', damageText),
                  if (a.reach.isNotEmpty) plaque('Alcance', a.reach),
                ],
              ),
            ],
          ),
  );
}

Widget _creatureSpellcasting(
  BuildContext context,
  ContentRepository repo,
  Creature creature,
  CreatureSpellcasting spellcasting,
) {
  final pal = context.palette;
  final castingSummary = [
    spellcasting.ability.label,
    if (spellcasting.saveDc case final dc?) 'CD $dc',
    if (spellcasting.attackBonus case final attack?)
      'Ataque ${_signed(attack)}',
  ].join(' · ');

  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          castingSummary,
          style: TextStyle(fontSize: 12.5, color: pal.textMuted),
        ),
        if (spellcasting.componentRule.isNotEmpty)
          Text(
            spellcasting.componentRule,
            style: TextStyle(fontSize: 12.5, color: pal.textMuted),
          ),
        for (final group in spellcasting.groups) ...[
          const SizedBox(height: 10),
          Text(
            group.usesPerDay == null
                ? 'A voluntad'
                : '${group.usesPerDay}/día cada uno',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          for (final ref in group.spells)
            _creatureSpellRow(
              context,
              repo,
              creature,
              spellcasting,
              ref,
              castingSummary,
            ),
        ],
      ],
    ),
  );
}

Widget _creatureSpellRow(
  BuildContext context,
  ContentRepository repo,
  Creature creature,
  CreatureSpellcasting spellcasting,
  CreatureSpellRef ref,
  String castingSummary,
) {
  final spell = repo.spell(ref.spellId);
  final pal = context.palette;
  final detail = [
    if (ref.castAtLevel case final level?) 'Se lanza a nivel $level',
    if (ref.note.isNotEmpty) ref.note,
  ].join(' · ');
  final contextText = [
    castingSummary,
    if (spellcasting.componentRule.isNotEmpty) spellcasting.componentRule,
    if (detail.isNotEmpty) detail,
  ].join('. ');

  return InkWell(
    key: ValueKey('creature-spell-${creature.id}-${ref.spellId}'),
    onTap: spell == null
        ? null
        : () => showSpellDetailsDialog(
            context,
            spell,
            contextTitle: 'Con ${creature.name}',
            contextText: contextText,
          ),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Row(
        children: [
          if (spell != null && spell.actionType != SpellActionType.longer) ...[
            ActionTypeIcon(spell.actionType, size: 14),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spell?.name ?? ref.spellId,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(fontSize: 11.5, color: pal.textMuted),
                  ),
              ],
            ),
          ),
          if (spell != null)
            Icon(Icons.info_outline, size: 14, color: pal.textMuted),
        ],
      ),
    ),
  );
}

/// Distintivo de procedencia para las tarjetas de selección.
class SourceBadge extends StatelessWidget {
  final ContentSource source;
  const SourceBadge(this.source, {super.key});
  @override
  Widget build(BuildContext context) {
    final label = sourceLabel(source);
    return Semantics(
      label: 'Procedencia: $label',
      child: GoldPill(label, highlighted: source == ContentSource.srd2024),
    );
  }
}
