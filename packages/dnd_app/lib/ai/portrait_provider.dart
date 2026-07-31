import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'azure_image_service.dart';
import 'azure_openai_image_service.dart';

/// Error legible de un proveedor de imágenes.
class ProviderException implements Exception {
  final String message;
  ProviderException(this.message);
  @override
  String toString() => message;
}

/// Proveedor de generación de retratos enchufable (brief §7). Cada uno sabe si
/// requiere API key y si admite imagen de referencia.
abstract class PortraitProvider {
  String get id;
  String get name;

  /// Pista de qué key pide, o null si no necesita.
  String? get keyHint;
  bool get supportsReference;

  /// Cantidad de imágenes por defecto que genera.
  int get defaultCount => 1;

  Future<List<Uint8List>> generate({
    required String prompt,
    String apiKey = '',
    Uint8List? reference,
    int? count,
  });
}

/// Pollinations.ai — gratis, sin key ni cuenta. Default.
///
/// El tier anónimo limita peticiones concurrentes (paralelo → 429), así que
/// generamos **en secuencia** y reintentamos ante 429.
class PollinationsProvider implements PortraitProvider {
  final http.Client _client;
  PollinationsProvider({http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'pollinations';
  @override
  String get name => 'Pollinations (gratis, sin key)';
  @override
  String? get keyHint => null;
  @override
  bool get supportsReference => false;
  @override
  int get defaultCount => 2;

  static Uri buildUri(String prompt, int seed) =>
      Uri.https('image.pollinations.ai', '/prompt/$prompt', {
        'width': '768',
        'height': '768',
        'nologo': 'true',
        'seed': '$seed',
        'model': 'flux',
      });

  Future<Uint8List> _fetch(Uri uri) async {
    for (var attempt = 0; ; attempt++) {
      final resp = await _client.get(uri).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) return resp.bodyBytes;
      if (resp.statusCode == 429 && attempt < 3) {
        await Future<void>.delayed(Duration(seconds: 3 * (attempt + 1)));
        continue;
      }
      throw ProviderException(
        resp.statusCode == 429
            ? 'Pollinations está limitando las peticiones (429). Esperá unos '
                  'segundos y probá de nuevo.'
            : 'Pollinations respondió ${resp.statusCode}.',
      );
    }
  }

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    String apiKey = '',
    Uint8List? reference,
    int? count,
  }) async {
    final n = count ?? defaultCount;
    final rng = Random();
    final out = <Uint8List>[];
    // En secuencia para no gatillar el límite de concurrencia (429).
    for (var i = 0; i < n; i++) {
      out.add(await _fetch(buildUri(prompt, rng.nextInt(1 << 31))));
    }
    return out;
  }
}

/// gpt-image-2 en Azure. Recurso y deployment fijos (ver
/// `azure_openai_image_service.dart`); solo pide la API key. Es el único
/// proveedor que acepta imagen de referencia.
class AzureOpenAiProvider implements PortraitProvider {
  final http.Client? _client;
  AzureOpenAiProvider({this._client});

  @override
  String get id => 'azure-gpt-image';
  @override
  String get name => 'Azure · gpt-image-2 (requiere API key)';
  @override
  String? get keyHint => 'API key del recurso de Azure';
  @override
  bool get supportsReference => true;
  @override
  int get defaultCount => 1;

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    String apiKey = '',
    Uint8List? reference,
    int? count,
  }) {
    final service = AzureOpenAiImageService(client: _client);
    return service
        .generate(
          apiKey: apiKey,
          prompt: prompt,
          count: count ?? defaultCount,
          reference: reference,
        )
        .whenComplete(service.close);
  }
}

/// Flux (Black Forest Labs) en Azure AI Foundry. Endpoint y modelo son fijos
/// (beca Azure Students de un solo recurso); solo pide la API key.
class AzureProvider implements PortraitProvider {
  final http.Client? _client;
  AzureProvider({this._client});

  @override
  String get id => 'azure';
  @override
  String get name => 'Azure AI Foundry (Flux, requiere API key)';
  @override
  String? get keyHint => 'API key del recurso de Azure AI Foundry';
  @override
  bool get supportsReference => false;
  @override
  int get defaultCount => 1;

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    String apiKey = '',
    Uint8List? reference,
    int? count,
  }) {
    final service = AzureImageService(client: _client);
    return service
        .generate(apiKey: apiKey, prompt: prompt, count: count ?? defaultCount)
        .whenComplete(service.close);
  }
}

/// Todos los proveedores disponibles, en orden de preferencia.
List<PortraitProvider> buildProviders() => [
  PollinationsProvider(),
  AzureOpenAiProvider(),
  AzureProvider(),
];

/// Ids que existieron y ya no. Un ajuste guardado con uno de estos degrada a
/// Pollinations sin avisar (ver [providerById]); la migración de `settings.json`
/// lo reescribe la próxima vez que se guarden los ajustes.
const retiredProviderIds = {'huggingface', 'gemini'};

PortraitProvider providerById(String id) => buildProviders().firstWhere(
  (p) => p.id == id,
  orElse: () => PollinationsProvider(),
);
