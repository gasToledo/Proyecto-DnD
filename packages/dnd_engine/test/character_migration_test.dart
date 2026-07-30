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

    expect(migrated['schemaVersion'], 5);
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
