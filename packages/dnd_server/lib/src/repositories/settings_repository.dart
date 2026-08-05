import 'package:postgres/postgres.dart';

/// Ajustes de una cuenta: un único documento JSON, igual que `settings.json`
/// en la aplicación de escritorio pero con propiedad por cuenta en vez de por
/// máquina.
abstract class SettingsRepository {
  /// `null` si la cuenta todavía no guardó ningún ajuste.
  Future<Map<String, dynamic>?> find(String userId);

  Future<void> save(String userId, Map<String, dynamic> document);
}

class PostgresSettingsRepository implements SettingsRepository {
  final Session _session;

  const PostgresSettingsRepository(this._session);

  @override
  Future<Map<String, dynamic>?> find(String userId) async {
    final result = await _session.execute(
      Sql.named(
        'SELECT document FROM account_settings WHERE user_id = @userId',
      ),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    if (result.isEmpty) return null;
    return (result.first.toColumnMap()['document'] as Map)
        .cast<String, dynamic>();
  }

  @override
  Future<void> save(String userId, Map<String, dynamic> document) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO account_settings (user_id, document, updated_at)
        VALUES (@userId, @document, now())
        ON CONFLICT (user_id)
        DO UPDATE SET document = excluded.document, updated_at = now()
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'document': TypedValue(Type.jsonb, document),
      },
    );
  }
}
