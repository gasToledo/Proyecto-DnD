import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El mecanismo de elecciones abiertas, probado contra contenido inventado.
///
/// Esta es la prueba de que agregar un catálogo nuevo (invocaciones del Brujo,
/// infusiones, lo que venga) es **puro dato**: acá no aparece ningún id del
/// contenido oficial y el motor no conoce ningún grupo por su nombre. Si algún
/// día hiciera falta tocar Dart para sumar un catálogo, este test lo delata.
ContentRepository _repo({
  List<Map<String, dynamic>> classFeatures = const [],
  List<Map<String, dynamic>> options = const [],
}) {
  return ContentRepository.fromJsonPacks(
    races: [
      {'id': 'test-race', 'name': 'Raza', 'source': 'homebrew'},
    ],
    classes: [
      {
        'id': 'test-class',
        'name': 'Clase',
        'source': 'homebrew',
        'hitDie': 8,
        'features': classFeatures,
      },
    ],
    backgrounds: [
      {'id': 'test-bg', 'name': 'Trasfondo', 'source': 'homebrew'},
    ],
    feats: options,
  );
}

Map<String, dynamic> _choiceEffect({
  int count = 1,
  bool replaceable = false,
  String category = 'test-option',
}) =>
    {
      'type': 'featureChoice',
      'groupId': 'test-group',
      'name': 'Elección de prueba',
      'featCategory': category,
      'count': count,
      'replaceable': replaceable,
    };

Map<String, dynamic> _option(
  String id, {
  List<Map<String, dynamic>> effects = const [],
  Map<String, dynamic>? prerequisite,
  String category = 'test-option',
}) =>
    {
      'id': id,
      'name': 'Opción $id',
      'source': 'homebrew',
      'category': category,
      'effects': effects,
      if (prerequisite != null) 'prerequisite': prerequisite,
    };

Character _character({
  int level = 1,
  Map<String, List<String>> choices = const {},
  int strength = 10,
}) =>
    Character(
      id: 'probe',
      name: 'Prueba',
      raceId: 'test-race',
      classId: 'test-class',
      backgroundId: 'test-bg',
      level: level,
      assignedScores: {
        for (final a in Ability.values)
          a: a == Ability.strength ? strength : 10,
      },
      hpPerLevel: List.filled(level, 5),
      featureChoices: choices,
    );

