import 'package:dnd_server/src/auth/session_cookie.dart';
import 'package:dnd_server/src/auth/session_token.dart';
import 'package:test/test.dart';

void main() {
  group('buildSessionCookieHeader', () {
    test('incluye HttpOnly, Secure y SameSite: la cookie no queda expuesta '
        'a JavaScript ni viaja en peticiones cruzadas', () {
      final header = buildSessionCookieHeader(
        'el-token',
        maxAge: const Duration(hours: 1),
      );

      expect(header, contains('HttpOnly'));
      expect(header, contains('Secure'));
      expect(header, contains('SameSite=Lax'));
      expect(header, contains('el-token'));
      expect(header, contains('Max-Age=3600'));
    });
  });

  group('buildExpiredSessionCookieHeader', () {
    test('vacía el valor y pone Max-Age=0', () {
      final header = buildExpiredSessionCookieHeader();

      expect(header, contains('Max-Age=0'));
      expect(header, contains('$sessionCookieName=;'));
    });
  });

  group('readSessionToken', () {
    test('extrae el token de una cabecera Cookie con una sola cookie', () {
      expect(readSessionToken('dnd_session=abc123'), 'abc123');
    });

    test('encuentra la cookie entre varias', () {
      expect(readSessionToken('otra=1; dnd_session=abc123; mas=2'), 'abc123');
    });

    test('sin cabecera devuelve null', () {
      expect(readSessionToken(null), isNull);
    });

    test('sin la cookie de sesión devuelve null', () {
      expect(readSessionToken('otra=1; mas=2'), isNull);
    });

    // Un valor de cookie puede contener '=' (RFC 6265: la cookie-value es
    // todo lo que sigue al PRIMER '='). Partir por todos los '=' descartaba
    // silenciosamente la cookie y dejaba la petición como no autenticada.
    test('conserva el valor completo cuando el token contiene "="', () {
      expect(readSessionToken('dnd_session=abc=='), 'abc==');
      expect(readSessionToken('otra=1; dnd_session=abc==; mas=2'), 'abc==');
    });

    // La prueba que ata las dos unidades: el token que este servidor emite de
    // verdad —base64url de 32 bytes, siempre con un '=' de relleno— tiene que
    // sobrevivir el viaje de ida y vuelta por la cabecera. Con tokens
    // inventados a mano ('abc123') el fallo era invisible.
    test('un token real sobrevive el viaje por la cabecera Cookie', () {
      for (var i = 0; i < 50; i++) {
        final token = generateSessionToken();
        expect(readSessionToken('$sessionCookieName=$token'), token);
      }
    });
  });
}
