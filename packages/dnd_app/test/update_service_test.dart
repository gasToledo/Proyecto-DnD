import 'dart:convert';
import 'dart:io';

import 'package:dnd_app/data/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> release(String tag) => {
    'tag_name': tag,
    'name': 'Fichas D&D $tag',
    'body': 'Cambios del release.',
    'assets': [
      {
        'name': 'FichasDnD-$tag-windows.zip',
        'browser_download_url':
            'https://github.com/gasToledo/Proyecto-DnD/releases/download/'
            '$tag/FichasDnD-$tag-windows.zip',
      },
    ],
  };

  test('detecta solamente una versión posterior', () async {
    final latest = UpdateService(
      currentVersion: '0.4.0',
      client: MockClient(
        (_) async => http.Response(jsonEncode(release('v0.4.1')), 200),
      ),
    );
    final current = UpdateService(
      currentVersion: '0.4.1',
      client: MockClient(
        (_) async => http.Response(jsonEncode(release('v0.4.1')), 200),
      ),
    );

    expect((await latest.checkForUpdate())?.version, '0.4.1');
    expect(await current.checkForUpdate(), isNull);
  });

  test('descarga el ZIP en la carpeta de exportaciones', () async {
    final sandbox = await Directory.systemTemp.createTemp('dnd-update-');
    addTearDown(() => sandbox.delete(recursive: true));
    final service = UpdateService(
      currentVersion: '0.4.0',
      client: MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
    );
    final update = AppUpdate(
      version: '0.4.1',
      title: 'v0.4.1',
      notes: '',
      assetName: 'FichasDnD-v0.4.1-windows.zip',
      downloadUrl: Uri.parse('https://github.com/download.zip'),
    );

    final file = await service.download(update, dataRoot: sandbox.path);

    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(file.path, contains('FichasDnD${Platform.pathSeparator}exports'));
  });
}
