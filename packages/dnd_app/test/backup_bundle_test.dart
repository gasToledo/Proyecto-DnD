import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_app/data/backup_bundle.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> manifestOf(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final content = archive.findFile('manifest.json')!.content as List<int>;
    return (jsonDecode(utf8.decode(content)) as Map).cast<String, dynamic>();
  }

  test('respaldo completo conserva personajes, retratos y contenido, sin '
      'ninguna ruta de la máquina que exportó', () async {
    final character = demoSagan().copyWith(
      portraitPaths: ['sagan/retrato.png'],
    );
    final portraitBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);

    final bytes = await BackupBundleCodec.encode(
      scope: BackupScope.full,
      characters: [character],
      readPortrait: (key) async {
        expect(key, 'sagan/retrato.png');
        return portraitBytes;
      },
      homebrew: {
        'weapons': [
          {'id': 'hb-espada', 'name': 'Espada casera'},
        ],
      },
      preferences: {
        'imageProvider': 'azure-gpt-image',
        // Credenciales actuales y de proveedores retirados: ninguna sale.
        'azureApiKey': 'no-exportar',
        'azureOpenAiApiKey': 'no-exportar',
        'geminiApiKey': 'no-exportar',
        'huggingFaceToken': 'no-exportar',
      },
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = manifestOf(bytes);
    expect(manifest['scope'], 'full');
    expect(manifest['characters'], [
      {
        'id': 'sagan',
        'file': 'characters/sagan.json',
        'portraits': ['portraits/sagan/0.png'],
      },
    ]);

    final portraitEntry = archive.findFile('portraits/sagan/0.png')!;
    expect(portraitEntry.content, portraitBytes);

    final characterJson =
        jsonDecode(
              utf8.decode(
                archive.findFile('characters/sagan.json')!.content as List<int>,
              ),
            )
            as Map;
    // El documento tal cual queda en el ZIP no arrastra ninguna clave de
    // retrato del sistema de archivos de origen: el original ya era una
    // clave opaca, y acá se conserva sin reescritura porque encode() no
    // toca portraitPaths (eso lo hace la migración de esquema, no el
    // codec de respaldo).
    expect(characterJson['portraitPaths'], ['sagan/retrato.png']);

    final homebrewJson =
        jsonDecode(
              utf8.decode(
                archive.findFile('homebrew/content.json')!.content as List<int>,
              ),
            )
            as Map;
    expect(homebrewJson['weapons'], [
      {'id': 'hb-espada', 'name': 'Espada casera'},
    ]);

    final preferencesJson =
        jsonDecode(
              utf8.decode(
                archive.findFile('settings/preferences.json')!.content
                    as List<int>,
              ),
            )
            as Map;
    expect(preferencesJson['imageProvider'], 'azure-gpt-image');
    for (final key in portableCredentialKeys) {
      expect(preferencesJson, isNot(contains(key)));
    }
  });

  test(
    'un alcance de personaje no incluye archivos de homebrew ni ajustes',
    () async {
      final bytes = await BackupBundleCodec.encode(
        scope: BackupScope.character,
        characters: [demoSagan()],
        readPortrait: (_) async => null,
      );

      final manifest = manifestOf(bytes);
      expect(manifest['homebrewFile'], isNull);
      expect(manifest['preferencesFile'], isNull);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('homebrew/content.json'), isNull);
      expect(archive.findFile('settings/preferences.json'), isNull);
    },
  );

  test('una clave de retrato que ya no resuelve a nada se omite sin fallar '
      'el respaldo entero', () async {
    final character = demoSagan().copyWith(
      portraitPaths: ['sagan/borrado.png'],
    );

    final bytes = await BackupBundleCodec.encode(
      scope: BackupScope.character,
      characters: [character],
      readPortrait: (_) async => null,
    );

    final manifest = manifestOf(bytes);
    expect(manifest['characters'], [
      {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
    ]);
  });

  test('no se puede exportar dos veces el mismo personaje', () async {
    final character = demoSagan();
    expect(
      () => BackupBundleCodec.encode(
        scope: BackupScope.full,
        characters: [character, character],
        readPortrait: (_) async => null,
      ),
      throwsFormatException,
    );
  });
}
