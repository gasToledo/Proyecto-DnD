import 'dart:convert';
import 'dart:io';

import 'package:dnd_app/data/app_paths.dart';
import 'package:dnd_app/data/atomic_json_file.dart';
import 'package:dnd_app/data/character_store.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/data/transfer_service.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('dnd-persistence-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('todos los stores usan la misma raíz canónica inyectada', () async {
    final characterStore = CharacterStore(dataRoot: sandbox.path);
    await characterStore.save(demoSagan());

    final settings = SettingsService(dataRoot: sandbox.path);
    await settings.save(AppSettings(imageProvider: 'pollinations'));

    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    final homebrew = HomebrewStore(dataRoot: sandbox.path);
    await homebrew.saveWeapon(repo.weapons.values.first);

    final transfer = TransferService(dataRoot: sandbox.path);
    await transfer.exportCharacter(demoSagan());

    final root = Directory(fichasDir(null, sandbox.path));
    expect(
      await File(p.join(root.path, 'characters', 'sagan.json')).exists(),
      isTrue,
    );
    expect(await File(p.join(root.path, 'settings.json')).exists(), isTrue);
    expect(
      await File(p.join(root.path, 'homebrew', 'weapons.json')).exists(),
      isTrue,
    );
    expect(await Directory(p.join(root.path, 'exports')).exists(), isTrue);
  });

  test('restaurar preferencias no reemplaza credenciales locales', () async {
    final service = SettingsService(dataRoot: sandbox.path);
    await service.save(
      AppSettings(
        imageProvider: 'gemini',
        geminiApiKey: 'clave-local',
        huggingFaceToken: 'token-local',
        huggingFaceModel: 'modelo/anterior',
      ),
    );

    await service.restorePortable({
      'imageProvider': 'huggingface',
      'huggingFaceModel': 'modelo/restaurado',
      'geminiApiKey': 'clave-del-respaldo',
      'huggingFaceToken': 'token-del-respaldo',
    });
    final restored = await service.load();

    expect(restored.imageProvider, 'huggingface');
    expect(restored.huggingFaceModel, 'modelo/restaurado');
    expect(restored.geminiApiKey, 'clave-local');
    expect(restored.huggingFaceToken, 'token-local');
  });

  test('la escritura atómica reemplaza JSON y no deja temporales', () async {
    final file = File(p.join(sandbox.path, 'value.json'));
    await writeJsonAtomic(file, {'value': 1});
    await writeJsonAtomic(file, {'value': 2});

    expect(jsonDecode(await file.readAsString()), {'value': 2});
    final leftovers = await sandbox
        .list()
        .where((e) => p.extension(e.path) == '.tmp')
        .toList();
    expect(leftovers, isEmpty);
  });

  test('un lote inválido no modifica los destinos ya existentes', () async {
    final first = File(p.join(sandbox.path, 'first.json'));
    await first.writeAsString('{"original":true}');
    final blocker = File(p.join(sandbox.path, 'no-es-directorio'));
    await blocker.writeAsString('bloqueo');
    final invalid = File(p.join(blocker.path, 'second.json'));

    await expectLater(
      writeJsonBatchAtomic({
        first: {'original': false},
        invalid: {'value': 2},
      }),
      throwsA(isA<FileSystemException>()),
    );

    expect(jsonDecode(await first.readAsString()), {'original': true});
  });

  test('un personaje corrupto se aparta y se informa', () async {
    final characterDir = Directory(
      p.join(fichasDir(null, sandbox.path), 'characters'),
    );
    await characterDir.create(recursive: true);
    final corrupt = File(p.join(characterDir.path, 'roto.json'));
    await corrupt.writeAsString('{no es json');

    final store = CharacterStore(dataRoot: sandbox.path);
    expect(await store.loadAll(), isEmpty);
    expect(store.recoveryIssues, hasLength(1));
    expect(await corrupt.exists(), isFalse);
    expect(
      await File(store.recoveryIssues.single.recoveryPath).exists(),
      isTrue,
    );
  });

  test(
    'ajustes y homebrew corruptos también se conservan para recuperación',
    () async {
      final root = Directory(fichasDir(null, sandbox.path));
      await root.create(recursive: true);
      await File(p.join(root.path, 'settings.json')).writeAsString('{roto');
      final homebrewDir = Directory(p.join(root.path, 'homebrew'));
      await homebrewDir.create(recursive: true);
      await File(
        p.join(homebrewDir.path, 'weapons.json'),
      ).writeAsString('[roto');

      final settings = SettingsService(dataRoot: sandbox.path);
      expect((await settings.load()).imageProvider, 'pollinations');
      expect(settings.recoveryIssues, hasLength(1));

      final homebrew = HomebrewStore(dataRoot: sandbox.path);
      await homebrew.load();
      expect(homebrew.weapons, isEmpty);
      expect(homebrew.recoveryIssues, hasLength(1));
      expect(
        await File(homebrew.recoveryIssues.single.recoveryPath).exists(),
        isTrue,
      );
    },
  );

  test(
    'migra personajes de la ubicación anterior sin borrar el original',
    () async {
      final legacy = Directory(p.join(sandbox.path, 'legacy-characters'));
      await legacy.create(recursive: true);
      final source = File(p.join(legacy.path, 'sagan.json'));
      await source.writeAsString(jsonEncode(demoSagan().toJson()));

      final canonicalRoot = p.join(sandbox.path, 'canonical');
      final store = CharacterStore(
        dataRoot: canonicalRoot,
        legacyDirectory: legacy.path,
      );
      final loaded = await store.loadAll();

      expect(loaded.single.id, 'sagan');
      expect(await source.exists(), isTrue);
      expect(
        await File(
          p.join(fichasDir('characters', canonicalRoot), 'sagan.json'),
        ).exists(),
        isTrue,
      );
    },
  );
}
