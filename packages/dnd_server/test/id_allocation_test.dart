import 'package:dnd_server/src/repositories/id_allocation.dart';
import 'package:test/test.dart';

void main() {
  test('un id libre se conserva tal cual', () {
    final id = resolveStorageId(
      requestedId: 'sagan',
      existingIds: const {},
      fallbackId: () => throw StateError('no debería llamarse'),
    );

    expect(id, 'sagan');
  });

  test('un id ya usado recibe uno libre generado por fallbackId', () {
    final id = resolveStorageId(
      requestedId: 'sagan',
      existingIds: const {'sagan'},
      fallbackId: () => 'sagan-2',
    );

    expect(id, 'sagan-2');
  });

  test('reintenta hasta encontrar uno realmente libre', () {
    var calls = 0;
    final generated = ['sagan', 'sagan-2', 'sagan-3'];
    final id = resolveStorageId(
      requestedId: 'sagan',
      existingIds: const {'sagan', 'sagan-2'},
      fallbackId: () => generated[calls++],
    );

    expect(id, 'sagan-3');
    expect(calls, 3);
  });
}
