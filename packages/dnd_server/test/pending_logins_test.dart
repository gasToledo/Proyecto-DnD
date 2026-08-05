import 'package:dnd_server/src/auth/pending_logins.dart';
import 'package:test/test.dart';

void main() {
  late DateTime ahora;
  PendingLogins<String> build({Duration? ttl, int? maxEntries}) =>
      PendingLogins<String>(
        ttl: ttl ?? const Duration(minutes: 15),
        maxEntries: maxEntries ?? 500,
        now: () => ahora,
      );

  setUp(() => ahora = DateTime.utc(2026, 1, 1, 12));

  test('un login en curso se canjea una sola vez', () {
    final pending = build()..add('state-1', 'flujo-1');

    expect(pending.remove('state-1'), 'flujo-1');
    expect(
      pending.remove('state-1'),
      isNull,
      reason: 'un mismo state no debe poder canjearse dos veces',
    );
  });

  test('un state desconocido no canjea nada', () {
    expect(build().remove('state-inventado'), isNull);
  });

  test('un login abandonado deja de ser canjeable al vencer', () {
    final pending = build(ttl: const Duration(minutes: 15))
      ..add('state-1', 'flujo-1');

    ahora = ahora.add(const Duration(minutes: 16));

    expect(pending.remove('state-1'), isNull);
  });

  test('dentro del ttl sigue siendo canjeable', () {
    final pending = build(ttl: const Duration(minutes: 15))
      ..add('state-1', 'flujo-1');

    ahora = ahora.add(const Duration(minutes: 14));

    expect(pending.remove('state-1'), 'flujo-1');
  });

  // El motivo de existir de esta clase: cada `GET /auth/login` sumaba una
  // entrada que no se borraba nunca si el login no se completaba.
  test('los logins abandonados no se acumulan', () {
    final pending = build(ttl: const Duration(minutes: 15));

    for (var i = 0; i < 50; i++) {
      pending.add('state-viejo-$i', 'flujo-$i');
    }
    expect(pending.length, 50);

    ahora = ahora.add(const Duration(minutes: 16));
    pending.add('state-nuevo', 'flujo-nuevo');

    expect(
      pending.length,
      1,
      reason: 'al agregar se barren las entradas ya vencidas',
    );
    expect(pending.remove('state-nuevo'), 'flujo-nuevo');
  });

  // Sin tope, un cliente que solo pide `/auth/login` en bucle hace crecer el
  // mapa hasta agotar la memoria del proceso, todo dentro del ttl.
  test('nunca supera el tope, aunque ninguna entrada haya vencido', () {
    final pending = build(ttl: const Duration(hours: 1), maxEntries: 10);

    for (var i = 0; i < 100; i++) {
      pending.add('state-$i', 'flujo-$i');
    }

    expect(pending.length, 10);
  });

  test('al llegar al tope se descarta el login más viejo, no el más nuevo', () {
    final pending = build(ttl: const Duration(hours: 1), maxEntries: 2)
      ..add('state-1', 'flujo-1')
      ..add('state-2', 'flujo-2')
      ..add('state-3', 'flujo-3');

    expect(pending.remove('state-1'), isNull);
    expect(pending.remove('state-2'), 'flujo-2');
    expect(pending.remove('state-3'), 'flujo-3');
  });
}
