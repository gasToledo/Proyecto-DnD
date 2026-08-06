import 'package:postgres/postgres.dart';

import 'oidc_service.dart';
import 'session_token.dart';

/// Perfil cacheado de la sesión: lo que el proveedor OIDC afirmó al abrirla.
/// Todos los campos pueden ser `null` (sesión anterior a `0004_sessions_profile`,
/// o cuenta sin esos claims), así que la pantalla tiene que tolerarlo.
class SessionProfile {
  final String? name;
  final String? email;
  final String? pictureUrl;
  final String? logoutUrl;

  const SessionProfile({
    this.name,
    this.email,
    this.pictureUrl,
    this.logoutUrl,
  });
}

/// Sesiones de servidor: la cookie del navegador solo lleva un token opaco,
/// nunca un id de cuenta ni un token del proveedor OIDC. Cerrar sesión o
/// dejarla expirar invalida el acceso sin que el cliente pueda hacer nada
/// para revivirla.
abstract class SessionStore {
  /// Crea una sesión para [userId] y devuelve el token que va en la cookie.
  /// [identity] es lo que el proveedor afirmó en este login; se guarda para
  /// poder mostrar la cuenta en pantalla sin volver a preguntarle.
  Future<String> create(String userId, {OidcIdentity? identity, Duration ttl});

  /// `null` si el token no existe o ya expiró.
  Future<String?> userIdForToken(String token);

  /// Perfil cacheado de la sesión, o `null` si el token no existe o venció.
  /// Consulta aparte de [userIdForToken] a propósito: esa es la que corre en
  /// cada request autenticado y no necesita leer el perfil.
  Future<SessionProfile?> profileForToken(String token);

  Future<void> invalidate(String token);

  /// Borra las sesiones ya vencidas. [userIdForToken] igual las ignora, así
  /// que esto no cambia quién puede entrar: existe solo para que la tabla no
  /// crezca sin techo.
  Future<void> deleteExpired();
}

/// El `WHERE` no es opcional: sin él, esta sentencia cerraría la sesión de
/// todas las cuentas conectadas. Se expone para que una prueba pueda fijar
/// ese predicado (ver `session_store_test.dart`), porque el doble de
/// [Session] registra parámetros pero no interpreta SQL.
const String deleteExpiredSessionsSql =
    'DELETE FROM sessions WHERE expires_at <= now()';

class PostgresSessionStore implements SessionStore {
  final Session _session;
  static const Duration defaultTtl = Duration(hours: 12);

  const PostgresSessionStore(this._session);

  @override
  Future<void> deleteExpired() async {
    await _session.execute(deleteExpiredSessionsSql);
  }

  /// Aprovecha el login —lo único que hace crecer la tabla— para barrer lo
  /// vencido, en vez de sumar un proceso periódico al contenedor. Es la
  /// operación menos frecuente del servidor (una por cuenta cada 12 horas),
  /// así que el barrido nunca compite con el tráfico normal de fichas.
  @override
  Future<String> create(
    String userId, {
    OidcIdentity? identity,
    Duration ttl = defaultTtl,
  }) async {
    await deleteExpired();
    final token = generateSessionToken();
    await _session.execute(
      Sql.named('''
        INSERT INTO sessions (
          token_hash, user_id, expires_at,
          display_name, email, picture_url, logout_url
        )
        VALUES (
          @tokenHash, @userId, @expiresAt,
          @displayName, @email, @pictureUrl, @logoutUrl
        )
      '''),
      parameters: {
        'tokenHash': TypedValue(Type.text, hashSessionToken(token)),
        'userId': TypedValue(Type.uuid, userId),
        'expiresAt': TypedValue(
          Type.timestampWithTimezone,
          DateTime.now().toUtc().add(ttl),
        ),
        'displayName': TypedValue(Type.text, identity?.name),
        'email': TypedValue(Type.text, identity?.email),
        'pictureUrl': TypedValue(Type.text, identity?.pictureUrl),
        'logoutUrl': TypedValue(Type.text, identity?.logoutUrl),
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
  Future<SessionProfile?> profileForToken(String token) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT display_name, email, picture_url, logout_url FROM sessions
        WHERE token_hash = @tokenHash AND expires_at > now()
      '''),
      parameters: {'tokenHash': TypedValue(Type.text, hashSessionToken(token))},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return SessionProfile(
      name: row['display_name'] as String?,
      email: row['email'] as String?,
      pictureUrl: row['picture_url'] as String?,
      logoutUrl: row['logout_url'] as String?,
    );
  }

  @override
  Future<void> invalidate(String token) async {
    await _session.execute(
      Sql.named('DELETE FROM sessions WHERE token_hash = @tokenHash'),
      parameters: {'tokenHash': TypedValue(Type.text, hashSessionToken(token))},
    );
  }
}
