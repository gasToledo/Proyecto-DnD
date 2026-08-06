import 'package:openid_client/openid_client.dart';

import '../config.dart';
import 'pending_logins.dart';

/// Une el descubrimiento OIDC, el flujo Authorization Code + PKCE y la
/// verificación del token de identidad. El navegador nunca ve nada de esto:
/// solo redirecciones y, al final, una cookie de sesión (ver
/// `session_cookie.dart`).
class OidcService {
  final OidcConfig config;
  final Client _client;

  /// Flujos de login en curso, indexados por `state`. Vive en memoria: un
  /// login abandonado a medias no necesita sobrevivir a un reinicio, y esta
  /// es una instalación de un solo proceso (ver `self-hosted-deployment`).
  /// [PendingLogins] es lo que le pone vencimiento y techo: en memoria no
  /// quiere decir para siempre.
  final PendingLogins<Flow> _pendingLogins = PendingLogins<Flow>();

  OidcService._(this.config, this._client);

  static Future<OidcService> connect(OidcConfig config) async {
    final issuer = await Issuer.discover(config.issuerUrl);
    final client = Client(
      issuer,
      config.clientId,
      clientSecret: config.clientSecret,
    );
    return OidcService._(config, client);
  }

  /// Arranca un login nuevo. Devuelve la URI a la que redirigir al
  /// navegador; el `state` (y el verificador PKCE) queda guardado en
  /// [_pendingLogins] hasta que llegue el callback.
  Uri beginLogin() {
    final flow = Flow.authorizationCodeWithPKCE(_client)
      ..redirectUri = config.redirectUri;
    _pendingLogins.add(flow.state, flow);
    return flow.authenticationUri;
  }

  /// Completa el login: intercambia el código, verifica la aserción de
  /// identidad y devuelve la identidad OIDC verificada.
  ///
  /// Lanza [OidcCallbackException] si el `state` no corresponde a ningún
  /// login en curso (nunca existió, ya se usó o venció, ver [PendingLogins]),
  /// o si la aserción no verifica (emisor, firma, audiencia, nonce o
  /// expiración inválidos): en todos esos casos la petición se trata como no
  /// autenticada, nunca se asume identidad a partir de datos no verificados.
  Future<OidcIdentity> completeLogin(Map<String, String> callbackParams) async {
    final state = callbackParams['state'];
    final flow = state == null ? null : _pendingLogins.remove(state);
    if (flow == null) {
      throw const OidcCallbackException('Login no reconocido o ya usado.');
    }

    final Credential credential;
    try {
      credential = await flow.callback(callbackParams);
    } catch (error) {
      throw OidcCallbackException('No se pudo completar el login: $error');
    }

    final errors = await credential.validateToken().toList();
    if (errors.isNotEmpty) {
      throw OidcCallbackException(
        'La aserción de identidad no es válida: ${errors.join('; ')}',
      );
    }

    // Los claims se leen recién acá, después de verificar la aserción: lo que
    // se muestre en pantalla como "la cuenta con la que entraste" tiene que
    // salir de datos verificados, igual que el `sub`.
    final claims = credential.idToken.claims;
    return OidcIdentity(
      subject: claims.subject,
      // Zitadel manda `name` si el perfil lo tiene cargado; si no, el nombre
      // de usuario es lo único que distingue una cuenta de otra.
      name: claims.name ?? claims.preferredUsername,
      email: claims.email,
      pictureUrl: claims.picture?.toString(),
      // Se calcula acá, con la credencial todavía en mano, porque al cerrar
      // sesión ya no queda nada del proveedor: la URL lleva el `id_token_hint`
      // que Zitadel necesita para cerrar *su* sesión, no solo la nuestra.
      logoutUrl: credential
          .generateLogoutUrl(redirectUri: config.postLogoutRedirectUri)
          ?.toString(),
    );
  }
}

/// Lo que el proveedor OIDC afirmó de la cuenta en este login, ya verificado.
/// Todo menos [subject] es opcional: son claims que el proveedor puede no
/// mandar (perfil incompleto, scope no concedido) y la aplicación funciona
/// igual sin ellos.
class OidcIdentity {
  final String subject;
  final String? name;
  final String? email;
  final String? pictureUrl;

  /// URL de cierre de sesión del proveedor, ya con el `id_token_hint` y el
  /// destino de vuelta. `null` si el proveedor no publica
  /// `end_session_endpoint`: entonces solo se puede cerrar la sesión local.
  final String? logoutUrl;

  const OidcIdentity({
    required this.subject,
    this.name,
    this.email,
    this.pictureUrl,
    this.logoutUrl,
  });
}

class OidcCallbackException implements Exception {
  final String message;
  const OidcCallbackException(this.message);

  @override
  String toString() => message;
}
