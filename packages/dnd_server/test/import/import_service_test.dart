import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/import/backup_bundle.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:test/test.dart';

import '../fakes/in_memory_portrait_blob_store.dart';

Character _character(String id) => Character(
  id: id,
  name: id,
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  assignedScores: const {},
);

const _pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2];

void main() {
  group('prepareImport', () {
    test('conserva el id cuando no hay colisión', () async {
      final portraits = InMemoryPortraitBlobStore();
      final bundle = BackupBundle(
        formatVersion: 2,
        scope: BackupScope.character,
        characters: [BundleCharacter(character: _character('sagan'))],
      );

      final prepared = await prepareImport(
        portraits: portraits,
        userId: 'user-a',
        bundle: bundle,
        existingIds: const {},
      );

      expect(prepared.characters.single.id, 'sagan');
      expect(prepared.portraitsImported, 0);
    });

    test(
      'reasigna un id libre si ya existe en la cuenta, sin sobrescribir',
      () async {
        final portraits = InMemoryPortraitBlobStore();
        final bundle = BackupBundle(
          formatVersion: 2,
          scope: BackupScope.character,
          characters: [BundleCharacter(character: _character('sagan'))],
        );

        final prepared = await prepareImport(
          portraits: portraits,
          userId: 'user-a',
          bundle: bundle,
          existingIds: {'sagan'},
        );

        expect(prepared.characters.single.id, isNot('sagan'));
      },
    );

    test(
      'guarda los retratos bajo el id efectivo (el reasignado, si lo hubo)',
      () async {
        final portraits = InMemoryPortraitBlobStore();
        final bundle = BackupBundle(
          formatVersion: 2,
          scope: BackupScope.character,
          characters: [
            BundleCharacter(
              character: _character('sagan'),
              portraits: [
                BundlePortrait(
                  fileName: 'retrato.png',
                  bytes: Uint8List.fromList(_pngBytes),
                ),
              ],
            ),
          ],
        );

        final prepared = await prepareImport(
          portraits: portraits,
          userId: 'user-a',
          bundle: bundle,
          existingIds: {'sagan'},
        );

        final character = prepared.characters.single;
        expect(character.id, isNot('sagan'));
        expect(prepared.portraitsImported, 1);
        expect(character.portraitPaths, hasLength(1));
        expect(character.portraitPaths.single, startsWith('${character.id}/'));

        final blob = await portraits.read(
          userId: 'user-a',
          portraitKey: character.portraitPaths.single,
        );
        expect(blob, isNotNull);
      },
    );

    test('importar el mismo respaldo dos veces produce copias con ids '
        'distintos, sin tocar la primera', () async {
      final portraits = InMemoryPortraitBlobStore();
      BackupBundle bundle() => BackupBundle(
        formatVersion: 2,
        scope: BackupScope.character,
        characters: [BundleCharacter(character: _character('sagan'))],
      );

      final first = await prepareImport(
        portraits: portraits,
        userId: 'user-a',
        bundle: bundle(),
        existingIds: const {},
      );
      final afterFirst = {'sagan', first.characters.single.id};

      final second = await prepareImport(
        portraits: portraits,
        userId: 'user-a',
        bundle: bundle(),
        existingIds: afterFirst,
      );

      expect(second.characters.single.id, isNot(first.characters.single.id));
      expect(second.characters.single.id, isNot('sagan'));
    });
  });
}
