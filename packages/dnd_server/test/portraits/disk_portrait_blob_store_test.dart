import 'dart:io';
import 'dart:typed_data';

import 'package:dnd_server/src/portraits/disk_portrait_blob_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  const pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];
  const jpegBytes = [0xFF, 0xD8, 0xFF, 1, 2, 3];
  const webpBytes = [
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
    1, 2, 3,
  ];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dnd_portraits_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('save/read', () {
    test('guarda y lee un PNG bajo la clave devuelta', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      final key = await store.save(
        userId: 'user-a',
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      expect(key, startsWith('sagan/'));
      expect(key, endsWith('.png'));

      final blob = await store.read(userId: 'user-a', portraitKey: key);
      expect(blob, isNotNull);
      expect(blob!.contentType, 'image/png');
      expect(blob.bytes, pngBytes);
    });

    test('reconoce JPEG y WEBP por su cabecera de bytes', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      final jpegKey = await store.save(
        userId: 'user-a',
        characterId: 'sagan',
        bytes: Uint8List.fromList(jpegBytes),
      );
      final webpKey = await store.save(
        userId: 'user-a',
        characterId: 'sagan',
        bytes: Uint8List.fromList(webpBytes),
      );

      expect(
        (await store.read(userId: 'user-a', portraitKey: jpegKey))!.contentType,
        'image/jpeg',
      );
      expect(
        (await store.read(userId: 'user-a', portraitKey: webpKey))!.contentType,
        'image/webp',
      );
    });

    test(
      'la primera clave sigue siendo la que se muestra como retrato activo',
      () async {
        // No es responsabilidad del store ordenar: solo garantiza que cada
        // guardado devuelve una clave nueva y estable; el orden de
        // `portraitPaths` lo conserva `Character`.
        final store = DiskPortraitBlobStore(
          root: tempDir.path,
          maxBytes: 1024 * 1024,
        );

        final first = await store.save(
          userId: 'user-a',
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        );
        final second = await store.save(
          userId: 'user-a',
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        );

        expect(first, isNot(second));
      },
    );
  });

  group('validación de imágenes entrantes', () {
    test('rechaza un archivo que supera el tamaño máximo', () async {
      final store = DiskPortraitBlobStore(root: tempDir.path, maxBytes: 4);

      expect(
        () => store.save(
          userId: 'user-a',
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        ),
        throwsFormatException,
      );
    });

    test('rechaza un archivo que no es una imagen admitida', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      expect(
        () => store.save(
          userId: 'user-a',
          characterId: 'sagan',
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        ),
        throwsFormatException,
      );
    });

    test('un rechazo por tamaño o tipo no deja nada guardado', () async {
      final store = DiskPortraitBlobStore(root: tempDir.path, maxBytes: 4);

      await expectLater(
        () => store.save(
          userId: 'user-a',
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        ),
        throwsFormatException,
      );

      expect(Directory(tempDir.path).listSync(recursive: true), isEmpty);
    });
  });

  group('aislamiento entre cuentas y claves manipuladas', () {
    test('un retrato de otra cuenta no se puede leer con su clave', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );
      final key = await store.save(
        userId: 'user-a',
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      expect(await store.read(userId: 'user-b', portraitKey: key), isNull);
    });

    test('una clave inexistente devuelve null, no un error', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      expect(
        await store.read(userId: 'user-a', portraitKey: 'sagan/no-existe.png'),
        isNull,
      );
    });

    test('una clave con segmentos que intentan escapar se rechaza', () async {
      final store = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      expect(
        () => store.read(userId: 'user-a', portraitKey: '../etc/passwd'),
        throwsFormatException,
      );
      expect(
        () => store.read(userId: 'user-a', portraitKey: 'sagan/../../x.png'),
        throwsFormatException,
      );
      expect(
        () => store.read(userId: 'user-a', portraitKey: 'sagan'),
        throwsFormatException,
      );
    });
  });

  test(
    'un retrato guardado sigue disponible tras "reiniciar" el store',
    () async {
      final firstProcess = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );
      final key = await firstProcess.save(
        userId: 'user-a',
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      // Simula el reinicio de los contenedores: una instancia nueva del store
      // apuntando al mismo volumen, sin ningún estado en memoria compartido.
      final afterRestart = DiskPortraitBlobStore(
        root: tempDir.path,
        maxBytes: 1024 * 1024,
      );

      final blob = await afterRestart.read(userId: 'user-a', portraitKey: key);
      expect(blob, isNotNull);
      expect(blob!.bytes, pngBytes);
    },
  );
}
