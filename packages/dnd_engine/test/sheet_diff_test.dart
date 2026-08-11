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

  test('subir a Artillero de nivel 3 avisa del Cañón Arcano', () {
    // El cañón dejó de ser un rasgo en prosa, así que sin `newCompanions` el
    // resumen de subida de nivel no diría que lo ganaste.
    Character artificer(int level) => Character(
          id: 'vex',
          name: 'Vex',
          raceId: 'human',
          classId: 'artificer',
          subclassId: level >= 3 ? 'artillerist' : null,
          backgroundId: 'sage',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 12},
          hpPerLevel: List.filled(level, 6),
        );

    final d = diffSheets(
      compiler.compile(artificer(2)),
      compiler.compile(artificer(3)),
    );
    expect(d.newCompanions.map((c) => c.id), ['eldritch-cannon']);
    expect(d.hasChanges, isTrue);
  });

  test('subir a Druida 4 avisa de las dos formas nuevas', () {
    // Mismo motivo que el cañón: el rasgo crece sin estrenar ningún texto, así
    // que sin esto el jugador se queda con dos formas por anotar y sin aviso.
    Character druid(int level) => Character(
          id: 'sagan',
          name: 'Sagan',
          raceId: 'human',
          classId: 'druid',
          backgroundId: 'sage',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 12},
          hpPerLevel: List.filled(level, 5),
        );

    expect(
      diffSheets(compiler.compile(druid(3)), compiler.compile(druid(4)))
          .wildShapeFormsGained,
      2,
    );
    // Un nivel que no toca el rasgo no dice nada.
    expect(
      diffSheets(compiler.compile(druid(2)), compiler.compile(druid(3)))
          .wildShapeFormsGained,
      0,
    );
  });
}
