import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';

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

List<Map> _imageData(Map<String, dynamic> json) =>
    (json['data'] as List? ?? const []).whereType<Map>().toList();

List<Uint8List> _base64Images(Map<String, dynamic> json) => [
  for (final item in _imageData(json))
    if (item['b64_json'] case final String value when value.isNotEmpty)
      base64Decode(value),
];

List<String> _imageUrls(Map<String, dynamic> json) => [
  for (final item in _imageData(json))
    if (item['url'] case final String value when value.isNotEmpty) value,
];

String? _azureErrorMessage(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map) {
      final error = json['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
  } catch (_) {}
  return null;
}

/// Recurso y deployment de gpt-image-2. Es un recurso cedido al despliegue, de
/// un solo dueño: no hace falta que sean configurables.
///
/// Ojo: **no** es el mismo recurso que el de Flux ([_azureResourceEndpoint]),
/// aunque ahora vivan en el mismo archivo. Aquel usa la API propia de Black
/// Forest Labs bajo `/providers/blackforestlabs/`; este habla la API estilo
/// OpenAI bajo `/openai/deployments/`. Por eso son dos proveedores y no un
/// parámetro.
const _azureOpenAiEndpoint =
    'https://ia-aplicada-resource.cognitiveservices.azure.com';
const _azureImageDeployment = 'gpt-image-2';

/// Versión de la API de imágenes. Si Azure devuelve 404 con la ruta correcta,
/// suele ser esto lo que hay que actualizar contra el recurso.
const _azureOpenAiApiVersion = '2025-04-01-preview';

/// gpt-image-2 en Azure. Es el único proveedor con imagen de referencia.
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

  static Uri _uri(String operation) => Uri.parse(
    '$_azureOpenAiEndpoint/openai/deployments/$_azureImageDeployment/'
    'images/$operation?api-version=$_azureOpenAiApiVersion',
  );

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    Uint8List? reference,
    int? count,
  }) async {
    final client = _client ?? http.Client();
    try {
      final n = count ?? defaultCount;
      final http.Response response;
      if (reference == null) {
        response = await client
            .post(
              _uri('generations'),
              headers: {'Content-Type': 'application/json', 'api-key': apiKey},
              body: jsonEncode({'prompt': prompt, 'n': n, 'size': '1024x1024'}),
            )
            .timeout(const Duration(seconds: 120));
      } else {
        final request = http.MultipartRequest('POST', _uri('edits'))
          ..headers['api-key'] = apiKey
          ..fields['prompt'] = prompt
          ..fields['n'] = '$n'
          ..fields['size'] = '1024x1024'
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              reference,
              filename: 'reference.png',
            ),
          );
        response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 120)),
        );
      }

      if (response.statusCode != 200) {
        throw ProviderException(
          _parseError(response.body, response.statusCode),
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final images = _base64Images(decoded);
      if (images.isNotEmpty) return images;

      final urls = _imageUrls(decoded);
      if (urls.isEmpty) {
        throw ProviderException(
          'La respuesta no incluyó ninguna imagen. Puede ser el filtro de '
          'contenido: probá quitar el arma o suavizar los detalles.',
        );
      }
      return [
        for (final url in urls) (await client.get(Uri.parse(url))).bodyBytes,
      ];
    } finally {
      client.close();
    }
  }

  static String _parseError(String body, int statusCode) {
    final message = _azureErrorMessage(body);
    if (message != null) return message;
    if (statusCode == 401 || statusCode == 403) {
      return 'La API key de Azure es inválida o no tiene acceso al '
          'deployment $_azureImageDeployment ($statusCode).';
    }
    if (statusCode == 404) {
      return 'Azure no encontró el deployment $_azureImageDeployment en el '
          'recurso configurado (404). Revisá el nombre del deployment y la '
          'versión de API.';
    }
    return 'Azure respondió con código $statusCode.';
  }
}

/// Recurso y modelo del deployment de Flux en Azure AI Foundry (beca Azure
/// Students). App personal de un solo despliegue: no hace falta que sean
/// configurables. Es un recurso **distinto** al de gpt-image-2 (ver
/// [_azureOpenAiEndpoint]).
const _azureResourceEndpoint =
    'https://proyecto-dnd-resource.services.ai.azure.com';
const _azureFluxModel = 'FLUX.2-pro';
const _azureFluxModelPath = 'flux-2-pro';

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

  static final _uri = Uri.parse(
    '$_azureResourceEndpoint/providers/blackforestlabs/v1/'
    '$_azureFluxModelPath?api-version=preview',
  );

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    Uint8List? reference,
    int? count,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            _uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _azureFluxModel,
              'prompt': prompt,
              'width': 1024,
              'height': 1024,
              'n': count ?? defaultCount,
              // Va de 0 (más estricto) a 6 (menos estricto); se pide el máximo
              // porque el contenido es fantasía/D&D (armas, combate) y con el
              // valor por defecto (2) el filtro da falsos positivos.
              'safety_tolerance': 6,
            }),
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) {
        throw ProviderException(
          _azureErrorMessage(response.body) ??
              'Azure respondió con código ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final images = _base64Images(decoded);
      if (images.isNotEmpty) return images;

      final urls = _imageUrls(decoded);
      if (urls.isEmpty) {
        if (decoded['stop_reason'] == 'refusal') {
          throw ProviderException(
            'El modelo rechazó el prompt (filtro de contenido de Azure). '
            'Suele dispararse con armas o violencia: probá quitar el arma o '
            'suavizar los detalles.',
          );
        }
        throw ProviderException('La respuesta no incluyó ninguna imagen.');
      }
      return [
        for (final url in urls) (await client.get(Uri.parse(url))).bodyBytes,
      ];
    } finally {
      client.close();
    }
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
