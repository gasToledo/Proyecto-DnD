import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_app/data/backup_bundle.dart';
import 'package:dnd_app/data/transfer_service.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('dnd-bundle-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('respaldo completo conserva personajes, retratos y contenido', () async {
    final portrait = File(p.join(sandbox.path, 'retrato.png'));
    await portrait.writeAsBytes([0x89, 0x50, 0x4e, 0x47]);
    final character = demoSagan().copyWith(portraitPaths: [portrait.path]);

    final bytes = await BackupBundleCodec.encode(
      scope: BackupScope.full,
      characters: [character],
      homebrew: {
        'weapons': [
          {'id': 'hb-espada', 'name': 'Espada casera'},
        ],
      },
      preferences: {
        'imageProvider': 'huggingface',
        'huggingFaceModel': 'modelo/prueba',
        'geminiApiKey': 'no-exportar',
        'huggingFaceToken': 'no-exportar',
      },
    );
    final decoded = BackupBundleCodec.decode(bytes);

    expect(decoded.scope, BackupScope.full);
    expect(decoded.characters.single.character.id, character.id);
    expect(decoded.characters.single.character.portraitPaths, isEmpty);
    expect(
      decoded.characters.single.portraits.single.bytes,
      await portrait.readAsBytes(),
    );
    expect(decoded.homebrew!['weapons']!.single['id'], 'hb-espada');
    expect(decoded.preferences!['imageProvider'], 'huggingface');
    expect(decoded.preferences, isNot(contains('geminiApiKey')));
    expect(decoded.preferences, isNot(contains('huggingFaceToken')));
  });

  test('exportación individual genera ZIP importable', () async {
    final transfer = TransferService(dataRoot: sandbox.path);
    final path = await transfer.exportCharacter(demoSagan());

    expect(p.extension(path), '.zip');
    final bundle = await transfer.readBundleOrLegacy(path);
    expect(bundle.scope, BackupScope.character);
    expect(bundle.characters.single.character.id, 'sagan');
  });

  test('sigue leyendo exportaciones JSON antiguas', () async {
    final file = File(p.join(sandbox.path, 'anterior.json'));
    await file.writeAsString(
      jsonEncode({
        'type': 'dnd_character',
        'formatVersion': 1,
        'character': demoSagan().toJson(),
      }),
    );

    final bundle = await TransferService(
      dataRoot: sandbox.path,
    ).readBundleOrLegacy(file.path);
    expect(bundle.scope, BackupScope.legacy);
    expect(bundle.characters.single.character.id, 'sagan');
  });

  test('rechaza rutas internas que intentan salir del respaldo', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'type': BackupBundleCodec.type,
            'formatVersion': BackupBundleCodec.formatVersion,
            'scope': 'full',
            'characters': <Object>[],
          }),
        ),
      )
      ..add(ArchiveFile.string('../fuera.txt', 'peligro'));
    final bytes = ZipEncoder().encodeBytes(archive);

    expect(() => BackupBundleCodec.decode(bytes), throwsFormatException);
  });

  test('rechaza versiones futuras del formato', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'type': BackupBundleCodec.type,
            'formatVersion': 999,
            'scope': 'full',
            'characters': <Object>[],
          }),
        ),
      );

    expect(
      () => BackupBundleCodec.decode(ZipEncoder().encodeBytes(archive)),
      throwsFormatException,
    );
  });

  test('materializa retratos y cambia ids que ya existen', () async {
    final original = demoSagan();
    final bundle = BackupBundle(
      formatVersion: BackupBundleCodec.formatVersion,
      scope: BackupScope.character,
      characters: [
        BundleCharacter(
          character: original,
          portraits: [
            BundlePortrait(
              fileName: 'retrato.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      ],
    );
    final prepared = await TransferService(
      dataRoot: sandbox.path,
    ).prepareCharacterImport(bundle, {'sagan'});

    expect(prepared.characters.single.id, isNot('sagan'));
    final restoredPath = prepared.characters.single.portraitPaths.single;
    expect(await File(restoredPath).readAsBytes(), [1, 2, 3]);

    await prepared.rollbackPortraits();
    expect(File(restoredPath).existsSync(), isFalse);
  });
}
