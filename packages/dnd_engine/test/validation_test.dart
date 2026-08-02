import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import 'character_compiler_test.dart' show sagan;

/// Repositorio mínimo aislado para probar las reglas nuevas sin depender del
/// contenido real del SRD (que puede crecer/cambiar con el tiempo).
ContentRepository _minimalRepo({
  Map<String, dynamic>? featOverrides,
  List<Map<String, dynamic>> extraFeats = const [],
  List<Map<String, dynamic>> classFeatures = const [],
}) {
  return ContentRepository.fromJsonPacks(
    races: [
      {
        'id': 'test-race',
        'name': 'Raza de prueba',
        'source': 'homebrew',
        'skillChoiceCount': 1,
        'skillChoiceFrom': ['athletics', 'perception'],
      },
    ],
    classes: [
      {
        'id': 'test-class',
        'name': 'Clase de prueba',
        'source': 'homebrew',
        'hitDie': 8,
        'skillChoiceCount': 1,
        'skillChoiceFrom': ['stealth', 'insight'],
        'weaponProficiencies': ['simple'],
        'asiLevels': [4],
        'features': classFeatures,
      },
    ],
    backgrounds: [
      {'id': 'test-bg', 'name': 'Trasfondo de prueba', 'source': 'homebrew'},
    ],
    feats: [
      {
        'id': 'test-feat',
        'name': 'Dote de prueba',
        'source': 'homebrew',
        'prerequisite': {
          'minAbilityScores': {'strength': 13},
        },
        ...?featOverrides,
      },
      ...extraFeats,
    ],
    weapons: [
      {
        'id': 'club',
        'name': 'Garrote',
        'source': 'homebrew',
        'category': 'simple',
        'damageDice': '1d4',
        'damageType': 'bludgeoning',
      },
      {
        'id': 'exotic-blade',
        'name': 'Hoja exótica',
        'source': 'homebrew',
        'category': 'exotic',
        'damageDice': '1d6',
        'damageType': 'slashing',
      },
    ],
  );
}

Character _minimalCharacter({
  List<String> chosenSkills = const ['athletics', 'stealth'],
  List<String> equippedWeaponIds = const ['club'],
  Map<Ability, int>? assignedScores,
  List<String> featIds = const [],
  int level = 1,
  List<AsiChoice> asiChoices = const [],
  List<int>? hpPerLevel,
}) =>
    Character(
      id: 'test',
      name: 'Test',
      raceId: 'test-race',
      classId: 'test-class',
      backgroundId: 'test-bg',
      level: level,
      assignedScores: assignedScores ??
          {
            Ability.strength: 10,
            Ability.dexterity: 10,
            Ability.constitution: 10,
            Ability.intelligence: 10,
            Ability.wisdom: 10,
            Ability.charisma: 10,
          },
      chosenSkills: chosenSkills,
      featIds: featIds,
      hpPerLevel: hpPerLevel ?? List.filled(level, 8),
      equippedWeaponIds: equippedWeaponIds,
      asiChoices: asiChoices,
    );

