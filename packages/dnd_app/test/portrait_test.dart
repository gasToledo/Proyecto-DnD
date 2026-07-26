import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/ai/gemini_image_service.dart';
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
  });

  group('Gemini request/response (puro)', () {
    test(
      'el cuerpo pide modalidad de imagen y sin referencia no incluye inlineData',
      () {
        final body = GeminiImageService.buildRequestBody('un prompt');
        final parts = (body['contents'] as List).first['parts'] as List;
        expect(parts.first['text'], 'un prompt');
        expect(parts.any((p) => (p as Map).containsKey('inlineData')), isFalse);
        expect(body['generationConfig']['responseModalities'], ['IMAGE']);
      },
    );

    test('con referencia agrega inlineData en base64', () {
      final ref = Uint8List.fromList([1, 2, 3, 4]);
      final body = GeminiImageService.buildRequestBody('p', reference: ref);
      final parts = (body['contents'] as List).first['parts'] as List;
      final inline = parts.firstWhere(
        (p) => (p as Map).containsKey('inlineData'),
      );
      expect(inline['inlineData']['data'], base64Encode(ref));
    });

    test('extractImages decodifica inlineData e inline_data', () {
      final data = base64Encode([9, 8, 7]);
      final resp = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inlineData': {'mimeType': 'image/png', 'data': data},
                },
              ],
            },
          },
        ],
      };
      final imgs = GeminiImageService.extractImages(resp);
      expect(imgs, hasLength(1));
      expect(imgs.first, [9, 8, 7]);
    });

    test('parseError extrae el mensaje de la API', () {
      final body = jsonEncode({
        'error': {'message': 'clave inválida'},
      });
      expect(GeminiImageService.parseError(body, 400), 'clave inválida');
    });
  });

  group('Proveedores enchufables', () {
    test('Pollinations no requiere key; Gemini y HF sí', () {
      expect(PollinationsProvider().keyHint, isNull);
      expect(HuggingFaceProvider().keyHint, isNotNull);
      expect(GeminiProvider().keyHint, isNotNull);
    });

    test('Pollinations arma la URL con prompt codificado y seed', () {
      final uri = PollinationsProvider.buildUri('un caballero rojo', 42);
      expect(uri.host, 'image.pollinations.ai');
      expect(uri.path, contains('prompt'));
      expect(uri.path, contains('caballero'));
      expect(uri.queryParameters['seed'], '42');
      expect(uri.queryParameters['model'], 'flux');
    });

    test('Hugging Face arma el cuerpo con el prompt', () {
      expect(HuggingFaceProvider.buildBody('un prompt'), {
        'inputs': 'un prompt',
      });
    });

    test('providerById cae en Pollinations ante id desconocido', () {
      expect(providerById('inexistente').id, 'pollinations');
      expect(providerById('huggingface').id, 'huggingface');
    });
  });
}
