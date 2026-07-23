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

  // --- Reasignación de dados con intercambio -------------------------------
  CreationDraft newDraft() =>
      CreationDraft(repo)..applyScoreMethod(ScoreMethod.standardArray);

  group('assignScore', () {
    test('asignar un valor libre no intercambia', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 14);
      expect(d.assignedScores[Ability.strength], 15);
      expect(d.assignedScores[Ability.dexterity], 14);
    });

    test('elegir un valor ya tomado por otra las intercambia', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 14);
      d.assignScore(Ability.strength, 14); // FUE roba el 14 → DES recibe el 15
      expect(d.assignedScores[Ability.strength], 14);
      expect(d.assignedScores[Ability.dexterity], 15);
    });

    test('elegir un valor tomado con el destino vacío se lo roba', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 15); // 15 no libre → roba a FUE
      expect(d.assignedScores[Ability.dexterity], 15);
      expect(d.assignedScores.containsKey(Ability.strength), isFalse);
    });

    test('con las 6 asignadas se puede reordenar', () {
      final d = newDraft();
      const order = [15, 14, 13, 12, 10, 8];
      for (var i = 0; i < Ability.values.length; i++) {
        d.assignScore(Ability.values[i], order[i]);
      }
      expect(d.allScoresAssigned, isTrue);
      d.assignScore(Ability.strength, 8); // intercambia FUE(15) con CAR(8)
      expect(d.assignedScores[Ability.strength], 8);
      expect(d.assignedScores[Ability.charisma], 15);
      expect(d.allScoresAssigned, isTrue);
    });

    test('clearScores vacía las asignaciones y conserva el pool', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      final pool = List.of(d.pool);
      d.clearScores();
      expect(d.assignedScores, isEmpty);
      expect(d.pool, pool);
    });
  });

  // --- Gating por paso -----------------------------------------------------
  group('pendingFor', () {
    test('Características bloquea hasta asignar las 6', () {
      final d = newDraft();
      expect(d.pendingFor('Características'), isNotEmpty);
      const order = [15, 14, 13, 12, 10, 8];
      for (var i = 0; i < Ability.values.length; i++) {
        d.assignScore(Ability.values[i], order[i]);
      }
      expect(d.pendingFor('Características'), isEmpty);
    });

    test('Clase (Guerrero) exige estilo, habilidades y maestrías', () {
      final d = newDraft(); // classId = fighter por defecto
      expect(d.pendingFor('Clase'), isNotEmpty);
      d.fightingStyleId = 'fs-defense';
      d.classSkills.addAll(['perception', 'survival']);
      final slots = d.weaponMasterySlots;
      d.weaponMasteries
          .addAll(d.proficientWeapons.take(slots).map((w) => w.id));
      expect(d.pendingFor('Clase'), isEmpty);
    });

    test('Especie exige elección y sus habilidades', () {
      final d = newDraft();
      expect(d.pendingFor('Especie'), isNotEmpty);
      final race = repo.races.values.first;
      d.raceId = race.id;
      // Algunas especies eligen "de cualquier lista" (skillChoiceFrom vacío).
      final pickable = race.skillChoiceFrom.isEmpty
          ? const ['acrobatics', 'arcana', 'athletics']
          : race.skillChoiceFrom;
      for (final s in pickable.take(race.skillChoiceCount)) {
        d.raceSkills.add(s);
      }
      if (race.effects.any((e) => e is GrantFeatEffect)) {
        expect(d.pendingFor('Especie'), isNotEmpty);
        d.raceFeatId =
            repo.feats.values.firstWhere((f) => f.category == 'origin').id;
      }
      expect(d.pendingFor('Especie'), isEmpty);
    });

    test('Equipo y Nombre nunca bloquean', () {
      final d = newDraft();
      expect(d.pendingFor('Equipo'), isEmpty);
      expect(d.pendingFor('Nombre'), isEmpty);
    });
  });
}
