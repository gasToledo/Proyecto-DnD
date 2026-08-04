import 'package:dnd_server/src/auth/session_token.dart';
import 'package:test/test.dart';

void main() {
  test('dos tokens generados no se repiten', () {
    final tokens = {for (var i = 0; i < 200; i++) generateSessionToken()};

    expect(tokens.length, 200);
  });

  test('el hash es determinístico para el mismo token', () {
    final token = generateSessionToken();

    expect(hashSessionToken(token), hashSessionToken(token));
  });

  test('el hash nunca contiene el token en claro', () {
    final token = generateSessionToken();

    expect(hashSessionToken(token), isNot(contains(token)));
  });

  test('tokens distintos producen hashes distintos', () {
    final a = generateSessionToken();
    final b = generateSessionToken();

    expect(hashSessionToken(a), isNot(hashSessionToken(b)));
  });
}
