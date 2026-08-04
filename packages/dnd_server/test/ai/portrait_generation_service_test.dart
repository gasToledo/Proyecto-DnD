import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../fakes/fake_portrait_provider.dart';

void main() {
  group('generate', () {
    test('rechaza un proveedor desconocido', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(id: 'pollinations'),
      ]);

      expect(
        () => service.generate(providerId: 'no-existe', prompt: 'x'),
        throwsFormatException,
      );
    });

    test('rechaza un proveedor sin credenciales configuradas', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(id: 'azure', isConfigured: false),
      ]);

      expect(
        () => service.generate(providerId: 'azure', prompt: 'x'),
        throwsFormatException,
      );
    });

    test('rechaza una referencia si el proveedor no la admite', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(id: 'pollinations', supportsReference: false),
      ]);

      expect(
        () => service.generate(
          providerId: 'pollinations',
          prompt: 'x',
          reference: Uint8List.fromList([1, 2, 3]),
        ),
        throwsFormatException,
      );
    });

    test('devuelve las imágenes que produce el proveedor', () async {
      final service = PortraitGenerationService([
        FakePortraitProvider(
          id: 'pollinations',
          onGenerate: ({required prompt, reference, count}) async => [
            Uint8List.fromList([1, 2, 3]),
          ],
        ),
      ]);

      final images = await service.generate(
        providerId: 'pollinations',
        prompt: 'un caballero',
      );

      expect(images, [
        [1, 2, 3],
      ]);
    });

    test('un error del proveedor se convierte en PortraitGenerationFailure con '
        'un mensaje comprensible', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(
          id: 'pollinations',
          onGenerate: ({required prompt, reference, count}) async =>
              throw ProviderException('el proveedor está limitando'),
        ),
      ]);

      expect(
        () => service.generate(providerId: 'pollinations', prompt: 'x'),
        throwsA(
          isA<PortraitGenerationFailure>().having(
            (e) => e.message,
            'message',
            'el proveedor está limitando',
          ),
        ),
      );
    });

    test('un timeout se convierte en un mensaje propio, no en 500', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(
          id: 'pollinations',
          onGenerate: ({required prompt, reference, count}) =>
              throw TimeoutException('tardó demasiado'),
        ),
      ]);

      expect(
        () => service.generate(providerId: 'pollinations', prompt: 'x'),
        throwsA(isA<PortraitGenerationFailure>()),
      );
    });
  });

  group('available', () {
    test('oculta los proveedores sin credenciales', () {
      final service = PortraitGenerationService([
        FakePortraitProvider(id: 'pollinations', isConfigured: true),
        FakePortraitProvider(id: 'azure', isConfigured: false),
      ]);

      expect(service.available.map((p) => p.id), ['pollinations']);
    });
  });

  group('la credencial nunca se filtra', () {
    const secretKey = 'super-secreta-azure-key';

    test(
      'un error del proveedor real no incluye la api key en su mensaje',
      () async {
        final service = PortraitGenerationService(
          buildProviders(
            const AiProvidersConfig(
              azureApiKey: '',
              azureOpenAiApiKey: secretKey,
            ),
            client: MockClient(
              (request) async => http.Response(
                jsonEncode({
                  'error': {'message': 'la clave enviada no es válida'},
                }),
                401,
              ),
            ),
          ),
        );

        try {
          await service.generate(providerId: 'azure-gpt-image', prompt: 'x');
          fail('debía lanzar PortraitGenerationFailure');
        } on PortraitGenerationFailure catch (e) {
          expect(e.message, isNot(contains(secretKey)));
        }
      },
    );
  });
}
