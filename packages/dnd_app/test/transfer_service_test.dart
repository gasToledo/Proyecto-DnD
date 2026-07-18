import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/transfer_service.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements CharacterStore {
  final Map<String, Character> saved = {};
  @override
  Future<List<Character>> loadAll() async => saved.values.toList();
  @override
  Future<void> save(Character c) async => saved[c.id] = c;
  @override
  Future<void> delete(String id) async => saved.remove(id);
  @override
  Future<String> directoryPath() async => '/fake';
}

void main() {
  group('parseImport', () {
    test('lee un envoltorio de personaje único', () {
      final c = demoSagan();
      final text = jsonEncode({
        'type': 'dnd_character',
        'formatVersion': 1,
        'character': c.toJson(),
      });
      final parsed = TransferService.parseImport(text);
      expect(parsed, hasLength(1));
      expect(parsed.first.id, 'sagan');
      expect(parsed.first.classId, 'fighter');
    });

    test('lee un respaldo completo con varios personajes', () {
      final c = demoSagan();
      final text = jsonEncode({
        'type': 'dnd_backup',
        'formatVersion': 1,
        'characters': [c.toJson(), c.toJson()],
      });
      expect(TransferService.parseImport(text), hasLength(2));
    });

    test('acepta un personaje crudo (archivo del propio almacén)', () {
      final text = jsonEncode(demoSagan().toJson());
      expect(TransferService.parseImport(text).first.classId, 'fighter');
    });

    test('rechaza un formato desconocido', () {
      expect(() => TransferService.parseImport('{"type":"otra_cosa"}'),
          throwsFormatException);
    });
  });

  test('importar un id existente no sobrescribe (asigna id nuevo)', () async {
    final store = _FakeStore();
    final ctrl = CharactersController(store)..add(demoSagan());

    final count = await ctrl.importCharacters([demoSagan()]);
    expect(count, 1);
    expect(ctrl.characters, hasLength(2));
    // Solo queda un 'sagan' original; el importado recibió id nuevo.
    expect(ctrl.characters.where((c) => c.id == 'sagan'), hasLength(1));
  });
}
