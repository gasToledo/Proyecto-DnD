import 'package:dnd_engine/dnd_engine.dart';

/// Sagan "The Red" del brief §10 — Humano, Guerrero, Soldado (reglas 2024).
/// Sirve como dato de demostración hasta que exista el wizard de creación.
Character demoSagan() => Character(
  id: 'sagan',
  name: 'Sagan "The Red"',
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  level: 1,
  assignedScores: {
    Ability.strength: 15,
    Ability.dexterity: 13,
    Ability.constitution: 14,
    Ability.intelligence: 10,
    Ability.wisdom: 12,
    Ability.charisma: 8,
  },
  backgroundAbilityBonuses: {Ability.strength: 2, Ability.constitution: 1},
  chosenSkills: ['perception', 'survival', 'insight'],
  fightingStyleId: 'fs-defense',
  weaponMasteryChoices: ['longsword', 'greatsword', 'dagger'],
  featIds: ['skilled'],
  hpPerLevel: [10],
  equippedArmorId: 'leather',
  equippedWeaponIds: ['longsword'],
  combat: CombatState(currentHp: 12),
);
