import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Resumen de "lo ganado" tras subir de nivel: PG, características, ataques,
/// rasgos de clase, pasivas de dote, competencias y recursos nuevos.
class LevelUpSummaryScreen extends StatelessWidget {
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
        title: Text('¡Nivel $level!'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
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
