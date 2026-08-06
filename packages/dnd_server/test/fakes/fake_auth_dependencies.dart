import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:dnd_server/src/auth/session_store.dart';

/// Doble en memoria de [AuthDependencies]: mapea tokens de sesión a cuentas y
/// simula el intercambio OIDC sin red ni base de datos real.
/// [failCompleteLoginWith] deja elegir, por prueba, si el "proveedor" acepta o
/// rechaza el código que vuelve en el callback.
class FakeAuthDependencies {
  final Map<String, String> sessionsByToken = {};
  final Map<String, SessionProfile> profilesByToken = {};
  final Map<String, String> accountsBySubject = {};
  int _tokenCounter = 0;

  /// Si no es null, `completeLogin` lo lanza en vez de devolver una identidad:
  /// simula una aserción con emisor o firma inválidos.
  Object? failCompleteLoginWith;

  /// Identidad que "verifica" el próximo callback, salvo que
  /// [failCompleteLoginWith] esté seteado.
  OidcIdentity nextVerifiedIdentity = const OidcIdentity(
    subject: 'oidc-subject-1',
    name: 'Ada Lovelace',
    email: 'ada@example.org',
    logoutUrl: 'https://idp.example/end_session?id_token_hint=abc',
  );

  /// Atajo para las pruebas a las que solo les importa *qué cuenta* entra y no
  /// el perfil: cambia el sujeto conservando el resto de la identidad.
  set nextVerifiedSubject(String subject) {
    final previous = nextVerifiedIdentity;
    nextVerifiedIdentity = OidcIdentity(
      subject: subject,
      name: previous.name,
      email: previous.email,
      pictureUrl: previous.pictureUrl,
      logoutUrl: previous.logoutUrl,
    );
  }

  late final AuthDependencies dependencies = AuthDependencies(
    resolveUserId: (token) async => sessionsByToken[token],
    beginLogin: () => Uri.parse('https://idp.example/authorize?state=abc'),
    completeLogin: (params) async {
      if (failCompleteLoginWith != null) throw failCompleteLoginWith!;
      return nextVerifiedIdentity;
    },
    createSessionForIdentity: (identity) async {
      final userId = accountsBySubject.putIfAbsent(
        identity.subject,
        () => 'account-${accountsBySubject.length + 1}',
      );
      // Termina en `=` a propósito: el token real es base64url de 32 bytes y
      // siempre trae relleno. Con tokens sin `=` toda esta batería pasaba en
      // verde mientras el despliegue real no podía leer una sola cookie.
      final token = 'token-${_tokenCounter++}=';
      sessionsByToken[token] = userId;
      profilesByToken[token] = SessionProfile(
        name: identity.name,
        email: identity.email,
        pictureUrl: identity.pictureUrl,
        logoutUrl: identity.logoutUrl,
      );
      return token;
    },
    sessionProfile: (token) async =>
        sessionsByToken.containsKey(token) ? profilesByToken[token] : null,
    invalidateSession: (token) async {
      sessionsByToken.remove(token);
      profilesByToken.remove(token);
    },
  );
}
