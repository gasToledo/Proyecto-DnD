import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Reusa el caso Sagan para verificar el diff entre niveles.
Character sagan(
        {required int level,
        required List<int> hp,
        List<AsiChoice> asi = const []}) =>
    Character(
      id: 'sagan',
      name: 'Sagan',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: level,
      assignedScores: {
        Ability.strength: 15,
        Ability.dexterity: 13,
        Ability.constitution: 14,
        Ability.intelligence: 10,
        Ability.wisdom: 12,
        Ability.charisma: 8,
      },
      backgroundAbilityBonuses: {Ability.strength: 2, Ability.constitution: 1},
      chosenSkills: const ['perception'],
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
      weaponMasteryChoices: const ['longsword'],
      featIds: const ['skilled'],
      asiChoices: asi,
      hpPerLevel: hp,
      equippedArmorId: 'leather',
      equippedWeaponIds: const ['longsword'],
    );

void main() {
  late CharacterCompiler compiler;

  setUpAll(() async {
    final repo =
        await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  test('subir de 1 a 2: gana PG y el recurso Oleada de Acción', () {
    final before = compiler.compile(sagan(level: 1, hp: [10]));
    final after = compiler.compile(sagan(level: 2, hp: [10, 6]));
    final d = diffSheets(before, after);

    expect(d.hpGained, 8); // 6 (dado) + 2 (CON)
    expect(d.newResources.map((r) => r.id), contains('action_surge'));
    expect(d.proficiencyBonusChanged, isFalse);
    expect(d.hasChanges, isTrue);
  });

  test('subir de 4 a 5: Ataque Adicional y bonif. de competencia', () {
    final before = compiler.compile(sagan(level: 4, hp: [10, 6, 6, 6]));
    final after = compiler.compile(sagan(level: 5, hp: [10, 6, 6, 6, 6]));
    final d = diffSheets(before, after);

    expect(d.extraAttacksGained, 1);
    expect(d.proficiencyBonusChanged, isTrue);
    expect(d.proficiencyBonusFrom, 2);
    expect(d.proficiencyBonusTo, 3);
  });

  test('un ASI +2 a Fuerza aparece como cambio de característica', () {
    final before = compiler.compile(sagan(level: 3, hp: [10, 6, 6]));
    final after = compiler.compile(sagan(
      level: 4,
      hp: [10, 6, 6, 6],
      asi: [
        const AsiChoice(level: 4, abilityIncreases: {Ability.strength: 2})
      ],
    ));
    final d = diffSheets(before, after);
    expect(d.abilityChanges[Ability.strength], 2);
  });
}
