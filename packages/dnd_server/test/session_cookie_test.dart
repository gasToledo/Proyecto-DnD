import 'package:dnd_server/src/auth/session_cookie.dart';
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
  });
}
