import 'package:dnd_engine/dnd_engine.dart';
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

      final store = HomebrewStore();
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
      expect(HomebrewStore().countCollisions(content), 0);
    },
  );
}
