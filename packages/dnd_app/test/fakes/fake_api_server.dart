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

  /// Fecha de alta por id, como la columna `created_at` del servidor. Se fija
  /// al guardar por primera vez y no cambia al editar; el reloj avanza de a un
  /// milisegundo para que el orden por antigüedad sea determinista.
  final Map<String, DateTime> createdAt = {};
  int _clock = 0;

  void _stampCreated(String id) => createdAt.putIfAbsent(
    id,
    () => DateTime.fromMillisecondsSinceEpoch(_clock++),
  );
  final Map<String, Map<String, Map<String, dynamic>>> homebrew = {};
  Map<String, dynamic>? settings;
  final Map<String, Uint8List> portraits = {};
  List<Map<String, dynamic>> providers = [];
  int _generatedIdCounter = 0;

  /// Campañas que dirige la cuenta, y los vínculos con personajes.
  ///
  /// El doble modela una sola cuenta, así que no hay nada que aislar entre
  /// dueños: eso ya lo prueba `dnd_server` contra su propia batería. Acá
  /// interesa el contrato que ve el cliente.
  final Map<String, Campaign> campaigns = {};
  final Map<String, ({String campaignId, String characterId})> campaignMembers =
      {};

  /// Códigos emitidos y todavía sin canjear, por el id del personaje.
  final Map<String, String> shareCodes = {};

  /// Avisos pendientes, con la forma que devuelve `GET /api/events`. La prueba
  /// los siembra directamente.
  final List<Map<String, dynamic>> events = [];
  final Set<String> seenEventIds = {};

  int _memberCounter = 0;
  int _shareCounter = 0;

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
        'characters': [
          for (final c in characters.values)
            {
              'character': c.toJson(),
              // Un milisegundo por personaje, en orden de alta: alcanza para
              // que el orden por antigüedad sea determinista en una prueba.
              'createdAt':
                  (createdAt[c.id] ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .toUtc()
                      .toIso8601String(),
            },
        ],
      });
    }
    if (method == 'POST' && path == '/api/characters') {
      var character = _characterFrom(_body(request)['character']);
      if (characters.containsKey(character.id)) {
        final newId = 'generated-${_generatedIdCounter++}';
        character = Character.fromJson(character.toJson()..['id'] = newId);
      }
      characters[character.id] = character;
      _stampCreated(character.id);
      return _json({'character': character.toJson()});
    }
    if (method == 'PUT' && path.startsWith('/api/characters/')) {
      final id = _segment(path, '/api/characters/');
      final character = _characterFrom(_body(request)['character']);
      characters[id] = character;
      _stampCreated(id);
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

    final campaignResponse = _handleCampaigns(request, method, path);
    if (campaignResponse != null) return campaignResponse;

    return _json({'error': 'no encontrado'}, 404);
  }

  /// Rutas de campañas, vínculo y avisos. Reproduce el contrato observable del
  /// servidor: un código sirve una sola vez, un código desconocido responde
  /// 404, y un aviso se entrega hasta que se marca visto.
  http.Response? _handleCampaigns(
    http.Request request,
    String method,
    String path,
  ) {
    if (method == 'GET' && path == '/api/campaigns') {
      final all = campaigns.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return _json({
        'campaigns': [for (final c in all) c.toJson()],
      });
    }

    if (method == 'POST' && path == '/api/campaigns') {
      var campaign = Campaign.fromJson(
        (_body(request)['campaign'] as Map).cast<String, dynamic>(),
      );
      if (campaigns.containsKey(campaign.id)) {
        campaign = Campaign.fromJson(
          campaign.toJson()..['id'] = 'generated-${_generatedIdCounter++}',
        );
      }
      campaigns[campaign.id] = campaign;
      return _json({'campaign': campaign.toJson()});
    }

    if (method == 'PUT' && path.startsWith('/api/campaigns/')) {
      final campaign = Campaign.fromJson(
        (_body(request)['campaign'] as Map).cast<String, dynamic>(),
      );
      if (!campaigns.containsKey(campaign.id)) {
        return _json({'error': 'Campaña no encontrada.'}, 404);
      }
      campaigns[campaign.id] = campaign;
      return _json({'status': 'ok'});
    }

    if (method == 'DELETE' &&
        path.startsWith('/api/campaigns/') &&
        !path.contains('/members')) {
      final id = _segment(path, '/api/campaigns/');
      campaigns.remove(id);
      campaignMembers.removeWhere((_, m) => m.campaignId == id);
      return _json({'status': 'ok'});
    }

    if (method == 'GET' &&
        path.startsWith('/api/campaigns/') &&
        path.endsWith('/members')) {
      final id = path.split('/')[3];
      if (!campaigns.containsKey(id)) {
        return _json({'error': 'Campaña no encontrada.'}, 404);
      }
      return _json({
        'members': [
          for (final entry in campaignMembers.entries)
            if (entry.value.campaignId == id &&
                characters.containsKey(entry.value.characterId))
              {
                'memberId': entry.key,
                'character': characters[entry.value.characterId]!.toJson(),
              },
        ],
      });
    }

    if (method == 'POST' &&
        path.startsWith('/api/campaigns/') &&
        path.endsWith('/members')) {
      final campaignId = path.split('/')[3];
      if (!campaigns.containsKey(campaignId)) {
        return _json({'error': 'Campaña no encontrada.'}, 404);
      }
      final code = _body(request)['code'] as String;
      final characterId = shareCodes.remove(code.toUpperCase());
      if (characterId == null) {
        return _json({'error': 'Código inválido o vencido.'}, 404);
      }
      final memberId =
          '00000000-0000-4000-8000-${(_memberCounter++).toString().padLeft(12, '0')}';
      campaignMembers[memberId] = (
        campaignId: campaignId,
        characterId: characterId,
      );
      return _json({
        'member': {
          'memberId': memberId,
          if (characters.containsKey(characterId))
            'character': characters[characterId]!.toJson(),
        },
      });
    }

    if (method == 'DELETE' && path.startsWith('/api/campaign-links/')) {
      final memberId = _segment(path, '/api/campaign-links/');
      if (campaignMembers.remove(memberId) == null) {
        return _json({'error': 'Vínculo no encontrado.'}, 404);
      }
      return _json({'status': 'ok'});
    }

    if (method == 'POST' &&
        path.startsWith('/api/characters/') &&
        path.endsWith('/share')) {
      final characterId = path.split('/')[3];
      if (!characters.containsKey(characterId)) {
        return _json({'error': 'Personaje no encontrado.'}, 404);
      }
      final code = 'CODE-${(_shareCounter++).toString().padLeft(4, '0')}';
      shareCodes[code] = characterId;
      return _json({
        'code': code,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 24))
            .toIso8601String(),
      });
    }

    if (method == 'GET' &&
        path.startsWith('/api/characters/') &&
        path.endsWith('/shares')) {
      final characterId = path.split('/')[3];
      if (!characters.containsKey(characterId)) {
        return _json({'error': 'Personaje no encontrado.'}, 404);
      }
      return _json({
        'shares': [
          for (final entry in campaignMembers.entries)
            if (entry.value.characterId == characterId)
              {
                'memberId': entry.key,
                'campaignName': campaigns[entry.value.campaignId]?.name ?? '',
              },
        ],
      });
    }

    if (method == 'GET' && path == '/api/events') {
      return _json({
        'events': [
          for (final event in events)
            if (!seenEventIds.contains(event['id'])) event,
        ],
      });
    }

    if (method == 'POST' && path == '/api/events/seen') {
      seenEventIds.addAll((_body(request)['ids'] as List).cast<String>());
      return _json({'status': 'ok'});
    }

    return null;
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
