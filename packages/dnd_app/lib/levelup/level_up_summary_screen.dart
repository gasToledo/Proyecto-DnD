import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

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
    final featureNames = newFeatures.map((f) => f.name).toSet();
    // Pasivas que no provienen de un rasgo de clase (p.ej. de una dote de ASI).
    final featPassives =
        diff.newPassives.where((p) => !featureNames.contains(p.name)).toList();

    final quickChips = <Widget>[
      if (diff.proficiencyBonusChanged)
        _chip(context, 'Competencia',
            '+${diff.proficiencyBonusFrom} → +${diff.proficiencyBonusTo}'),
      if (diff.extraAttacksGained > 0)
        _chip(context, 'Ataques/acción', '+${diff.extraAttacksGained}'),
      if (diff.weaponMasterySlotsGained > 0)
        _chip(context, 'Maestrías', '+${diff.weaponMasterySlotsGained}'),
      if (diff.speedGained != 0)
        _chip(context, 'Velocidad', '${_signed(diff.speedGained)} ft'),
      if (diff.newDarkvision != null)
        _chip(context, 'Visión osc.', '${diff.newDarkvision} ft'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('¡Nivel $level!'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // PG destacados.
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+${diff.hpGained} PG máximos',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('Tus PG actuales suben lo mismo.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (quickChips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: quickChips),
          ],
          if (diff.abilityChanges.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(context, 'Características'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: diff.abilityChanges.entries
                  .map((e) => Chip(
                        avatar: const Icon(Icons.arrow_upward, size: 16),
                        label: Text('${e.key.abbr} ${_signed(e.value)}'),
                      ))
                  .toList(),
            ),
          ],
          if (diff.newSkillProficiencies.isNotEmpty ||
              diff.newSaveProficiencies.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(context, 'Nuevas competencias'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...diff.newSaveProficiencies
                    .map((a) => Chip(label: Text('Salv. ${a.abbr}'))),
                ...diff.newSkillProficiencies
                    .map((s) => Chip(label: Text(_title2(s)))),
              ],
            ),
          ],
          if (newFeatures.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(context, 'Rasgos de clase ganados'),
            ...newFeatures.map((f) => _featureCard(f.name, f.description)),
          ],
          if (featPassives.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(context, 'De tu dote'),
            ...featPassives.map((p) => _featureCard(p.name, p.description)),
          ],
          if (diff.newResources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title(context, 'Recursos nuevos'),
            ...diff.newResources.map((r) => _featureCard(
                r.name, 'Usos: ${r.max} · recarga: ${_recharge(r.recharge)}')),
          ],
          const SizedBox(height: 80),
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

  Widget _featureCard(String title, String subtitle) => Card(
        child: ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
        ),
      );

  Widget _chip(BuildContext context, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );
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
