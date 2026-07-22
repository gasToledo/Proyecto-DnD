import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Resumen de "lo ganado" tras subir de nivel: PG, características, ataques,
/// rasgos de clase, pasivas de dote, competencias y recursos nuevos. Se abre con
/// una breve celebración: el medallón de nivel aparece con un "pop", un estallido
/// dorado detrás, y las secciones entran con un fade escalonado.
class LevelUpSummaryScreen extends StatefulWidget {
  final int level;
  final SheetDiff diff;
  final List<ClassFeature> newFeatures;
  const LevelUpSummaryScreen({
    super.key,
    required this.level,
    required this.diff,
    required this.newFeatures,
  });

  @override
  State<LevelUpSummaryScreen> createState() => _LevelUpSummaryScreenState();
}

class _LevelUpSummaryScreenState extends State<LevelUpSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _pop = CurvedAnimation(
      parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
  late final Animation<double> _content = CurvedAnimation(
      parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get level => widget.level;
  SheetDiff get diff => widget.diff;
  List<ClassFeature> get newFeatures => widget.newFeatures;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final featureNames = newFeatures.map((f) => f.name).toSet();
    // Pasivas que no provienen de un rasgo de clase (p.ej. de una dote de ASI).
    final featPassives =
        diff.newPassives.where((p) => !featureNames.contains(p.name)).toList();

    final quickChips = <Widget>[
      if (diff.proficiencyBonusChanged)
        _StatChip('Competencia',
            '+${diff.proficiencyBonusFrom} → +${diff.proficiencyBonusTo}'),
      if (diff.extraAttacksGained > 0)
        _StatChip('Ataques/acción', '+${diff.extraAttacksGained}'),
      if (diff.weaponMasterySlotsGained > 0)
        _StatChip('Maestrías', '+${diff.weaponMasterySlotsGained}'),
      if (diff.speedGained != 0)
        _StatChip('Velocidad', '${_signed(diff.speedGained)} ft'),
      if (diff.newDarkvision != null)
        _StatChip('Visión osc.', '${diff.newDarkvision} ft'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subida de nivel'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        children: [
          _celebrationHero(context),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _content,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // PG destacados.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 34, color: pal.crimson),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('+${diff.hpGained} PG máximos',
                        style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 24,
                            color: pal.crimson)),
                    const SizedBox(height: 2),
                    Text('Tus PG actuales suben lo mismo.',
                        style: TextStyle(fontSize: 13, color: muted)),
                  ],
                ),
              ],
            ),
          ),
          if (quickChips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: quickChips),
          ],
          if (diff.abilityChanges.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Eyebrow('Características'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: diff.abilityChanges.entries
                  .map((e) => GoldPill('${e.key.abbr} ${_signed(e.value)}'))
                  .toList(),
            ),
          ],
          if (diff.newSkillProficiencies.isNotEmpty ||
              diff.newSaveProficiencies.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Eyebrow('Nuevas competencias'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...diff.newSaveProficiencies
                    .map((a) => GoldPill('Salv. ${a.abbr}')),
                ...diff.newSkillProficiencies.map((s) => GoldPill(_title2(s))),
              ],
            ),
          ],
          if (newFeatures.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Eyebrow('Rasgos de clase ganados'),
            DenseRows(children: [
              for (final f in newFeatures) _featureRow(context, f.name, f.description),
            ]),
          ],
          if (featPassives.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Eyebrow('De tu dote'),
            DenseRows(children: [
              for (final p in featPassives) _featureRow(context, p.name, p.description),
            ]),
          ],
          if (diff.newResources.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Eyebrow('Recursos nuevos'),
            DenseRows(children: [
              for (final r in diff.newResources)
                _featureRow(context, r.name,
                    'Usos: ${r.max} · recarga: ${_recharge(r.recharge)}'),
            ]),
          ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_circle),
            label: const Text('¡Listo!'),
          ),
        ),
      ),
    );
  }

  /// Encabezado de celebración: estallido dorado + medallón de nivel con "pop".
  Widget _celebrationHero(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => CustomPaint(
                  size: const Size(260, 150),
                  painter: _BurstPainter(_ctrl.value, pal.gold),
                ),
              ),
              ScaleTransition(
                scale: _pop,
                child: Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [pal.goldSoft, pal.plaque]),
                    border: Border.all(color: pal.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: pal.gold.withAlpha(70),
                          blurRadius: 26,
                          spreadRadius: 1),
                    ],
                  ),
                  child: Text('$level',
                      style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 46,
                          height: 1,
                          color: pal.gold)),
                ),
              ),
            ],
          ),
        ),
        FadeTransition(
          opacity: _content,
          child: Text('¡Subiste a nivel $level!',
              style: TextStyle(
                  fontSize: 15, letterSpacing: 0.3, color: muted)),
        ),
      ],
    );
  }

  Widget _featureRow(BuildContext context, String title, String subtitle) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Georgia', fontSize: 18, color: pal.gold)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, letterSpacing: 1, color: pal.textMuted)),
        ],
      ),
    );
  }
}

/// Estallido de destellos dorados detrás del medallón de nivel. Los rayos y
/// puntos irradian del centro y se desvanecen en la primera parte de la
/// animación (progreso [t] de 0 a 1).
class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;
  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = (t / 0.7).clamp(0.0, 1.0);
    final fade = 1.0 - p;
    if (fade <= 0.01) return;
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOut.transform(p);
    final maxR = size.width * 0.46;
    const rays = 12;

    final rayPaint = Paint()
      ..color = color.withAlpha((180 * fade).round())
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0 * fade + 0.5;
    final dotPaint = Paint()..color = color.withAlpha((150 * fade).round());

    for (var i = 0; i < rays; i++) {
      final ang = (i / rays) * 2 * pi + 0.3;
      final dir = Offset(cos(ang), sin(ang));
      final inner = 48 + eased * (maxR - 48);
      final outer = inner + 16 * (1 - eased * 0.5);
      canvas.drawLine(center + dir * inner, center + dir * outer, rayPaint);

      final dotAng = ang + pi / rays;
      final dotDir = Offset(cos(dotAng), sin(dotAng));
      final dotR = 48 + eased * (maxR - 24);
      canvas.drawCircle(center + dotDir * dotR, 2.2 * fade + 0.3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

String _recharge(RechargeOn r) => switch (r) {
      RechargeOn.shortRest => 'descanso corto',
      RechargeOn.longRest => 'descanso largo',
      RechargeOn.none => '—',
    };

String _title2(String s) => s.isEmpty
    ? s
    : s
        .split(RegExp(r'[-_ ]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
