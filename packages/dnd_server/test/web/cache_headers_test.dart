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

  // Nombres reales que produce `flutter build web`. Ninguno lleva huella de
  // contenido: son idénticos entre una versión y la siguiente, así que
  // ninguno puede cachearse sin revalidar.
  const buildOutput = [
    '',
    'index.html',
    'flutter_bootstrap.js',
    'flutter.js',
    'main.dart.js',
    'version.json',
    'manifest.json',
    'flutter_service_worker.js',
    'favicon.png',
    'icons/Icon-192.png',
    'assets/AssetManifest.bin.json',
    'assets/FontManifest.json',
    'assets/NOTICES',
    'assets/fonts/MaterialIcons-Regular.otf',
    'canvaskit/canvaskit.js',
    'canvaskit/canvaskit.wasm',
  ];

  group('webCacheHeadersMiddleware', () {
    test('ningún archivo del build se declara immutable ni se cachea a largo '
        'plazo: los nombres se repiten entre versiones', () async {
      for (final path in buildOutput) {
        final cacheControl = (await handle(path)).headers['cache-control'];

        expect(
          cacheControl,
          isNot(contains('immutable')),
          reason:
              '"$path" se declaró immutable con un nombre que se repite entre '
              'versiones: una recarga seguiría sirviendo el build viejo.',
        );
        expect(
          cacheControl,
          isNot(matches(RegExp(r'max-age=[1-9]'))),
          reason: '"$path" se cacheó sin revalidar ($cacheControl).',
        );
      }
    });

    test('todo el build revalida contra el servidor', () async {
      for (final path in buildOutput) {
        expect(
          (await handle(path)).headers['cache-control'],
          contains('no-cache'),
          reason: '"$path" no revalida.',
        );
      }
    });

    // Sin `private`, Cloudflare almacenaba los `.js` en el borde y reescribía
    // la cabecera hacia el navegador a `max-age=14400`: un despliegue tardaba
    // hasta cuatro horas en llegar aunque el origen dijera `no-cache`.
    test(
      'ninguna caché compartida puede quedarse un archivo del build',
      () async {
        for (final path in buildOutput) {
          expect(
            (await handle(path)).headers['cache-control'],
            contains('private'),
            reason: '"$path" puede quedar almacenado por un intermediario.',
          );
        }
      },
    );

    test('la política es la misma para la raíz que para index.html', () async {
      expect(
        (await handle('')).headers['cache-control'],
        (await handle('index.html')).headers['cache-control'],
      );
    });
  });
}
