import 'package:dnd_app/data/asset_content_loader.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lo que carga el navegador y lo que cargan las pruebas salen de caminos
  // distintos. Los archivos se piden en paralelo y se reparten por nombre, así
  // que un pack asignado al campo equivocado recién se vería en producción.
  test('el contenido empaquetado es el mismo que el del directorio', () async {
    final bundled = await loadOfficialContent();
    final disk = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );

    Map<String, Set<String>> ids(ContentRepository r) => {
      'races': r.races.keys.toSet(),
      'classes': r.classes.keys.toSet(),
      'subclasses': r.subclasses.keys.toSet(),
      'lineages': r.lineages.keys.toSet(),
      'backgrounds': r.backgrounds.keys.toSet(),
      'feats': r.feats.keys.toSet(),
      'weapons': r.weapons.keys.toSet(),
      'armor': r.armor.keys.toSet(),
      'items': r.items.keys.toSet(),
      'spells': r.spells.keys.toSet(),
      'creatures': r.creatures.keys.toSet(),
    };
    expect(ids(bundled), ids(disk));
  });
}
