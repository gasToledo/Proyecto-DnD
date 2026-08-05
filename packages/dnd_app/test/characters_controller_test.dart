import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_exception.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  test('add persiste el personaje tras el debounce', () async {
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client));

    ctrl.add(demoSagan());
    expect(server.characters, isEmpty, reason: 'no guarda inmediatamente');
    expect(ctrl.saveState, CharacterSaveState.saving);

    await Future.delayed(const Duration(milliseconds: 600));
    expect(server.characters.containsKey('sagan'), isTrue);
    expect(ctrl.saveState, CharacterSaveState.saved);
  });

  test('ediciones rápidas se agrupan en un solo guardado (debounce)', () async {
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client))
      ..add(demoSagan());
    await Future.delayed(const Duration(milliseconds: 600)); // guarda inicial

    final c = ctrl.characters.first;
    for (var i = 0; i < 5; i++) {
      c.combat.currentHp = 10 - i;
      ctrl.touch(c);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    expect(server.characters['sagan']!.combat.currentHp, 6);
  });

  test('flush guarda todo lo pendiente de inmediato', () async {
    final server = FakeApiServer();
    final ctrl = CharactersController(ApiClient(client: server.client));
    ctrl.add(demoSagan());
    await ctrl.flush();
    expect(server.characters.containsKey('sagan'), isTrue);
  });

  test('load repuebla la lista desde el servidor', () async {
    final server = FakeApiServer()..characters['sagan'] = demoSagan();
    final ctrl = CharactersController(ApiClient(client: server.client));
    await ctrl.load();
    expect(ctrl.characters, hasLength(1));
    expect(ctrl.characters.first.id, 'sagan');
  });

  test(
    'una carga sin conexión se distingue de una cuenta sin personajes',
    () async {
      final server = FakeApiServer()..failWith = const ApiException(null, 'x');
      final ctrl = CharactersController(ApiClient(client: server.client));
      await ctrl.load();
      expect(ctrl.characters, isEmpty);
      expect(ctrl.loadFailedOffline, isTrue);
    },
  );

  test(
    'un error de guardado queda expuesto sin excepción no controlada',
    () async {
      final server = FakeApiServer();
      final ctrl = CharactersController(ApiClient(client: server.client))
        ..add(demoSagan());
      await Future.delayed(const Duration(milliseconds: 600));
      server.failWith = const ApiException(500, 'sin espacio');
      ctrl.touch(ctrl.characters.first);
      await Future.delayed(const Duration(milliseconds: 600));
      expect(ctrl.lastSaveError, isA<ApiException>());
      expect(ctrl.isSaving, isFalse);
      expect(ctrl.saveState, CharacterSaveState.error);
    },
  );

  test(
    'una sesión expirada (401) queda expuesta como error de autenticación',
    () async {
      final server = FakeApiServer();
      final ctrl = CharactersController(ApiClient(client: server.client))
        ..add(demoSagan());
      await Future.delayed(const Duration(milliseconds: 600));
      server.authenticated = false;
      ctrl.touch(ctrl.characters.first);
      await Future.delayed(const Duration(milliseconds: 600));
      expect(ctrl.lastSaveError?.isAuthError, isTrue);
    },
  );

  test(
    'si borrar en el servidor falla conserva el personaje en memoria',
    () async {
      final server = FakeApiServer()..failWith = const ApiException(500, 'x');
      final ctrl = CharactersController(ApiClient(client: server.client))
        ..characters.add(demoSagan());
      await expectLater(
        ctrl.remove(ctrl.characters.first),
        throwsA(isA<ApiException>()),
      );
      expect(ctrl.characters, hasLength(1));
    },
  );
}
