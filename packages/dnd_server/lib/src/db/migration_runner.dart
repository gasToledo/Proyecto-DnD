import 'package:postgres/postgres.dart';

import 'migrations.dart' as schema;
import 'migrations.dart' show Migration;

/// Ejecuta las migraciones pendientes contra una sesión de Postgres,
/// llevando el registro en `schema_migrations`. Pensado para correr al
/// arrancar el servidor (una sola conexión, antes de aceptar tráfico), no
/// dentro de la conexión de cada request.
class MigrationRunner {
  final List<Migration> _migrations;

  const MigrationRunner([List<Migration>? migrations])
    : _migrations = migrations ?? schema.migrations;

  /// Aplica, en orden, las migraciones que todavía no estén registradas.
  /// Devuelve los ids recién aplicados (vacío si ya estaba todo al día).
  Future<List<String>> run(Session session) async {
    await session.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    ''');

    final appliedRows = await session.execute(
      'SELECT id FROM schema_migrations',
    );
    final applied = {
      for (final row in appliedRows) row.toColumnMap()['id'] as String,
    };

    final ranNow = <String>[];
    for (final migration in _migrations) {
      if (applied.contains(migration.id)) continue;
      await session.execute(migration.sql);
      await session.execute(
        Sql.named('INSERT INTO schema_migrations (id) VALUES (@id)'),
        parameters: {'id': TypedValue(Type.text, migration.id)},
      );
      ranNow.add(migration.id);
    }
    return ranNow;
  }
}
