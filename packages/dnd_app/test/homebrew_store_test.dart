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

  test('load omite entradas inválidas y permite borrarlas', () async {
    final server = FakeApiServer();
    server.homebrew['weapons'] = {
      'broken': {'id': 'broken', 'name': 'Sin reglas', 'source': 'homebrew'},
    };
    final store = HomebrewStore(ApiClient(client: server.client));

    await store.load();

    expect(store.weapons, isEmpty);
    expect(store.loadIssues, hasLength(1));
    expect(store.loadIssues.single.id, 'broken');
    await store.deleteInvalid(store.loadIssues.single);
    expect(store.loadIssues, isEmpty);
    expect(server.homebrew['weapons'], isEmpty);
  });

  // El diálogo de borrado se apoya en esto para decir «lo usan Grommash y Lyra»
  // en vez de amenazar en abstracto, así que lo que importa es que encuentre la
  // referencia esté donde esté en el documento.
  group('charactersUsing', () {
    Character character({
      String id = 'grommash',
      List<String> equippedWeaponIds = const [],
      List<String> spellIds = const [],
      String raceId = 'human',
      List<InventoryEntry> inventory = const [],
    }) => Character(
      id: id,
      name: id,
      raceId: raceId,
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final ability in Ability.values) ability: 10},
      hpPerLevel: const [10],
      equippedWeaponIds: equippedWeaponIds,
      spellIds: spellIds,
      inventory: inventory,
    );

    test('encuentra la referencia en cualquier parte de la ficha', () {
      final equipada = character(id: 'equipada', equippedWeaponIds: ['hb-hoz']);
      final guardada = character(
        id: 'guardada',
        inventory: const [InventoryEntry(entryId: 'e1', itemId: 'hb-hoz')],
      );
      final conjuro = character(id: 'conjuro', spellIds: ['hb-marea']);
      final especie = character(id: 'especie', raceId: 'hb-triton');

      expect(
        charactersUsing('hb-hoz', [equipada, guardada, conjuro, especie]),
        [equipada, guardada],
      );
      expect(charactersUsing('hb-marea', [conjuro, especie]), [conjuro]);
      expect(charactersUsing('hb-triton', [conjuro, especie]), [especie]);
    });

    test('no confunde un id con otro que lo contiene', () {
      final ficha = character(equippedWeaponIds: ['hb-hoz-de-guerra']);

      // Compara la cadena entera: si comparara por prefijo, borrar «hb-hoz»
      // avisaría de fichas que no lo usan.
      expect(charactersUsing('hb-hoz', [ficha]), isEmpty);
      expect(charactersUsing('hb-hoz-de-guerra', [ficha]), [ficha]);
    });

    test('sin fichas no hay uso', () {
      expect(charactersUsing('hb-hoz', const []), isEmpty);
    });
  });
}
