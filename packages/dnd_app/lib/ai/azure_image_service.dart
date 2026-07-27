import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Recurso y modelo del deployment de Flux en Azure AI Foundry (beca Azure
/// Students). App personal de un solo usuario: no hace falta que sean
/// configurables.
const azureResourceEndpoint =
    'https://proyecto-dnd-resource.services.ai.azure.com';
const azureFluxModel = 'FLUX.2-pro';
const _azureFluxModelPath = 'flux-2-pro';

/// Error de generación con mensaje legible.
class AzureImageException implements Exception {
  final String message;
  AzureImageException(this.message);
  @override
  String toString() => message;
}

/// Cliente de la API específica de Black Forest Labs en Azure AI Foundry.
/// Solo requiere la API key: endpoint y modelo son fijos (ver arriba).
/// https://learn.microsoft.com/azure/ai-foundry/foundry-models/how-to/use-foundry-models-flux
class AzureImageService {
  final http.Client _client;
  AzureImageService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri uri = Uri.parse(
    '$azureResourceEndpoint/providers/blackforestlabs/v1/'
    '$_azureFluxModelPath?api-version=preview',
  );

  /// Cuerpo de la petición. Puro y testeable.
  /// `safety_tolerance` va de 0 (más estricto) a 6 (menos estricto); se pide
  /// el máximo porque el contenido es fantasía/D&D (armas, combate) y con el
  /// valor por defecto (2) el filtro da falsos positivos.
  static Map<String, dynamic> buildRequestBody(String prompt, int count) => {
    'model': azureFluxModel,
    'prompt': prompt,
    'width': 1024,
    'height': 1024,
    'n': count,
    'safety_tolerance': 6,
  };

  /// Extrae las imágenes en base64 de una respuesta ya decodificada. Puro y
  /// testeable.
  static List<Uint8List> extractImages(Map<String, dynamic> json) {
    final images = <Uint8List>[];
    for (final item in _dataItems(json)) {
      final b64 = item['b64_json'];
      if (b64 is String && b64.isNotEmpty) images.add(base64Decode(b64));
    }
    return images;
  }

  /// Extrae las URLs de imagen de una respuesta ya decodificada (algunos
  /// modelos devuelven `url` en vez de `b64_json`). Puro y testeable.
  static List<String> extractImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];
    for (final item in _dataItems(json)) {
      final url = item['url'];
      if (url is String && url.isNotEmpty) urls.add(url);
    }
    return urls;
  }

  static List<Map> _dataItems(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().toList();
  }

  /// Extrae el mensaje de error de una respuesta de la API. Puro.
  static String parseError(String body, int statusCode) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final error = j['error'];
        if (error is Map) {
          final msg = error['message'];
          if (msg is String && msg.isNotEmpty) return msg;
        }
      }
    } catch (_) {}
    return 'Azure respondió con código $statusCode.';
  }

  Future<List<Uint8List>> generate({
    required String apiKey,
    required String prompt,
    int count = 1,
  }) async {
    final resp = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(buildRequestBody(prompt, count)),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      throw AzureImageException(parseError(resp.body, resp.statusCode));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final images = extractImages(decoded);
    if (images.isNotEmpty) return images;

    final urls = extractImageUrls(decoded);
    if (urls.isEmpty) {
      // Con 200 y `data` vacío, el modelo se negó a generar en vez de fallar.
      if (decoded['stop_reason'] == 'refusal') {
        throw AzureImageException(
          'El modelo rechazó el prompt (filtro de contenido de Azure). Suele '
          'dispararse con armas o violencia: probá quitar el arma o suavizar '
          'los detalles.',
        );
      }
      throw AzureImageException('La respuesta no incluyó ninguna imagen.');
    }
    return [
      for (final url in urls) (await _client.get(Uri.parse(url))).bodyBytes,
    ];
  }

  void close() => _client.close();
}
