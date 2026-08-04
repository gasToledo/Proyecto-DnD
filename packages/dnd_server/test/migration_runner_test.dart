import 'package:dnd_server/src/db/migration_runner.dart';
import 'package:dnd_server/src/db/migrations.dart';
import 'package:test/test.dart';

import 'fakes/fake_migration_session.dart';

void main() {
  test('aplica todas las migraciones en orden en una base nueva', () async {
    final session = FakeMigrationSession();
    const runner = MigrationRunner([
      Migration(id: '0001_a', sql: 'CREATE TABLE a ();'),
      Migration(id: '0002_b', sql: 'CREATE TABLE b ();'),
    ]);

    final ranNow = await runner.run(session);

    expect(ranNow, ['0001_a', '0002_b']);
    expect(session.executedMigrationSql, [
      'CREATE TABLE a ();',
      'CREATE TABLE b ();',
    ]);
    expect(session.insertedIds, ['0001_a', '0002_b']);
  });

  test('no reaplica una migración ya registrada', () async {
    final session = FakeMigrationSession(appliedIds: {'0001_a'});
    const runner = MigrationRunner([
      Migration(id: '0001_a', sql: 'CREATE TABLE a ();'),
      Migration(id: '0002_b', sql: 'CREATE TABLE b ();'),
    ]);

    final ranNow = await runner.run(session);

    expect(ranNow, ['0002_b']);
    expect(session.executedMigrationSql, ['CREATE TABLE b ();']);
  });

  test('con todo al día no ejecuta ninguna migración', () async {
    final session = FakeMigrationSession(appliedIds: {'0001_a', '0002_b'});
    const runner = MigrationRunner([
      Migration(id: '0001_a', sql: 'CREATE TABLE a ();'),
      Migration(id: '0002_b', sql: 'CREATE TABLE b ();'),
    ]);

    final ranNow = await runner.run(session);

    expect(ranNow, isEmpty);
    expect(session.executedMigrationSql, isEmpty);
  });

  test('la lista real de migraciones no está vacía y arranca en 0001_init', () {
    expect(migrations, isNotEmpty);
    expect(migrations.first.id, '0001_init');
  });
}
