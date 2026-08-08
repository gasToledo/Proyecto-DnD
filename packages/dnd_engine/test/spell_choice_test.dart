import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// `SpellChoiceEffect`: "elegí N conjuros de un pozo filtrado; quedan siempre
/// preparados".
///
/// Nació de tres rasgos que prometían conjuros a elección y no los daban:
/// Conjuros Característicos y Maestría sobre Conjuros del Mago, y
/// Descubrimientos Mágicos del Colegio del Conocimiento.
///
/// Igual que `expertise_test`, el mecanismo se prueba contra contenido
/// inventado y al final se comprueba el catálogo oficial.
ContentRepository _repo({
  required List<Map<String, dynamic>> classFeatures,
  List<Map<String, dynamic>>? spells,
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
          'features': [
            {
              'level': 1,
              'name': 'Magia',
              'effects': [
                {
                  'type': 'spellcasting',
                  'ability': 'intelligence',
                  'progression': 'full',
                  'preparation': 'prepared',
                  'spellList': 'c',
                  'cantripsKnown': 2,
                },
              ],
            },
            ...classFeatures,
          ],
        },
      ],
      backgrounds: [
        {'id': 'b', 'name': 'Trasfondo', 'source': 'homebrew'},
      ],
      spells: spells ?? _spells,
    );

/// Pozo de prueba: dos trucos y conjuros de nivel 1 a 5, repartidos entre dos
/// listas y dos escuelas, con un tiempo de lanzamiento distinto en uno.
final List<Map<String, dynamic>> _spells = [
  for (final s in [
    ('t1', 0, 'c', 'Evocación', 'Acción'),
    ('t2', 0, 'otra', 'Abjuración', 'Acción'),
    ('n1', 1, 'c', 'Evocación', 'Acción'),
    ('n1b', 1, 'c', 'Abjuración', 'Acción Adicional'),
    ('n2', 2, 'c', 'Abjuración', 'Acción'),
    ('n3', 3, 'c', 'Evocación', 'Acción'),
    ('n3b', 3, 'otra', 'Evocación', 'Acción'),
    ('n5', 5, 'c', 'Evocación', 'Acción'),
  ])
    {
      'id': s.$1,
      'name': s.$1.toUpperCase(),
      'source': 'homebrew',
      'level': s.$2,
      'school': s.$4,
      'castingTime': s.$5,
      'range': 'Toque',
      'components': 'V',
      'duration': 'Instantánea',
      'description': '',
      'classes': [s.$3],
    },
];