void main() {
  group('Reglas nuevas (repositorio aislado)', () {
    late ContentRepository repo;
    setUp(() => repo = _minimalRepo());

    test('personaje bien formado no genera advertencias nuevas', () {
      final warnings = CharacterValidator(repo).validate(_minimalCharacter());
      expect(warnings, isEmpty);
    });

    test('arma sin competencia advierte weapon_not_proficient', () {
      final c = _minimalCharacter(equippedWeaponIds: ['exotic-blade']);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('weapon_not_proficient'));
    });

    test('puntuación fuera de 3-18 advierte ability_out_of_range', () {
      final c = _minimalCharacter(assignedScores: {
        Ability.strength: 20,
        Ability.dexterity: 10,
        Ability.constitution: 10,
        Ability.intelligence: 10,
        Ability.wisdom: 10,
        Ability.charisma: 10,
      });
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('ability_out_of_range'));
    });

    test('cantidad de habilidades incorrecta advierte skill_choice_count', () {
      final c = _minimalCharacter(chosenSkills: ['athletics']);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('skill_choice_count'));
    });

    test('habilidad repetida advierte skill_choice_duplicate', () {
      final c = _minimalCharacter(chosenSkills: ['athletics', 'athletics']);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('skill_choice_duplicate'));
    });

    test(
        'habilidad fuera de las listas de raza/clase advierte skill_choice_invalid',
        () {
      final c = _minimalCharacter(chosenSkills: ['athletics', 'medicine']);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('skill_choice_invalid'));
    });

    test('nivel de ASI sin elección advierte asi_pending', () {
      final c = _minimalCharacter(level: 4, hpPerLevel: [8, 5, 5, 5]);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('asi_pending'));
    });

    test('ASI en un nivel que no corresponde advierte asi_invalid_level', () {
      final c = _minimalCharacter(
        level: 4,
        hpPerLevel: [8, 5, 5, 5],
        asiChoices: const [
          AsiChoice(level: 3, abilityIncreases: {Ability.strength: 2}),
        ],
      );
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('asi_invalid_level'));
    });

    test('dote sin cumplir prerrequisito advierte feat_prerequisite', () {
      final c = _minimalCharacter(featIds: ['test-feat']);
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), contains('feat_prerequisite'));
    });

    test('dote con prerrequisito cumplido no advierte', () {
      final c = _minimalCharacter(
        featIds: ['test-feat'],
        assignedScores: {
          Ability.strength: 13,
          Ability.dexterity: 10,
          Ability.constitution: 10,
          Ability.intelligence: 10,
          Ability.wisdom: 10,
          Ability.charisma: 10,
        },
      );
      final warnings = CharacterValidator(repo).validate(c);
      expect(warnings.map((w) => w.code), isNot(contains('feat_prerequisite')));
    });

    test('dote no repetible elegida dos veces advierte feat_duplicate', () {
      final warnings = CharacterValidator(repo)
          .validate(_minimalCharacter(featIds: ['test-feat', 'test-feat']));
      expect(warnings.map((w) => w.code), contains('feat_duplicate'));
    });

    test('dos dotes del mismo grupo advierten feat_exclusive_group', () {
      final repoExclusive = _minimalRepo(
        featOverrides: {'exclusiveGroup': 'resilient'},
        extraFeats: const [
          {
            'id': 'test-feat-2',
            'name': 'Dote de prueba 2',
            'source': 'homebrew',
            'exclusiveGroup': 'resilient',
          },
        ],
      );
      final warnings = CharacterValidator(repoExclusive).validate(
        _minimalCharacter(featIds: ['test-feat', 'test-feat-2']),
      );
      expect(
        warnings.map((w) => w.code),
        contains('feat_exclusive_group'),
      );
    });

    test('prerrequisito disyuntivo: basta cumplir una de las dos', () {
      // El PHB 2024 escribe "Fuerza o Destreza 13 o más"; con el mapa
      // conjuntivo esto no se podía expresar sin exigir las dos.
      Map<Ability, int> scores(int str, int dex) => {
            Ability.strength: str,
            Ability.dexterity: dex,
            Ability.constitution: 10,
            Ability.intelligence: 10,
            Ability.wisdom: 10,
            Ability.charisma: 10,
          };
      final repoAny = _minimalRepo(featOverrides: {
        'prerequisite': {
          'anyAbilityScores': {'strength': 13, 'dexterity': 13},
        },
      });
      List<String> codesFor(int str, int dex) => CharacterValidator(repoAny)
          .validate(_minimalCharacter(
              featIds: ['test-feat'], assignedScores: scores(str, dex)))
          .map((w) => w.code)
          .toList();

      expect(codesFor(13, 8), isNot(contains('feat_prerequisite')),
          reason: 'alcanza con Fuerza');
      expect(codesFor(8, 13), isNot(contains('feat_prerequisite')),
          reason: 'alcanza con Destreza');
      expect(codesFor(8, 8), contains('feat_prerequisite'),
          reason: 'ninguna de las dos llega a 13');
    });

    test('el motor sigue sin bloquear pese a las advertencias', () {
      final c = _minimalCharacter(chosenSkills: const []);
      expect(() => CharacterCompiler(repo).compile(c), returnsNormally);
    });
  });

  // La UI consulta estos dos métodos para no ofrecer dotes inelegibles, en vez
  // de reimplementar la comprobación: son la misma lógica que usa `validate`.
  group('Prerrequisitos consultables desde afuera', () {
    late ContentRepository repo;
    setUp(() => repo = _minimalRepo());

    ComputedSheet sheetOf(ContentRepository r, Character c) =>
        CharacterCompiler(r).compile(c);

    test('unmetFeatPrerequisite explica la característica que falta', () {
      final c = _minimalCharacter();
      final motivo = CharacterValidator(repo).unmetFeatPrerequisite(
        repo.feat('test-feat')!,
        c,
        sheetOf(repo, c),
      );
      expect(motivo, 'STR 13');
    });

    test('unmetFeatPrerequisite devuelve null cuando se cumple', () {
      final c = _minimalCharacter(assignedScores: {
        Ability.strength: 13,
        Ability.dexterity: 10,
        Ability.constitution: 10,
        Ability.intelligence: 10,
        Ability.wisdom: 10,
        Ability.charisma: 10,
      });
      final motivo = CharacterValidator(repo).unmetFeatPrerequisite(
        repo.feat('test-feat')!,
        c,
        sheetOf(repo, c),
      );
      expect(motivo, isNull);
    });

    test('un rasgo de clase puede ser prerrequisito de una dote', () {
      final withoutFeature = _minimalRepo(featOverrides: {
        'prerequisite': {'requiredClassFeature': 'Estilo de Combate'},
      });
      final c = _minimalCharacter();
      expect(
        CharacterValidator(withoutFeature).unmetFeatPrerequisite(
          withoutFeature.feat('test-feat')!,
          c,
          sheetOf(withoutFeature, c),
        ),
        contains('Estilo de Combate'),
      );

      final withFeature = _minimalRepo(
        featOverrides: {
          'prerequisite': {'requiredClassFeature': 'Estilo de Combate'},
        },
        classFeatures: const [
          {
            'level': 1,
            'name': 'Estilo de Combate',
            'description': 'Obtienes una dote de estilo de combate.',
          },
        ],
      );
      expect(
        CharacterValidator(withFeature).unmetFeatPrerequisite(
          withFeature.feat('test-feat')!,
          c,
          sheetOf(withFeature, c),
        ),
        isNull,
      );
    });

    test('una dote excluye las demás de su mismo grupo', () {
      final repoExclusive = _minimalRepo(
        featOverrides: {'exclusiveGroup': 'resilient'},
        extraFeats: const [
          {
            'id': 'test-feat-2',
            'name': 'Dote de prueba 2',
            'source': 'homebrew',
            'exclusiveGroup': 'resilient',
          },
        ],
      );
      final c = _minimalCharacter();
      final motivo = CharacterValidator(repoExclusive).unmetFeatPrerequisite(
        repoExclusive.feat('test-feat-2')!,
        c,
        sheetOf(repoExclusive, c),
        held: const {'test-feat'},
      );
      expect(motivo, contains('resilient'));
    });

    test('una dote que exige otra dote se evalúa contra las ya tenidas', () {
      final repoChain = _minimalRepo(featOverrides: {
        'prerequisite': {
          'requiredFeatIds': ['base-feat'],
        },
      });
      final validator = CharacterValidator(repoChain);
      final feat = repoChain.feat('test-feat')!;

      // Sin la dote base: no se puede tomar.
      final sinBase = _minimalCharacter();
      expect(
        validator.unmetFeatPrerequisite(
            feat, sinBase, sheetOf(repoChain, sinBase)),
        isNotNull,
      );

      // `held` permite evaluar una dote que todavía no está elegida contra el
      // set real de dotes del personaje: es lo que hace el selector.
      expect(
        validator.unmetFeatPrerequisite(
          feat,
          sinBase,
          sheetOf(repoChain, sinBase),
          held: const {'base-feat'},
        ),
        isNull,
      );
    });

    test('heldFeatIds junta las elegidas y las elecciones abiertas', () {
      // Desde que el estilo de combate es una elección más, `copyWith` sí la
      // expone: ya no hace falta fijarla por JSON.
      final c = _minimalCharacter(featIds: ['test-feat']).copyWith(
        featureChoices: const {
          'fighting-style': ['style-feat'],
        },
      );
      expect(
        CharacterValidator(repo).heldFeatIds(c),
        {'test-feat', 'style-feat'},
      );
    });

    test('heldFeatIds alcanza a cualquier grupo, no solo al estilo', () {
      // Es lo que hace que los prerrequisitos entre invocaciones funcionen sin
      // que la validación conozca el grupo.
      final c = _minimalCharacter().copyWith(
        featureChoices: const {
          'warlock-invocation': ['pact-a', 'pact-b'],
        },
      );
      expect(
        CharacterValidator(repo).heldFeatIds(c),
        containsAll(<String>['pact-a', 'pact-b']),
      );
    });
  });

  group('Regresión contra el contenido real del SRD', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    test('Sagan nivel 1 no dispara ninguna de las reglas nuevas', () {
      final warnings = CharacterValidator(repo).validate(sagan());
      const newCodes = {
        'weapon_not_proficient',
        'ability_out_of_range',
        'skill_choice_count',
        'skill_choice_duplicate',
        'skill_choice_invalid',
        'asi_pending',
        'asi_invalid_level',
        'feat_prerequisite',
      };
      expect(
          warnings.map((w) => w.code).toSet().intersection(newCodes), isEmpty);
    });

    test('Bardo acepta cualquier habilidad válida cuando su lista está vacía',
        () {
      final json = sagan().toJson()
        ..['raceId'] = 'elf'
        ..['lineageId'] = 'elf-drow'
        ..['classId'] = 'bard'
        ..['chosenSkills'] = const [
          'persuasion',
          'deception',
          'insight',
          'perception',
        ];
      final bard = Character.fromJson(json);

      final warnings = CharacterValidator(repo).validate(bard);

      expect(
        warnings.map((warning) => warning.code),
        isNot(contains('skill_choice_invalid')),
      );
      expect(
        warnings.map((warning) => warning.code),
        isNot(contains('skill_choice_count')),
      );
    });

    // El Alto Elfo recibe Prestidigitación a nivel 1 y Detectar Magia a nivel
    // 3, ambos por el linaje y ambos en la lista de Mago. Elegirlos otra vez
    // desde la clase gasta un cupo sin ganar nada: el rasgo ya los da siempre
    // preparados y con un uso gratis.
    Character altoElfoMago({
      List<String> cantrips = const [],
      List<String> spells = const [],
    }) =>
        Character.fromJson(sagan(level: 3, hp: [6, 4, 4]).toJson()
          ..['raceId'] = 'elf'
          ..['lineageId'] = 'elf-high'
          ..['classId'] = 'wizard'
          ..['subclassId'] = 'evocation'
          ..['fightingStyleId'] = null
          ..['weaponMasteryChoices'] = const <String>[]
          ..['chosenSkills'] = const ['arcana', 'investigation']
          ..['cantripIds'] = cantrips
          ..['spellIds'] = spells);

    test('avisa si se elige un truco que el linaje ya concede', () {
      final warnings = CharacterValidator(repo)
          .validate(altoElfoMago(cantrips: const ['prestidigitation']));

      expect(
        warnings.map((w) => w.code),
        contains('cantrip_already_granted'),
      );
    });

    test('avisa si se prepara un conjuro que el linaje ya concede', () {
      // Detectar Magia entra a nivel 3 por el linaje Alto Elfo.
      final warnings = CharacterValidator(repo)
          .validate(altoElfoMago(spells: const ['detect-magic']));

      expect(
        warnings.map((w) => w.code),
        contains('spell_already_granted'),
      );
    });

    test('no avisa por conjuros que el linaje no concede', () {
      final warnings = CharacterValidator(repo).validate(
        altoElfoMago(cantrips: const ['fire-bolt'], spells: const ['shield']),
      );

      expect(
        warnings.map((w) => w.code),
        isNot(contains('cantrip_already_granted')),
      );
      expect(
        warnings.map((w) => w.code),
        isNot(contains('spell_already_granted')),
      );
    });

    group('Combate con dos armas', () {
      Character duelist({
        List<String> equipped = const ['dagger', 'shortsword'],
        Map<String, bool> offHand = const {'dagger': true},
      }) =>
          Character.fromJson(sagan().toJson()
            ..['classId'] = 'rogue'
            ..['fightingStyleId'] = null
            ..['weaponMasteryChoices'] = const <String>[]
            ..['chosenSkills'] = const ['stealth', 'acrobatics', 'perception']
            ..['equippedWeaponIds'] = equipped
            ..['weaponOffHand'] = offHand);

      List<String> codesFor(Character c) =>
          CharacterValidator(repo).validate(c).map((w) => w.code).toList();

      test('dos armas Ligeras no disparan ninguna advertencia de mano', () {
        final codes = codesFor(duelist());
        expect(codes, isNot(contains('off_hand_not_light')));
        expect(codes, isNot(contains('off_hand_without_pair')));
        expect(codes, isNot(contains('too_many_off_hands')));
      });

      test('un arma no Ligera en la secundaria advierte', () {
        // La espada larga es marcial y no es Ligera.
        final codes = codesFor(duelist(
          equipped: const ['dagger', 'longsword'],
          offHand: const {'longsword': true},
        ));
        expect(codes, contains('off_hand_not_light'));
      });

      test('sin otra arma Ligera en la principal, el ataque no se puede hacer',
          () {
        final codes = codesFor(duelist(
          equipped: const ['dagger', 'longsword'],
          offHand: const {'dagger': true},
        ));
        expect(codes, contains('off_hand_without_pair'));
      });

      test('marcar dos armas como secundaria advierte', () {
        final codes = codesFor(duelist(
          offHand: const {'dagger': true, 'shortsword': true},
        ));
        expect(codes, contains('too_many_off_hands'));
      });

      test('una marca de un arma desequipada se ignora en silencio', () {
        // Desequipar no debería ensuciar la ficha con advertencias.
        final codes = codesFor(duelist(
          equipped: const ['shortsword'],
          offHand: const {'dagger': true},
        ));
        expect(codes, isNot(contains('off_hand_not_light')));
        expect(codes, isNot(contains('too_many_off_hands')));
        expect(codes, isNot(contains('off_hand_without_pair')));
      });
    });

    test('Bardo sigue rechazando un identificador de habilidad desconocido',
        () {
      final json = sagan().toJson()
        ..['raceId'] = 'elf'
        ..['lineageId'] = 'elf-drow'
        ..['classId'] = 'bard'
        ..['chosenSkills'] = const [
          'persuasion',
          'deception',
          'insight',
          'not-a-skill',
        ];
      final bard = Character.fromJson(json);

      final warnings = CharacterValidator(repo).validate(bard);

      expect(
        warnings.map((warning) => warning.code),
        contains('skill_choice_invalid'),
      );
    });
  });
}
