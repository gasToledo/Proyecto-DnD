import 'package:dnd_server/src/app.dart';

/// Doble en memoria de [AuthDependencies]: mapea tokens de sesión a cuentas y
/// simula el intercambio OIDC sin red ni base de datos real. `subjectForCode`
/// deja elegir, por prueba, si el "proveedor" acepta o rechaza el código que
/// vuelve en el callback.
class FakeAuthDependencies {
  final Map<String, String> sessionsByToken = {};
  final Map<String, String> accountsBySubject = {};
  int _tokenCounter = 0;

  /// Si no es null, `completeLogin` lo lanza en vez de devolver un sujeto:
  /// simula una aserción con emisor o firma inválidos.
  Object? failCompleteLoginWith;

  /// Sujeto que "verifica" el próximo callback, salvo que
  /// [failCompleteLoginWith] esté seteado.
  String nextVerifiedSubject = 'oidc-subject-1';

  late final AuthDependencies dependencies = AuthDependencies(
    resolveUserId: (token) async => sessionsByToken[token],
    beginLogin: () => Uri.parse('https://idp.example/authorize?state=abc'),
    completeLogin: (params) async {
      if (failCompleteLoginWith != null) throw failCompleteLoginWith!;
      return nextVerifiedSubject;
    },
    createSessionForSubject: (subject) async {
      final userId = accountsBySubject.putIfAbsent(
        subject,
        () => 'account-${accountsBySubject.length + 1}',
      );
      // Termina en `=` a propósito: el token real es base64url de 32 bytes y
      // siempre trae relleno. Con tokens sin `=` toda esta batería pasaba en
      // verde mientras el despliegue real no podía leer una sola cookie.
      final token = 'token-${_tokenCounter++}=';
      sessionsByToken[token] = userId;
      return token;
    },
    invalidateSession: (token) async {
      sessionsByToken.remove(token);
    },
  );
}
