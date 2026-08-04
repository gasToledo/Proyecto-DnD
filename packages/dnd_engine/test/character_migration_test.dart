import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  test('migra secuencialmente una ficha v1 sin modificar el documento fuente',
      () async {
    final source = (jsonDecode(
      await File('test/fixtures/character_v1.json').readAsString(),
    ) as Map)
        .cast<String, dynamic>();
    final original = jsonEncode(source);

    final migrated = Character.migrateJson(source);
    final character = Character.fromJson(source);

    expect(source['schemaVersion'], 1);
    expect(jsonEncode(source), original);
    expect(migrated['schemaVersion'], Character.currentSchemaVersion);
    expect(migrated['status'], CharacterStatus.active.name);
    expect(migrated['tableConfig'], isA<Map>());
    expect(migrated['combat'], isA<Map>());
    expect(character.id, 'fixture-v1');
    expect(character.toJson()['schemaVersion'], Character.currentSchemaVersion);
  });

  test('una ficha sin versión se interpreta como el esquema histórico v1', () {
    final source = {
      'id': 'sin-version',
      'name': 'Legado',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
    };

    expect(Character.schemaVersionOf(source), 1);
    expect(
      Character.fromJson(source).toJson()['schemaVersion'],
      Character.currentSchemaVersion,
    );
  });

  test('la migración incluye el paso v3 → v4 de ids históricos', () {
    // Los ids estaban mal, no el contenido: la ficha eligió el conjuro que
    // quería y no debe perderlo porque el pack corrija su identificador.
    final source = {
      'schemaVersion': 3,
      'id': 'v3',
      'name': 'Consagrada',
      'raceId': 'human',
      'classId': 'cleric',
      'backgroundId': 'acolyte',
      'assignedScores': const <String, int>{},
      'cantripIds': const ['sacred-flame'],
      'spellIds': const [
        'bless-the-ground',
        'negative-energy-flood',
        'fabricate-shadow',
        'conjure-volley',
        'conjure-volley-arrows',
        'cure-wounds',
      ],
    };

    final migrated = Character.migrateJson(source);

    expect(migrated['schemaVersion'], Character.currentSchemaVersion);
    expect(migrated['cantripIds'], ['sacred-flame']);
    // Los dos de Conjurar intercambian id: ninguno puede migrar dos veces.
    expect(migrated['spellIds'], [
      'hallow',
      'antilife-shell',
      'creation',
      'conjure-barrage',
      'conjure-volley',
      'cure-wounds',
    ]);
  });

  test('v4 → v5: normaliza los cinco ids heredados del catálogo 2014', () {
    final source = {
      'schemaVersion': 4,
      'id': 'v4',
      'name': 'Cronista',
      'raceId': 'human',
      'classId': 'wizard',
      'backgroundId': 'sage',
      'assignedScores': const <String, int>{},
      'cantripIds': const ['toll-the-dead'],
      'spellIds': const [
        'feeblemind',
        'snare',
        'dispel-good-and-evil',
        'holy-word',
        'branding-smite',
        'magic-missile',
      ],
    };

    final migrated = Character.migrateJson(source);

    // La cadena sigue hasta la versión actual; lo que prueba este caso es que
    // el paso v4 → v5 renombró los ids, no dónde termina la cadena.
    expect(migrated['schemaVersion'], Character.currentSchemaVersion);
    expect(migrated['cantripIds'], ['toll-the-dead']);
    expect(migrated['spellIds'], [
      'befuddlement',
      'cordon-of-arrows',
      'dispel-evil-and-good',
      'divine-word',
      'shining-smite',
      'magic-missile',
    ]);
  });

  test('v7 → v8: las dotes divididas apuntan a su variante', () {
    // Dividir una dote en variantes hace desaparecer su id, y una ficha que la
    // tuviera perdería la dote en silencio. La variante de destino es la que
    // el catálogo asignaba sola, así que la ficha compila igual que antes.
    final source = {
      'schemaVersion': 7,
      'id': 'v7',
      'name': 'Veterana',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
      'featIds': const [
        'athlete',
        'sentinel',
        // Ésta se dividió en una tanda anterior sin migración: su id llevaba
        // tiempo huérfano.
        'shadow-touched',
        // Una que no se dividió no se toca.
        'lucky',
      ],
    };

    final migrated = Character.migrateJson(source);

    expect(migrated['schemaVersion'], Character.currentSchemaVersion);
    expect(migrated['featIds'], [
      'athlete-dexterity',
      'sentinel-strength',
      'shadow-touched-charisma',
      'lucky',
    ]);
  });

  test('v7 → v8: tolera un featIds con basura', () {
    // El mismo camino procesa importaciones, que no son datos confiables.
    final source = {
      'schemaVersion': 7,
      'id': 'v7b',
      'name': 'Importada',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
      'featIds': const ['athlete', 42, null],
    };
    final migrated = Character.migrateJson(source);
    expect(migrated['featIds'], ['athlete-dexterity', 42, null]);
  });

  group('v9 → v10: Versatilidad de Habilidad del Khoravar', () {
    Map<String, dynamic> khoravar({
      required List<dynamic> chosenSkills,
      Map<String, dynamic> proficiencyChoices = const {},
    }) =>
        {
          'schemaVersion': 9,
          'id': 'v9',
          'name': 'Mediorco de Khorvaire',
          'raceId': 'khoravar',
          'classId': 'artificer',
          'backgroundId': 'artisan',
          'assignedScores': const <String, int>{},
          'chosenSkills': chosenSkills,
          'proficiencyChoices': proficiencyChoices,
        };

    test('la habilidad de la especie se muda a su grupo', () {
      final migrated = Character.migrateJson(
        khoravar(chosenSkills: ['arcana', 'sleight-of-hand', 'perception']),
      );

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      // Quedan las dos de la clase; la de la especie, que el wizard agrega
      // última, pasa a ser una elección de competencia.
      expect(migrated['chosenSkills'], ['arcana', 'sleight-of-hand']);
      expect(
        (migrated['proficiencyChoices']
            as Map)['race:khoravar:skill-versatility'],
        ['perception'],
      );
    });

    test('si ya eligió con la interfaz nueva, la vieja se descarta', () {
      // Es el caso de una ficha que se abrió después del cambio de contenido:
      // eligió por el grupo nuevo y la vieja quedó duplicando la competencia.
      final migrated = Character.migrateJson(
        khoravar(
          chosenSkills: ['arcana', 'sleight-of-hand', 'perception'],
          proficiencyChoices: {
            'race:khoravar:skill-versatility': ['stealth'],
          },
        ),
      );

      expect(migrated['chosenSkills'], ['arcana', 'sleight-of-hand']);
      expect(
        (migrated['proficiencyChoices']
            as Map)['race:khoravar:skill-versatility'],
        ['stealth'],
      );
    });

    test('otra especie no pierde ninguna habilidad', () {
      final source = khoravar(chosenSkills: ['arcana', 'sleight-of-hand'])
        ..['raceId'] = 'shifter';

      final migrated = Character.migrateJson(source);

      expect(migrated['chosenSkills'], ['arcana', 'sleight-of-hand']);
    });

    test('tolera un chosenSkills vacío o con basura', () {
      expect(
        Character.migrateJson(khoravar(chosenSkills: []))['chosenSkills'],
        isEmpty,
      );
      final basura = Character.migrateJson(
        khoravar(chosenSkills: ['arcana', 42]),
      );
      expect(basura['chosenSkills'], ['arcana']);
      expect(
        (basura['proficiencyChoices'] as Map)
            .containsKey('race:khoravar:skill-versatility'),
        isFalse,
      );
    });
  });

  test('v5 → v6: la mano secundaria arranca vacía', () {
    final source = {
      'schemaVersion': 5,
      'id': 'v5',
      'name': 'Espadachín',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
      'equippedWeaponIds': const ['dagger', 'shortsword'],
    };

    final migrated = Character.migrateJson(source);

    expect(migrated['schemaVersion'], Character.currentSchemaVersion);
    expect(migrated['weaponOffHand'], isEmpty);
    // Nadie queda con un arma en la secundaria por accidente: hasta que el
    // jugador la marque, la ficha se compila igual que antes.
    expect(Character.fromJson(source).weaponOffHand, isEmpty);
  });

  test('una bandera de equipo con basura se descarta sin perder la ficha', () {
    // Las importaciones son datos no confiables: un valor de tipo equivocado
    // no puede costar el personaje entero.
    final source = {
      'schemaVersion': 6,
      'id': 'basura',
      'name': 'Importado',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
      'weaponOffHand': const {'dagger': 'sí', 'shortsword': true},
      'weaponTwoHanded': const {'longsword': 3},
    };

    final c = Character.fromJson(source);

    expect(c.weaponOffHand, {'shortsword': true});
    expect(c.weaponTwoHanded, isEmpty);
  });

  test('weaponOffHand que no es un mapa se ignora', () {
    final source = {
      'schemaVersion': 6,
      'id': 'basura2',
      'name': 'Importado',
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': const <String, int>{},
      'weaponOffHand': 7,
    };

    expect(Character.fromJson(source).weaponOffHand, isEmpty);
  });

  group('v6 → v7: el estilo de combate pasa a ser una elección más', () {
    Map<String, dynamic> v6(
            {Object? fightingStyleId, Object? featureChoices}) =>
        {
          'schemaVersion': 6,
          'id': 'v6',
          'name': 'Espadachín',
          'raceId': 'human',
          'classId': 'fighter',
          'backgroundId': 'soldier',
          'assignedScores': const <String, int>{},
          if (fightingStyleId != null) 'fightingStyleId': fightingStyleId,
          if (featureChoices != null) 'featureChoices': featureChoices,
        };

    test('el estilo guardado se muda a su grupo', () {
      final migrated = Character.migrateJson(v6(fightingStyleId: 'fs-defense'));

      expect(migrated['featureChoices'], {
        'fighting-style': ['fs-defense'],
      });
      // El campo viejo se va: dejarlo sería un dato muerto que contradice.
      expect(migrated.containsKey('fightingStyleId'), isFalse);
      expect(
        Character.fromJson(v6(fightingStyleId: 'fs-defense')).fightingStyleId,
        'fs-defense',
      );
    });

    test('sin estilo no inventa una entrada vacía', () {
      // Es el caso de todo personaje que no sea Guerrero: el campo existía y
      // estaba en null. Un `['null']` acá rompería la ficha entera.
      final migrated = Character.migrateJson(v6(fightingStyleId: null));

      expect(migrated['featureChoices'], isEmpty);
      expect(Character.fromJson(v6()).fightingStyleId, isNull);
    });

    test('si vienen los dos campos, gana el nuevo', () {
      final migrated = Character.migrateJson(
        v6(
          fightingStyleId: 'fs-archery',
          featureChoices: {
            'fighting-style': ['fs-defense'],
          },
        ),
      );

      expect(migrated['featureChoices'], {
        'fighting-style': ['fs-defense'],
      });
    });

    test('un featureChoices basura no cuesta la ficha', () {
      expect(Character.fromJson(v6(featureChoices: 3)).featureChoices, isEmpty);
      expect(
        Character.fromJson(
          v6(
            featureChoices: {
              'fighting-style': [1, 'fs-defense', null],
              'otro': 'no-es-lista',
            },
          ),
        ).featureChoices,
        {
          'fighting-style': ['fs-defense'],
        },
      );
    });
  });

  test('rechaza una versión futura con un error comprensible', () {
    final future = {
      'schemaVersion': Character.currentSchemaVersion + 1,
    };

    expect(
      () => Character.migrateJson(future),
      throwsA(
        isA<UnsupportedDataVersionException>()
            .having(
              (e) => e.found,
              'versión encontrada',
              Character.currentSchemaVersion + 1,
            )
            .having(
              (e) => e.supported,
              'versión soportada',
              Character.currentSchemaVersion,
            ),
      ),
    );
  });
}