void main() {
  group('Espacios declarados por el contenido', () {
    test('un rasgo de clase declara cuántas opciones se eligen', () {
      final repo = _repo(
        classFeatures: [
          {
            'level': 1,
            'name': 'Rasgo',
            'effects': [_choiceEffect(count: 2)],
          },
        ],
        options: [_option('a')],
      );

      final slot = CharacterCompiler(
        repo,
      ).compile(_character()).featureChoiceSlots.single;

      expect(slot.groupId, 'test-group');
      expect(slot.name, 'Elección de prueba');
      expect(slot.featCategory, 'test-option');
      expect(slot.count, 2);
      expect(slot.replaceable, isFalse);
    });

    test('la cantidad crece con el nivel y gana el acumulado mayor', () {
      // El contenido declara el total a cada nivel, no el incremento: es la
      // misma convención que los tramos de recurso y los espacios de maestría.
      final repo = _repo(
        classFeatures: [
          {
            'level': 1,
            'name': 'Rasgo',
            'effects': [_choiceEffect(count: 2)],
          },
          {
            'level': 5,
            'name': 'Rasgo (3)',
            'effects': [_choiceEffect(count: 3)],
          },
        ],
        options: [_option('a')],
      );
      final compiler = CharacterCompiler(repo);

      expect(
        compiler.compile(_character(level: 1)).featureChoiceSlots.single.count,
        2,
      );
      expect(
        compiler.compile(_character(level: 5)).featureChoiceSlots.single.count,
        3,
      );
    });

    test('sin el rasgo no hay ningún espacio', () {
      final repo = _repo(options: [_option('a')]);
      expect(
        CharacterCompiler(repo).compile(_character()).featureChoiceSlots,
        isEmpty,
      );
    });

    test('featCategory cae en groupId cuando el JSON lo omite', () {
      final repo = _repo(
        classFeatures: [
          {
            'level': 1,
            'name': 'Rasgo',
            'effects': [
              {
                'type': 'featureChoice',
                'groupId': 'test-group',
                'name': 'Elección de prueba',
                'count': 1,
              },
            ],
          },
        ],
      );
      expect(
        CharacterCompiler(
          repo,
        ).compile(_character()).featureChoiceSlots.single.featCategory,
        'test-group',
      );
    });
  });

  group('Los efectos de lo elegido llegan a la ficha', () {
    final repo = _repo(
      classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo',
          'effects': [_choiceEffect(count: 2)],
        },
      ],
      options: [
        _option(
          'a',
          effects: [
            {'type': 'armorClassBonus', 'amount': 1},
          ],
        ),
        _option(
          'b',
          effects: [
            {'type': 'speedBonus', 'feet': 10},
          ],
        ),
      ],
    );

    test('elegir una opción aplica sus efectos', () {
      final sheet = CharacterCompiler(repo).compile(
        _character(
          choices: const {
            'test-group': ['a'],
          },
        ),
      );
      expect(sheet.armorClass, 11, reason: '10 + DES 0 + 1 de la opción');
    });

    test('elegir varias las aplica todas', () {
      final sheet = CharacterCompiler(repo).compile(
        _character(
          choices: const {
            'test-group': ['a', 'b'],
          },
        ),
      );
      expect(sheet.armorClass, 11);
      expect(sheet.speed, 40, reason: '30 base + 10 de la opción');
    });

    test('sin elegir nada no se aplica nada', () {
      final sheet = CharacterCompiler(repo).compile(_character());
      expect(sheet.armorClass, 10);
      expect(sheet.speed, 30);
    });
  });

  group('Prerrequisitos de las opciones', () {
    final repo = _repo(
      classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo',
          'effects': [_choiceEffect(count: 2)],
        },
      ],
      options: [
        _option('base'),
        _option(
          'exige-fuerza',
          prerequisite: {
            'minAbilityScores': {'strength': 13},
          },
        ),
        // Una opción que exige otra opción del mismo grupo: es la forma que
        // usan las invocaciones encadenadas.
        _option(
          'exige-base',
          prerequisite: {
            'requiredFeatIds': ['base'],
          },
        ),
      ],
    );

    test('una característica insuficiente bloquea la opción', () {
      final c = _character(strength: 10);
      final unmet = CharacterValidator(repo).unmetFeatPrerequisite(
        repo.feat('exige-fuerza')!,
        c,
        CharacterCompiler(repo).compile(c),
      );
      expect(unmet, isNotNull);
    });

    test('con la característica alcanzada la opción se habilita', () {
      final c = _character(strength: 14);
      final unmet = CharacterValidator(repo).unmetFeatPrerequisite(
        repo.feat('exige-fuerza')!,
        c,
        CharacterCompiler(repo).compile(c),
      );
      expect(unmet, isNull);
    });

    test('una opción elegida habilita a la que la exige', () {
      // Sin esto, los prerrequisitos entre opciones no funcionarían: dependen
      // de que las elecciones entren en `heldFeatIds`.
      final sinBase = _character();
      expect(
        CharacterValidator(repo).unmetFeatPrerequisite(
          repo.feat('exige-base')!,
          sinBase,
          CharacterCompiler(repo).compile(sinBase),
        ),
        isNotNull,
      );

      final conBase = _character(
        choices: const {
          'test-group': ['base'],
        },
      );
      expect(
        CharacterValidator(repo).unmetFeatPrerequisite(
          repo.feat('exige-base')!,
          conBase,
          CharacterCompiler(repo).compile(conBase),
        ),
        isNull,
      );
    });
  });

  group('Validación', () {
    final repo = _repo(
      classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo',
          'effects': [_choiceEffect(count: 2)],
        },
      ],
      options: [
        _option('a'),
        _option('b'),
        _option('c'),
        _option('de-otra-categoria', category: 'otra'),
      ],
    );

    List<String> codes(Character c) =>
        CharacterValidator(repo).validate(c).map((w) => w.code).toList();

    test('avisa cuando faltan elecciones', () {
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['a'],
            },
          ),
        ),
        contains('feature_choice_pending'),
      );
    });

    test('no avisa cuando están completas', () {
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['a', 'b'],
            },
          ),
        ),
        isNot(contains('feature_choice_pending')),
      );
    });

    test('avisa cuando sobran elecciones', () {
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['a', 'b', 'c'],
            },
          ),
        ),
        contains('too_many_feature_choices'),
      );
    });

    test('avisa cuando la opción no existe o es de otra categoría', () {
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['no-existe'],
            },
          ),
        ),
        contains('feature_choice_invalid'),
      );
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['de-otra-categoria'],
            },
          ),
        ),
        contains('feature_choice_invalid'),
      );
    });

    test('avisa por elecciones de un grupo que el personaje ya no tiene', () {
      // Pasa al cambiar de clase o si se retira el contenido que lo declaraba.
      expect(
        codes(
          _character(
            choices: const {
              'grupo-fantasma': ['a'],
            },
          ),
        ),
        contains('feature_choice_orphan'),
      );
    });

    test('elegir dos veces la misma opción cae en feat_duplicate', () {
      // No hay código de duplicado propio: las opciones son dotes y las reglas
      // de dotes ya las cubren.
      expect(
        codes(
          _character(
            choices: const {
              'test-group': ['a', 'a'],
            },
          ),
        ),
        contains('feat_duplicate'),
      );
    });
  });

  group('Regresión contra el contenido real', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    Character guerrero({String? estilo}) => Character(
          id: 'guerrero',
          name: 'Prueba',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'soldier',
          level: 1,
          assignedScores: {
            Ability.strength: 16,
            Ability.dexterity: 14,
            Ability.constitution: 14,
            Ability.intelligence: 10,
            Ability.wisdom: 12,
            Ability.charisma: 8,
          },
          hpPerLevel: const [10],
          equippedArmorId: 'leather',
          featureChoices: {
            if (estilo != null) 'fighting-style': [estilo],
          },
        );

    test('el Guerrero declara su Estilo de Combate a nivel 1', () {
      final slot = CharacterCompiler(
        repo,
      ).compile(guerrero()).featureChoiceSlots.single;

      expect(slot.groupId, 'fighting-style');
      expect(slot.featCategory, 'fighting-style');
      expect(slot.count, 1);
    });

    test('un Guerrero migrado compila igual que con el campo viejo', () {
      // Criterio de aceptación del cambio: la ficha de un personaje guardado
      // no puede moverse un punto por haber mudado el dato de lugar.
      final sheet =
          CharacterCompiler(repo).compile(guerrero(estilo: 'fs-defense'));
      final sinEstilo = CharacterCompiler(repo).compile(guerrero());

      expect(sheet.armorClass, sinEstilo.armorClass + 1,
          reason: 'Defensa suma +1 a la CA, como antes');
      // Y nada más se movió por haber mudado el dato de lugar.
      expect(sheet.maxHp, sinEstilo.maxHp);
      expect(sheet.speed, sinEstilo.speed);
      expect(sheet.attacks.length, sinEstilo.attacks.length);
    });

    test('las diez opciones salen de la categoría, sin lista de ids', () {
      final slot = CharacterCompiler(
        repo,
      ).compile(guerrero()).featureChoiceSlots.single;

      expect(repo.featsByCategory(slot.featCategory), hasLength(10));
    });

    test('el Mago no declara ninguna elección abierta', () {
      final mago = Character(
        id: 'mago',
        name: 'Prueba',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 1,
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: const [6],
      );
      expect(
        CharacterCompiler(repo).compile(mago).featureChoiceSlots,
        isEmpty,
      );
    });
  });

  test('el efecto sobrevive un round-trip por JSON', () {
    const effect = FeatureChoiceEffect(
      groupId: 'g',
      name: 'N',
      featCategory: 'c',
      count: 3,
      replaceable: true,
    );
    final restored = Effect.fromJson(effect.toJson()) as FeatureChoiceEffect;
    expect(restored.groupId, 'g');
    expect(restored.name, 'N');
    expect(restored.featCategory, 'c');
    expect(restored.count, 3);
    expect(restored.replaceable, isTrue);
  });
}
