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
        imageProvider: 'azure',
        azureApiKey: 'clave-local',
        azureOpenAiApiKey: 'clave-local-gpt',
      ),
    );

    await service.restorePortable({
      'imageProvider': 'azure-gpt-image',
      'azureApiKey': 'clave-del-respaldo',
      'azureOpenAiApiKey': 'clave-del-respaldo-gpt',
    });
    final restored = await service.load();

    expect(restored.imageProvider, 'azure-gpt-image');
    expect(restored.azureApiKey, 'clave-local');
    expect(restored.azureOpenAiApiKey, 'clave-local-gpt');
  });

  test('restaurar un proveedor retirado no rompe los ajustes', () async {
    final service = SettingsService(dataRoot: sandbox.path);
    await service.save(AppSettings(imageProvider: 'azure'));

    // Un respaldo hecho cuando Gemini todavía existía.
    await service.restorePortable({'imageProvider': 'gemini'});

    expect((await service.load()).imageProvider, 'azure');
  });

  test('migra ajustes v1 al documento actual y conserva una copia', () async {
    final root = Directory(fichasDir(null, sandbox.path));
    await root.create(recursive: true);
    final file = File(p.join(root.path, 'settings.json'));
    await file.writeAsString(
      await File('test/fixtures/settings_v1.json').readAsString(),
    );

    final service = SettingsService(dataRoot: sandbox.path);
    final settings = await service.load();

    // El fixture v1 usaba Gemini con su token: el proveedor ya no existe, así
    // que la migración lo devuelve al que no necesita key y borra del archivo
    // las credenciales que quedaron huérfanas.
    expect(settings.imageProvider, 'pollinations');
    final credentials =
        jsonDecode(await file.readAsString())['credentials'] as Map;
    expect(
      credentials.keys,
      unorderedEquals(['azureApiKey', 'azureOpenAiApiKey']),
    );
    expect(service.migrationBackups, hasLength(1));
    expect(
      jsonDecode(await file.readAsString())['schemaVersion'],
      AppSettings.currentSchemaVersion,
    );
    expect(
      jsonDecode(
        await File(service.migrationBackups.single.backupPath).readAsString(),
      ),
      isNot(contains('schemaVersion')),
    );
  });

  test('migra Homebrew v1 al documento v2 y conserva una copia', () async {
    final homebrewDir = Directory(
      p.join(fichasDir(null, sandbox.path), 'homebrew'),
    );
    await homebrewDir.create(recursive: true);
    final file = File(p.join(homebrewDir.path, 'weapons.json'));
    await file.writeAsString(
      await File('test/fixtures/homebrew_weapons_v1.json').readAsString(),
    );

    final store = HomebrewStore(dataRoot: sandbox.path);
    await store.load();

    expect(store.weapons, contains('espada-fixture'));
    expect(store.migrationBackups, hasLength(1));
    final migrated = jsonDecode(await file.readAsString());
    expect(migrated['schemaVersion'], HomebrewStore.currentSchemaVersion);
    expect(migrated['items'], hasLength(1));
    expect(
      jsonDecode(
        await File(store.migrationBackups.single.backupPath).readAsString(),
      ),
      isA<List>(),
    );
  });

  test('versiones futuras de ajustes y Homebrew quedan intactas', () async {
    final root = Directory(fichasDir(null, sandbox.path));
    final homebrewDir = Directory(p.join(root.path, 'homebrew'));
    await homebrewDir.create(recursive: true);
    final settingsFile = File(p.join(root.path, 'settings.json'));
    final homebrewFile = File(p.join(homebrewDir.path, 'weapons.json'));
    final futureSettings = jsonEncode({
      'schemaVersion': AppSettings.currentSchemaVersion + 1,
      'preferences': const {},
      'credentials': const {},
    });
    final futureHomebrew = jsonEncode({
      'schemaVersion': HomebrewStore.currentSchemaVersion + 1,
      'items': const [],
    });
    await settingsFile.writeAsString(futureSettings);
    await homebrewFile.writeAsString(futureHomebrew);

    final settings = SettingsService(dataRoot: sandbox.path);
    expect((await settings.load()).imageProvider, 'pollinations');
    expect(settings.recoveryIssues, hasLength(1));
    await expectLater(settings.save(AppSettings()), throwsA(isA<StateError>()));
    expect(await settingsFile.readAsString(), futureSettings);

    final homebrew = HomebrewStore(dataRoot: sandbox.path);
    await homebrew.load();
    expect(homebrew.weapons, isEmpty);
    expect(homebrew.recoveryIssues, hasLength(1));
    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    await expectLater(
      homebrew.saveWeapon(repo.weapons.values.first),
      throwsA(isA<StateError>()),
    );
    expect(await homebrewFile.readAsString(), futureHomebrew);
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
    'migra una ficha v1, conserva copia y persiste el esquema actual',
    () async {
      final characterDir = Directory(
        p.join(fichasDir(null, sandbox.path), 'characters'),
      );
      await characterDir.create(recursive: true);
      final legacy = demoSagan().toJson()..['schemaVersion'] = 1;
      legacy.remove('status');
      legacy.remove('tableConfig');
      final file = File(p.join(characterDir.path, 'sagan.json'));
      await file.writeAsString(jsonEncode(legacy));

      final store = CharacterStore(dataRoot: sandbox.path);
      final loaded = await store.loadAll();

      expect(loaded.single.id, 'sagan');
      expect(store.migrationBackups, hasLength(1));
      final backup = store.migrationBackups.single;
      expect(await File(backup.backupPath).exists(), isTrue);
      expect(
        jsonDecode(
          await File(backup.backupPath).readAsString(),
        )['schemaVersion'],
        1,
      );
      expect(
        jsonDecode(await file.readAsString())['schemaVersion'],
        Character.currentSchemaVersion,
      );
    },
  );

  test(
    'una ficha de versión futura se informa sin mover ni reescribir',
    () async {
      final characterDir = Directory(
        p.join(fichasDir(null, sandbox.path), 'characters'),
      );
      await characterDir.create(recursive: true);
      final future = demoSagan().toJson()
        ..['schemaVersion'] = Character.currentSchemaVersion + 1;
      final file = File(p.join(characterDir.path, 'sagan.json'));
      final original = jsonEncode(future);
      await file.writeAsString(original);

      final store = CharacterStore(dataRoot: sandbox.path);

      expect(await store.loadAll(), isEmpty);
      expect(store.recoveryIssues, hasLength(1));
      expect(store.recoveryIssues.single.recoveryPath, file.path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), original);
      expect(store.migrationBackups, isEmpty);
      await expectLater(store.save(demoSagan()), throwsA(isA<StateError>()));
      expect(await file.readAsString(), original);
    },
  );

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
    'Homebrew v1 inválido se aparta antes de persistir la migración',
    () async {
      final homebrewDir = Directory(
        p.join(fichasDir(null, sandbox.path), 'homebrew'),
      );
      await homebrewDir.create(recursive: true);
      final file = File(p.join(homebrewDir.path, 'weapons.json'));
      await file.writeAsString('[{"id":"incompleta"}]');

      final store = HomebrewStore(dataRoot: sandbox.path);
      await store.load();

      expect(store.weapons, isEmpty);
      expect(store.migrationBackups, isEmpty);
      expect(store.recoveryIssues, hasLength(1));
      expect(store.recoveryIssues.single.wasMoved, isTrue);
      expect(await file.exists(), isFalse);
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
