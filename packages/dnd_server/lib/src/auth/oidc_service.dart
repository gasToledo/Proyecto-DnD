import 'package:openid_client/openid_client.dart';

import '../config.dart';

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
  final Map<String, Flow> _pendingLogins = {};

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
    _pendingLogins[flow.state] = flow;
    return flow.authenticationUri;
  }

  /// Completa el login: intercambia el código, verifica la aserción de
  /// identidad y devuelve el sujeto OIDC verificado (`sub`).
  ///
  /// Lanza [OidcCallbackException] si el `state` no corresponde a ningún
  /// login en curso, o si la aserción no verifica (emisor, firma, audiencia,
  /// nonce o expiración inválidos): en ambos casos la petición se trata como
  /// no autenticada, nunca se asume identidad a partir de datos no
  /// verificados.
  Future<String> completeLogin(Map<String, String> callbackParams) async {
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

    final subject = credential.idToken.claims.subject;
    return subject;
  }
}

class OidcCallbackException implements Exception {
  final String message;
  const OidcCallbackException(this.message);

  @override
  String toString() => message;
}
