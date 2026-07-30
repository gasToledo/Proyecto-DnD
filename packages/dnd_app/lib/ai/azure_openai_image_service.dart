import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Recurso y deployment de gpt-image-2 en Azure. Es un recurso cedido al
/// usuario, de un solo dueño: no hace falta que sean configurables.
///
/// Ojo: **no** es el mismo recurso que el de Flux
/// (`azure_image_service.dart`). Aquel usa la API propia de Black Forest Labs
/// bajo `/providers/blackforestlabs/`; este habla la API estilo OpenAI bajo
/// `/openai/deployments/`. Por eso son dos servicios y no un parámetro.
const azureOpenAiEndpoint =
    'https://ia-aplicada-resource.cognitiveservices.azure.com';
const azureImageDeployment = 'gpt-image-2';

/// Versión de la API de imágenes. Si Azure devuelve 404 con la ruta correcta,
/// suele ser esto lo que hay que actualizar contra el recurso.
const azureOpenAiApiVersion = '2025-04-01-preview';

/// Error de generación con mensaje legible.
class AzureOpenAiImageException implements Exception {
  final String message;
  AzureOpenAiImageException(this.message);
  @override
  String toString() => message;
}

/// Cliente de gpt-image-2 en Azure (API compatible con OpenAI Images).
/// La API key viaja en el encabezado `api-key`, nunca en la URL.
class AzureOpenAiImageService {
  final http.Client _client;
  AzureOpenAiImageService({http.Client? client})
    : _client = client ?? http.Client();

  static Uri _uri(String operation) => Uri.parse(
    '$azureOpenAiEndpoint/openai/deployments/$azureImageDeployment/'
    'images/$operation?api-version=$azureOpenAiApiVersion',
  );

  /// Generación desde texto.
  static Uri get generationsUri => _uri('generations');

  /// Generación con imagen de referencia. Es la operación que reemplaza lo que
  /// antes hacía Gemini, el único proveedor que aceptaba referencia.
  static Uri get editsUri => _uri('edits');

  /// Cuerpo de la petición de texto a imagen. Puro y testeable.
  static Map<String, dynamic> buildRequestBody(String prompt, int count) => {
    'prompt': prompt,
    'n': count,
    'size': '1024x1024',
  };

  /// Extrae las imágenes en base64 de una respuesta ya decodificada. Puro.
  static List<Uint8List> extractImages(Map<String, dynamic> json) {
    final images = <Uint8List>[];
    for (final item in _dataItems(json)) {
      final b64 = item['b64_json'];
      if (b64 is String && b64.isNotEmpty) images.add(base64Decode(b64));
    }
    return images;
  }

  /// Extrae las URLs de imagen de una respuesta ya decodificada, para los
  /// casos en que el modelo devuelve `url` en vez de `b64_json`. Puro.
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
    if (statusCode == 401 || statusCode == 403) {
      return 'La API key de Azure es inválida o no tiene acceso al '
          'deployment $azureImageDeployment ($statusCode).';
    }
    if (statusCode == 404) {
      return 'Azure no encontró el deployment $azureImageDeployment en el '
          'recurso configurado (404). Revisá el nombre del deployment y la '
          'versión de API.';
    }
    return 'Azure respondió con código $statusCode.';
  }

  Future<List<Uint8List>> generate({
    required String apiKey,
    required String prompt,
    int count = 1,
    Uint8List? reference,
  }) async {
    final resp = reference == null
        ? await _generateFromText(apiKey, prompt, count)
        : await _generateFromReference(apiKey, prompt, count, reference);
    if (resp.statusCode != 200) {
      throw AzureOpenAiImageException(parseError(resp.body, resp.statusCode));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final images = extractImages(decoded);
    if (images.isNotEmpty) return images;

    final urls = extractImageUrls(decoded);
    if (urls.isEmpty) {
      throw AzureOpenAiImageException(
        'La respuesta no incluyó ninguna imagen. Puede ser el filtro de '
        'contenido: probá quitar el arma o suavizar los detalles.',
      );
    }
    return [
      for (final url in urls) (await _client.get(Uri.parse(url))).bodyBytes,
    ];
  }

  Future<http.Response> _generateFromText(
    String apiKey,
    String prompt,
    int count,
  ) => _client
      .post(
        generationsUri,
        headers: {'Content-Type': 'application/json', 'api-key': apiKey},
        body: jsonEncode(buildRequestBody(prompt, count)),
      )
      .timeout(const Duration(seconds: 120));

  /// `images/edits` va como multipart: la referencia es un archivo, no base64
  /// dentro de un JSON.
  Future<http.Response> _generateFromReference(
    String apiKey,
    String prompt,
    int count,
    Uint8List reference,
  ) async {
    final request = http.MultipartRequest('POST', editsUri)
      ..headers['api-key'] = apiKey
      ..fields['prompt'] = prompt
      ..fields['n'] = '$count'
      ..fields['size'] = '1024x1024'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          reference,
          filename: 'reference.png',
        ),
      );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 120));
    return http.Response.fromStream(streamed);
  }

  void close() => _client.close();
}
