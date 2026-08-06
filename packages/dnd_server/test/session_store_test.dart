import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:dnd_server/src/auth/session_store.dart';
import 'package:dnd_server/src/auth/session_token.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'fakes/recording_session.dart';

Object? _valueOf(Object? parameter) =>
    parameter is TypedValue ? parameter.value : parameter;

void main() {
  late RecordingSession session;
  late PostgresSessionStore store;

  setUp(() {
    session = RecordingSession();
    store = PostgresSessionStore(session);
  });

  group('create', () {
    test('guarda el hash del token, nunca el token en claro', () async {
      final token = await store.create('11111111-1111-1111-1111-111111111111');

      final insert = session.executedParameters.last!;
      expect(_valueOf(insert['tokenHash']), hashSessionToken(token));
      expect(
        session.executedParameters.map(
          (p) => p?.values.map(_valueOf).toList() ?? const [],
        ),
        everyElement(isNot(contains(token))),
        reason: 'el token en claro llegó a la base',
      );
    });

    test('el vencimiento sale del ttl pedido', () async {
      final antes = DateTime.now().toUtc();

      await store.create(
        '11111111-1111-1111-1111-111111111111',
        ttl: const Duration(hours: 3),
      );

      final expiresAt =
          _valueOf(session.executedParameters.last!['expiresAt']) as DateTime;
      expect(expiresAt.isAfter(antes.add(const Duration(hours: 2))), isTrue);
      expect(
        expiresAt.isBefore(antes.add(const Duration(hours: 4))),
        isTrue,
        reason: 'expiresAt fue $expiresAt',
      );
    });

    // La tabla `sessions` solo crece: nada borraba las filas vencidas, y cada
    // login abre una fila nueva. Un ciclo de login roto la llena en minutos.
    test('purga las sesiones vencidas además de insertar la nueva', () async {
      await store.create('11111111-1111-1111-1111-111111111111');

      expect(
        session.executedCount,
        2,
        reason: 'se esperaba la purga de vencidas más el INSERT',
      );
      expect(
        session.executedParameters.first,
        isNull,
        reason: 'la purga no lleva parámetros: se acota con now() en el SQL',
      );
    });
  });

  group('perfil de la sesión', () {
    test('el perfil verificado se guarda junto con la sesión', () async {
      await store.create(
        '11111111-1111-1111-1111-111111111111',
        identity: const OidcIdentity(
          subject: 'oidc-subject-1',
          name: 'Ada Lovelace',
          email: 'ada@example.org',
          pictureUrl: 'https://idp.example/ada.png',
          logoutUrl: 'https://idp.example/end_session?id_token_hint=abc',
        ),
      );

      final insert = session.executedParameters.last!;
      expect(_valueOf(insert['displayName']), 'Ada Lovelace');
      expect(_valueOf(insert['email']), 'ada@example.org');
      expect(_valueOf(insert['pictureUrl']), 'https://idp.example/ada.png');
      expect(
        _valueOf(insert['logoutUrl']),
        'https://idp.example/end_session?id_token_hint=abc',
      );
    });

    // Un login sin claims de perfil (scope no concedido, cuenta incompleta)
    // tiene que abrir sesión igual: solo se pierde qué mostrar en pantalla.
    test('sin identidad, las columnas de perfil quedan en null', () async {
      await store.create('11111111-1111-1111-1111-111111111111');

      final insert = session.executedParameters.last!;
      expect(_valueOf(insert['displayName']), isNull);
      expect(_valueOf(insert['logoutUrl']), isNull);
    });

    test('profileForToken consulta por el hash, no por el token', () async {
      final token = generateSessionToken();
      session.nextRows = [
        {
          'display_name': 'Ada Lovelace',
          'email': 'ada@example.org',
          'picture_url': null,
          'logout_url': 'https://idp.example/end_session',
        },
      ];

      final profile = await store.profileForToken(token);

      expect(profile!.name, 'Ada Lovelace');
      expect(profile.email, 'ada@example.org');
      expect(profile.pictureUrl, isNull);
      expect(profile.logoutUrl, 'https://idp.example/end_session');
      final params = session.executedParameters.single!;
      expect(_valueOf(params['tokenHash']), hashSessionToken(token));
      expect(params.values.map(_valueOf), isNot(contains(token)));
    });

    test('sin filas devuelve null', () async {
      expect(await store.profileForToken(generateSessionToken()), isNull);
    });
  });

  group('deleteExpired', () {
    test('emite una sola sentencia sin parámetros', () async {
      await store.deleteExpired();

      expect(session.executedCount, 1);
      expect(session.executedParameters.single, isNull);
    });

    // La red de seguridad de verdad: un DELETE sin este predicado cerraría la
    // sesión de todas las cuentas conectadas.
    test('el DELETE está acotado a las que ya vencieron', () {
      expect(deleteExpiredSessionsSql, contains('DELETE FROM sessions'));
      expect(deleteExpiredSessionsSql, contains('expires_at <= now()'));
    });
  });

  group('userIdForToken', () {
    test('consulta por el hash, nunca por el token en claro', () async {
      final token = generateSessionToken();
      session.nextRows = [
        {'user_id': '11111111-1111-1111-1111-111111111111'},
      ];

      final userId = await store.userIdForToken(token);

      expect(userId, '11111111-1111-1111-1111-111111111111');
      final params = session.executedParameters.single!;
      expect(_valueOf(params['tokenHash']), hashSessionToken(token));
      expect(params.values.map(_valueOf), isNot(contains(token)));
    });

    test('sin filas devuelve null', () async {
      expect(await store.userIdForToken(generateSessionToken()), isNull);
    });
  });

  group('invalidate', () {
    test('borra por el hash, nunca por el token en claro', () async {
      final token = generateSessionToken();

      await store.invalidate(token);

      final params = session.executedParameters.single!;
      expect(_valueOf(params['tokenHash']), hashSessionToken(token));
      expect(params.values.map(_valueOf), isNot(contains(token)));
    });
  });
}
