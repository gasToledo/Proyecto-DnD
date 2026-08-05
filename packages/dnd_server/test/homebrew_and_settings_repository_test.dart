import 'package:test/test.dart';

import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_settings_repository.dart';

void main() {
  group('HomebrewRepository', () {
    late InMemoryHomebrewRepository repo;
    setUp(() => repo = InMemoryHomebrewRepository());

    test(
      'el homebrew de una cuenta no aparece en el catálogo de otra',
      () async {
        await repo.upsert('user-a', 'weapons', 'hb-espada', {
          'id': 'hb-espada',
          'name': 'Espada casera',
        });
        await repo.upsert('user-b', 'weapons', 'hb-lanza', {
          'id': 'hb-lanza',
          'name': 'Lanza casera',
        });

        final aContent = await repo.listForUser('user-a');
        expect(aContent['weapons']!.single['id'], 'hb-espada');

        final bContent = await repo.listForUser('user-b');
        expect(bContent['weapons']!.single['id'], 'hb-lanza');
      },
    );

    test('se agrupa por categoría', () async {
      await repo.upsert('user-a', 'weapons', 'w1', {'id': 'w1'});
      await repo.upsert('user-a', 'feats', 'f1', {'id': 'f1'});

      final content = await repo.listForUser('user-a');

      expect(content.keys, containsAll(['weapons', 'feats']));
    });

    test('delete quita solo esa entrada', () async {
      await repo.upsert('user-a', 'weapons', 'w1', {'id': 'w1'});
      await repo.upsert('user-a', 'weapons', 'w2', {'id': 'w2'});

      await repo.delete('user-a', 'weapons', 'w1');

      final content = await repo.listForUser('user-a');
      expect(content['weapons']!.map((e) => e['id']), ['w2']);
    });
  });

  group('SettingsRepository', () {
    late InMemorySettingsRepository repo;
    setUp(() => repo = InMemorySettingsRepository());

    test('sin ajustes guardados devuelve null', () async {
      expect(await repo.find('user-a'), isNull);
    });

    test('dos cuentas reciben sus propios ajustes', () async {
      await repo.save('user-a', {'imageProvider': 'pollinations'});
      await repo.save('user-b', {'imageProvider': 'azure-gpt-image'});

      expect((await repo.find('user-a'))!['imageProvider'], 'pollinations');
      expect((await repo.find('user-b'))!['imageProvider'], 'azure-gpt-image');
    });

    test('guardar de nuevo reemplaza el documento anterior', () async {
      await repo.save('user-a', {'a': 1});
      await repo.save('user-a', {'a': 2});

      expect(await repo.find('user-a'), {'a': 2});
    });
  });
}
