import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Duelo y Tiro con Arco eran solo texto: el jugador los elegía y la ficha
/// seguía con los mismos números. Ahora son reglas de arma.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character fighter(
    String style, {
    List<String> weapons = const ['longsword'],
    Map<String, bool> twoHanded = const {},
  }) =>
      Character(
        id: 'f',
        name: 'Prueba',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {
          Ability.strength: 16,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 10,
          Ability.charisma: 10,
        },
        featureChoices: {
          'fighting-style': [style],
        },
        hpPerLevel: const [10],
        equippedWeaponIds: weapons,
        weaponTwoHanded: twoHanded,
      );

  Attack attack(Character c, String weaponId) => CharacterCompiler(repo)
      .compile(c)
      .attacks
      .firstWhere((a) => a.baseWeaponId == weaponId);

  test('Duelo suma +2 al daño con un arma a una mano y sin otra', () {
    final plain = attack(fighter('fs-defense'), 'longsword');
    final dueling = attack(fighter('fs-dueling'), 'longsword');
    expect(plain.damage, '1d8 + 3');
    expect(dueling.damage, '1d8 + 5');
    expect(dueling.attackBonus, plain.attackBonus);
  });

  test('Duelo no aplica empuñando a dos manos', () {
    final c = fighter('fs-dueling', twoHanded: const {'longsword': true});
    expect(attack(c, 'longsword').damage, '1d10 + 3');
  });

  test('Duelo no aplica con otra arma equipada', () {
    final c = fighter('fs-dueling', weapons: const ['longsword', 'dagger']);
    expect(attack(c, 'longsword').damage, '1d8 + 3');
  });

  test('Tiro con Arco suma +2 al ataque a distancia y no cuerpo a cuerpo', () {
    final plain = fighter('fs-defense', weapons: const ['shortbow', 'dagger']);
    final archer = fighter('fs-archery', weapons: const ['shortbow', 'dagger']);
    expect(
      attack(archer, 'shortbow').attackBonus,
      attack(plain, 'shortbow').attackBonus + 2,
    );
    expect(
      attack(archer, 'dagger').attackBonus,
      attack(plain, 'dagger').attackBonus,
    );
  });
}
