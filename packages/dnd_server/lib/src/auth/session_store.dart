import 'package:postgres/postgres.dart';

import 'session_token.dart';

/// Sesiones de servidor: la cookie del navegador solo lleva un token opaco,
/// nunca un id de cuenta ni un token del proveedor OIDC. Cerrar sesión o
/// dejarla expirar invalida el acceso sin que el cliente pueda hacer nada
/// para revivirla.
abstract class SessionStore {
  /// Crea una sesión para [userId] y devuelve el token que va en la cookie.
  Future<String> create(String userId, {Duration ttl});

  /// `null` si el token no existe o ya expiró.
  Future<String?> userIdForToken(String token);

  Future<void> invalidate(String token);
}

class PostgresSessionStore implements SessionStore {
  final Session _session;
  static const Duration defaultTtl = Duration(hours: 12);

  const PostgresSessionStore(this._session);

  @override
  Future<String> create(String userId, {Duration ttl = defaultTtl}) async {
    final token = generateSessionToken();
    await _session.execute(
      Sql.named('''
        INSERT INTO sessions (token_hash, user_id, expires_at)
        VALUES (@tokenHash, @userId, @expiresAt)
      '''),
      parameters: {
        'tokenHash': TypedValue(Type.text, hashSessionToken(token)),
        'userId': TypedValue(Type.uuid, userId),
        'expiresAt': TypedValue(
          Type.timestampWithTimezone,
          DateTime.now().toUtc().add(ttl),
        ),
      },
    );
    return token;
  }

  @override
  Future<String?> userIdForToken(String token) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT user_id FROM sessions
        WHERE token_hash = @tokenHash AND expires_at > now()
      '''),
      parameters: {'tokenHash': TypedValue(Type.text, hashSessionToken(token))},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['user_id'] as String;
  }

  @override
  Future<void> invalidate(String token) async {
    await _session.execute(
      Sql.named('DELETE FROM sessions WHERE token_hash = @tokenHash'),
      parameters: {'tokenHash': TypedValue(Type.text, hashSessionToken(token))},
    );
  }
}
