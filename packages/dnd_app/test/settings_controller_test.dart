import 'dart:async';
import 'dart:convert';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  test('serializa y agrupa snapshots sin perder cambios recientes', () async {
    final server = FakeApiServer();
    final api = ApiClient(client: server.client);
    final controller = SettingsController(
      api,
      AppSettings(favoriteCharacterId: 'original'),
    );
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final sent = <Map<String, dynamic>>[];
    var calls = 0;

    server.beforeHandle = (request) async {
      if (request.method != 'PUT' || request.url.path != '/api/settings') {
        return;
      }
      sent.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
      calls++;
      if (calls == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
    };

    final first = controller.update((settings) {
      settings.themeMode = 'light';
    });
    await firstStarted.future;
    final second = controller.update((settings) {
      settings.characterOrder = ['sagan'];
    });
    final third = controller.update((settings) {
      settings.favoriteCharacterId = 'sagan';
    });
    releaseFirst.complete();

    await Future.wait([first, second, third]);

    expect(sent, hasLength(2));
    expect(sent.first['themeMode'], 'light');
    expect(sent.first['favoriteCharacterId'], 'original');
    expect(sent.last['themeMode'], 'light');
    expect(sent.last['characterOrder'], ['sagan']);
    expect(sent.last['favoriteCharacterId'], 'sagan');
    expect(server.settings, sent.last);
  });
}
