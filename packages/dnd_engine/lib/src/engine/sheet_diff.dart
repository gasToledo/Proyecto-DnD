import '../domain/ability.dart';
import '../domain/computed_sheet.dart';

/// Diferencia entre dos [ComputedSheet] (antes/después). Se usa para mostrar el
/// resumen de "lo ganado" al subir de nivel. Lógica pura y testeable.
class SheetDiff {
  final int hpGained;
  final int proficiencyBonusFrom;
  final int proficiencyBonusTo;

  /// Cambios de característica (solo las que variaron; delta ≠ 0).
  final Map<Ability, int> abilityChanges;

  /// Ataques adicionales por acción ganados (p.ej. Ataque Adicional = 1).
  final int extraAttacksGained;
  final int weaponMasterySlotsGained;

  final List<PassiveTrait> newPassives;
  final List<CharacterResource> newResources;

  /// Compañeros nuevos. Van aparte de [newPassives] porque el Cañón Arcano y
  /// el Defensor de Acero dejaron de ser un rasgo en prosa: sin esto, subir al
  /// nivel que los concede no aparecería en el resumen.
  final List<CompanionOption> newCompanions;
  final List<String> newSkillProficiencies;
  final List<Ability> newSaveProficiencies;

  final int speedGained;

  /// Nueva visión en la oscuridad si cambió, en pies (null si no cambió).
  final int? newDarkvision;

  const SheetDiff({
    required this.hpGained,
    required this.proficiencyBonusFrom,
    required this.proficiencyBonusTo,
    required this.abilityChanges,
    required this.extraAttacksGained,
    required this.weaponMasterySlotsGained,
    required this.newPassives,
    required this.newResources,
    required this.newCompanions,
    required this.newSkillProficiencies,
    required this.newSaveProficiencies,
    required this.speedGained,
    required this.newDarkvision,
  });

  bool get proficiencyBonusChanged =>
      proficiencyBonusFrom != proficiencyBonusTo;

  /// True si hay algo relevante que mostrar.
  bool get hasChanges =>
      hpGained != 0 ||
      abilityChanges.isNotEmpty ||
      extraAttacksGained != 0 ||
      weaponMasterySlotsGained != 0 ||
      newPassives.isNotEmpty ||
      newResources.isNotEmpty ||
      newCompanions.isNotEmpty ||
      newSkillProficiencies.isNotEmpty ||
      newSaveProficiencies.isNotEmpty ||
      proficiencyBonusChanged ||
      speedGained != 0 ||
      newDarkvision != null;
}

/// Calcula el diff de [before] a [after].
SheetDiff diffSheets(ComputedSheet before, ComputedSheet after) {
  final abilityChanges = <Ability, int>{};
  for (final a in Ability.values) {
    final d = (after.abilityScores[a] ?? 0) - (before.abilityScores[a] ?? 0);
    if (d != 0) abilityChanges[a] = d;
  }

  final beforePassiveNames = before.passives.map((p) => p.name).toSet();
  final newPassives = after.passives
      .where((p) => !beforePassiveNames.contains(p.name))
      .toList();

  final beforeResIds = before.resources.map((r) => r.id).toSet();
  final newResources =
      after.resources.where((r) => !beforeResIds.contains(r.id)).toList();

  final beforeCompanionIds = before.companions.map((c) => c.id).toSet();
  final newCompanions = after.companions
      .where((c) => !beforeCompanionIds.contains(c.id))
      .toList();

  final newSkills = after.skillProficiencies
      .difference(before.skillProficiencies)
      .toList()
    ..sort();
  final newSaves = after.savingThrowProficiencies
      .difference(before.savingThrowProficiencies)
      .toList();

  return SheetDiff(
    hpGained: after.maxHp - before.maxHp,
    proficiencyBonusFrom: before.proficiencyBonus,
    proficiencyBonusTo: after.proficiencyBonus,
    abilityChanges: abilityChanges,
    extraAttacksGained: after.attacksPerAction - before.attacksPerAction,
    weaponMasterySlotsGained:
        after.weaponMasterySlots - before.weaponMasterySlots,
    newPassives: newPassives,
    newResources: newResources,
    newCompanions: newCompanions,
    newSkillProficiencies: newSkills,
    newSaveProficiencies: newSaves,
    speedGained: after.speed - before.speed,
    newDarkvision:
        before.darkvision != after.darkvision ? after.darkvision : null,
  );
}
