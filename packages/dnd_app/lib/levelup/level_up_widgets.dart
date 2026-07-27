part of 'level_up_screen.dart';

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
