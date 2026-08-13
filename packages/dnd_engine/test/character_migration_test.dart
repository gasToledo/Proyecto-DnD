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

  group('v10 → v11: Castigo Arcano pasa a Castigo Sobrenatural', () {
    Map<String, dynamic> brujo(Map<String, dynamic> extra) => {
          'schemaVersion': 10,
          'id': 'v10',
          'name': 'Brujo del Pacto',
          'raceId': 'human',
          'classId': 'warlock',
          'backgroundId': 'soldier',
          'assignedScores': const <String, int>{},
          ...extra,
        };

    test('la invocación se renombra dentro de featureChoices', () {
      // Es donde viven las invocaciones: si la migración sólo mirara `featIds`
      // el brujo perdería la invocación en silencio.
      final migrated = Character.migrateJson(brujo({
        'featureChoices': {
          'warlock-invocation': ['pact-of-the-blade', 'arcane-smite'],
        },
      }));

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(
        (migrated['featureChoices'] as Map)['warlock-invocation'],
        ['pact-of-the-blade', 'eldritch-smite'],
      );
    });

    test('el rename de v7 → v8 sigue alcanzando featIds', () {
      // No-regresión: el helper ahora recorre dos lugares, pero el paso viejo
      // tiene que seguir produciendo exactamente lo mismo.
      final migrated = Character.migrateJson({
        'schemaVersion': 7,
        'id': 'v7c',
        'name': 'Atleta',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'featIds': const ['athlete'],
      });

      expect(migrated['featIds'], ['athlete-dexterity']);
    });

    test('tolera un featureChoices con basura', () {
      final migrated = Character.migrateJson(brujo({
        'featureChoices': {
          'warlock-invocation': ['arcane-smite', 42, null],
          'roto': 'no es una lista',
        },
      }));

      final choices = migrated['featureChoices'] as Map;
      expect(choices['warlock-invocation'], ['eldritch-smite', 42, null]);
      expect(choices['roto'], 'no es una lista');
    });
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

  group('v12 → v13: habilidad temporal del Kalashtar', () {
    test('descarta la antigua habilidad permanente de especie', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 12,
        'raceId': 'kalashtar',
        'chosenSkills': ['arcana', 'stealth', 'perception'],
      });

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['chosenSkills'], ['arcana', 'stealth']);
    });

    test('no toca las habilidades de otras especies', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 12,
        'raceId': 'shifter',
        'chosenSkills': ['arcana', 'stealth', 'survival'],
      });

      expect(migrated['chosenSkills'], ['arcana', 'stealth', 'survival']);
    });
  });

  group('v18 → v19: inventario y monedas', () {
    test('el inventario arranca con lo que la ficha ya llevaba puesto', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 18,
        'id': 'v18',
        'name': 'Exploradora',
        'raceId': 'human',
        'classId': 'ranger',
        'backgroundId': 'outlander',
        'assignedScores': const <String, int>{},
        'equippedArmorId': 'leather',
        'shieldEquipped': true,
        'equippedWeaponIds': ['longbow', 'shortsword'],
      });

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['coins'], isEmpty);
      expect(
        [for (final e in migrated['inventory'] as List) e['itemId']],
        ['leather', 'shield', 'longbow', 'shortsword'],
      );
    });

    test('una ficha sin nada equipado migra a un inventario vacío', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 18,
        'id': 'v18-desnudo',
        'assignedScores': const <String, int>{},
      });

      expect(migrated['inventory'], isEmpty);
      expect(migrated['coins'], isEmpty);
    });

    test('no pisa un inventario que ya venía', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 18,
        'inventory': [
          {'itemId': 'torch', 'quantity': 5},
        ],
        'coins': {'gp': 12},
        'equippedWeaponIds': ['club'],
      });

      expect(migrated['inventory'], hasLength(1));
      expect(migrated['coins'], {'gp': 12});
    });
  });

  group('v19 → v20: equipado vive en cada entrada', () {
    test('conserva armadura, escudo, armas y metadatos del inventario', () {
      final character = Character.fromJson({
        'schemaVersion': 19,
        'id': 'v19',
        'name': 'Veterana',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'equippedArmorId': 'plate',
        'shieldEquipped': true,
        'equippedWeaponIds': ['longsword'],
        'inventory': [
          {'itemId': 'plate', 'quantity': 1, 'note': 'Abollada'},
          {'itemId': 'shield', 'quantity': 1},
          {
            'itemId': 'longsword',
            'quantity': 2,
            'attuned': true,
            'note': 'La segunda queda de repuesto',
          },
          {'itemId': 'torch', 'quantity': 7},
        ],
      });

      expect(character.inventory.map((entry) => entry.entryId).toSet(), {
        'legacy-0-plate',
        'legacy-1-shield',
        'legacy-2-longsword',
        'legacy-3-torch',
      });
      expect(
        character.inventory
            .where((entry) => entry.equipped)
            .map((entry) => entry.itemId),
        containsAll(['plate', 'shield', 'longsword']),
      );
      final sword = character.inventory[2];
      expect(sword.quantity, 2);
      expect(sword.attuned, isTrue);
      expect(sword.note, 'La segunda queda de repuesto');
      expect(character.inventory[3].quantity, 7);
      expect(character.magicItemChoices, isEmpty);
    });
  });

  group('la entrada de inventario sobrevive el ida y vuelta', () {
    test('conserva cantidad, equipado, sintonizado y nota', () {
      final original = Character(
        id: 'ficha',
        name: 'Bruja',
        raceId: 'human',
        classId: 'warlock',
        backgroundId: 'sage',
        assignedScores: const {},
        inventory: const [
          InventoryEntry(
            itemId: 'book',
            quantity: 3,
            equipped: true,
            attuned: true,
            note: 'La carta del alcalde va entre las páginas.',
          ),
        ],
        coins: const {'gp': 25, 'sp': 4},
      );

      final round = Character.fromJson(
        Character.migrateJson(jsonDecode(jsonEncode(original.toJson()))),
      );

      expect(round.inventory, hasLength(1));
      final entry = round.inventory.single;
      expect(entry.itemId, 'book');
      expect(entry.quantity, 3);
      expect(entry.equipped, isTrue);
      expect(entry.attuned, isTrue);
      expect(entry.note, 'La carta del alcalde va entre las páginas.');
      expect(round.coins, {'gp': 25, 'sp': 4});
    });

    test('descarta cantidades y monedas que no se pueden mostrar', () {
      // Una importación no es dato confiable: una cantidad de 0 o una bolsa con
      // −3 piezas de oro tienen que degradar, no romper la carga de la ficha.
      final round = Character.fromJson(
        Character.migrateJson({
          'schemaVersion': Character.currentSchemaVersion,
          'id': 'importada',
          'name': 'Importada',
          'raceId': 'human',
          'classId': 'fighter',
          'backgroundId': 'soldier',
          'assignedScores': const <String, int>{},
          'inventory': [
            {'itemId': 'rope', 'quantity': 0},
          ],
          'coins': {'gp': -3, 'sp': 5, 'chapitas': 99},
        }),
      );

      expect(round.inventory.single.quantity, 1);
      expect(round.coins, {'sp': 5});
    });
  });

  group('v13 → v14: elección de conjuros', () {
    test('la ficha vieja arranca sin ninguna elegida', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 13,
        'id': 'v13',
        'name': 'Maga',
        'raceId': 'human',
        'classId': 'wizard',
        'backgroundId': 'sage',
        'assignedScores': const <String, int>{},
      });

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['spellChoices'], isEmpty);
    });

    test('no pisa lo que ya venía elegido', () {
      final migrated = Character.migrateJson({
        'schemaVersion': 13,
        'spellChoices': {
          'class:wizard:signature-spells': ['fireball'],
        },
      });

      expect(migrated['spellChoices'], {
        'class:wizard:signature-spells': ['fireball'],
      });
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

  group('v11 → v12: los retratos pasan de ruta absoluta a clave opaca', () {
    test('una ruta de Windows se convierte en characterId/archivo', () {
      final source = {
        'schemaVersion': 8,
        'id': 'con-retratos',
        'name': 'Retratada',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'portraitPaths': const [
          r'C:\Users\jugador\FichasDnD\portraits\con-retratos\111.png',
          r'C:\Users\jugador\FichasDnD\portraits\con-retratos\222.png',
        ],
      };

      final migrated = Character.migrateJson(source);

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['portraitPaths'], [
        'con-retratos/111.png',
        'con-retratos/222.png',
      ]);
      final character = Character.fromJson(source);
      expect(character.portraitPaths, [
        'con-retratos/111.png',
        'con-retratos/222.png',
      ]);
      // Ninguna clave conserva nada que identifique la máquina de origen.
      for (final key in character.portraitPaths) {
        expect(key.contains(':'), isFalse);
        expect(key.contains(r'\'), isFalse);
        expect(key.contains('Users'), isFalse);
      }
    });

    test('una ruta POSIX también se reduce a la clave', () {
      final source = {
        'schemaVersion': 8,
        'id': 'posix',
        'name': 'Retratada',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'portraitPaths': const [
          '/home/jugador/FichasDnD/portraits/posix/333.png',
        ],
      };

      expect(
        Character.fromJson(source).portraitPaths,
        ['posix/333.png'],
      );
    });

    test('sin retratos no agrega nada', () {
      final source = {
        'schemaVersion': 8,
        'id': 'sin-retratos',
        'name': 'Sin retrato',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
      };

      expect(Character.fromJson(source).portraitPaths, isEmpty);
    });

    // La ficha que de verdad existe en disco: una publicada por la v0.5.1 de
    // escritorio, que ya pasó por la cadena vieja y quedó en 11 con rutas
    // absolutas. Si el paso de retratos se hubiera dejado en 8→9, este
    // documento nunca lo cruzaría y llegaría al servidor con `C:\Users\...`.
    test('una ficha de escritorio ya en v11 también se convierte', () {
      final source = {
        'schemaVersion': 11,
        'id': 'veterana',
        'name': 'Veterana',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'portraitPaths': const [
          r'C:\Users\jugador\FichasDnD\portraits\veterana\retrato.png',
        ],
      };

      final migrated = Character.migrateJson(source);

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['portraitPaths'], ['veterana/retrato.png']);
    });

    // El otro documento que existe de verdad: uno guardado por el servidor
    // mientras su rama numeraba este mismo paso como 8→9, así que ya tiene la
    // clave opaca y arranca la cadena en 9. Cruza los pasos 9→10 y 10→11 que
    // en su origen no existían, y vuelve a cruzar el de retratos.
    //
    // Que eso sea inocuo es lo que hace segura la renumeración, y depende de
    // dos propiedades que conviene dejar clavadas: el paso de retratos es
    // idempotente sobre una clave ya convertida, y saltearse el `case 8:`
    // deja `proficiencyChoices` igual que si se hubiera aplicado.
    test('una ficha del servidor ya en v9 no se corrompe al renumerar', () {
      final source = {
        'schemaVersion': 9,
        'id': 'del-servidor',
        'name': 'Sembrada',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'portraitPaths': const ['del-servidor/retrato.png'],
      };

      final migrated = Character.migrateJson(source);

      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['portraitPaths'], ['del-servidor/retrato.png']);
      expect(Character.fromJson(source).proficiencyChoices, isEmpty);
    });

    test('una entrada que no es String se descarta sin perder la ficha', () {
      final source = {
        'schemaVersion': 8,
        'id': 'basura-retrato',
        'name': 'Importada',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': const <String, int>{},
        'portraitPaths': const [
          r'C:\Users\jugador\FichasDnD\portraits\basura-retrato\1.png',
          42,
          null,
        ],
      };

      expect(
        Character.fromJson(source).portraitPaths,
        ['basura-retrato/1.png'],
      );
    });
  });

  group('15 → 16: compañeros invocados', () {
    Map<String, dynamic> at15({Map<String, dynamic>? combat}) => {
          'schemaVersion': 15,
          'id': 'artillero',
          'name': 'Artillero',
          'raceId': 'human',
          'classId': 'artificer',
          'backgroundId': 'sage',
          'assignedScores': const <String, int>{},
          if (combat != null) 'combat': combat,
        };

    test('una ficha sin compañeros queda con la lista vacía', () {
      final migrated = Character.migrateJson(at15());
      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect((migrated['combat'] as Map)['companions'], isEmpty);
      expect(Character.fromJson(at15()).combat.companions, isEmpty);
    });

    test('no pisa el resto del estado de combate', () {
      final character = Character.fromJson(
        at15(combat: {'currentHp': 17, 'exhaustion': 2}),
      );
      expect(character.combat.currentHp, 17);
      expect(character.combat.exhaustion, 2);
      expect(character.combat.companions, isEmpty);
    });
  });

  group('16 → 17: formas de Forma Salvaje', () {
    Map<String, dynamic> at16() => {
          'schemaVersion': 16,
          'id': 'druida',
          'name': 'Druida',
          'raceId': 'human',
          'classId': 'druid',
          'backgroundId': 'sage',
          'level': 4,
          'assignedScores': const <String, int>{},
          'spellIds': const ['entangle'],
          'combat': const {'currentHp': 21},
        };

    test('un druida viejo queda sin formas anotadas y con todo lo demás', () {
      final migrated = Character.migrateJson(at16());
      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['wildShapeForms'], isEmpty);

      final character = Character.fromJson(at16());
      expect(character.wildShapeForms, isEmpty);
      expect(character.level, 4);
      expect(character.spellIds, ['entangle']);
      expect(character.combat.currentHp, 21);
      expect(character.combat.wildShapeCreatureId, isNull);
    });
  });

  group('17 → 18: aptitud mágica elegida por dote', () {
    Map<String, dynamic> at17() => {
          'schemaVersion': 17,
          'id': 'marcado',
          'name': 'Marcado',
          'raceId': 'human',
          'classId': 'fighter',
          'backgroundId': 'soldier',
          'level': 4,
          'assignedScores': const <String, int>{},
          'featIds': const ['mark-of-storm'],
          'spellIds': const [],
          'combat': const {'currentHp': 30},
        };

    test('una ficha vieja queda sin elección y no pierde nada', () {
      final migrated = Character.migrateJson(at17());
      expect(migrated['schemaVersion'], Character.currentSchemaVersion);
      expect(migrated['featSpellcastingAbilities'], isEmpty);

      final character = Character.fromJson(at17());
      // Pendiente, no inventada: el motor no elige por el jugador.
      expect(character.featSpellcastingAbilities, isEmpty);
      expect(character.featIds, ['mark-of-storm']);
      expect(character.level, 4);
      expect(character.combat.currentHp, 30);
    });

    test('la elección sobrevive el round-trip de la versión actual', () {
      final elegido = Character(
        id: 'marcado',
        name: 'Marcado',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'soldier',
        level: 4,
        assignedScores: const {},
        hpPerLevel: const [10, 6, 6, 6],
        featIds: const ['mark-of-storm', 'magic-initiate-wizard'],
        featSpellcastingAbilities: const {
          'mark-of-storm': Ability.charisma,
          'magic-initiate-wizard': Ability.wisdom,
        },
      );
      final vuelta = Character.fromJson(elegido.toJson());
      expect(vuelta.featSpellcastingAbilities, {
        'mark-of-storm': Ability.charisma,
        'magic-initiate-wizard': Ability.wisdom,
      });
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
