import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/import/backup_bundle.dart';
import 'package:test/test.dart';

Map<String, dynamic> _characterJson(String id) => {
  'id': id,
  'name': id,
  'raceId': 'human',
  'classId': 'fighter',
  'backgroundId': 'soldier',
  'assignedScores': <String, dynamic>{},
};

Uint8List _buildZip({
  required Map<String, dynamic> manifest,
  required Map<String, Map<String, dynamic>> characterFiles,
  Map<String, List<int>> extraBinaryEntries = const {},
  List<String> extraRawEntries = const [],
}) {
  final archive = Archive();
  archive.add(
    ArchiveFile.string('manifest.json', const JsonEncoder().convert(manifest)),
  );
  for (final entry in characterFiles.entries) {
    archive.add(
      ArchiveFile.string(entry.key, const JsonEncoder().convert(entry.value)),
    );
  }
  for (final entry in extraBinaryEntries.entries) {
    archive.add(ArchiveFile.bytes(entry.key, entry.value));
  }
  for (final path in extraRawEntries) {
    archive.add(ArchiveFile.string(path, 'x'));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  group('BackupBundleCodec.decode', () {
    test('decodifica un bundle válido de un personaje sin retratos', () {
      final zip = _buildZip(
        manifest: {
          'type': 'dnd_bundle',
          'formatVersion': 2,
          'scope': 'character',
          'characters': [
            {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
          ],
        },
        characterFiles: {'characters/sagan.json': _characterJson('sagan')},
      );

      final bundle = BackupBundleCodec.decode(zip);

      expect(bundle.characters, hasLength(1));
      expect(bundle.characters.single.character.id, 'sagan');
      expect(bundle.characters.single.portraits, isEmpty);
      // `_characterJson` no declara `schemaVersion`: por defecto es 1, así
      // que decodificar ya migra al esquema vigente (delegado en
      // `Character.fromJson`, que corre la cadena de migración del motor).
      expect(
        bundle.characters.single.character.toJson()['schemaVersion'],
        Character.currentSchemaVersion,
      );
    });

    test('incluye los retratos declarados y limpia portraitPaths', () {
      final portraitBytes = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3];
      final zip = _buildZip(
        manifest: {
          'type': 'dnd_bundle',
          'formatVersion': 2,
          'scope': 'character',
          'characters': [
            {
              'id': 'sagan',
              'file': 'characters/sagan.json',
              'portraits': ['portraits/sagan/0_retrato.png'],
            },
          ],
        },
        characterFiles: {
          'characters/sagan.json': {
            ..._characterJson('sagan'),
            'portraitPaths': ['una-clave-vieja/0.png'],
          },
        },
        extraBinaryEntries: {'portraits/sagan/0_retrato.png': portraitBytes},
      );

      final bundle = BackupBundleCodec.decode(zip);

      final entry = bundle.characters.single;
      expect(entry.character.portraitPaths, isEmpty);
      expect(entry.portraits, hasLength(1));
      expect(entry.portraits.single.bytes, portraitBytes);
    });

    test('rechaza una versión de formato futura', () {
      final zip = _buildZip(
        manifest: {
          'type': 'dnd_bundle',
          'formatVersion': 999,
          'scope': 'character',
          'characters': [],
        },
        characterFiles: {},
      );

      expect(() => BackupBundleCodec.decode(zip), throwsFormatException);
    });

    test('rechaza un archivo que no es un respaldo de Fichas D&D', () {
      final zip = _buildZip(
        manifest: {
          'type': 'otra_cosa',
          'formatVersion': 2,
          'scope': 'character',
          'characters': [],
        },
        characterFiles: {},
      );

      expect(() => BackupBundleCodec.decode(zip), throwsFormatException);
    });

    test('rechaza ids de personaje repetidos en el manifiesto', () {
      final zip = _buildZip(
        manifest: {
          'type': 'dnd_bundle',
          'formatVersion': 2,
          'scope': 'character',
          'characters': [
            {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
            {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
          ],
        },
        characterFiles: {'characters/sagan.json': _characterJson('sagan')},
      );

      expect(() => BackupBundleCodec.decode(zip), throwsFormatException);
    });

    test(
      'rechaza el respaldo entero si una entrada intenta escapar del zip',
      () {
        final zip = _buildZip(
          manifest: {
            'type': 'dnd_bundle',
            'formatVersion': 2,
            'scope': 'character',
            'characters': [
              {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
            ],
          },
          characterFiles: {'characters/sagan.json': _characterJson('sagan')},
          extraRawEntries: ['../evil.txt'],
        );

        expect(() => BackupBundleCodec.decode(zip), throwsFormatException);
      },
    );

    test(
      'rechaza una ruta de retrato que no pertenece al personaje declarado',
      () {
        final zip = _buildZip(
          manifest: {
            'type': 'dnd_bundle',
            'formatVersion': 2,
            'scope': 'character',
            'characters': [
              {
                'id': 'sagan',
                'file': 'characters/sagan.json',
                // Declara un retrato bajo el espacio de otro personaje.
                'portraits': ['portraits/otro/0.png'],
              },
            ],
          },
          characterFiles: {'characters/sagan.json': _characterJson('sagan')},
          extraBinaryEntries: {
            'portraits/otro/0.png': [1, 2, 3],
          },
        );

        expect(() => BackupBundleCodec.decode(zip), throwsFormatException);
      },
    );
  });
}
