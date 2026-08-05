import 'package:postgres/postgres.dart';

/// Contenido homebrew de una cuenta, agrupado por categoría (`weapons`,
/// `armor`, `feats`, `races`, `backgrounds`, `spells`, ...): la misma
/// partición que ya usa `ContentRepository.fromJsonPacks`. Cada documento es
/// el JSON de una sola entidad de esa categoría; a esta clase no le importa
/// su forma interna, solo su categoría e id.
abstract class HomebrewRepository {
  Future<void> upsert(
    String userId,
    String category,
    String id,
    Map<String, dynamic> document,
  );

  /// Todo el homebrew de una cuenta, agrupado por categoría. El contenido de
  /// una cuenta MUST NOT aparecer para otra: siempre filtrado por [userId].
  Future<Map<String, List<Map<String, dynamic>>>> listForUser(String userId);

  Future<void> delete(String userId, String category, String id);
}

class PostgresHomebrewRepository implements HomebrewRepository {
  final Session _session;

  const PostgresHomebrewRepository(this._session);

  @override
  Future<void> upsert(
    String userId,
    String category,
    String id,
    Map<String, dynamic> document,
  ) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO homebrew_content (user_id, category, id, document, updated_at)
        VALUES (@userId, @category, @id, @document, now())
        ON CONFLICT (user_id, category, id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'category': TypedValue(Type.text, category),
        'id': TypedValue(Type.text, id),
        'document': TypedValue(Type.jsonb, document),
      },
    );
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> listForUser(
    String userId,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT category, document FROM homebrew_content
        WHERE user_id = @userId
        ORDER BY category, id
      '''),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in result) {
      final columns = row.toColumnMap();
      final category = columns['category'] as String;
      final document = (columns['document'] as Map).cast<String, dynamic>();
      (grouped[category] ??= []).add(document);
    }
    return grouped;
  }

  @override
  Future<void> delete(String userId, String category, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM homebrew_content
        WHERE user_id = @userId AND category = @category AND id = @id
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'category': TypedValue(Type.text, category),
        'id': TypedValue(Type.text, id),
      },
    );
  }
}
