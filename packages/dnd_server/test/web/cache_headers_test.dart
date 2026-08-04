import 'package:dnd_server/src/web/cache_headers.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  Future<Response> handle(String path) async {
    final handler = const Pipeline()
        .addMiddleware(webCacheHeadersMiddleware)
        .addHandler((request) => Response.ok('cuerpo'));
    return await handler(Request('GET', Uri.parse('http://localhost/$path')));
  }

  group('webCacheHeadersMiddleware', () {
    test('index.html no se cachea', () async {
      final response = await handle('index.html');
      expect(response.headers['cache-control'], 'no-cache');
    });

    test('la raíz (equivalente a index.html) no se cachea', () async {
      final response = await handle('');
      expect(response.headers['cache-control'], 'no-cache');
    });

    test('flutter_service_worker.js no se cachea', () async {
      final response = await handle('flutter_service_worker.js');
      expect(response.headers['cache-control'], 'no-cache');
    });

    test('un recurso con huella se cachea de forma prolongada', () async {
      final response = await handle('main.dart.js');
      expect(
        response.headers['cache-control'],
        'public, max-age=31536000, immutable',
      );
    });

    test(
      'un asset dentro de una subcarpeta se cachea de forma prolongada',
      () async {
        final response = await handle('assets/AssetManifest.json');
        expect(
          response.headers['cache-control'],
          'public, max-age=31536000, immutable',
        );
      },
    );
  });
}
