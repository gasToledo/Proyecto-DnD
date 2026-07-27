import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Caso validado del brief §10: Sagan "The Red" — Humano, Guerrero, Soldado.
/// Baseline de reglas 2024 (trasfondo da +característica y dote de origen;
/// Guerrero da Maestría de Armas).
Character sagan({int level = 1, List<int>? hp}) => Character(
      id: 'sagan',
      name: 'Sagan "The Red"',
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
      backgroundAbilityBonuses: {
        Ability.strength: 2,
        Ability.constitution: 1,
      },
      chosenSkills: ['perception', 'survival', 'insight'],
      fightingStyleId: 'fs-defense',
      weaponMasteryChoices: ['longsword', 'greatsword', 'dagger'],
      featIds: ['skilled'],
      hpPerLevel: hp ?? [10],
      equippedArmorId: 'leather',
      equippedWeaponIds: ['longsword'],
    );

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  group('Sagan nivel 1', () {
    late ComputedSheet s;
    setUp(() => s = compiler.compile(sagan()));

    test('características finales (base + trasfondo 2024)', () {
      expect(s.abilityScores[Ability.strength], 17);
      expect(s.abilityScores[Ability.constitution], 15);
      expect(s.abilityScores[Ability.dexterity], 13);
      expect(s.abilityModifiers[Ability.strength], 3);
      expect(s.abilityModifiers[Ability.constitution], 2);
      expect(s.abilityModifiers[Ability.dexterity], 1);
    });

    test('bonificador de competencia', () => expect(s.proficiencyBonus, 2));

    test('PG máximos = dado máx + mod CON', () => expect(s.maxHp, 12));

    test('CA = cuero (11) + DEX (1) + Defensa (1)', () {
      expect(s.armorClass, 13);
    });

    test('iniciativa y velocidad', () {
      expect(s.initiative, 1);
      expect(s.speed, 30);
    });

    test('Percepción Pasiva con competencia', () {
      // 10 + WIS(1) + competencia(2)
      expect(s.passivePerception, 13);
    });

    test('salvaciones de Guerrero', () {
      expect(
          s.savingThrowProficiencies,
          containsAll([
            Ability.strength,
            Ability.constitution,
          ]));
    });

    test('Maestría de Armas: 3 espacios', () {
      expect(s.weaponMasterySlots, 3);
    });

    test('recurso Segundo Aliento presente', () {
      expect(s.resources.map((r) => r.id), contains('second_wind'));
    });

    test('ataque con espada larga (maestría Sap)', () {
      expect(s.attacks, hasLength(1));
      final a = s.attacks.single;
      expect(a.name, 'Espada larga');
      expect(a.attackBonus, 5); // STR(3) + competencia(2)
      expect(a.damage, '1d8 + 3');
      expect(a.damageType, 'slashing');
      expect(a.mastery, 'sap');
    });

    test('un solo ataque por acción en nivel 1', () {
      expect(s.attacksPerAction, 1);
    });
  });

  group('Sagan subida a nivel 2', () {
    late ComputedSheet s;
    setUp(() => s = compiler.compile(sagan(level: 2, hp: [10, 6])));

    test('PG acumulados (10 + 6) + mod CON por nivel', () {
      expect(s.maxHp, 20); // 16 + 2*2
    });

    test('gana Oleada de Acción', () {
      expect(s.resources.map((r) => r.id), contains('action_surge'));
    });

    test('competencia sigue en 2', () => expect(s.proficiencyBonus, 2));
  });

  group('Sagan a nivel 5 (subida de nivel)', () {
    late ComputedSheet s;
    setUp(() {
      final c = Character.fromJson(sagan().toJson());
      final leveled = c.copyWith(
        level: 5,
        hpPerLevel: [10, 6, 6, 6, 6],
        asiChoices: [
          const AsiChoice(level: 4, abilityIncreases: {Ability.strength: 2}),
        ],
      );
      s = compiler.compile(leveled);
    });

    test('Ataque Adicional otorga 2 ataques por acción', () {
      expect(s.attacksPerAction, 2);
    });

    test('bonificador de competencia sube a 3', () {
      expect(s.proficiencyBonus, 3);
    });

    test('el ASI de nivel 4 aplica +2 a Fuerza', () {
      expect(s.abilityScores[Ability.strength], 19);
    });

    test('PG acumulados con mod. de CON por nivel', () {
      // (10+6+6+6+6) + CON(+2) * 5 = 34 + 10
      expect(s.maxHp, 44);
    });

    test('ataque con competencia 3 + Fuerza 4', () {
      expect(s.attacks.single.attackBonus, 7);
    });
  });

  group('Serialización', () {
    test('round-trip JSON produce la misma ficha', () {
      final original = sagan();
      final restored = Character.fromJson(original.toJson());
      final a = compiler.compile(original);
      final b = compiler.compile(restored);
      expect(b.maxHp, a.maxHp);
      expect(b.armorClass, a.armorClass);
      expect(
          b.abilityScores[Ability.strength], a.abilityScores[Ability.strength]);
      expect(b.attacks.single.mastery, a.attacks.single.mastery);
    });
  });

  group('Validación no bloqueante', () {
    test('advierte por demasiadas maestrías sin impedir', () {
      // 4 maestrías elegidas cuando solo hay 3 espacios.
      final json = sagan().toJson();
      json['weaponMasteryChoices'] = [
        'longsword',
        'greatsword',
        'dagger',
        'shortbow'
      ];
      final over = Character.fromJson(json);

      final warnings = CharacterValidator(repo).validate(over);
      expect(warnings.map((w) => w.code), contains('too_many_masteries'));
      // La compilación sigue funcionando pese a la advertencia (no bloquea).
      expect(() => compiler.compile(over), returnsNormally);
    });

    test('el Guerrero es competente con armadura pesada (no advierte)', () {
      final json = sagan().toJson();
      json['equippedArmorId'] = 'chain-mail';
      final warnings =
          CharacterValidator(repo).validate(Character.fromJson(json));
      expect(
          warnings.map((w) => w.code), isNot(contains('armor_not_proficient')));
    });
  });

  group('La maestría de armas requiere competencia (2024)', () {
    /// Pícaro: tiene espacios de maestría, y su competencia con armas marciales
    /// es por id (estoque, espada corta, cimitarra, látigo) en vez de por
    /// categoría. Sirve para probar los dos caminos de `weaponProficiencies`.
    Character rogue(String weaponId) => Character(
          id: 'probe-mastery',
          name: 'Prueba',
          raceId: 'human',
          classId: 'rogue',
          backgroundId: 'soldier',
          level: 1,
          assignedScores: {
            Ability.strength: 12,
            Ability.dexterity: 15,
            Ability.constitution: 14,
            Ability.intelligence: 13,
            Ability.wisdom: 10,
            Ability.charisma: 10,
          },
          weaponMasteryChoices: [weaponId],
          hpPerLevel: const [8],
          equippedWeaponIds: [weaponId],
        );

    test('Sagan conserva la maestría: es competente con marciales', () {
      final a = compiler.compile(sagan()).attacks.single;
      expect(a.mastery, 'sap');
    });

    test('sin competencia con el arma, la maestría no se aplica', () {
      // La espada larga es marcial y no figura en la lista del Pícaro.
      final s = compiler.compile(rogue('longsword'));
      expect(s.weaponProficiencies, isNot(contains('martial')));
      expect(s.attacks.single.mastery, isNull);
    });

    test('advierte cuando la maestría elegida no se aplica', () {
      final warnings = CharacterValidator(repo).validate(rogue('longsword'));
      expect(warnings.map((w) => w.code), contains('mastery_not_proficient'));
    });

    test('la competencia por id del arma también habilita la maestría', () {
      // El estoque es marcial pero está listado por id en el Pícaro: el chequeo
      // mira la ficha compilada, no solo la categoría.
      final s = compiler.compile(rogue('rapier'));
      expect(s.attacks.single.mastery, 'vex');
      final warnings = CharacterValidator(repo).validate(rogue('rapier'));
      expect(warnings.map((w) => w.code),
          isNot(contains('mastery_not_proficient')));
    });
  });
}
