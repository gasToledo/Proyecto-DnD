import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Pericia: duplicar el bonificador por competencia en una habilidad elegida
/// entre las que ya sos competente.
///
/// Nació de una queja concreta: "los bardos tienen pericia con el nivel 2 que
/// duplica el bonificador de competencia, pero nunca me lo hizo elegir". Estaba
/// declarada solo como texto en siete rasgos de clase.
///
/// Igual que `proficiency_choice_test`, el mecanismo se prueba contra contenido
/// inventado y al final se comprueba el catálogo oficial.
ContentRepository _repo({
  required List<Map<String, dynamic>> classFeatures,
  List<String> backgroundSkills = const ['stealth', 'perception'],
}) =>
    ContentRepository.fromJsonPacks(
      races: [
        {'id': 'r', 'name': 'Raza', 'source': 'homebrew'},
      ],
      classes: [
        {
          'id': 'c',
          'name': 'Clase',
          'source': 'homebrew',
          'hitDie': 8,
          'features': classFeatures,
        },
      ],
      backgrounds: [
        {
          'id': 'b',
          'name': 'Trasfondo',
          'source': 'homebrew',
          'skillProficiencies': backgroundSkills,
        },
      ],
    );

Character _char({
  int level = 1,
  Map<String, List<String>> choices = const {},
}) =>
    Character(
      id: 'p',
      name: 'Prueba',
      raceId: 'r',
      classId: 'c',
      backgroundId: 'b',
      level: level,
      assignedScores: {for (final a in Ability.values) a: 14},
      hpPerLevel: List.filled(level, 5),
      proficiencyChoices: choices,
    );

/// Un rasgo de clase que concede Pericia.
Map<String, dynamic> _feature({
  required int level,
  required String groupId,
  int count = 2,
  List<String> skills = const [],
}) =>
    {
      'level': level,
      'name': 'Pericia n$level',
      'effects': [
        {
          'type': 'proficiencyChoice',
          'groupId': groupId,
          'name': 'Pericia n$level',
          'count': count,
          'expertise': true,
          if (skills.isNotEmpty) 'skills': skills,
        },
      ],
    };

