import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Compañeros invocados: cómo el compilador los saca de los rasgos y cómo el
/// estado de partida los lleva.
///
/// El contenido de este archivo es sintético a propósito. Las criaturas reales
/// se prueban contra el catálogo en `content_integrity_test.dart`; acá lo que
/// se verifica es la maquinaria, y un perfil de mentira con números redondos la
/// deja legible.
void main() {
  Map<String, dynamic> creature(
    String id, {
    String ac = '10',
    String hp = '10',
    bool scalesWithSpellLevel = false,
  }) =>
      {
        'id': id,
        'name': id,
        'source': 'srd_2024',
        'ac': ac,
        'hp': hp,
        'scalesWithSpellLevel': scalesWithSpellLevel,
      };

  ContentRepository repoWith(List<Map<String, dynamic>> companionEffects) =>
      ContentRepository.fromJsonPacks(
        races: [
          {'id': 'human', 'name': 'Humano', 'source': 'srd_2024', 'speed': 30},
        ],
        backgrounds: [
          {'id': 'sage', 'name': 'Sabio', 'source': 'srd_2024'},
        ],
        classes: [
          {
            'id': 'tinker',
            'name': 'Manitas',
            'source': 'srd_2024',
            'hitDie': 8,
            'features': [
              {'level': 1, 'name': 'Rasgo', 'effects': companionEffects},
            ],
          },
        ],
        spells: [
          {
            'id': 'find-familiar',
            'name': 'Encontrar Familiar',
            'source': 'srd_2024',
            'level': 1,
          },
        ],
        creatures: [
          creature('cannon', ac: '18', hp: '5*level'),
          creature('defender', ac: '12+INT', hp: '5+5*level'),
          creature('steed',
              ac: '10+spellLevel',
              hp: '5+10*spellLevel',
              scalesWithSpellLevel: true),
          creature('cat'),
          creature('owl'),
        ],
      );

  ComputedSheet compile(
    ContentRepository repo, {
    int level = 5,
    int intelligence = 18,
    List<String> spellIds = const [],
  }) =>
      CharacterCompiler(repo).compile(
        Character(
          id: 'probe',
          name: 'Prueba',
          raceId: 'human',
          classId: 'tinker',
          backgroundId: 'sage',
          level: level,
          spellIds: spellIds,
          assignedScores: {
            Ability.strength: 10,
            Ability.dexterity: 10,
            Ability.constitution: 10,
            Ability.intelligence: intelligence,
            Ability.wisdom: 10,
            Ability.charisma: 10,
          },
          hpPerLevel: List.filled(level, 5),
        ),
      );

  group('El compilador resuelve los compañeros', () {
    test('un rasgo con companion aparece en la ficha con su fuente', () {
      final sheet = compile(
        repoWith([
          {
            'type': 'companion',
            'id': 'steel-defender',
            'name': 'Defensor de Acero',
            'creatureIds': ['defender'],
          },
        ]),
      );
      expect(sheet.companions, hasLength(1));
      final option = sheet.companions.single;
      expect(option.id, 'steel-defender');
      expect(option.name, 'Defensor de Acero');
      expect(option.source, 'Rasgo');
      expect(option.maxActive, 1);
      expect(option.forms.single.id, 'defender');
    });

    test('un personaje sin rasgos de compañero no tiene ninguno', () {
      expect(compile(repoWith(const [])).companions, isEmpty);
    });

    test('gana la declaración de mayor nivel del mismo id', () {
      final repo = ContentRepository.fromJsonPacks(
        races: [
          {'id': 'human', 'name': 'Humano', 'source': 'srd_2024', 'speed': 30},
        ],
        backgrounds: [
          {'id': 'sage', 'name': 'Sabio', 'source': 'srd_2024'},
        ],
        classes: [
          {
            'id': 'tinker',
            'name': 'Manitas',
            'source': 'srd_2024',
            'hitDie': 8,
            'features': [
              {
                'level': 1,
                'name': 'Cañón Arcano',
                'effects': [
                  {
                    'type': 'companion',
                    'id': 'cannon',
                    'name': 'Cañón',
                    'creatureIds': ['cannon'],
                    'maxActive': 1,
                  },
                ],
              },
              {
                'level': 5,
                'name': 'Cañón Mejorado',
                'effects': [
                  {
                    'type': 'companion',
                    'id': 'cannon',
                    'name': 'Cañón',
                    'creatureIds': ['cannon-improved'],
                    'maxActive': 2,
                  },
                ],
              },
            ],
          },
        ],
        creatures: [
          creature('cannon', ac: '18', hp: '5*level'),
          creature('cannon-improved', ac: '18', hp: '6*level'),
        ],
      );
      final before = compile(repo, level: 4).companions.single;
      expect(before.maxActive, 1);
      expect(before.forms.single.id, 'cannon');

      // El rasgo de nivel 5 pisa al de nivel 1 entero: cambia el perfil y la
      // cantidad, no solo la cantidad.
      final after = compile(repo, level: 5).companions.single;
      expect(after.maxActive, 2);
      expect(after.forms.single.id, 'cannon-improved');
    });

    test('una instancia vieja sigue el perfil nuevo si la forma es única', () {
      // El Artillero que sube a nivel 9 con el cañón invocado: el compañero
      // creció, así que la instancia guardada apunta al perfil de ahora en vez
      // de quedar huérfana.
      final option = CompanionOption(
        id: 'cannon',
        name: 'Cañón',
        source: 'Rasgo',
        forms: [Creature.fromJson(creature('cannon-improved'))],
      );
      expect(option.form('cannon')!.id, 'cannon-improved');
    });

    test('con varias formas, una que no existe no se adivina', () {
      final option = CompanionOption(
        id: 'familiar',
        name: 'Familiar',
        source: 'Rasgo',
        forms: [
          Creature.fromJson(creature('cat')),
          Creature.fromJson(creature('owl')),
        ],
      );
      expect(option.form('gato-inventado'), isNull);
    });

    test('requiresSpell descarta el compañero si el conjuro no está', () {
      final repo = repoWith([
        {
          'type': 'companion',
          'id': 'familiar',
          'name': 'Familiar',
          'creatureIds': ['cat', 'owl'],
          'requiresSpell': 'find-familiar',
        },
      ]);
      expect(compile(repo).companions, isEmpty);
      expect(
        compile(repo, spellIds: ['find-familiar']).companions.single.forms,
        hasLength(2),
      );
    });

    test('una criatura que el catálogo no conoce se descarta sin romper', () {
      final sheet = compile(
        repoWith([
          {
            'type': 'companion',
            'id': 'ghost',
            'name': 'Fantasma',
            'creatureIds': ['no-existe'],
          },
        ]),
      );
      expect(sheet.companions, isEmpty);
    });

    test('las formas llegan sin resolver, para que las resuelva quien invoca',
        () {
      final option = compile(
        repoWith([
          {
            'type': 'companion',
            'id': 'steed',
            'name': 'Corcel',
            'creatureIds': ['steed'],
          },
        ]),
      ).companions.single;
      expect(option.scalesWithSpellLevel, isTrue);
      expect(option.forms.single.hp, '5+10*spellLevel');
    });
  });

  group('Resolver un perfil contra el personaje', () {
    test('el Defensor de un nivel 5 con INT 18 da PG 30 y CA 16', () {
      final sheet = compile(
        repoWith([
          {
            'type': 'companion',
            'id': 'steel-defender',
            'name': 'Defensor',
            'creatureIds': ['defender'],
          },
        ]),
      );
      final resolved = sheet.companions.single.forms.single.resolve(
        CreatureVars.from(
          level: sheet.level,
          proficiencyBonus: sheet.proficiencyBonus,
          abilityModifiers: sheet.abilityModifiers,
        ),
      );
      expect(resolved.maxHp, 30);
      expect(resolved.armorClass, 16);
    });

    test('el Corcel escala con el espacio gastado, no con el nivel', () {
      final steed = repoWith(const []).creature('steed')!;
      int hpAt(int spellLevel) => steed
          .resolve(
            CreatureVars.from(
              level: 20,
              proficiencyBonus: 6,
              abilityModifiers: const {},
              spellLevel: spellLevel,
            ),
          )
          .maxHp;
      expect(hpAt(2), 25);
      expect(hpAt(4), 45);
    });
  });

  group('Contra el contenido real', () {
    late ContentRepository srd;

    setUpAll(() async {
      srd = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    ComputedSheet build({
      required String classId,
      String? subclassId,
      int level = 5,
      List<String> spellIds = const [],
      List<String> featIds = const [],
      Map<String, List<String>> featureChoices = const {},
      Map<Ability, int> scores = const {},
    }) =>
        CharacterCompiler(srd).compile(
          Character(
            id: 'probe',
            name: 'Prueba',
            raceId: 'human',
            classId: classId,
            subclassId: subclassId,
            backgroundId: 'sage',
            level: level,
            spellIds: spellIds,
            featIds: featIds,
            featureChoices: featureChoices,
            assignedScores: {
              for (final a in Ability.values) a: scores[a] ?? 10,
            },
            hpPerLevel: List.filled(level, 5),
          ),
        );

    CompanionOption? companion(ComputedSheet s, String id) {
      for (final o in s.companions) {
        if (o.id == id) return o;
      }
      return null;
    }

    test('el Artillero tiene un cañón, y dos a partir de nivel 15', () {
      final at3 = companion(
        build(classId: 'artificer', subclassId: 'artillerist', level: 3),
        'eldritch-cannon',
      );
      expect(at3, isNotNull);
      expect(at3!.maxActive, 1);
      expect(
        companion(
          build(classId: 'artificer', subclassId: 'artillerist', level: 15),
          'eldritch-cannon',
        )!
            .maxActive,
        2,
      );
    });

    test('el cañón crece a nivel 9 y no vuelve atrás a nivel 15', () {
      CompanionOption cannonAt(int level) => companion(
            build(
                classId: 'artificer', subclassId: 'artillerist', level: level),
            'eldritch-cannon',
          )!;

      expect(cannonAt(3).forms.single.id, 'eldritch-cannon');
      // Cañón Explosivo: el mismo id, otro perfil.
      expect(cannonAt(9).forms.single.id, 'eldritch-cannon-explosive');
      // Posición Fortificada suma el segundo cañón sin revivir el perfil viejo.
      expect(cannonAt(15).forms.single.id, 'eldritch-cannon-explosive');
    });

    test('el Cañón Explosivo pega más fuerte y suma la detonación', () {
      final sheet = build(
        classId: 'artificer',
        subclassId: 'artillerist',
        level: 9,
        scores: {Ability.intelligence: 18},
      );
      final resolved =
          companion(sheet, 'eldritch-cannon')!.forms.single.resolve(
                CreatureVars.from(
                  level: sheet.level,
                  proficiencyBonus: sheet.proficiencyBonus,
                  abilityModifiers: sheet.abilityModifiers,
                  spellAttackBonus: sheet.spellcasting!.attackBonus,
                  spellSaveDc: sheet.spellcasting!.saveDc,
                ),
              );
      final byName = {for (final a in resolved.actions) a.name: a};
      expect(byName['Lanzallamas']!.damage, '3d8');
      expect(byName['Ballesta de Fuerza']!.damage, '3d8');
      expect(byName['Protector']!.damage, '2d8+4');
      expect(byName['Detonar']!.reaction, isTrue);
    });

    test('el Defensor de Acero sale con los números del libro', () {
      final sheet = build(
        classId: 'artificer',
        subclassId: 'battle-smith',
        level: 5,
        scores: {Ability.intelligence: 18},
      );
      final defender = companion(sheet, 'steel-defender');
      expect(defender, isNotNull);

      final resolved = defender!.forms.single.resolve(
        CreatureVars.from(
          level: sheet.level,
          proficiencyBonus: sheet.proficiencyBonus,
          abilityModifiers: sheet.abilityModifiers,
          spellAttackBonus: sheet.spellcasting!.attackBonus,
          spellSaveDc: sheet.spellcasting!.saveDc,
        ),
      );
      // PG 5 + 5×nivel, CA 12 + INT, ataque con tu bono de conjuros.
      expect(resolved.maxHp, 30);
      expect(resolved.armorClass, 16);
      expect(
          resolved.actions.first.attackBonus, sheet.spellcasting!.attackBonus);
      expect(resolved.actions.first.damage, '1d8+6');
    });

    test('el Señor de Bestias elige entre tierra, mar y aire', () {
      final beast = companion(
        build(classId: 'ranger', subclassId: 'beast-master', level: 3),
        'primal-companion',
      );
      expect(beast, isNotNull);
      expect(
        beast!.forms.map((f) => f.id),
        containsAll(
            ['beast-of-the-land', 'beast-of-the-sea', 'beast-of-the-sky']),
      );
    });

    test('el Mago solo tiene familiar si aprendió el conjuro', () {
      expect(companion(build(classId: 'wizard'), 'familiar'), isNull);
      final withSpell = companion(
        build(classId: 'wizard', spellIds: ['find-familiar']),
        'familiar',
      );
      expect(withSpell, isNotNull);
      expect(withSpell!.forms.length, 24);
    });

    test('el Pacto de la Cadena suma las formas especiales', () {
      final sheet = build(
        classId: 'warlock',
        level: 2,
        featIds: ['pact-of-the-chain'],
        featureChoices: {
          'warlock-invocation': ['pact-of-the-chain'],
        },
      );
      final familiar = companion(sheet, 'familiar');
      expect(familiar, isNotNull, reason: 'el pacto concede el conjuro');
      expect(
        familiar!.forms.map((f) => f.id),
        containsAll(['imp', 'quasit', 'pseudodragon', 'sprite']),
      );
    });

    test('el Corcel Sobrenatural escala con el espacio, no con el nivel', () {
      final sheet = build(classId: 'paladin', level: 5);
      final steed = companion(sheet, 'otherworldly-steed');
      expect(steed, isNotNull);
      expect(steed!.scalesWithSpellLevel, isTrue);

      ResolvedCreature at(int spellLevel) => steed.forms.single.resolve(
            CreatureVars.from(
              level: sheet.level,
              proficiencyBonus: sheet.proficiencyBonus,
              abilityModifiers: sheet.abilityModifiers,
              spellLevel: spellLevel,
            ),
          );
      expect(at(2).maxHp, 25);
      expect(at(2).armorClass, 12);
      expect(at(3).maxHp, 35);
    });

    test('los conjuros de invocación llegan a quien los conoce', () {
      final wizard = build(
        classId: 'wizard',
        level: 11,
        spellIds: ['summon-dragon', 'summon-undead'],
      );
      expect(
        wizard.companions.map((c) => c.id),
        containsAll(['summon-dragon', 'summon-undead']),
      );
      // Y no los que no aprendió.
      expect(companion(wizard, 'summon-fiend'), isNull);

      // El druida tiene los suyos, que no son los del mago.
      final druid = build(
        classId: 'druid',
        level: 9,
        spellIds: ['summon-beast'],
      );
      expect(companion(druid, 'summon-beast')!.forms, hasLength(3));
      expect(companion(druid, 'summon-undead'), isNull);
    });

    test('un espíritu no se puede invocar por debajo del nivel del conjuro',
        () {
      final wizard = build(
        classId: 'wizard',
        level: 17,
        spellIds: ['summon-fiend', 'summon-dragon'],
      );
      // Invocar Demonio es de nivel 6 e Invocar Dragón de nivel 5: con un
      // espacio menor, la fórmula de PG contaría niveles negativos.
      expect(companion(wizard, 'summon-fiend')!.minSpellLevel, 6);
      expect(companion(wizard, 'summon-dragon')!.minSpellLevel, 5);
    });

    test('el Espíritu dracónico sale con los números del libro', () {
      final sheet = build(
        classId: 'wizard',
        level: 17,
        spellIds: ['summon-dragon'],
        scores: {Ability.intelligence: 20},
      );
      final option = companion(sheet, 'summon-dragon')!;
      ResolvedCreature at(int slot) => option.forms.single.resolve(
            CreatureVars.from(
              level: sheet.level,
              proficiencyBonus: sheet.proficiencyBonus,
              abilityModifiers: sheet.abilityModifiers,
              spellAttackBonus: sheet.spellcasting!.attackBonus,
              spellSaveDc: sheet.spellcasting!.saveDc,
              spellLevel: slot,
            ),
          );

      // CA 14 + nivel, PG 50 + 10 por cada nivel por encima del 5.
      expect(at(5).armorClass, 19);
      expect(at(5).maxHp, 50);
      expect(at(7).armorClass, 21);
      expect(at(7).maxHp, 70);

      final byName = {for (final a in at(7).actions) a.name: a};
      // Desgarro: 1d6 + 4 + el nivel del conjuro.
      expect(byName['Desgarro']!.damage, '1d6+11');
      // Ataque múltiple: la mitad del nivel del conjuro, redondeando abajo.
      expect(byName['Ataque múltiple']!.description, contains('3 ataques'));
    });

    test('un Guerrero no tiene ningún compañero', () {
      expect(build(classId: 'fighter', level: 20).companions, isEmpty);
    });
  });

  group('Estado de partida', () {
    late CombatState combat;
    late CompanionOption option;
    late Creature form;
    final vars = CreatureVars.from(
      level: 5,
      proficiencyBonus: 3,
      abilityModifiers: const {Ability.intelligence: 4},
    );

    setUp(() {
      final repo = repoWith(const []);
      form = repo.creature('defender')!;
      option = CompanionOption(
        id: 'steel-defender',
        name: 'Defensor',
        source: 'Rasgo',
        forms: [form],
      );
      combat = CombatState(currentHp: 40);
    });

    test('invocar lo deja con los PG al máximo', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      expect(combat.companions, hasLength(1));
      expect(instance.currentHp, 30);
      expect(instance.creatureId, 'defender');
      expect(instance.spellLevel, 0);
    });

    test('invocar de nuevo reemplaza al que había cuando maxActive es 1', () {
      final first = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.damageCompanion(combat, first, 10);
      final second = CombatOps.summonCompanion(combat, option, form, vars);
      expect(combat.companions, hasLength(1));
      expect(combat.companions.single, same(second));
      expect(second.currentHp, 30);
    });

    test('con maxActive 2 conviven dos y el tercero desplaza al primero', () {
      final two = CompanionOption(
        id: option.id,
        name: option.name,
        source: option.source,
        forms: option.forms,
        maxActive: 2,
      );
      final first = CombatOps.summonCompanion(combat, two, form, vars);
      final second = CombatOps.summonCompanion(combat, two, form, vars);
      expect(combat.companions, hasLength(2));
      final third = CombatOps.summonCompanion(combat, two, form, vars);
      expect(combat.companions, [second, third]);
      expect(combat.companions, isNot(contains(first)));
    });

    test('el daño consume primero los PG temporales', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.setCompanionTempHp(instance, 5);
      CombatOps.damageCompanion(combat, instance, 8);
      expect(instance.tempHp, 0);
      expect(instance.currentHp, 27);
    });

    test('llegar a 0 PG lo destruye y lo saca de la ficha', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      expect(CombatOps.damageCompanion(combat, instance, 999), isTrue);
      expect(instance.currentHp, 0);
      expect(combat.companions, isEmpty);
    });

    test('el daño que no llega a 0 no lo destruye', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      expect(CombatOps.damageCompanion(combat, instance, 29), isFalse);
      expect(combat.companions, hasLength(1));
      expect(instance.currentHp, 1);
    });

    test('los PG temporales pueden salvarlo del golpe que lo destruiría', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.setCompanionTempHp(instance, 10);
      expect(CombatOps.damageCompanion(combat, instance, 35), isFalse);
      expect(instance.currentHp, 5);
      expect(combat.companions, hasLength(1));
    });

    test('curar no pasa del máximo', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.damageCompanion(combat, instance, 20);
      CombatOps.healCompanion(instance, 30, 100);
      expect(instance.currentHp, 30);
    });

    test('despedir lo saca de la lista', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.dismissCompanion(combat, instance);
      expect(combat.companions, isEmpty);
    });

    test('el descanso largo lo deja a tope y sin condiciones', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.damageCompanion(combat, instance, 25);
      CombatOps.setCompanionTempHp(instance, 4);
      instance.conditions.add('prone');

      CombatOps.longRest(combat, 40, const [], 5, companionMaxHp: (_) => 30);

      expect(instance.currentHp, 30);
      expect(instance.tempHp, 0);
      expect(instance.conditions, isEmpty);
    });

    test('el descanso largo sin resolutor no toca a los compañeros', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.damageCompanion(combat, instance, 25);
      CombatOps.longRest(combat, 40, const [], 5);
      expect(instance.currentHp, 5);
    });

    test('el estado sobrevive a un ida y vuelta por JSON', () {
      final instance = CombatOps.summonCompanion(combat, option, form, vars);
      CombatOps.damageCompanion(combat, instance, 7);
      instance.conditions.add('prone');

      final restored = CombatState.fromJson(combat.toJson());

      expect(restored.companions, hasLength(1));
      final back = restored.companions.single;
      expect(back.optionId, 'steel-defender');
      expect(back.creatureId, 'defender');
      expect(back.currentHp, 23);
      expect(back.conditions, {'prone'});
    });
  });
}
