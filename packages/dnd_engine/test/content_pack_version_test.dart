import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('el paquete oficial declara una versión compatible', () async {
    final decoded = jsonDecode(
      await File('lib/assets/srd_2024/manifest.json').readAsString(),
    );
    final manifest = ContentPackManifest.fromJson(
      (decoded as Map).cast<String, dynamic>(),
    );

    expect(manifest.id, 'srd_2024');
    expect(manifest.formatVersion, ContentPackManifest.currentFormatVersion);
  });

  test('rechaza un paquete de contenido de versión futura', () async {
    final sandbox = await Directory.systemTemp.createTemp('dnd-pack-future-');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });
    await File(p.join(sandbox.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'type': ContentPackManifest.type,
        'formatVersion': ContentPackManifest.currentFormatVersion + 1,
        'id': 'futuro',
        'ruleset': 'SRD futuro',
      }),
    );

    await expectLater(
      ContentRepository.loadFromDirectory(sandbox.path),
      throwsA(isA<UnsupportedDataVersionException>()),
    );
  });

  test('rechaza un directorio que no declara manifiesto', () async {
    final sandbox = await Directory.systemTemp.createTemp('dnd-pack-missing-');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    await expectLater(
      ContentRepository.loadFromDirectory(sandbox.path),
      throwsA(isA<FormatException>()),
    );
  });
}
