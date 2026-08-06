import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Doble en memoria del servidor, para probar `ApiClient` y todo lo que lo
/// usa (`CharactersController`, `HomebrewStore`, `SettingsService`,
/// `TransferService`) sin un servidor real. Reproduce el contrato
/// observable de cada endpoint que ya prueba `dnd_server` por su cuenta
/// (reasignación de id ante colisión, agrupación por categoría, etc.), no su
/// implementación.
class FakeApiServer {
  final Map<String, Character> characters = {};
  final Map<String, Map<String, Map<String, dynamic>>> homebrew = {};
  Map<String, dynamic>? settings;
  final Map<String, Uint8List> portraits = {};
  List<Map<String, dynamic>> providers = [];
  int _generatedIdCounter = 0;

  bool authenticated = true;

  /// Perfil que devuelve `/api/me`. Ambos pueden ser null: el proveedor OIDC
  /// no siempre manda nombre o correo.
  String? accountName = 'Ada Lovelace';
  String? accountEmail = 'ada@example.org';

  /// URL de cierre de sesión del proveedor que devuelve `/auth/logout`, y
  /// cuántas veces se llamó.
  String? logoutUrl = 'https://idp.example/end_session';
  int logoutCalls = 0;

  /// Si no es null, toda llamada lanza esto (simula falta de conexión).
  Object? failWith;

  late final http.Client client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    if (failWith != null) throw failWith!;
    final path = request.url.path;
    final method = request.method;

    if (path != '/auth/login' && !authenticated) {
      return _json({'error': 'No autenticado.'}, 401);
    }

    if (method == 'GET' && path == '/api/me') {
      return _json({
        'userId': 'fake-user',
        'name': accountName,
        'email': accountEmail,
        'pictureUrl': null,
      });
    }

    if (method == 'POST' && path == '/auth/logout') {
      logoutCalls++;
      authenticated = false;
      return _json({'status': 'ok', 'logoutUrl': logoutUrl});
    }

    if (method == 'GET' && path == '/api/characters') {
      return _json({
        'characters': [for (final c in characters.values) c.toJson()],
      });
    }
    if (method == 'POST' && path == '/api/characters') {
      var character = _characterFrom(_body(request)['character']);
      if (characters.containsKey(character.id)) {
        final newId = 'generated-${_generatedIdCounter++}';
        character = Character.fromJson(character.toJson()..['id'] = newId);
      }
      characters[character.id] = character;
      return _json({'character': character.toJson()});
    }
    if (method == 'PUT' && path.startsWith('/api/characters/')) {
      final id = _segment(path, '/api/characters/');
      final character = _characterFrom(_body(request)['character']);
      characters[id] = character;
      return _json({'status': 'ok'});
    }
    if (method == 'DELETE' && path.startsWith('/api/characters/')) {
      final id = _segment(path, '/api/characters/');
      characters.remove(id);
      return _json({'status': 'ok'});
    }

    if (method == 'GET' && path == '/api/homebrew') {
      return _json({
        'content': {
          for (final entry in homebrew.entries)
            entry.key: entry.value.values.toList(),
        },
      });
    }
    if (method == 'PUT' && path.startsWith('/api/homebrew/')) {
      final rest = path.substring('/api/homebrew/'.length).split('/');
      final category = rest[0];
      final id = rest[1];
      (homebrew[category] ??= {})[id] = _body(request);
      return _json({'status': 'ok'});
    }
    if (method == 'DELETE' && path.startsWith('/api/homebrew/')) {
      final rest = path.substring('/api/homebrew/'.length).split('/');
      homebrew[rest[0]]?.remove(rest[1]);
      return _json({'status': 'ok'});
    }

    if (method == 'GET' && path == '/api/settings') {
      return _json({'settings': settings});
    }
    if (method == 'PUT' && path == '/api/settings') {
      settings = _body(request);
      return _json({'status': 'ok'});
    }

    if (method == 'GET' && path == '/api/portraits/providers') {
      return _json({'providers': providers});
    }
    if (method == 'POST' && path == '/api/portraits/generate') {
      return _json({'images': <String>[]});
    }
    if (method == 'POST' &&
        path.startsWith('/api/characters/') &&
        path.endsWith('/portraits')) {
      final characterId = _segment(
        path,
        '/api/characters/',
      ).replaceAll('/portraits', '');
      final bytes = base64Decode(_body(request)['bytes'] as String);
      final key = '$characterId/${portraits.length}.png';
      portraits[key] = bytes;
      return _json({'key': key});
    }
    if (method == 'GET' && path.startsWith('/api/portraits/')) {
      final key = _segment(path, '/api/portraits/');
      final bytes = portraits[key];
      if (bytes == null) return _json({'error': 'no encontrado'}, 404);
      return http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'image/png'},
      );
    }

    if (method == 'POST' && path == '/api/import') {
      return _json({'charactersImported': 0, 'portraitsImported': 0});
    }

    return _json({'error': 'no encontrado'}, 404);
  }

  Character _characterFrom(Object? json) =>
      Character.fromJson((json as Map).cast<String, dynamic>());

  Map<String, dynamic> _body(http.Request request) =>
      (jsonDecode(request.body) as Map).cast<String, dynamic>();

  String _segment(String path, String prefix) =>
      Uri.decodeComponent(path.substring(prefix.length));

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}
