import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Círculo de la Tierra: la subclase cuya tabla de conjuros depende de un
/// terreno que elige el jugador (árido, polar, templado o tropical).
///
/// Era la última deuda de `feature_promises_test` y la única que no se resolvía
/// con un efecto nuevo, sino reusando dos que ya existían: los cuatro terrenos
/// son dotes de la categoría `druid-land` y el rasgo de nivel 3 declara un
/// `FeatureChoiceEffect` sobre ellas. Los tramos 5/7/9 y la resistencia de 10
/// van dentro de cada dote con `LeveledEffect`.
///
/// Viven en dotes y no como rasgos repetidos de la subclase porque
/// `subclasses_test` prohíbe repetir nombre de rasgo salvo que sea
/// *exclusivamente* tabla de conjuros, y estos además conceden resistencia.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  ComputedSheet druida(int level, {String? terreno}) =>
      compiler.compile(Character(
        id: 'p',
        name: 'Druida',
        raceId: 'human',
        classId: 'druid',
        backgroundId: 'sage',
        subclassId: 'circle-land',
        level: level,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(level, 6),
        featureChoices: terreno == null
            ? const {}
            : {
                'circle-land:terrain': [terreno],
              },
      ));

  /// Los tramos oficiales, tal como los declara el SRD 5.2.1.
  const tablas = {
    'druid-land-arid': (
      resistencia: 'fire',
      n3: ['blur', 'fire-bolt', 'burning-hands'],
      n5: 'fireball',
      n7: 'blight',
      n9: 'wall-of-stone',
    ),
    'druid-land-polar': (
      resistencia: 'cold',
      n3: ['hold-person', 'fog-cloud', 'ray-of-frost'],
      n5: 'sleet-storm',
      n7: 'ice-storm',
      n9: 'cone-of-cold',
    ),
    'druid-land-temperate': (
      resistencia: 'lightning',
      n3: ['shocking-grasp', 'sleep', 'misty-step'],
      n5: 'lightning-bolt',
      n7: 'freedom-of-movement',
      n9: 'tree-stride',
    ),
    'druid-land-tropical': (
      resistencia: 'poison',
      n3: ['ray-of-sickness', 'acid-splash', 'web'],
      n5: 'stinking-cloud',
      n7: 'polymorph',
      n9: 'insect-plague',
    ),
  };

  group('El catálogo de terrenos', () {
    test('son exactamente cuatro dotes', () {
      expect(
        repo.featsByCategory('druid-land').map((f) => f.id).toSet(),
        tablas.keys.toSet(),
      );
    });

    test('ninguna declara exclusiveGroup', () {
      for (final f in repo.featsByCategory('druid-land')) {
        expect(f.exclusiveGroup, isNull, reason: f.id);
      }
    });

    test('con un terreno elegido, los otros tres siguen siendo elegibles', () {
      // Ésta es la aserción que importa, y el test de arriba es solo su causa.
      // Los tres selectores de la aplicación filtran las opciones con
      // `unmetFeatPrerequisite`: si los terrenos compartieran `exclusiveGroup`,
      // elegir uno haría desaparecer los otros y el druida no podría volver a
      // cambiarlo, en contra de la regla ("tras finalizar un descanso largo,
      // elige un tipo de terreno").
      final c = Character(
        id: 'p',
        name: 'Druida',
        raceId: 'human',
        classId: 'druid',
        backgroundId: 'sage',
        subclassId: 'circle-land',
        level: 5,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(5, 6),
        featureChoices: const {
          'circle-land:terrain': ['druid-land-arid'],
        },
      );
      final sheet = compiler.compile(c);
      final validator = CharacterValidator(repo);

      for (final f in repo.featsByCategory('druid-land')) {
        expect(validator.unmetFeatPrerequisite(f, c, sheet), isNull,
            reason: 'con Árido elegido, ${f.id} tiene que seguir ofreciéndose');
      }
    });

    test('cada una trae un passiveTrait de nivel superior para la tarjeta', () {
      // `featSummary` solo lee passives de nivel superior: sin él, la opción
      // sale sin texto en el selector.
      for (final f in repo.featsByCategory('druid-land')) {
        expect(
          f.effects.whereType<PassiveTraitEffect>(),
          isNotEmpty,
          reason: f.id,
        );
      }
    });

    test('ningún terreno repite conjuro entre tramos', () {
      for (final entry in tablas.entries) {
        final t = entry.value;
        final todos = [...t.n3, t.n5, t.n7, t.n9];
        expect(todos.toSet(), hasLength(todos.length), reason: entry.key);
      }
    });

    test('cada conjuro entra en los espacios del Druida a su tramo', () {
      // La comprobación que valida una transcripción no es contar conjuros:
      // es que ninguno se haya corrido de fila. Un lanzador completo llega a
      // espacios de nivel 2 en el 3, 3 en el 5, 4 en el 7 y 5 en el 9.
      const techo = {3: 2, 5: 3, 7: 4, 9: 5};
      for (final entry in tablas.entries) {
        final t = entry.value;
        for (final MapEntry(key: nivel, value: ids) in {
          3: t.n3,
          5: [t.n5],
          7: [t.n7],
          9: [t.n9],
        }.entries) {
          for (final id in ids) {
            final spell = repo.spell(id);
            expect(spell, isNotNull, reason: '${entry.key}: falta $id');
            expect(spell!.level, lessThanOrEqualTo(techo[nivel]!),
                reason: '${entry.key} n$nivel: $id no entra en los espacios');
          }
        }
      }
    });
  });

  group('La elección', () {
    test('a nivel 3 hay un cupo pendiente y reemplazable', () {
      final slot = druida(3)
          .featureChoiceSlots
          .firstWhere((s) => s.groupId == 'circle-land:terrain');
      expect(slot.featCategory, 'druid-land');
      expect(slot.count, 1);
      expect(slot.replaceable, isTrue);
    });

    test('sin elegir no concede ningún conjuro de círculo', () {
      final sheet = druida(9);
      for (final id in tablas['druid-land-arid']!.n3) {
        expect(sheet.alwaysPreparedSpellIds, isNot(contains(id)));
      }
    });

    test('la validación avisa que falta elegirlo, como info', () {
      final c = Character(
        id: 'p',
        name: 'Druida',
        raceId: 'human',
        classId: 'druid',
        backgroundId: 'sage',
        subclassId: 'circle-land',
        level: 3,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: List.filled(3, 6),
      );
      // El Druida también tiene pendiente Orden Primordial a nivel 1, así que
      // se filtra por el rasgo de esta subclase.
      final w = CharacterValidator(repo).validate(c).where((x) =>
          x.code == 'feature_choice_pending' &&
          x.message.contains('Terreno del Círculo'));
      expect(w, hasLength(1));
      expect(w.single.severity, WarningSeverity.info);
    });
  });

  group('Los tramos', () {
    for (final entry in tablas.entries) {
      final terreno = entry.key;
      final t = entry.value;

      test('$terreno crece 3/5/7/9 y no antes de tiempo', () {
        final n3 = druida(3, terreno: terreno).alwaysPreparedSpellIds;
        expect(n3, containsAll(t.n3));
        expect(n3, isNot(contains(t.n5)));

        expect(druida(4, terreno: terreno).alwaysPreparedSpellIds,
            isNot(contains(t.n5)));
        expect(
            druida(5, terreno: terreno).alwaysPreparedSpellIds, contains(t.n5));

        expect(druida(6, terreno: terreno).alwaysPreparedSpellIds,
            isNot(contains(t.n7)));
        expect(
            druida(7, terreno: terreno).alwaysPreparedSpellIds, contains(t.n7));

        expect(druida(8, terreno: terreno).alwaysPreparedSpellIds,
            isNot(contains(t.n9)));
        expect(druida(9, terreno: terreno).alwaysPreparedSpellIds,
            containsAll([...t.n3, t.n5, t.n7, t.n9]));
      });

      test('$terreno da su resistencia a nivel 10, no a nivel 9', () {
        expect(druida(9, terreno: terreno).resistances,
            isNot(contains(t.resistencia)));
        expect(
            druida(10, terreno: terreno).resistances, contains(t.resistencia));
      });
    }

    test('la inmunidad al estado envenenado llega a 10 con o sin terreno', () {
      expect(druida(9, terreno: 'druid-land-arid').immunities,
          isNot(contains('poisoned')));
      expect(druida(10, terreno: 'druid-land-arid').immunities,
          contains('poisoned'));
    });
  });

  group('Cambiar de terreno', () {
    test('reemplaza el conjunto entero', () {
      final arido = druida(9, terreno: 'druid-land-arid');
      final polar = druida(9, terreno: 'druid-land-polar');

      expect(arido.alwaysPreparedSpellIds, contains('fireball'));
      expect(polar.alwaysPreparedSpellIds, isNot(contains('fireball')));
      expect(polar.alwaysPreparedSpellIds, contains('sleet-storm'));
    });

    test('y también la resistencia', () {
      expect(druida(10, terreno: 'druid-land-arid').resistances,
          allOf(contains('fire'), isNot(contains('cold'))));
      expect(druida(10, terreno: 'druid-land-polar').resistances,
          allOf(contains('cold'), isNot(contains('fire'))));
    });
  });

  test('los conjuros de círculo no gastan cupo de preparados', () {
    // Es lo que dice la regla y lo que ya garantiza `alwaysPreparedSpellIds`;
    // el test lo fija porque es la razón por la que el jugador se quejó.
    final sin = druida(9).spellcasting!.preparedCount;
    final con =
        druida(9, terreno: 'druid-land-arid').spellcasting!.preparedCount;
    expect(con, sin);
  });
}