void main() {
  group('Mecanismo', () {
    test('solo ofrece las habilidades en las que ya sos competente', () {
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1')],
      );
      final sheet = CharacterCompiler(repo).compile(_char());
      final slot = sheet.expertiseChoiceSlots.single;

      expect(slot.expertise, isTrue);
      expect(slot.count, 2);
      // El trasfondo da Sigilo y Percepción; nada más es elegible. Las opciones
      // salen en el orden del catálogo de habilidades, no en el del trasfondo.
      expect(slot.skills, ['perception', 'stealth']);
      expect(slot.tools, isEmpty);
      expect(slot.pending, 2);
    });

    test('no se mezcla con los cupos de competencia', () {
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1')],
      );
      final sheet = CharacterCompiler(repo).compile(_char());
      expect(sheet.proficiencyChoiceSlots, isEmpty);
      expect(sheet.expertiseChoiceSlots, hasLength(1));
    });

    test('lo elegido duplica el bonificador por competencia', () {
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1')],
      );
      final sheet = CharacterCompiler(repo).compile(
        _char(choices: {
          'g1': ['stealth', 'perception']
        }),
      );

      expect(sheet.expertiseSkills, {'stealth', 'perception'});
      // Sigue siendo competente, además de tener Pericia.
      expect(sheet.skillProficiencies, containsAll(['stealth', 'perception']));

      final dex = sheet.abilityModifiers[Ability.dexterity]!;
      expect(sheet.skillModifier('stealth'), dex + sheet.proficiencyBonus * 2);
      // Una competencia sin Pericia sigue sumando el bonificador una vez.
      expect(sheet.skillModifier('acrobatics'), dex,
          reason: 'sin competencia no suma nada');
    });

    test('la Percepción pasiva refleja la Pericia', () {
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1', count: 1)],
      );
      final compiler = CharacterCompiler(repo);
      final sin = compiler.compile(_char());
      final con = compiler.compile(_char(choices: {
        'g1': ['perception']
      }));

      // Percepción es competencia del trasfondo en los dos casos.
      expect(sin.passivePerception, 10 + sin.skillModifier('perception'));
      expect(
          con.passivePerception, sin.passivePerception + con.proficiencyBonus,
          reason: 'la Pericia suma el bonificador una segunda vez');
    });

    test('un segundo cupo no puede repetir lo elegido en el primero', () {
      final repo = _repo(
        classFeatures: [
          _feature(level: 1, groupId: 'g1', count: 1),
          _feature(level: 6, groupId: 'g6', count: 1),
        ],
      );
      final sheet = CharacterCompiler(repo).compile(
        _char(level: 6, choices: {
          'g1': ['stealth']
        }),
      );

      final segundo =
          sheet.expertiseChoiceSlots.singleWhere((s) => s.groupId == 'g6');
      expect(segundo.skills, ['perception'],
          reason: 'Sigilo ya se usó en el cupo de nivel 1');
    });

    test('el cupo de un nivel superior todavía no alcanzado no aparece', () {
      final repo = _repo(
        classFeatures: [
          _feature(level: 1, groupId: 'g1', count: 1),
          _feature(level: 6, groupId: 'g6', count: 1),
        ],
      );
      final sheet = CharacterCompiler(repo).compile(_char(level: 5));
      expect(sheet.expertiseChoiceSlots.map((s) => s.groupId), ['g1']);
    });

    test('perder la competencia invalida la Pericia guardada', () {
      // Se revalida contra el catálogo actual: si el trasfondo deja de dar
      // Sigilo, la Pericia elegida sobre Sigilo deja de aplicarse y el cupo
      // vuelve a quedar pendiente. La elección no se borra de la ficha.
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1', count: 1)],
        backgroundSkills: const ['perception'],
      );
      final sheet = CharacterCompiler(repo).compile(
        _char(choices: {
          'g1': ['stealth']
        }),
      );

      expect(sheet.expertiseSkills, isEmpty);
      expect(sheet.expertiseChoiceSlots.single.pending, 1);
    });

    test('una habilidad fuera del catálogo no revienta el modificador', () {
      final repo = _repo(
        classFeatures: [_feature(level: 1, groupId: 'g1')],
      );
      final sheet = CharacterCompiler(repo).compile(_char());
      expect(sheet.skillModifier('inventada-por-homebrew'), 0);
    });

    test('la lista restringida limita las opciones', () {
      final repo = _repo(
        classFeatures: [
          _feature(level: 1, groupId: 'g1', count: 1, skills: ['perception']),
        ],
      );
      final sheet = CharacterCompiler(repo).compile(_char());
      expect(sheet.expertiseChoiceSlots.single.skills, ['perception'],
          reason: 'Sigilo es competencia pero no está en la lista del rasgo');
    });
  });

  group('Catálogo oficial', () {
    late ContentRepository repo;
    late CharacterCompiler compiler;

    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
      compiler = CharacterCompiler(repo);
    });

    ComputedSheet oficial(
      String classId,
      int level, {
      Map<String, List<String>> choices = const {},
      List<String> skills = const ['perception', 'stealth', 'arcana'],
    }) =>
        compiler.compile(Character(
          id: 'p',
          name: 'Prueba',
          raceId: 'human',
          classId: classId,
          backgroundId: 'sage',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 14},
          hpPerLevel: List.filled(level, 6),
          chosenSkills: skills,
          proficiencyChoices: choices,
        ));

    test('el Bardo de nivel 2 pide dos Pericias', () {
      // La queja original: nunca se la hizo elegir.
      final l1 = oficial('bard', 1);
      expect(l1.expertiseChoiceSlots, isEmpty,
          reason: 'Pericia llega a nivel 2');

      final l2 = oficial('bard', 2);
      final slot = l2.expertiseChoiceSlots.single;
      expect(slot.groupId, 'class:bard:expertise-2');
      expect(slot.count, 2);
      expect(slot.pending, 2);
      // Solo se ofrecen las competencias que tiene.
      expect(slot.skills, containsAll(['perception', 'stealth', 'arcana']));
      expect(slot.skills, isNot(contains('athletics')));
    });

    test('el Bardo suma el segundo par a nivel 9', () {
      final l9 = oficial('bard', 9);
      expect(
        l9.expertiseChoiceSlots.map((s) => s.groupId),
        ['class:bard:expertise-2', 'class:bard:expertise-9'],
      );
    });

    test('elegir la Pericia del Bardo duplica el bonificador', () {
      final sheet = oficial(
        'bard',
        2,
        choices: {
          'class:bard:expertise-2': ['perception', 'stealth']
        },
      );
      expect(sheet.expertiseSkills, {'perception', 'stealth'});
      expect(sheet.expertiseChoiceSlots.single.pending, 0);

      final wis = sheet.abilityModifiers[Ability.wisdom]!;
      expect(
          sheet.skillModifier('perception'), wis + sheet.proficiencyBonus * 2);
      expect(sheet.passivePerception, 10 + wis + sheet.proficiencyBonus * 2);
    });

    test('una Pericia sin elegir avisa, sin bloquear', () {
      final validator = CharacterValidator(repo);
      final c = Character(
        id: 'p',
        name: 'Prueba',
        raceId: 'human',
        classId: 'bard',
        backgroundId: 'sage',
        level: 2,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [8, 5],
        chosenSkills: const ['perception', 'stealth', 'arcana'],
      );

      final pendiente = validator.validate(c);
      final aviso =
          pendiente.singleWhere((v) => v.code == 'proficiency_choice_count');
      expect(aviso.severity, WarningSeverity.info,
          reason: 'no debe bloquear la ficha');
      expect(aviso.message, contains('0 de 2'));

      // Elegidas, el aviso desaparece.
      final resuelto = validator.validate(c.copyWith(
        proficiencyChoices: {
          'class:bard:expertise-2': const ['perception', 'stealth'],
        },
      ));
      expect(
          resuelto.where((v) => v.code == 'proficiency_choice_count'), isEmpty);
      expect(resuelto.where((v) => v.code == 'proficiency_choice_duplicate'),
          isEmpty,
          reason: 'la Pericia cae sobre una competencia a propósito');
    });

    test('el Pícaro pide dos a nivel 1 y otras dos a nivel 6', () {
      expect(oficial('rogue', 1).expertiseChoiceSlots.single.count, 2);
      expect(
        oficial('rogue', 6).expertiseChoiceSlots.map((s) => s.groupId),
        ['class:rogue:expertise-1', 'class:rogue:expertise-6'],
      );
    });

    test('el Explorador pide una a nivel 2 y dos a nivel 9', () {
      expect(oficial('ranger', 2).expertiseChoiceSlots.single.count, 1);
      final l9 = oficial('ranger', 9).expertiseChoiceSlots;
      expect(l9.map((s) => s.count), [1, 2]);
    });

    test('Académico del Mago se limita a las seis habilidades de estudio', () {
      final slot = oficial('wizard', 2).expertiseChoiceSlots.single;
      expect(slot.count, 1);
      // Se cruzan dos filtros: la lista de seis del rasgo y las competencias
      // que tiene. El trasfondo Sabio da Arcanos e Historia; Percepción y
      // Sigilo son competencias pero no están entre las seis.
      expect(slot.skills, ['arcana', 'history']);
      expect(slot.skills, isNot(contains('perception')));
    });

    test('los siete rasgos de Pericia del catálogo declaran su cupo', () {
      final conPericia = <String>{};
      for (final klass in repo.classes.values) {
        for (final f in klass.features) {
          if (f.effects
              .whereType<ProficiencyChoiceEffect>()
              .any((e) => e.expertise)) {
            conPericia.add('${klass.id} n${f.level}');
          }
        }
      }
      expect(conPericia, {
        'rogue n1',
        'rogue n6',
        'bard n2',
        'bard n9',
        'ranger n2',
        'ranger n9',
        'wizard n2',
      });
    });

    test('Mente Aguda da Pericia si ya eras competente, y si no competencia',
        () {
      // La dote ofrece cinco habilidades fijas y no filtra por competencia:
      // es una elección de competencia que se convierte en Pericia cuando ya la
      // tenías. Por eso vive en `proficiencyChoiceSlots`, no en el otro.
      final grupo = CharacterCompiler(repo)
          .compile(Character(
            id: 'p',
            name: 'Sabio',
            raceId: 'human',
            classId: 'wizard',
            backgroundId: 'sage',
            level: 4,
            assignedScores: {for (final a in Ability.values) a: 14},
            hpPerLevel: const [6, 4, 4, 4],
            featIds: const ['keen-mind'],
            chosenSkills: const ['arcana'],
          ))
          .proficiencyChoiceSlots
          .single
          .groupId;

      ComputedSheet conEleccion(String skill, List<String> propias) =>
          CharacterCompiler(repo).compile(Character(
            id: 'p',
            name: 'Sabio',
            raceId: 'human',
            classId: 'wizard',
            backgroundId: 'sage',
            level: 4,
            assignedScores: {for (final a in Ability.values) a: 14},
            hpPerLevel: const [6, 4, 4, 4],
            featIds: const ['keen-mind'],
            chosenSkills: propias,
            proficiencyChoices: {
              grupo: [skill]
            },
          ));

      // Ya competente en Arcanos: la dote lo sube a Pericia.
      final sube = conEleccion('arcana', const ['arcana']);
      expect(sube.expertiseSkills, contains('arcana'));

      // Sin competencia en Naturaleza: la dote concede competencia normal.
      final concede = conEleccion('nature', const ['arcana']);
      expect(concede.skillProficiencies, contains('nature'));
      expect(concede.expertiseSkills, isNot(contains('nature')));
    });
  });
}
