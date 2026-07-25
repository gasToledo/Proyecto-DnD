import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/characters_controller.dart';
import 'package:dnd_app/data/data_recovery.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén en memoria para probar el controlador sin tocar el sistema de
/// archivos (evita path_provider en tests).
class _FakeStore implements CharacterStore {
  final Map<String, Character> saved = {};
  int saveCount = 0;

  @override
  final List<DataRecoveryIssue> recoveryIssues = [];
  @override
  final List<DataMigrationBackup> migrationBackups = [];

  @override
  Future<List<Character>> loadAll() async => saved.values.toList();

  @override
  Future<void> save(Character c) async {
    saved[c.id] = c;
    saveCount++;
  }

  @override
  Future<void> saveAll(Iterable<Character> characters) async {
    for (final character in characters) {
      await save(character);
    }
  }

  @override
  Future<void> delete(String id) async => saved.remove(id);

  @override
  Future<String> directoryPath() async => '/fake';
}

class _FailingStore extends _FakeStore {
  @override
  Future<void> save(Character c) async {
    throw const FileSystemException('sin espacio');
  }

  @override
  Future<void> saveAll(Iterable<Character> characters) async {
    throw const FileSystemException('sin espacio');
  }

  @override
  Future<void> delete(String id) async {
    throw const FileSystemException('sin permisos');
  }
}

void main() {
  test('add persiste el personaje tras el debounce', () async {
    final store = _FakeStore();
    final ctrl = CharactersController(store);

    ctrl.add(demoSagan());
    expect(store.saveCount, 0, reason: 'no guarda inmediatamente');
    expect(ctrl.saveState, CharacterSaveState.saving);

    await Future.delayed(const Duration(milliseconds: 600));
    expect(store.saveCount, 1);
    expect(store.saved.containsKey('sagan'), isTrue);
    expect(ctrl.saveState, CharacterSaveState.saved);
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
    expect(
      store.saveCount,
      before + 1,
      reason: '5 cambios rápidos = 1 guardado',
    );
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

  test('una importación fallida no altera la memoria', () async {
    final ctrl = CharactersController(_FailingStore())
      ..characters.add(demoSagan());
    final incoming = Character.fromJson(
      demoSagan().toJson()..['id'] = 'otro-personaje',
    );

    await expectLater(
      ctrl.importCharacters([incoming]),
      throwsA(isA<FileSystemException>()),
    );
    expect(ctrl.characters.map((c) => c.id), ['sagan']);
  });

  test(
    'un error de guardado queda expuesto sin excepción no controlada',
    () async {
      final ctrl = CharactersController(_FailingStore())..add(demoSagan());
      await Future.delayed(const Duration(milliseconds: 600));
      expect(ctrl.lastSaveError, isA<FileSystemException>());
      expect(ctrl.isSaving, isFalse);
      expect(ctrl.saveState, CharacterSaveState.error);
    },
  );

  test('si borrar del disco falla conserva el personaje en memoria', () async {
    final ctrl = CharactersController(_FailingStore())
      ..characters.add(demoSagan());
    await expectLater(
      ctrl.remove(ctrl.characters.first),
      throwsA(isA<FileSystemException>()),
    );
    expect(ctrl.characters, hasLength(1));
  });
}
