import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifica que el wizard (capa de estado `CreationDraft`) reproduce el caso
/// Sagan y produce una ficha compilada con los valores esperados.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024');
  });

  test('un draft con las elecciones de Sagan compila correctamente', () {
    final d = CreationDraft(repo)
      ..classId = 'fighter'
      ..fightingStyleId = 'fs-defense'
      ..weaponMasteries.addAll(['longsword', 'greatsword', 'dagger'])
      ..raceId = 'human'
      ..raceFeatId = 'skilled'
      ..backgroundId = 'soldier'
      ..spreadMode = AbilitySpreadMode.twoOne
      ..spreadPlusTwo = Ability.strength
      ..spreadPlusOne = Ability.constitution
      ..equippedArmorId = 'leather'
      ..weaponId = 'longsword'
      ..name = 'Sagan "The Red"';

    d.classSkills.addAll(['perception', 'survival']);
    d.raceSkills.add('insight');

    // Asignación de array estándar.
    d.applyScoreMethod(ScoreMethod.standardArray);
    d.assignedScores.addAll({
      Ability.strength: 15,
      Ability.dexterity: 13,
      Ability.constitution: 14,
      Ability.intelligence: 10,
      Ability.wisdom: 12,
      Ability.charisma: 8,
    });

    final character = d.build();
    final sheet = CharacterCompiler(repo).compile(character);

    expect(sheet.abilityScores[Ability.strength], 17);
    expect(sheet.abilityScores[Ability.constitution], 15);
    expect(sheet.maxHp, 12);
    expect(sheet.armorClass, 13); // cuero 11 + DEX 1 + Defensa 1
    expect(sheet.weaponMasterySlots, 3);
    expect(sheet.passivePerception, 13);
    expect(sheet.attacks.single.attackBonus, 5);
    expect(sheet.attacks.single.mastery, 'sap');
    expect(character.name, 'Sagan "The Red"');
  });

  test('el reparto +1/+1/+1 aplica a las tres características del trasfondo', () {
    final d = CreationDraft(repo)
      ..backgroundId = 'soldier'
      ..spreadMode = AbilitySpreadMode.oneOneOne;
    expect(d.abilitySpread, {
      Ability.strength: 1,
      Ability.dexterity: 1,
      Ability.constitution: 1,
    });
  });
}
