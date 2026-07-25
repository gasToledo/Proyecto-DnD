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
