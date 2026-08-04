import 'package:postgres/postgres.dart';

/// Doble de [Session] que entiende exactamente las tres formas de consulta
/// que emite [MigrationRunner]: no ejecuta SQL de verdad, así que sirve para
/// probar la lógica de secuenciación (qué se aplica, en qué orden, qué queda
/// registrado) sin una base de datos real.
class FakeMigrationSession implements Session {
  final Set<String> appliedIds;
  final List<String> executedMigrationSql = [];
  final List<String> insertedIds = [];

  FakeMigrationSession({Set<String>? appliedIds})
    : appliedIds = appliedIds ?? <String>{};

  static final _idColumnSchema = ResultSchema([
    ResultSchemaColumn(typeOid: 25, type: Type.text, columnName: 'id'),
  ]);

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed => Future<void>.value();

  @override
  Future<Statement> prepare(Object query) => throw UnimplementedError();

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    if (query is String) {
      if (query.contains('CREATE TABLE IF NOT EXISTS schema_migrations')) {
        return _empty();
      }
      if (query.contains('SELECT id FROM schema_migrations')) {
        return Result(
          rows: [
            for (final id in appliedIds)
              ResultRow(values: [id], schema: _idColumnSchema),
          ],
          affectedRows: appliedIds.length,
          schema: _idColumnSchema,
        );
      }
      executedMigrationSql.add(query);
      return _empty();
    }

    final params = (parameters as Map).cast<String, Object?>();
    final id = (params['id'] as TypedValue).value as String;
    insertedIds.add(id);
    appliedIds.add(id);
    return _empty();
  }

  Result _empty() =>
      Result(rows: const [], affectedRows: 0, schema: ResultSchema(const []));
}
