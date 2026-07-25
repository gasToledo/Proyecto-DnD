import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../data/app_paths.dart';

/// Error de generación con mensaje legible.
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Cliente de la API de imágenes de Gemini (Google AI Studio / "Nano Banana").
/// La API key viaja en el header `x-goog-api-key`, nunca en la URL.
class GeminiImageService {
  final http.Client _client;
  final String model;
  GeminiImageService({http.Client? client, this.model = 'gemini-2.5-flash-image'})
      : _client = client ?? http.Client();

  Uri get _uri => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');

  /// Cuerpo de la petición. [reference] es una imagen de referencia opcional.
  /// Puro y testeable.
  static Map<String, dynamic> buildRequestBody(String prompt,
      {Uint8List? reference, String referenceMime = 'image/png'}) {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (reference != null)
        {
          'inlineData': {
            'mimeType': referenceMime,
            'data': base64Encode(reference),
          }
        },
    ];
    return {
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE'],
      },
    };
  }

  /// Extrae las imágenes (bytes) de una respuesta ya decodificada. Tolera
  /// `inlineData`/`inline_data`. Puro y testeable.
  static List<Uint8List> extractImages(Map<String, dynamic> json) {
    final images = <Uint8List>[];
    final candidates = json['candidates'];
    if (candidates is! List) return images;
    for (final cand in candidates) {
      final content = cand is Map ? cand['content'] : null;
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is! Map) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        final data = inline is Map ? inline['data'] : null;
        if (data is String && data.isNotEmpty) {
          images.add(base64Decode(data));
        }
      }
    }
    return images;
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
    return 'La API respondió con código $statusCode.';
  }

  /// Genera imágenes a partir de un prompt. Lanza [GeminiException] ante error
  /// de la API o [SocketException]/otros ante falta de conexión.
  Future<List<Uint8List>> generate({
    required String apiKey,
    required String prompt,
    Uint8List? reference,
  }) async {
    final resp = await _client.post(
      _uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode(buildRequestBody(prompt, reference: reference)),
    );
    if (resp.statusCode != 200) {
      throw GeminiException(parseError(resp.body, resp.statusCode));
    }
    final images = extractImages(jsonDecode(resp.body) as Map<String, dynamic>);
    if (images.isEmpty) {
      throw GeminiException('La respuesta no incluyó ninguna imagen.');
    }
    return images;
  }

  void close() => _client.close();
}

/// Guarda una imagen generada en disco y devuelve su ruta.
Future<String> savePortrait({
  required String portraitsRoot,
  required String characterId,
  required Uint8List bytes,
}) async {
  final safeCharacterId =
      requireSafePathSegment(characterId, label: 'id de personaje');
  final dir = Directory(p.join(portraitsRoot, safeCharacterId));
  await dir.create(recursive: true);
  final file =
      File(p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.png'));
  await file.writeAsBytes(bytes);
  return file.path;
}
