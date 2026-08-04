import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'azure_image_service.dart';
import 'azure_openai_image_service.dart';

/// Error legible de un proveedor de imágenes. El mensaje se muestra a la
/// cuenta que pidió la generación; MUST NOT contener ninguna credencial.
class ProviderException implements Exception {
  final String message;
  ProviderException(this.message);
  @override
  String toString() => message;
}

/// Proveedor de generación de retratos enchufable. A diferencia de la versión
/// que tenía la aplicación de escritorio, la credencial ya no la manda quien
/// llama: vive en la configuración del servidor y queda fija al construir el
/// proveedor (ver capacidad `ai-portrait-generation`).
abstract class PortraitProvider {
  String get id;
  String get name;

  bool get supportsReference;

  /// Cantidad de imágenes por defecto que genera.
  int get defaultCount => 1;

  /// `true` si este servidor tiene lo necesario para usar el proveedor. Los
  /// que no piden credencial siempre lo están; los que sí, solo si la
  /// configuración del servidor trae la key.
  bool get isConfigured;

  Future<List<Uint8List>> generate({
    required String prompt,
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
  bool get supportsReference => false;
  @override
  int get defaultCount => 2;
  @override
  bool get isConfigured => true;

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
/// `azure_openai_image_service.dart`); solo necesita la API key. Es el único
/// proveedor que acepta imagen de referencia.
class AzureOpenAiProvider implements PortraitProvider {
  final String apiKey;
  final http.Client? _client;
  AzureOpenAiProvider({required this.apiKey, http.Client? client})
    : _client = client;

  @override
  String get id => 'azure-gpt-image';
  @override
  String get name => 'Azure · gpt-image-2';
  @override
  bool get supportsReference => true;
  @override
  int get defaultCount => 1;
  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
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

/// Flux (Black Forest Labs) en Azure AI Foundry. Endpoint y modelo son fijos;
/// solo necesita la API key.
class AzureProvider implements PortraitProvider {
  final String apiKey;
  final http.Client? _client;
  AzureProvider({required this.apiKey, http.Client? client}) : _client = client;

  @override
  String get id => 'azure';
  @override
  String get name => 'Azure AI Foundry (Flux)';
  @override
  bool get supportsReference => false;
  @override
  int get defaultCount => 1;
  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    Uint8List? reference,
    int? count,
  }) {
    final service = AzureImageService(client: _client);
    return service
        .generate(apiKey: apiKey, prompt: prompt, count: count ?? defaultCount)
        .whenComplete(service.close);
  }
}

/// Todos los proveedores del servidor, en orden de preferencia, con su
/// credencial ya resuelta desde [config]. Algunos no estarán [isConfigured]
/// si el despliegue no cargó su key.
List<PortraitProvider> buildProviders(
  AiProvidersConfig config, {
  http.Client? client,
}) => [
  PollinationsProvider(client: client),
  AzureOpenAiProvider(apiKey: config.azureOpenAiApiKey, client: client),
  AzureProvider(apiKey: config.azureApiKey, client: client),
];

/// Ids que existieron y ya no. Un ajuste de cuenta guardado con uno de estos
/// degrada a Pollinations al cargarlo (ver [resolveStoredProviderId]).
const retiredProviderIds = {'huggingface', 'gemini'};

/// Proveedores listos para ofrecerse como opción: los que no piden
/// credencial, más los que la tienen configurada en este servidor. Un
/// proveedor sin key MUST NOT aparecer acá (ver capacidad
/// `ai-portrait-generation`).
List<PortraitProvider> availableProviders(List<PortraitProvider> providers) =>
    providers.where((p) => p.isConfigured).toList();

/// Resuelve el proveedor guardado en los ajustes de una cuenta. Un id
/// desconocido o retirado degrada a Pollinations sin tocar el resto del
/// documento de ajustes; a diferencia de una petición de generación en vivo
/// con un id inválido, acá no hay pedido que rechazar: es una preferencia
/// guardada que hay que poder seguir cargando.
String resolveStoredProviderId(
  String? stored,
  List<PortraitProvider> providers,
) {
  if (stored == null || retiredProviderIds.contains(stored)) {
    return 'pollinations';
  }
  final known = providers.any((p) => p.id == stored);
  return known ? stored : 'pollinations';
}