Character _char({
  int level = 20,
  Map<String, List<String>> choices = const {},
  List<String> spellIds = const [],
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
      spellChoices: choices,
      spellIds: spellIds,
    );

/// Un rasgo de clase que declara un cupo de elección de conjuros.
Map<String, dynamic> _feature({
  int level = 1,
  String groupId = 'g',
  String name = 'Cupo',
  int count = 1,
  int minLevel = 0,
  int? maxLevel,
  bool maxLevelFromSlots = false,
  List<String> fromClasses = const [],
  List<String> schools = const [],
  List<String> castingTimes = const [],
  String? freeCast,
  bool replaceable = false,
}) =>
    {
      'level': level,
      'name': 'Rasgo n$level',
      'effects': [
        {
          'type': 'spellChoice',
          'groupId': groupId,
          'name': name,
          'count': count,
          'minLevel': minLevel,
          if (maxLevel != null) 'maxLevel': maxLevel,
          if (maxLevelFromSlots) 'maxLevelFromSlots': true,
          'fromClasses': fromClasses,
          'schools': schools,
          'castingTimes': castingTimes,
          if (freeCast != null) 'freeCast': freeCast,
          'replaceable': replaceable,
        },
      ],
    };

void main() {
  group('Filtros del pozo', () {
    test('sin filtros ofrece todo el catálogo', () {
      final repo = _repo(classFeatures: [_feature()]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, hasLength(_spells.length));
      expect(slot.count, 1);
      expect(slot.pending, 1);
    });

    test('minLevel deja fuera los trucos', () {
      final repo = _repo(classFeatures: [_feature(minLevel: 1)]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, isNot(contains('t1')));
      expect(slot.options, contains('n1'));
    });

    test('maxLevel acota por arriba, y minLevel + maxLevel fija un nivel', () {
      final repo = _repo(classFeatures: [
        _feature(groupId: 'solo3', minLevel: 3, maxLevel: 3),
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, ['n3', 'n3b']);
    });

    test('fromClasses filtra por lista de clase', () {
      final repo = _repo(classFeatures: [
        _feature(fromClasses: ['otra']),
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, ['t2', 'n3b']);
    });

    test('schools filtra por escuela', () {
      final repo = _repo(classFeatures: [
        _feature(schools: ['Abjuración']),
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, ['t2', 'n1b', 'n2']);
    });

    test('castingTimes compara exacto: "Acción" no trae "Acción Adicional"',
        () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, castingTimes: ['Acción']),
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, contains('n1'));
      expect(slot.options, isNot(contains('n1b')));
    });

    test('maxLevelFromSlots sube el techo con el nivel del personaje', () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, maxLevelFromSlots: true),
      ]);
      final compiler = CharacterCompiler(repo);

      // Lanzador completo: a nivel 1 solo espacios de nivel 1.
      final low = compiler.compile(_char(level: 1)).spellChoiceSlots.single;
      expect(low.options, ['n1', 'n1b']);

      // A nivel 9 ya llega a nivel 5.
      final high = compiler.compile(_char(level: 9)).spellChoiceSlots.single;
      expect(high.options, contains('n5'));
    });

    test('el cupo no existe antes de su nivel', () {
      final repo = _repo(classFeatures: [_feature(level: 6)]);
      final compiler = CharacterCompiler(repo);
      expect(compiler.compile(_char(level: 5)).spellChoiceSlots, isEmpty);
      expect(compiler.compile(_char(level: 6)).spellChoiceSlots, hasLength(1));
    });
  });

  group('Lo elegido', () {
    test('llega a alwaysPreparedSpellIds, que es el punto único', () {
      final repo = _repo(classFeatures: [_feature(count: 2, minLevel: 1)]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1', 'n3'],
      }));

      expect(sheet.alwaysPreparedSpellIds, containsAll(['n1', 'n3']));
      expect(sheet.spellChoiceSlots.single.chosen, ['n1', 'n3']);
      expect(sheet.spellChoiceSlots.single.pending, 0);
    });

    test('no gasta cupo de preparados', () {
      final repo = _repo(classFeatures: [_feature(count: 2, minLevel: 1)]);
      final compiler = CharacterCompiler(repo);
      final sin = compiler.compile(_char()).spellcasting!.preparedCount;
      final con = compiler
          .compile(_char(choices: {
            'g': ['n1', 'n3'],
          }))
          .spellcasting!
          .preparedCount;
      expect(con, sin);
    });

    test('se recorta al count declarado', () {
      final repo = _repo(classFeatures: [_feature(count: 1, minLevel: 1)]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1', 'n3'],
      }));
      expect(sheet.spellChoiceSlots.single.chosen, ['n1']);
      expect(sheet.alwaysPreparedSpellIds, isNot(contains('n3')));
    });

    test('un id repetido no cuenta dos veces', () {
      final repo = _repo(classFeatures: [_feature(count: 2, minLevel: 1)]);
      final slot = CharacterCompiler(repo)
          .compile(_char(choices: {
            'g': ['n1', 'n1'],
          }))
          .spellChoiceSlots
          .single;
      expect(slot.chosen, ['n1']);
      expect(slot.pending, 1);
    });
  });

  group('Revalidación', () {
    // Nunca se confía en lo guardado: el pozo se rearma en cada compilación y
    // lo que dejó de calificar se descarta en silencio, devolviendo el cupo.
    test('lo guardado que ya no califica se descarta y el cupo vuelve', () {
      final repo = _repo(classFeatures: [
        _feature(count: 1, minLevel: 3, maxLevel: 3),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1'], // fuera de rango
      }));
      expect(sheet.spellChoiceSlots.single.chosen, isEmpty);
      expect(sheet.spellChoiceSlots.single.pending, 1);
      expect(sheet.alwaysPreparedSpellIds, isNot(contains('n1')));
    });

    test('un id que el catálogo no conoce se descarta', () {
      final repo = _repo(classFeatures: [_feature()]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['inventado'],
      }));
      expect(sheet.spellChoiceSlots.single.chosen, isEmpty);
    });

    test('el techo por espacios poda al bajar de nivel', () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, maxLevelFromSlots: true),
      ]);
      final compiler = CharacterCompiler(repo);
      final choices = {
        'g': ['n5'],
      };
      expect(
        compiler.compile(_char(level: 9, choices: choices)).chosenOf('g'),
        ['n5'],
      );
      expect(
        compiler.compile(_char(level: 1, choices: choices)).chosenOf('g'),
        isEmpty,
      );
    });
  });

  group('Varios cupos', () {
    test('un conjuro tomado en el primero no se ofrece en el segundo', () {
      final repo = _repo(classFeatures: [
        _feature(groupId: 'g1', minLevel: 1),
        _feature(groupId: 'g2', minLevel: 1),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g1': ['n1'],
      }));

      final g2 = sheet.spellChoiceSlots.firstWhere((s) => s.groupId == 'g2');
      expect(g2.options, isNot(contains('n1')));
    });

    test('lo que otro rasgo ya concede no se ofrece', () {
      final repo = _repo(classFeatures: [
        {
          'level': 1,
          'name': 'Concede',
          'effects': [
            {'type': 'alwaysPreparedSpell', 'spellId': 'n1'},
          ],
        },
        _feature(minLevel: 1),
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.options, isNot(contains('n1')));
    });
  });

  group('Lanzamiento gratis', () {
    test('sin freeCast no hay conjuro innato ni recurso', () {
      final repo = _repo(classFeatures: [_feature(minLevel: 1)]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1'],
      }));
      expect(sheet.innateSpells, isEmpty);
      expect(sheet.resources.where((r) => r.id.startsWith('innate-')), isEmpty);
    });

    test('oncePerShortRest acuña el recurso con recarga corta', () {
      final repo = _repo(classFeatures: [
        _feature(
            minLevel: 3, maxLevel: 3, count: 2, freeCast: 'oncePerShortRest'),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n3', 'n3b'],
      }));

      expect(sheet.innateSpells.map((s) => s.spellId), ['n3', 'n3b']);
      // Un recurso por conjuro: la regla dice "cada uno una vez".
      final recursos =
          sheet.resources.where((r) => r.id.startsWith('innate-')).toList();
      expect(recursos, hasLength(2));
      expect(recursos.every((r) => r.recharge == RechargeOn.shortRest), isTrue);
      expect(recursos.every((r) => r.max == 1), isTrue);
    });

    test('atWill no acuña recurso pero sí conjuro innato', () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, freeCast: 'atWill'),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1'],
      }));
      expect(sheet.innateSpells.single.spellId, 'n1');
      expect(sheet.innateSpells.single.use, InnateSpellUse.atWill);
      expect(sheet.resources.where((r) => r.id.startsWith('innate-')), isEmpty);
    });

    test('el innato usa la aptitud de lanzamiento de la clase', () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, freeCast: 'oncePerLongRest'),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1'],
      }));
      expect(sheet.innateSpells.single.ability, Ability.intelligence);
    });

    test('sigue estando siempre preparado además del uso gratis', () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 1, freeCast: 'oncePerShortRest'),
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(choices: {
        'g': ['n1'],
      }));
      expect(sheet.alwaysPreparedSpellIds, contains('n1'));
    });
  });

  group('Validación', () {
    List<ValidationWarning> warn(ContentRepository repo, Character c) =>
        CharacterValidator(repo).validate(c);

    test('spell_choice_pending es info y se va al elegir', () {
      final repo = _repo(classFeatures: [_feature(minLevel: 1)]);
      final pend =
          warn(repo, _char()).where((x) => x.code == 'spell_choice_pending');
      expect(pend, hasLength(1));
      expect(pend.single.severity, WarningSeverity.info);

      expect(
        warn(
            repo,
            _char(choices: {
              'g': ['n1'],
            })).where((x) => x.code == 'spell_choice_pending'),
        isEmpty,
      );
    });

    test('too_many_spell_choices avisa si guardaste de más', () {
      final repo = _repo(classFeatures: [_feature(count: 1, minLevel: 1)]);
      final w = warn(
          repo,
          _char(choices: {
            'g': ['n1', 'n3'],
          }));
      expect(w.map((x) => x.code), contains('too_many_spell_choices'));
    });

    test('spell_choice_invalid avisa por lo guardado que dejó de calificar',
        () {
      final repo = _repo(classFeatures: [
        _feature(minLevel: 3, maxLevel: 3),
      ]);
      final w = warn(
          repo,
          _char(choices: {
            'g': ['n1'],
          }));
      expect(w.map((x) => x.code), contains('spell_choice_invalid'));
    });

    test('spell_choice_orphan avisa por un grupo que ya no existe', () {
      final repo = _repo(classFeatures: [_feature(minLevel: 1)]);
      final w = warn(
          repo,
          _char(choices: {
            'g': ['n1'],
            'viejo': ['n3'],
          }));
      final orphan = w.where((x) => x.code == 'spell_choice_orphan');
      expect(orphan, hasLength(1));
      expect(orphan.single.severity, WarningSeverity.info);
    });

    test('elegirlo y además prepararlo lo cubre spell_already_granted', () {
      // No hay código propio para esto: el conjuro entra en
      // alwaysPreparedSpellIds y la validación de conjuros ya lo detecta. El
      // test está para que nadie lo "arregle" una segunda vez.
      final repo = _repo(classFeatures: [_feature(minLevel: 1)]);
      final w = warn(
          repo,
          _char(choices: {
            'g': ['n1'],
          }, spellIds: [
            'n1'
          ]));
      expect(w.map((x) => x.code), contains('spell_already_granted'));
    });
  });

  group('Serialización', () {
    test('round-trip del efecto', () {
      const original = SpellChoiceEffect(
        groupId: 'g',
        name: 'Cupo',
        count: 2,
        minLevel: 1,
        maxLevel: 3,
        maxLevelFromSlots: true,
        fromClasses: ['wizard'],
        schools: ['Evocación'],
        castingTimes: ['Acción'],
        freeCast: InnateSpellUse.oncePerShortRest,
        replaceable: true,
      );
      final back = Effect.fromJson(original.toJson()) as SpellChoiceEffect;

      expect(back.groupId, 'g');
      expect(back.name, 'Cupo');
      expect(back.count, 2);
      expect(back.minLevel, 1);
      expect(back.maxLevel, 3);
      expect(back.maxLevelFromSlots, isTrue);
      expect(back.fromClasses, ['wizard']);
      expect(back.schools, ['Evocación']);
      expect(back.castingTimes, ['Acción']);
      expect(back.freeCast, InnateSpellUse.oncePerShortRest);
      expect(back.replaceable, isTrue);
    });

    test('los valores por defecto se omiten y se recuperan', () {
      const minimal = SpellChoiceEffect(groupId: 'g');
      final json = minimal.toJson();
      expect(json.containsKey('maxLevel'), isFalse);
      expect(json.containsKey('freeCast'), isFalse);
      expect(json.containsKey('name'), isFalse);

      final back = Effect.fromJson(json) as SpellChoiceEffect;
      expect(back.count, 1);
      expect(back.minLevel, 0);
      expect(back.maxLevel, isNull);
      expect(back.freeCast, isNull);
      expect(back.name, isEmpty);
    });

    test('el cupo sin nombre propio hereda el del rasgo', () {
      final repo = _repo(classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo n1',
          'effects': [
            {'type': 'spellChoice', 'groupId': 'g'},
          ],
        },
      ]);
      final slot =
          CharacterCompiler(repo).compile(_char()).spellChoiceSlots.single;
      expect(slot.name, 'Rasgo n1');
    });

    test('Character conserva spellChoices en el round-trip', () {
      final c = _char(choices: {
        'g': ['n1', 'n3'],
      });
      final back = Character.fromJson(c.toJson());
      expect(back.spellChoices, {
        'g': ['n1', 'n3'],
      });
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
      String? subclassId,
      Map<String, List<String>> choices = const {},
    }) =>
        compiler.compile(Character(
          id: 'p',
          name: 'Prueba',
          raceId: 'human',
          classId: classId,
          backgroundId: 'sage',
          subclassId: subclassId,
          level: level,
          assignedScores: {for (final a in Ability.values) a: 14},
          hpPerLevel: List.filled(level, 6),
          spellChoices: choices,
        ));

    test('Conjuros Característicos llega a nivel 20, no antes', () {
      expect(oficial('wizard', 19).spellChoiceSlots.map((s) => s.groupId),
          isNot(contains('class:wizard:signature-spells')));

      final slot =
          oficial('wizard', 20).slotOf('class:wizard:signature-spells');
      expect(slot.count, 2);
      expect(slot.pending, 2);
    });

    test('y solo ofrece conjuros de nivel 3 de la lista de Mago', () {
      final slot =
          oficial('wizard', 20).slotOf('class:wizard:signature-spells');
      expect(slot.options, isNotEmpty);
      for (final id in slot.options) {
        final spell = repo.spell(id)!;
        expect(spell.level, 3, reason: id);
        expect(spell.classes, contains('wizard'), reason: id);
      }
    });

    test('elegidos quedan siempre preparados y con un uso gratis cada uno', () {
      final sheet = oficial('wizard', 20, choices: {
        'class:wizard:signature-spells': ['fireball', 'fly'],
      });

      expect(sheet.alwaysPreparedSpellIds, containsAll(['fireball', 'fly']));

      final gratis =
          sheet.resources.where((r) => r.id.startsWith('innate-')).toList();
      expect(gratis.map((r) => r.id),
          containsAll(['innate-fireball', 'innate-fly']));
      expect(
        gratis
            .where((r) => r.id == 'innate-fireball' || r.id == 'innate-fly')
            .every((r) => r.recharge == RechargeOn.shortRest && r.max == 1),
        isTrue,
      );
    });

    test('no le comen cupo de preparados al Mago', () {
      final sin = oficial('wizard', 20).spellcasting!.preparedCount;
      final con = oficial('wizard', 20, choices: {
        'class:wizard:signature-spells': ['fireball', 'fly'],
      }).spellcasting!.preparedCount;
      expect(con, sin);
    });

    test('Maestría sobre Conjuros son dos cupos, uno por nivel', () {
      final sheet = oficial('wizard', 18);
      final n1 = sheet.slotOf('class:wizard:spell-mastery-1');
      final n2 = sheet.slotOf('class:wizard:spell-mastery-2');

      expect(n1.count, 1);
      expect(n2.count, 1);
      expect(n1.options.every((id) => repo.spell(id)!.level == 1), isTrue);
      expect(n2.options.every((id) => repo.spell(id)!.level == 2), isTrue);
    });

    test('y solo ofrece los que se lanzan con una acción', () {
      // La regla lo exige, y "Acción Adicional" no cuenta: el filtro compara
      // exacto justamente por eso.
      final n1 = oficial('wizard', 18).slotOf('class:wizard:spell-mastery-1');
      expect(n1.options, isNotEmpty);
      expect(
        n1.options.every((id) => repo.spell(id)!.castingTime == 'Acción'),
        isTrue,
      );
      // Escudo es de reacción y Retirada Rápida de acción adicional: los dos
      // son de nivel 1 en la lista de Mago y ninguno puede aparecer.
      expect(n1.options, isNot(contains('shield')));
    });

    test('Maestría sobre Conjuros se lanza a voluntad, sin recurso', () {
      final sheet = oficial('wizard', 18, choices: {
        'class:wizard:spell-mastery-1': ['magic-missile'],
      });
      final innato =
          sheet.innateSpells.firstWhere((s) => s.spellId == 'magic-missile');
      expect(innato.use, InnateSpellUse.atWill);
      expect(sheet.resources.map((r) => r.id),
          isNot(contains('innate-magic-missile')));
    });

    test('Descubrimientos Mágicos llega a nivel 6, no antes', () {
      const grupo = 'subclass:college-lore:magical-discoveries';
      expect(
        oficial('bard', 5, subclassId: 'college-lore')
            .spellChoiceSlots
            .map((s) => s.groupId),
        isNot(contains(grupo)),
      );

      final slot = oficial('bard', 6, subclassId: 'college-lore').slotOf(grupo);
      expect(slot.count, 2);
      expect(slot.replaceable, isTrue);
    });

    test('ofrece Clérigo, Druida y Mago, y no la lista de Bardo', () {
      const grupo = 'subclass:college-lore:magical-discoveries';
      final slot = oficial('bard', 6, subclassId: 'college-lore').slotOf(grupo);

      // Cada opción viene de alguna de las tres listas permitidas.
      for (final id in slot.options) {
        final spell = repo.spell(id)!;
        expect(
          spell.classes.any(const {'cleric', 'druid', 'wizard'}.contains),
          isTrue,
          reason: id,
        );
      }
      // Y las tres están representadas.
      for (final lista in ['cleric', 'druid', 'wizard']) {
        expect(
          slot.options.any((id) => repo.spell(id)!.classes.contains(lista)),
          isTrue,
          reason: lista,
        );
      }
    });

    test('admite trucos y respeta el techo de espacios del Bardo', () {
      const grupo = 'subclass:college-lore:magical-discoveries';
      final slot = oficial('bard', 6, subclassId: 'college-lore').slotOf(grupo);

      // "trucos o conjuros para los que tengas espacios": a nivel 6 el Bardo
      // llega a espacios de nivel 3.
      expect(slot.options.any((id) => repo.spell(id)!.level == 0), isTrue);
      expect(slot.options.every((id) => repo.spell(id)!.level <= 3), isTrue);

      final alto =
          oficial('bard', 20, subclassId: 'college-lore').slotOf(grupo);
      expect(alto.options.any((id) => repo.spell(id)!.level > 3), isTrue);
    });
  });
}

extension on ComputedSheet {
  List<String> chosenOf(String groupId) =>
      spellChoiceSlots.firstWhere((s) => s.groupId == groupId).chosen;

  SpellChoiceSlot slotOf(String groupId) =>
      spellChoiceSlots.firstWhere((s) => s.groupId == groupId);
}
