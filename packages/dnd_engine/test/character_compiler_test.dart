import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Personaje de referencia: Sagan "The Red" — Humano, Guerrero, Soldado.
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
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
      weaponMasteryChoices: ['longsword', 'greatsword', 'dagger'],
      featIds: ['skilled'],
      hpPerLevel: hp ?? [10],
      equippedArmorId: 'leather',
      equippedWeaponIds: ['longsword'],
    );

Character multiclassCharacter({
  required String classId,
  required List<String> classHistory,
  Map<Ability, int>? assignedScores,
}) =>
    Character(
      id: 'multiclass',
      name: 'Multiclase',
      raceId: 'human',
      classId: classId,
      backgroundId: 'soldier',
      classHistory: classHistory,
      assignedScores: assignedScores ??
          {
            for (final ability in Ability.values) ability: 14,
          },
      hpPerLevel: [for (var i = 0; i < classHistory.length; i++) 8],
    );

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  test('compila rasgos y recursos por nivel de clase', () {
    final c = sagan(
      level: 7,
      hp: const [10, 6, 6, 6, 6, 6, 6],
    ).copyWith(
      classHistory: const [
        'fighter',
        'fighter',
        'fighter',
        'fighter',
        'fighter',
        'wizard',
        'wizard',
      ],
    );

    final sheet = compiler.compile(c);

    expect(sheet.level, 7);
    expect(sheet.attacksPerAction, 2);
    expect(
      sheet.resources.map((resource) => resource.key),
      containsAll(['fighter:second_wind', 'fighter:action_surge']),
    );
    expect(
      sheet.savingThrowProficiencies,
      containsAll([Ability.strength, Ability.constitution]),
    );
    expect(
        sheet.savingThrowProficiencies, isNot(contains(Ability.intelligence)));
  });

  test('aplica la mejora de característica según el nivel de su clase', () {
    final c = sagan(
      level: 8,
      hp: const [10, 6, 6, 6, 6, 6, 6, 6],
    ).copyWith(
      classHistory: const [
        'fighter',
        'fighter',
        'fighter',
        'fighter',
        'wizard',
        'wizard',
        'wizard',
        'wizard',
      ],
      asiChoices: const [
        AsiChoice(
          classId: 'wizard',
          level: 4,
          abilityIncreases: {Ability.intelligence: 2},
        ),
      ],
    );

    expect(compiler.compile(c).abilityScores[Ability.intelligence], 12);
  });

  test('separa recursos homónimos y no acumula Ataque Adicional', () {
    final clericPaladin = multiclassCharacter(
      classId: 'cleric',
      classHistory: [
        'cleric',
        'cleric',
        'cleric',
        'paladin',
        'paladin',
        'paladin',
      ],
    );
    final resources = compiler.compile(clericPaladin).resources;
    expect(
      resources.map((resource) => resource.key),
      containsAll(['cleric:channel_divinity', 'paladin:channel_divinity']),
    );

    final fighterPaladin = multiclassCharacter(
      classId: 'fighter',
      classHistory: [
        ...List.filled(5, 'fighter'),
        ...List.filled(5, 'paladin'),
      ],
    );
    final sheet = compiler.compile(fighterPaladin);
    expect(sheet.attacksPerAction, 2);
    expect(sheet.classLevels, {'fighter': 5, 'paladin': 5});
  });

  test('expone las dos defensas sin armadura y respeta la elegida', () {
    final c = multiclassCharacter(
      classId: 'barbarian',
      classHistory: const ['barbarian', 'monk'],
      assignedScores: {
        Ability.strength: 12,
        Ability.dexterity: 14,
        Ability.constitution: 16,
        Ability.intelligence: 10,
        Ability.wisdom: 18,
        Ability.charisma: 8,
      },
    ).copyWith(unarmoredDefenseClassId: 'monk');

    final sheet = compiler.compile(c);
    expect(sheet.unarmoredDefenseOptions, hasLength(2));
    expect(sheet.selectedUnarmoredDefenseClassId, 'monk');
    expect(sheet.armorClass, 16);
  });

  test('combina espacios normales y conserva los de pacto por separado', () {
    final clericWizard = multiclassCharacter(
      classId: 'cleric',
      classHistory: const [
        'cleric',
        'cleric',
        'cleric',
        'wizard',
        'wizard',
      ],
    );
    final combined = compiler.compile(clericWizard);
    expect(combined.spellcastingBlocks.map((b) => b.classId),
        containsAll(['cleric', 'wizard']));
    expect(combined.normalSpellSlotsByLevel, {1: 4, 2: 3, 3: 2});

    final warlockWizard = multiclassCharacter(
      classId: 'warlock',
      classHistory: const [
        'warlock',
        'warlock',
        'warlock',
        'wizard',
        'wizard',
        'wizard',
      ],
    );
    final pact = compiler.compile(warlockWizard);
    expect(pact.normalSpellSlotsByLevel, {1: 4, 2: 2});
    expect(pact.pactSlotsByLevel, {2: 2});
  });

  test('combina Ranger 4 / Sorcerer 3 sin mezclar sus fuentes', () {
    final c = multiclassCharacter(
      classId: 'ranger',
      classHistory: const [
        'ranger',
        'ranger',
        'ranger',
        'ranger',
        'sorcerer',
        'sorcerer',
        'sorcerer',
      ],
    );

    final sheet = compiler.compile(c);
    expect(sheet.normalSpellSlotsByLevel, {1: 4, 2: 3, 3: 2});
    expect(
      sheet.spellcastingBlocks
          .map((block) => (block.classId, block.classLevel)),
      containsAll([('ranger', 4), ('sorcerer', 3)]),
    );
    expect(
      sheet.spellcastingBlocks.map((block) => block.spellcasting.ability),
      containsAll([Ability.wisdom, Ability.charisma]),
    );
  });

  test('mantiene elecciones de estilo separadas por clase', () {
    final c = multiclassCharacter(
      classId: 'fighter',
      classHistory: const ['fighter', 'paladin', 'paladin'],
    ).copyWith(
      classFeatureChoices: const {
        'fighter': {
          'fighting-style': ['fs-defense']
        },
        'paladin': {
          'fighting-style': ['fs-dueling']
        },
      },
    );

    final sheet = compiler.compile(c);
    expect(
      sheet.featureChoiceSlots.map((slot) => slot.groupId),
      containsAll(['fighter:fighting-style', 'paladin:fighting-style']),
    );
    expect(
      sheet.passives.map((passive) => passive.name),
      containsAll(['Defensa', 'Duelo']),
    );
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

  group('Una dote no repetible se aplica una sola vez', () {
    // El Soldado ya concede Atacante Salvaje. Si el Humano elige la misma dote
    // para su rasgo Versátil, el personaje la tiene por dos vías y sus efectos
    // se aplicaban dos veces. El PHB es explícito: una dote se toma una sola
    // vez salvo que su descripción diga lo contrario.
    Character conDoteRepetida() =>
        sagan().copyWith(featIds: ['savage-attacker']);

    test('el rasgo pasivo no se duplica en la ficha', () {
      final s = compiler.compile(conDoteRepetida());
      final atacante = s.passives.where((t) => t.name == 'Atacante Salvaje');
      expect(atacante, hasLength(1));
    });

    test('sigue advirtiendo aunque el efecto ya no se duplique', () {
      final warnings = CharacterValidator(repo).validate(conDoteRepetida());
      expect(warnings.map((w) => w.code), contains('feat_duplicate'));
    });

    test('una dote repetible sí acumula sus efectos', () {
      // Duro da +2 PG por nivel y no es repetible; Mejora de Característica
      // sí lo es, así que dos instancias deben sumar 2 puntos, no 1.
      final base = sagan().copyWith(featIds: const []);
      final unaVez = sagan().copyWith(featIds: ['tough']);
      final dosVeces = sagan().copyWith(featIds: ['tough', 'tough']);
      final hpBase = compiler.compile(base).maxHp;
      expect(compiler.compile(unaVez).maxHp, greaterThan(hpBase));
      expect(
        compiler.compile(dosVeces).maxHp,
        compiler.compile(unaVez).maxHp,
        reason: 'Duro no es repetible: no debe acumular dos veces',
      );
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

  group('Combate con dos armas (2024)', () {
    late ContentRepository repo;
    late CharacterCompiler compiler;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
      compiler = CharacterCompiler(repo);
    });

    /// Guerrero con dos armas equipadas. `dexterity` se parametriza para poder
    /// probar el caso de modificador negativo, que la regla trata distinto.
    Character dualWielder({
      required String mainHand,
      required String offHand,
      String? fightingStyleId,
      List<String> masteries = const [],
      int dexterity = 14,
      int strength = 16,
    }) =>
        Character(
          id: 'probe-dual',
          name: 'Prueba',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'soldier',
          level: 1,
          assignedScores: {
            Ability.strength: strength,
            Ability.dexterity: dexterity,
            Ability.constitution: 14,
            Ability.intelligence: 10,
            Ability.wisdom: 12,
            Ability.charisma: 8,
          },
          featureChoices: {
            if (fightingStyleId != null) 'fighting-style': [fightingStyleId],
          },
          weaponMasteryChoices: masteries,
          hpPerLevel: const [10],
          equippedWeaponIds: [mainHand, offHand],
          weaponOffHand: {offHand: true},
        );

    Attack attackFor(ComputedSheet s, String weaponId) =>
        s.attacks.firstWhere((a) => a.weaponId == weaponId);

    test('la mano secundaria no suma el modificador al daño', () {
      // Hacha de mano: Ligera, FUE 16 (+3). El ataque sí suma el mod; el daño no.
      final s = compiler.compile(
        dualWielder(mainHand: 'handaxe', offHand: 'handaxe'),
      );
      final off = attackFor(s, 'handaxe');
      expect(off.offHand, isTrue);
      expect(off.damage, '1d6', reason: 'el +3 de Fuerza no va al daño');
      expect(off.attackBonus, 5, reason: 'el ataque sí lo suma: 3 + 2');
    });

    test('el estilo Combate con Dos Armas devuelve el modificador', () {
      final s = compiler.compile(dualWielder(
        mainHand: 'handaxe',
        offHand: 'handaxe',
        fightingStyleId: 'fs-two-weapon-fighting',
      ));
      expect(attackFor(s, 'handaxe').damage, '1d6 + 3');
    });

    test('un modificador negativo sí se resta, aunque no haya estilo', () {
      // La regla omite el modificador solo cuando es positivo. Daga con DES 8
      // (−1) y FUE 8 (−1): sutil es finesse, así que toma el mayor de los dos.
      final s = compiler.compile(dualWielder(
        mainHand: 'dagger',
        offHand: 'dagger',
        dexterity: 8,
        strength: 8,
      ));
      expect(attackFor(s, 'dagger').damage, '1d4 - 1');
    });

    test('el arma sin marcar es de mano principal y usa la acción de Atacar',
        () {
      final s = compiler.compile(
        dualWielder(mainHand: 'longsword', offHand: 'handaxe'),
      );
      final main = attackFor(s, 'longsword');
      expect(main.offHand, isFalse);
      expect(main.action, AttackAction.action);
      expect(main.damage, '1d8 + 3', reason: 'la mano principal no cambia');
    });

    test('sin la maestría Mellar, la mano secundaria es acción adicional', () {
      final s = compiler.compile(
        dualWielder(mainHand: 'handaxe', offHand: 'handaxe'),
      );
      expect(attackFor(s, 'handaxe').action, AttackAction.bonusAction);
    });
  });
}
