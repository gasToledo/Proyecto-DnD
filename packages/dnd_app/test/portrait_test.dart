import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/ai/azure_image_service.dart';
import 'package:dnd_app/ai/azure_openai_image_service.dart';
import 'package:dnd_app/ai/portrait_prompt.dart';
import 'package:dnd_app/ai/portrait_provider.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPortraitPrompt', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024',
      );
    });

    test('auto-completa raza, clase, armadura, arma y estilo', () {
      final prompt = buildPortraitPrompt(
        character: demoSagan(),
        repo: repo,
        style: 'Óleo clásico',
        extraText: 'pelo rojo largo',
      );
      expect(prompt, contains('Humano Guerrero'));
      expect(prompt, contains('Armadura de cuero'));
      expect(prompt, contains('Espada larga'));
      expect(prompt, contains('pelo rojo largo'));
      expect(prompt, contains('Estilo: Óleo clásico'));
    });

    test(
      'con includeWeapon: false omite el arma pero conserva la armadura',
      () {
        final prompt = buildPortraitPrompt(
          character: demoSagan(),
          repo: repo,
          style: 'Óleo clásico',
          extraText: '',
          includeWeapon: false,
        );
        expect(prompt, contains('Armadura de cuero'));
        expect(prompt, isNot(contains('Espada larga')));
      },
    );
  });

  group('Azure gpt-image-2 request/response (puro)', () {
    test('las URLs usan la ruta estilo OpenAI, no la de Black Forest Labs', () {
      // Es la diferencia que obliga a tener dos servicios de Azure y no uno
      // con el endpoint parametrizado.
      expect(
        AzureOpenAiImageService.generationsUri.toString(),
        '$azureOpenAiEndpoint/openai/deployments/$azureImageDeployment/'
        'images/generations?api-version=$azureOpenAiApiVersion',
      );
      expect(
        AzureOpenAiImageService.editsUri.toString(),
        contains('/images/edits?api-version='),
      );
      expect(AzureOpenAiImageService.generationsUri.host, isNot(contains('&')));
    });

    test('ninguna URL lleva la credencial', () {
      // La key va siempre en el encabezado `api-key`.
      for (final uri in [
        AzureOpenAiImageService.generationsUri,
        AzureOpenAiImageService.editsUri,
      ]) {
        expect(uri.queryParameters.keys, ['api-version']);
        expect(uri.userInfo, isEmpty);
      }
    });

    test('el cuerpo manda prompt, cantidad y tamaño', () {
      final body = AzureOpenAiImageService.buildRequestBody('un prompt', 2);
      expect(body['prompt'], 'un prompt');
      expect(body['n'], 2);
      expect(body['size'], '1024x1024');
    });

    test('extractImages decodifica data[].b64_json', () {
      final data = base64Encode([9, 8, 7]);
      final resp = {
        'data': [
          {'b64_json': data},
        ],
      };
      final imgs = AzureOpenAiImageService.extractImages(resp);
      expect(imgs, hasLength(1));
      expect(imgs.first, [9, 8, 7]);
    });

    test('parseError extrae el mensaje de la API y explica los 404', () {
      final body = jsonEncode({
        'error': {'message': 'clave inválida'},
      });
      expect(AzureOpenAiImageService.parseError(body, 400), 'clave inválida');
      expect(
        AzureOpenAiImageService.parseError('no es json', 404),
        contains(azureImageDeployment),
      );
    });
  });

  group('Azure request/response (puro)', () {
    test('la URL apunta al proveedor BFL con api-version', () {
      expect(
        AzureImageService.uri.toString(),
        '$azureResourceEndpoint/providers/blackforestlabs/v1/flux-2-pro'
        '?api-version=preview',
      );
    });

    test('el cuerpo manda el modelo, prompt, tamaño y cantidad', () {
      final body = AzureImageService.buildRequestBody('un prompt', 2);
      expect(body['model'], azureFluxModel);
      expect(body['prompt'], 'un prompt');
      expect(body['width'], 1024);
      expect(body['height'], 1024);
      expect(body['n'], 2);
      expect(body['safety_tolerance'], 6);
    });

    test('extractImages decodifica data[].b64_json', () {
      final data = base64Encode([9, 8, 7]);
      final resp = {
        'data': [
          {'b64_json': data},
        ],
      };
      final imgs = AzureImageService.extractImages(resp);
      expect(imgs, hasLength(1));
      expect(imgs.first, [9, 8, 7]);
    });

    test('extractImageUrls lee data[].url cuando no hay b64_json', () {
      final resp = {
        'data': [
          {'url': 'https://ejemplo/imagen.png'},
        ],
      };
      expect(AzureImageService.extractImages(resp), isEmpty);
      expect(AzureImageService.extractImageUrls(resp), [
        'https://ejemplo/imagen.png',
      ]);
    });

    test('parseError extrae el mensaje de la API', () {
      final body = jsonEncode({
        'error': {'message': 'clave inválida'},
      });
      expect(AzureImageService.parseError(body, 400), 'clave inválida');
    });
  });

  group('Proveedores enchufables', () {
    test('Pollinations no requiere key; los dos de Azure sí', () {
      expect(PollinationsProvider().keyHint, isNull);
      expect(AzureProvider().keyHint, isNotNull);
      expect(AzureOpenAiProvider().keyHint, isNotNull);
    });

    test('gpt-image-2 es el único que acepta imagen de referencia', () {
      // Al retirar Gemini la app se quedaba sin referencia; esto lo fija.
      final withReference = buildProviders().where((p) => p.supportsReference);
      expect(withReference.map((p) => p.id), ['azure-gpt-image']);
    });

    test('Pollinations arma la URL con prompt codificado y seed', () {
      final uri = PollinationsProvider.buildUri('un caballero rojo', 42);
      expect(uri.host, 'image.pollinations.ai');
      expect(uri.path, contains('prompt'));
      expect(uri.path, contains('caballero'));
      expect(uri.queryParameters['seed'], '42');
      expect(uri.queryParameters['model'], 'flux');
    });

    test('providerById cae en Pollinations ante un id desconocido', () {
      expect(providerById('inexistente').id, 'pollinations');
      // Los proveedores retirados degradan solo: un settings.json viejo no
      // deja la app sin proveedor.
      for (final retired in retiredProviderIds) {
        expect(providerById(retired).id, 'pollinations');
      }
      expect(providerById('azure-gpt-image').id, 'azure-gpt-image');
    });
  });
}
