import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Idiomas (SRD 5.2.1, "Elige tus idiomas").
///
/// La regla 2024 es corta y tiene tres partes que el motor separa: todo
/// personaje sabe **Común**; elige **dos** de la tabla de estándar; y un rasgo
/// puede conceder uno fijo o dejar elegir otro. En 2024 los idiomas **no
/// vienen de la especie**, a diferencia de 2014.
ContentRepository _repo({
  List<Map<String, dynamic>> classFeatures = const [],
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
        {'id': 'b', 'name': 'Trasfondo', 'source': 'homebrew'},
      ],
    );

Character _char({
  List<String> languages = const [],
  Map<String, List<String>> languageChoices = const {},
  int level = 1,
}) =>
    Character(
      id: 'p',
      name: 'Prueba',
      raceId: 'r',
      classId: 'c',
      backgroundId: 'b',
      level: level,
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: List.filled(level, 5),
      languages: languages,
      languageChoices: languageChoices,
    );

void main() {
  group('Catálogo', () {
    test('Común es estándar y es el que sabe todo personaje', () {
      expect(Language.universal, Language.common);
      expect(Language.common.standard, isTrue);
    });

    test('los elegibles en el origen son los estándar menos Común', () {
      final ids = Language.originChoices.map((l) => l.id);
      expect(ids, isNot(contains('common')));
      expect(ids, contains('elvish'));
      // Un inusual no se puede elegir al crear el personaje.
      expect(ids, isNot(contains('druidic')));
      expect(Language.originChoices, hasLength(9));
    });

    test('los inusuales existen pero no son estándar', () {
      for (final id in [
        'abyssal',
        'celestial',
        'deep-speech',
        'druidic',
        'infernal',
        'primordial',
        'sylvan',
        'thieves-cant',
        'undercommon',
      ]) {
        final l = Language.fromId(id);
        expect(l, isNotNull, reason: id);
        expect(l!.standard, isFalse, reason: id);
      }
    });

    test('un id desconocido cae al id capitalizado en vez de fallar', () {
      // Es la red para el homebrew, igual que en Skill y en damage_type.
      expect(Language.labelFor('quenya'), 'Quenya');
      expect(Language.labelFor('elvish'), 'Elfo');
    });
  });

  group('Los del origen', () {
    test('Común se sabe siempre, sin elegirlo', () {
      final sheet = CharacterCompiler(_repo()).compile(_char());
      expect(sheet.languages, contains('common'));
    });

    test('los dos elegidos se suman', () {
      final sheet = CharacterCompiler(_repo()).compile(
        _char(languages: ['elvish', 'dwarvish']),
      );
      expect(sheet.languages, {'common', 'elvish', 'dwarvish'});
    });

    test('de más se recortan al cupo', () {
      final sheet = CharacterCompiler(_repo()).compile(
        _char(languages: ['elvish', 'dwarvish', 'orc']),
      );
      expect(sheet.languages, isNot(contains('orc')));
    });

    test('la especie no concede ninguno: en 2024 vienen del origen', () {
      // Regresión contra volver al modelo 2014. Si alguna especie oficial
      // empieza a declararlos, este test no lo ve; lo vigila el que recorre el
      // catálogo, más abajo.
      final sheet = CharacterCompiler(_repo()).compile(_char());
      expect(sheet.languages, {'common'});
    });
  });

  group('Los que concede un rasgo', () {
    ContentRepository conRasgo(Map<String, dynamic> effect) => _repo(
          classFeatures: [
            {
              'level': 1,
              'name': 'Rasgo',
              'effects': [effect],
            },
          ],
        );

    test('un idioma fijo se suma, aunque sea inusual', () {
      final sheet = CharacterCompiler(
        conRasgo({'type': 'language', 'language': 'druidic'}),
      ).compile(_char(languages: ['elvish', 'dwarvish']));
      expect(sheet.languages, containsAll(['common', 'druidic']));
    });

    test('no gasta ninguna de las dos elecciones del origen', () {
      final sheet = CharacterCompiler(
        conRasgo({'type': 'language', 'language': 'druidic'}),
      ).compile(_char(languages: ['elvish', 'dwarvish']));
      expect(sheet.languages, {'common', 'elvish', 'dwarvish', 'druidic'});
    });

    test('el rasgo respeta el nivel al que llega', () {
      final repo = _repo(classFeatures: [
        {
          'level': 5,
          'name': 'Rasgo',
          'effects': [
            {'type': 'language', 'language': 'druidic'},
          ],
        },
      ]);
      final compiler = CharacterCompiler(repo);
      expect(compiler.compile(_char(level: 4)).languages,
          isNot(contains('druidic')));
      expect(compiler.compile(_char(level: 5)).languages, contains('druidic'));
    });
  });

  group('Elección por rasgo', () {
    ContentRepository conCupo({int count = 1, bool standardOnly = false}) =>
        _repo(classFeatures: [
          {
            'level': 1,
            'name': 'Rasgo',
            'effects': [
              {
                'type': 'languageChoice',
                'groupId': 'g',
                'name': 'Idioma extra',
                'count': count,
                'standardOnly': standardOnly,
              },
            ],
          },
        ]);

    test('declara un cupo pendiente', () {
      final slot = CharacterCompiler(conCupo())
          .compile(_char())
          .languageChoiceSlots
          .single;
      expect(slot.groupId, 'g');
      expect(slot.name, 'Idioma extra');
      expect(slot.count, 1);
      expect(slot.pending, 1);
    });

    test('el pozo excluye lo que ya sabe por otra vía', () {
      final slot = CharacterCompiler(conCupo())
          .compile(_char(languages: ['elvish', 'dwarvish']))
          .languageChoiceSlots
          .single;
      expect(slot.options, isNot(contains('common')));
      expect(slot.options, isNot(contains('elvish')));
      expect(slot.options, isNot(contains('dwarvish')));
      expect(slot.options, contains('orc'));
    });

    test('sin standardOnly ofrece también los inusuales', () {
      final slot = CharacterCompiler(conCupo())
          .compile(_char())
          .languageChoiceSlots
          .single;
      expect(slot.options, contains('infernal'));
    });

    test('con standardOnly se limita a la tabla de estándar', () {
      final slot = CharacterCompiler(conCupo(standardOnly: true))
          .compile(_char())
          .languageChoiceSlots
          .single;
      expect(slot.options, isNot(contains('infernal')));
      expect(slot.options, contains('orc'));
    });

    test('lo elegido llega a la ficha', () {
      final sheet = CharacterCompiler(conCupo()).compile(
        _char(languageChoices: {
          'g': ['infernal'],
        }),
      );
      expect(sheet.languages, containsAll(['common', 'infernal']));
      expect(sheet.languageChoiceSlots.single.pending, 0);
    });

    test('lo guardado que ya sabe por otra vía se descarta y devuelve el cupo',
        () {
      // Nunca se confía en lo guardado: el pozo se rearma en cada compilación.
      final sheet = CharacterCompiler(conCupo()).compile(
        _char(languages: [
          'elvish',
          'dwarvish'
        ], languageChoices: {
          'g': ['elvish'],
        }),
      );
      final slot = sheet.languageChoiceSlots.single;
      expect(slot.chosen, isEmpty);
      expect(slot.pending, 1);
    });

    test('dos cupos no ofrecen el mismo idioma', () {
      final repo = _repo(classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo',
          'effects': [
            {'type': 'languageChoice', 'groupId': 'g1', 'count': 1},
            {'type': 'languageChoice', 'groupId': 'g2', 'count': 1},
          ],
        },
      ]);
      final sheet = CharacterCompiler(repo).compile(
        _char(languageChoices: {
          'g1': ['orc'],
        }),
      );
      final g2 = sheet.languageChoiceSlots.firstWhere((s) => s.groupId == 'g2');
      expect(g2.options, isNot(contains('orc')));
    });
  });

  group('Validación', () {
    List<String> codigos(ContentRepository repo, Character c) =>
        CharacterValidator(repo).validate(c).map((w) => w.code).toList();

    test('faltan idiomas: aviso informativo', () {
      final w = CharacterValidator(_repo())
          .validate(_char())
          .where((x) => x.code == 'language_choice_pending');
      expect(w, hasLength(1));
      expect(w.single.severity, WarningSeverity.info);
    });

    test('con los dos elegidos no avisa', () {
      expect(
        codigos(_repo(), _char(languages: ['elvish', 'dwarvish'])),
        isNot(contains('language_choice_pending')),
      );
    });

    test('de más avisa', () {
      expect(
        codigos(_repo(), _char(languages: ['elvish', 'dwarvish', 'orc'])),
        contains('too_many_languages'),
      );
    });

    test('repetido avisa', () {
      expect(
        codigos(_repo(), _char(languages: ['elvish', 'elvish'])),
        contains('language_duplicate'),
      );
    });

    test('elegir Común avisa: no ocupa una elección', () {
      expect(
        codigos(_repo(), _char(languages: ['common', 'elvish'])),
        contains('language_universal_chosen'),
      );
    });

    test('elegir un inusual en el origen avisa', () {
      expect(
        codigos(_repo(), _char(languages: ['druidic', 'elvish'])),
        contains('language_not_standard'),
      );
    });

    test('un id de homebrew no avisa: puede ser un idioma inventado', () {
      expect(
        codigos(_repo(), _char(languages: ['quenya', 'elvish'])),
        isNot(contains('language_not_standard')),
      );
    });

    test('elección de rasgo huérfana avisa', () {
      final w = CharacterValidator(_repo()).validate(
        _char(languages: [
          'elvish',
          'dwarvish'
        ], languageChoices: {
          'viejo': ['orc'],
        }),
      );
      expect(w.map((x) => x.code), contains('language_choice_orphan'));
    });
  });

  group('Serialización', () {
    test('round-trip de los dos efectos', () {
      const fijo = LanguageEffect('druidic');
      expect((Effect.fromJson(fijo.toJson()) as LanguageEffect).language,
          'druidic');

      const cupo = LanguageChoiceEffect(
        groupId: 'g',
        name: 'Extra',
        count: 2,
        standardOnly: true,
      );
      final back = Effect.fromJson(cupo.toJson()) as LanguageChoiceEffect;
      expect(back.groupId, 'g');
      expect(back.name, 'Extra');
      expect(back.count, 2);
      expect(back.standardOnly, isTrue);
    });

    test('Character conserva idiomas y elecciones', () {
      final c = _char(languages: [
        'elvish'
      ], languageChoices: {
        'g': ['orc'],
      });
      final back = Character.fromJson(c.toJson());
      expect(back.languages, ['elvish']);
      expect(back.languageChoices, {
        'g': ['orc'],
      });
    });

    test('una ficha v14 migra sin idiomas y con el aviso pendiente', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 14,
        'id': 'v14',
        'name': 'Vieja',
        'raceId': 'r',
        'classId': 'c',
        'backgroundId': 'b',
        'assignedScores': const <String, int>{},
      });
      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['languages'], isEmpty);
      expect(migrated['languageChoices'], isEmpty);
    });
  });

  group('Catálogo oficial', () {
    late ContentRepository repo;

    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    Character oficial(String classId) => Character(
          id: 'p',
          name: 'Prueba',
          raceId: 'human',
          classId: classId,
          backgroundId: 'sage',
          level: 1,
          assignedScores: {for (final a in Ability.values) a: 12},
          hpPerLevel: const [8],
          languages: const ['elvish', 'dwarvish'],
        );

    test('ninguna especie ni trasfondo concede idiomas', () {
      // En 2024 vienen del origen del personaje, no de la especie. Si alguien
      // carga contenido al estilo 2014, esto lo caza.
      for (final r in repo.races.values) {
        expect(r.effects.whereType<LanguageEffect>(), isEmpty, reason: r.id);
      }
      for (final b in repo.backgrounds.values) {
        expect(b.effects.whereType<LanguageEffect>(), isEmpty, reason: b.id);
      }
    });

    test('el Druida sabe Druídico', () {
      final sheet = CharacterCompiler(repo).compile(oficial('druid'));
      expect(sheet.languages, containsAll(['common', 'druidic']));
    });

    test('el Pícaro sabe la Jerga y además elige otro', () {
      final compiler = CharacterCompiler(repo);
      final sheet = compiler.compile(oficial('rogue'));
      expect(sheet.languages, contains('thieves-cant'));

      final slot = sheet.languageChoiceSlots.single;
      expect(slot.groupId, 'class:rogue:cant-language');
      expect(slot.count, 1);
      // "de las tablas de idiomas": puede tomar uno inusual.
      expect(slot.options, contains('infernal'));
      // Y no le ofrece lo que ya sabe.
      expect(slot.options, isNot(contains('thieves-cant')));
      expect(slot.options, isNot(contains('elvish')));
    });

    test('todo id de idioma del contenido está en el catálogo', () {
      // Red contra un typo: un id desconocido se mostraría capitalizado en vez
      // de fallar, así que sin este test pasaría inadvertido.
      for (final k in repo.classes.values) {
        for (final f in k.features) {
          for (final e in f.effects.whereType<LanguageEffect>()) {
            expect(Language.fromId(e.language), isNotNull,
                reason: '${k.id} n${f.level}: "${e.language}"');
          }
        }
      }
    });
  });
}
