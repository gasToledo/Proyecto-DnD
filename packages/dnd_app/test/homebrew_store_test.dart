import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  test(
    'countCollisions cuenta solo los ids que ya existen en el store',
    () async {
      final repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024',
      );
      final w = repo.weapons.values.first;

      // countCollisions es lógica pura sobre los mapas en memoria: no hace
      // ninguna llamada de red, así que un ApiClient sin servidor detrás
      // alcanza para esta prueba.
      final store = HomebrewStore(ApiClient());
      store.weapons[w.id] = w; // homebrew existente con este id

      final Map<String, List<Map<String, dynamic>>> content = {
        'weapons': [
          {'id': w.id}, // colisiona
          {'id': 'arma-nueva'}, // no colisiona
        ],
        'feats': [
          {'id': 'dote-nueva'}, // no colisiona
        ],
      };

      expect(store.countCollisions(content), 1);
      // Un store vacío no reporta ninguna colisión.
      expect(HomebrewStore(ApiClient()).countCollisions(content), 0);
    },
  );

  test('importContent no permite sobrescribir un id oficial', () async {
    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    final server = FakeApiServer();
    final store = HomebrewStore(ApiClient(client: server.client));
    final official = repo.weapons.values.first;

    await expectLater(
      store.importContent({
        'weapons': [official.toJson()..['source'] = 'homebrew'],
      }, repository: repo),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('catálogo oficial'),
        ),
      ),
    );
    expect(server.homebrew, isEmpty);
  });

  test('importContent rechaza un id repetido entre catálogos', () async {
    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    final server = FakeApiServer();
    final store = HomebrewStore(ApiClient(client: server.client));
    final weapon = repo.weapons.values.first.toJson()..['id'] = 'compartido';
    final armor = repo.armor.values.first.toJson()..['id'] = 'compartido';

    await expectLater(
      store.importContent({
        'weapons': [weapon],
        'armor': [armor],
      }, repository: repo),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('weapons y armor'),
        ),
      ),
    );
    expect(server.homebrew, isEmpty);
  });
}
