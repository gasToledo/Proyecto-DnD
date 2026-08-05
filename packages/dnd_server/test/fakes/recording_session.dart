import 'package:postgres/postgres.dart';

/// Doble de [Session] que registra cada `execute` (con sus parámetros) y
/// devuelve las filas que se le programen. No ejecuta SQL de verdad: sirve
/// para fijar qué manda a la base [PostgresSessionStore] —sobre todo, qué
/// valores viajan como parámetros— sin una base real.
class RecordingSession implements Session {
  /// Un elemento por `execute`, en orden. `null` cuando la sentencia no
  /// llevó parámetros.
  final List<Map<String, Object?>?> executedParameters = [];

  /// Filas que devuelve el próximo `execute`. Se consume en el primero que
  /// ocurra, así que se programa justo antes de la consulta que se prueba.
  List<Map<String, Object?>> nextRows = const [];

  int get executedCount => executedParameters.length;

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
    executedParameters.add(
      parameters == null ? null : (parameters as Map).cast<String, Object?>(),
    );

    final rows = nextRows;
    nextRows = const [];
    if (rows.isEmpty) {
      return Result(rows: const [], affectedRows: 0, schema: ResultSchema([]));
    }

    final columns = rows.first.keys.toList();
    final schema = ResultSchema([
      for (final column in columns)
        ResultSchemaColumn(typeOid: 25, type: Type.text, columnName: column),
    ]);
    return Result(
      rows: [
        for (final row in rows)
          ResultRow(
            values: [for (final column in columns) row[column]],
            schema: schema,
          ),
      ],
      affectedRows: rows.length,
      schema: schema,
    );
  }
}
