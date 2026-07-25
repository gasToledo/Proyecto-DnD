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
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
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
            duration: const Duration(milliseconds: 120),
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

/// Paso 1 · Especie. Elección + rasgos de la especie elegida. Las habilidades y
/// la dote de origen se eligen más adelante, en Aptitudes.
