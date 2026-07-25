import 'package:flutter/material.dart';

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

/// Diálogo para renombrar un personaje. Devuelve el nombre nuevo (recortado) o
/// null si se canceló o quedó vacío. Compartido entre la ficha y el dashboard.
Future<String?> showRenameDialog(BuildContext context, String current) async {
  final ctrl = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Editar nombre'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nombre del personaje',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  final trimmed = result?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

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
  const StatPlaque({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.footer,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$label: $value',
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
    child: LinearProgressIndicator(
      value: ratio.clamp(0, 1),
      minHeight: 5,
      backgroundColor: track,
      valueColor: AlwaysStoppedAnimation(color),
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
  const ShieldBadge(this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Clase de armadura: $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 46,
        height: 52,
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
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

/// Plaqueta de característica con pip de salvación.
class AbilityPlaque extends StatelessWidget {
  final String abbr;
  final int score;
  final int modifier;
  final bool saveProficient;
  const AbilityPlaque({
    super.key,
    required this.abbr,
    required this.score,
    required this.modifier,
    required this.saveProficient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mod = modifier >= 0 ? '+$modifier' : '$modifier';
    return Semantics(
      label:
          '$abbr: $score, modificador $mod'
          '${saveProficient ? ', competente en salvación' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          color: p.plaque,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: saveProficient ? p.gold : p.hairline,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  abbr,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 26,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.hairline),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mod,
                    style: TextStyle(
                      fontSize: 13,
                      color: p.gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Medallón de retrato: círculo con aro dorado. Muestra [image] o [fallback].
class Medallion extends StatelessWidget {
  final ImageProvider? image;
  final String fallback;
  final double size;

  /// Emblema para cuando no hay retrato: un ícono sobre un degradado de
  /// [emblemColor]. Si no se pasa, se cae a la inicial de [fallback].
  final IconData? emblemIcon;
  final Color? emblemColor;

  const Medallion({
    super.key,
    this.image,
    required this.fallback,
    this.size = 74,
    this.emblemIcon,
    this.emblemColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasEmblem = image == null && emblemIcon != null;
    final accent = emblemColor ?? p.gold;
    return Semantics(
      image: true,
      label: image == null ? 'Emblema de $fallback' : 'Retrato de $fallback',
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
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image != null
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
  const CappedChipSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.max,
    required this.onChanged,
    this.disabled = const {},
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
        return FilterChip(
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
  const GoldPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: p.goldSoft,
        border: Border.all(color: p.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: p.gold)),
    );
  }
}
