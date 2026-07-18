import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén en memoria para probar el controlador sin tocar el sistema de
/// archivos (evita path_provider en tests).
class _FakeStore implements CharacterStore {
  final Map<String, Character> saved = {};
  int saveCount = 0;

  @override
  Future<List<Character>> loadAll() async => saved.values.toList();

  @override
  Future<void> save(Character c) async {
    saved[c.id] = c;
    saveCount++;
  }

  @override
  Future<void> delete(String id) async => saved.remove(id);

  @override
  Future<String> directoryPath() async => '/fake';
}

void main() {
  test('add persiste el personaje tras el debounce', () async {
    final store = _FakeStore();
    final ctrl = CharactersController(store);

    ctrl.add(demoSagan());
    expect(store.saveCount, 0, reason: 'no guarda inmediatamente');

    await Future.delayed(const Duration(milliseconds: 600));
    expect(store.saveCount, 1);
    expect(store.saved.containsKey('sagan'), isTrue);
  });

  test('ediciones rápidas se agrupan en un solo guardado (debounce)', () async {
    final store = _FakeStore();
    final ctrl = CharactersController(store)..add(demoSagan());
    await Future.delayed(const Duration(milliseconds: 600)); // guarda inicial

    final c = ctrl.characters.first;
    for (var i = 0; i < 5; i++) {
      c.combat.currentHp = 10 - i;
      ctrl.touch(c);
    }
    final before = store.saveCount;
    await Future.delayed(const Duration(milliseconds: 600));
    expect(store.saveCount, before + 1,
        reason: '5 cambios rápidos = 1 guardado');
    expect(store.saved['sagan']!.combat.currentHp, 6);
  });

  test('flush guarda todo lo pendiente de inmediato', () async {
    final store = _FakeStore();
    final ctrl = CharactersController(store);
    ctrl.add(demoSagan());
    await ctrl.flush();
    expect(store.saved.containsKey('sagan'), isTrue);
  });

  test('load repuebla la lista desde el almacén', () async {
    final store = _FakeStore()..saved['sagan'] = demoSagan();
    final ctrl = CharactersController(store);
    await ctrl.load();
    expect(ctrl.characters, hasLength(1));
    expect(ctrl.characters.first.id, 'sagan');
  });
}
