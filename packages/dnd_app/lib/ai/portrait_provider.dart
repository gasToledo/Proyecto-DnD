import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'gemini_image_service.dart';

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

/// Hugging Face Inference (router actual) — token gratis (cuenta sin tarjeta).
class HuggingFaceProvider implements PortraitProvider {
  final http.Client _client;
  final String model;
  HuggingFaceProvider({
    http.Client? client,
    this.model = 'stabilityai/stable-diffusion-3-medium-diffusers',
  }) : _client = client ?? http.Client();

  @override
  String get id => 'huggingface';
  @override
  String get name => 'Hugging Face (token gratis)';
  @override
  String? get keyHint => 'Token de huggingface.co (empieza con "hf_")';
  @override
  bool get supportsReference => false;
  @override
  int get defaultCount => 1;

  Uri get _uri =>
      Uri.parse('https://router.huggingface.co/hf-inference/models/$model');

  static Map<String, dynamic> buildBody(String prompt) => {'inputs': prompt};

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    String apiKey = '',
    Uint8List? reference,
    int? count,
  }) async {
    final resp = await _client
        .post(
          _uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'image/png',
          },
          body: jsonEncode(buildBody(prompt)),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode == 503) {
      throw ProviderException(
        'El modelo se está cargando en Hugging Face; probá de nuevo en ~20 s.',
      );
    }
    if (resp.statusCode != 200) {
      throw ProviderException(_error(resp.body, resp.statusCode));
    }
    return [resp.bodyBytes];
  }

  static String _error(String body, int status) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    if (status == 401) return 'Token de Hugging Face inválido o ausente (401).';
    if (status == 403) {
      return 'El modelo requiere aceptar su licencia en huggingface.co con tu '
          'cuenta (403).';
    }
    if (status == 404) {
      return 'El modelo no está disponible en el proveedor gratuito (404). '
          'Cambialo en Ajustes o usá Pollinations.';
    }
    return 'Hugging Face respondió con código $status.';
  }
}

/// Gemini (Google AI Studio). Requiere key (y hoy, en general, billing).
class GeminiProvider implements PortraitProvider {
  final GeminiImageService _service;
  GeminiProvider({GeminiImageService? service})
    : _service = service ?? GeminiImageService();

  @override
  String get id => 'gemini';
  @override
  String get name => 'Gemini (requiere API key/billing)';
  @override
  String? get keyHint => 'API key de Google AI Studio';
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
    return _service.generate(
      apiKey: apiKey,
      prompt: prompt,
      reference: reference,
    );
  }
}

/// Todos los proveedores disponibles, en orden de preferencia.
List<PortraitProvider> buildProviders() => [
  PollinationsProvider(),
  HuggingFaceProvider(),
  GeminiProvider(),
];

PortraitProvider providerById(String id) => buildProviders().firstWhere(
  (p) => p.id == id,
  orElse: () => PollinationsProvider(),
);
