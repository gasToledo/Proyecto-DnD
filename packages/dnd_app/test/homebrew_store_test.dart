import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
