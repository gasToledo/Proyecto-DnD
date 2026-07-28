part of 'level_up_screen.dart';

/// Detalle de la dote elegida en la subida de nivel.
///
/// La grilla de dotes son 57 chips con solo el nombre, así que sin esto hay que
/// elegir a ciegas. Se muestra el texto completo, sin recortar: la decisión es
/// permanente y el motivo de este panel es justamente poder leerla entera.
class _FeatDetail extends StatelessWidget {
  final Feat feat;
  const _FeatDetail(this.feat);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final summary = featSummary(feat);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, size: 18, color: pal.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feat.name,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SourceBadge(feat.source),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (feat.repeatable) ...[
            const SizedBox(height: 8),
            Text(
              'Se puede tomar más de una vez.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Insignia de espacios de conjuro de un nivel. Resalta en oro si el nivel se
/// abrió recién en esta subida.
class _SlotBadge extends StatelessWidget {
  final int level;
  final int count;
  final bool isNew;
  const _SlotBadge({
    required this.level,
    required this.count,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isNew ? pal.goldSoft : pal.plaque,
        border: Border.all(color: isNew ? pal.gold : pal.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nv $level  ×$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isNew ? pal.gold : null,
            ),
          ),
          if (isNew) ...[
            const SizedBox(width: 5),
            Text(
              'nuevo',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                color: pal.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
