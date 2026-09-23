import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'api_models.dart';

/// Cliente HTTP usado por los servicios de lib/data/. Las peticiones van
/// al mismo origen por defecto; el navegador envía la cookie de sesión
/// HttpOnly sin exponer el token a este cliente.
class ApiClient {
  static const defaultRequestTimeout = Duration(seconds: 15);

  http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration requestTimeout;
  int _requestGeneration = 0;

  ApiClient({
    http.Client? client,
    this.baseUrl = '',
    this.requestTimeout = defaultRequestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Invalida las solicitudes que pertenezcan a un intento anterior.
  ///
  /// El transporte creado internamente se cierra para abortar las peticiones
  /// abiertas y se reemplaza por uno nuevo. Un cliente inyectado pertenece a
  /// su llamador, así que solo se invalida lógicamente y no se cierra.
  void cancelPendingRequests({bool recreateClient = true}) {
    _requestGeneration++;
    if (!_ownsClient) return;

    _client.close();
    if (recreateClient) {
      _client = http.Client();
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Uri get loginUri => _uri('/auth/login');

  Future<http.Response> _send(
    String method,
    String path, {
    Object? jsonBody,
  }) async {
    final generation = _requestGeneration;
    final request = http.Request(method, _uri(path));
    if (jsonBody != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    }
    try {
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(requestTimeout);

      if (generation != _requestGeneration) {
        throw const ApiException(null, 'La solicitud fue cancelada.');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw ApiException(response.statusCode, _errorMessageFrom(response));
    } on TimeoutException {
      throw const ApiException(
        null,
        'La conexión tardó demasiado en responder.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      if (generation != _requestGeneration) {
        throw const ApiException(null, 'La solicitud fue cancelada.');
      }
      throw const ApiException(null, 'No se pudo conectar con el servidor.');
    }
  }

  String _errorMessageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Cuerpo no-JSON (p.ej. un proxy intermedio): se cae al mensaje genérico.
    }
    return 'Error del servidor (${response.statusCode}).';
  }

  Map<String, dynamic> _json(http.Response response) =>
      (jsonDecode(response.body) as Map).cast<String, dynamic>();

  // --- Sesión ---------------------------------------------------------

  /// `null` si no hay sesión válida (401). Cualquier otro fallo (sin
  /// conexión, error del servidor) se propaga: la ausencia de sesión y la
  /// imposibilidad de comprobarla son estados distintos para quien arranca
  /// la app (ver capacidad `web-client`, "sin conexión" vs. "cuenta sin
  /// personajes").
  Future<AccountInfo?> currentAccount() async {
    try {
      final response = await _send('GET', '/api/me');
      return AccountInfo.fromJson(_json(response));
    } on ApiException catch (e) {
      if (e.isAuthError) return null;
      rethrow;
    }
  }

  /// Cierra la sesión de servidor y devuelve la URL a la que hay que navegar
  /// para cerrar también la del proveedor OIDC. `null` si el servidor no la
  /// pudo calcular: la sesión local igual quedó cerrada.
  Future<String?> logout() async {
    final response = await _send('POST', '/auth/logout');
    return _json(response)['logoutUrl'] as String?;
  }

  // --- Personajes -------------------------------------------------------

  Future<List<StoredCharacter>> listCharacters() async {
    final response = await _send('GET', '/api/characters');
    final list = _json(response)['characters'] as List;
    return [
      for (final json in list)
        StoredCharacter(
          character: Character.fromJson(
            ((json as Map)['character'] as Map).cast<String, dynamic>(),
          ),
          createdAt: DateTime.parse(json['createdAt'] as String),
        ),
    ];
  }

  /// Crea un personaje. Si el id ya existe en la cuenta, el servidor le
  /// asigna uno libre: el personaje devuelto es el que efectivamente quedó
  /// guardado.
  Future<Character> createCharacter(Character character) async {
    final response = await _send(
      'POST',
      '/api/characters',
      jsonBody: {'character': character.toJson()},
    );
    return Character.fromJson(
      (_json(response)['character'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> upsertCharacter(Character character) => _send(
    'PUT',
    '/api/characters/${Uri.encodeComponent(character.id)}',
    jsonBody: {'character': character.toJson()},
  );

  Future<void> deleteCharacter(String id) =>
      _send('DELETE', '/api/characters/${Uri.encodeComponent(id)}');

  // --- Homebrew -----------------------------------------------------

  Future<Map<String, List<Map<String, dynamic>>>> listHomebrew() async {
    final response = await _send('GET', '/api/homebrew');
    final content = _json(response)['content'] as Map;
    return {
      for (final entry in content.entries)
        entry.key as String: [
          for (final json in entry.value as List)
            (json as Map).cast<String, dynamic>(),
        ],
    };
  }

  Future<void> upsertHomebrew(String category, Map<String, dynamic> document) {
    final id = document['id'] as String;
    return _send(
      'PUT',
      '/api/homebrew/$category/${Uri.encodeComponent(id)}',
      jsonBody: document,
    );
  }

  Future<int> importHomebrew(
    Map<String, List<Map<String, dynamic>>> content,
  ) async {
    final response = await _send(
      'POST',
      '/api/homebrew/import',
      jsonBody: {'content': content},
    );
    return _json(response)['importedCount'] as int;
  }

  Future<void> deleteHomebrew(String category, String id) =>
      _send('DELETE', '/api/homebrew/$category/${Uri.encodeComponent(id)}');

  // --- Ajustes --------------------------------------------------------

  Future<Map<String, dynamic>?> loadSettingsDocument() async {
    final response = await _send('GET', '/api/settings');
    return _json(response)['settings'] as Map<String, dynamic>?;
  }

  Future<void> saveSettingsDocument(Map<String, dynamic> document) =>
      _send('PUT', '/api/settings', jsonBody: document);

  // --- Retratos -------------------------------------------------------

  Future<List<PortraitProviderInfo>> listPortraitProviders() async {
    final response = await _send('GET', '/api/portraits/providers');
    final list = _json(response)['providers'] as List;
    return [
      for (final json in list)
        PortraitProviderInfo.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<Uint8List>> generatePortraits({
    required String providerId,
    required String prompt,
    Uint8List? reference,
    int? count,
  }) async {
    final referenceBase64 = reference == null ? null : base64Encode(reference);
    final response = await _send(
      'POST',
      '/api/portraits/generate',
      jsonBody: {
        'providerId': providerId,
        'prompt': prompt,
        'referenceBase64': ?referenceBase64,
        'count': ?count,
      },
    );
    final images = _json(response)['images'] as List;
    return [for (final b64 in images) base64Decode(b64 as String)];
  }

  Future<String> savePortrait({
    required String characterId,
    required Uint8List bytes,
  }) async {
    final response = await _send(
      'POST',
      '/api/characters/${Uri.encodeComponent(characterId)}/portraits',
      jsonBody: {'bytes': base64Encode(bytes)},
    );
    return _json(response)['key'] as String;
  }

  /// Borra un retrato del almacén. Un 404 cuenta como hecho: la clave ya no
  /// resuelve, que es exactamente el estado que se buscaba, y la ficha tiene
  /// que poder soltarla igual en vez de quedar atada a un archivo que no está.
  Future<void> deletePortrait(String portraitKey) async {
    try {
      await _send('DELETE', '/api/portraits/$portraitKey');
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }

  /// Bytes de un retrato, para armar un respaldo ZIP en el navegador (ver
  /// `TransferService`). `null` si el retrato ya no existe: un respaldo no
  /// debe fallar por completo por una referencia huérfana (misma tolerancia
  /// que ya tenía `BackupBundleCodec.encode` en el escritorio).
  Future<Uint8List?> fetchPortraitBytes(String portraitKey) async {
    try {
      final response = await _send('GET', '/api/portraits/$portraitKey');
      return response.bodyBytes;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // --- Importación ------------------------------------------------------

  Future<ImportSummary> importBackup(Uint8List zipBytes) async {
    final response = await _send(
      'POST',
      '/api/import',
      jsonBody: {'bytes': base64Encode(zipBytes)},
    );
    final body = _json(response);
    return ImportSummary(
      charactersImported: body['charactersImported'] as int,
      portraitsImported: body['portraitsImported'] as int,
    );
  }

  // --- Campañas ---------------------------------------------------------

  Future<List<Campaign>> listCampaigns() async {
    final response = await _send('GET', '/api/campaigns');
    final list = _json(response)['campaigns'] as List;
    return [
      for (final json in list)
        Campaign.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// Devuelve la campaña efectivamente guardada: si el id ya estaba en uso, el
  /// servidor asigna uno libre en vez de sobrescribir.
  Future<Campaign> createCampaign(Campaign campaign) async {
    final response = await _send(
      'POST',
      '/api/campaigns',
      jsonBody: {'campaign': campaign.toJson()},
    );
    return Campaign.fromJson(
      (_json(response)['campaign'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> upsertCampaign(Campaign campaign) => _send(
    'PUT',
    '/api/campaigns/${Uri.encodeComponent(campaign.id)}',
    jsonBody: {'campaign': campaign.toJson()},
  );

  Future<void> deleteCampaign(String id) =>
      _send('DELETE', '/api/campaigns/${Uri.encodeComponent(id)}');

  /// Las fichas vinculadas a una campaña, leídas de su fila real: es lo que el
  /// jugador tiene ahora, no una copia del momento en que se vinculó.
  Future<List<CampaignMember>> listCampaignMembers(String campaignId) async {
    final response = await _send(
      'GET',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/members',
    );
    final list = _json(response)['members'] as List;
    return [
      for (final json in list)
        CampaignMember.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// Canjea el código que el jugador le pasó al DM. Un código que no sirve
  /// llega como [ApiException] con 404 y el mensaje del servidor.
  Future<CampaignMember> addCampaignMember({
    required String campaignId,
    required String code,
  }) async {
    final response = await _send(
      'POST',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/members',
      jsonBody: {'code': code},
    );
    return CampaignMember.fromJson(
      (_json(response)['member'] as Map).cast<String, dynamic>(),
    );
  }

  /// Corta el vínculo. Sirve para las dos puntas: el DM echando a un personaje
  /// y el jugador dejando de compartirlo.
  Future<void> deleteCampaignLink(String memberId) =>
      _send('DELETE', '/api/campaign-links/${Uri.encodeComponent(memberId)}');

  // --- Compartir un personaje propio ------------------------------------

  Future<ShareCode> shareCharacter(String characterId) async {
    final response = await _send(
      'POST',
      '/api/characters/${Uri.encodeComponent(characterId)}/share',
    );
    return ShareCode.fromJson(_json(response));
  }

  Future<List<CharacterShare>> listCharacterShares(String characterId) async {
    final response = await _send(
      'GET',
      '/api/characters/${Uri.encodeComponent(characterId)}/shares',
    );
    final list = _json(response)['shares'] as List;
    return [
      for (final json in list)
        CharacterShare.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// Las campañas de un personaje propio, con lo que su jugador puede ver:
  /// capítulos cerrados y batallas.
  ///
  /// Cuelga de `/api/characters/<id>/…` y no de `/api/campaigns/…` como el
  /// resto de las rutas de campaña: es el jugador quien pregunta, y el único
  /// nombre que tiene derecho a decir es el de su propio personaje.
  Future<List<PlayerCampaign>> listPlayerCampaigns(String characterId) async {
    final response = await _send(
      'GET',
      '/api/characters/${Uri.encodeComponent(characterId)}/campaigns',
    );
    final list = _json(response)['campaigns'] as List;
    return [
      for (final json in list)
        PlayerCampaign.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  // --- Capítulos ----------------------------------------------------------

  Future<List<Chapter>> listChapters(String campaignId) async {
    final response = await _send(
      'GET',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/chapters',
    );
    final list = _json(response)['chapters'] as List;
    return [
      for (final json in list)
        Chapter.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// Devuelve el capítulo efectivamente guardado: si el id ya estaba en uso, el
  /// servidor asigna uno libre en vez de sobrescribir.
  Future<Chapter> createChapter(String campaignId, Chapter chapter) async {
    final response = await _send(
      'POST',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/chapters',
      jsonBody: {'chapter': chapter.toJson()},
    );
    return Chapter.fromJson(
      (_json(response)['chapter'] as Map).cast<String, dynamic>(),
    );
  }

  /// Guarda los cambios de un capítulo. **No sirve para cerrarlo**: el servidor
  /// rechaza el estado `completed` por acá y lo dice en el mensaje, porque
  /// cerrar avisa a los jugadores y una ruta de edición repetiría los avisos.
  Future<void> upsertChapter(String campaignId, Chapter chapter) => _send(
    'PUT',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/chapters/'
        '${Uri.encodeComponent(chapter.id)}',
    jsonBody: {'chapter': chapter.toJson()},
  );

  Future<void> deleteChapter(String campaignId, String chapterId) => _send(
    'DELETE',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/chapters/'
        '${Uri.encodeComponent(chapterId)}',
  );

  /// Cierra el capítulo y le avisa a cada jugador de la mesa.
  Future<void> closeChapter(String campaignId, String chapterId) => _send(
    'POST',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/chapters/'
        '${Uri.encodeComponent(chapterId)}/close',
  );

  /// Le avisa al jugador que le concediste Inspiración Heroica.
  ///
  /// **La marca él en su ficha**: el DM no escribe la ficha de otra cuenta.
  /// Esto solo le deja la nota en la bandeja.
  Future<void> grantHeroicInspiration(String campaignId, String memberId) =>
      _send(
        'POST',
        '/api/campaigns/${Uri.encodeComponent(campaignId)}/members/'
            '${Uri.encodeComponent(memberId)}/heroic-inspiration',
      );

  /// El Cuaderno de campaña entero: las notas del DM y los combates ya
  /// cerrados.
  ///
  /// Viene en un solo viaje porque la pantalla los intercala dentro de cada
  /// capítulo: pedirlos por separado la obligaría a esperar dos respuestas para
  /// poder pintar uno solo.
  Future<Notebook> loadNotebook(String campaignId) async {
    final response = await _send(
      'GET',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/notebook',
    );
    final body = _json(response);
    return Notebook(
      notes: [
        for (final json in body['notes'] as List)
          Note.fromJson((json as Map).cast<String, dynamic>()),
      ],
      encounterLogs: [
        for (final json in body['encounterLogs'] as List)
          EncounterLog.fromJson((json as Map).cast<String, dynamic>()),
      ],
    );
  }

  /// Devuelve la nota efectivamente guardada: si el id ya estaba en uso, el
  /// servidor le asigna otro, igual que con los capítulos.
  Future<Note> createNote(String campaignId, Note note) async {
    final response = await _send(
      'POST',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/notes',
      jsonBody: {'note': note.toJson()},
    );
    return Note.fromJson(
      (_json(response)['note'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> updateNote(String campaignId, Note note) => _send(
    'PUT',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/notes/'
        '${Uri.encodeComponent(note.id)}',
    jsonBody: {'note': note.toJson()},
  );

  Future<void> deleteNote(String campaignId, String noteId) => _send(
    'DELETE',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/notes/'
        '${Uri.encodeComponent(noteId)}',
  );

  // --- Combate ------------------------------------------------------------

  /// El combate abierto de una campaña, o `null` si no hay ninguno. Sin
  /// controller propio: el estado del combate lo tiene la pantalla que lo usa,
  /// igual que `_CampaignDetail` con la mesa — son acciones discretas y
  /// contadas, no algo que se edite tecleando.
  Future<Encounter?> getEncounter(String campaignId) async {
    try {
      final response = await _send(
        'GET',
        '/api/campaigns/${Uri.encodeComponent(campaignId)}/encounter',
      );
      return Encounter.fromJson(
        (_json(response)['encounter'] as Map).cast<String, dynamic>(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Guarda el combate entero. No hay rutas finas de "avanzar turno" o "dañar
  /// monstruo": el cliente del DM manda el documento completo en cada acción.
  Future<void> saveEncounter(String campaignId, Encounter encounter) => _send(
    'PUT',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/encounter',
    jsonBody: {'encounter': encounter.toJson()},
  );

  /// Cierra el combate y archiva su log del lado del servidor.
  ///
  /// Con [discard] no queda registro: es para el combate que se abrió por
  /// error o se armó mal, que no tiene por qué figurar en la campaña como si
  /// se hubiera jugado.
  ///
  /// [deadNpcIds] son los PNJ que el DM marcó como muertos al terminar. El
  /// servidor los aplica en la misma transacción que el cierre, y solo si el
  /// combate se archiva: descartar no mata a nadie.
  Future<void> endEncounter(
    String campaignId, {
    bool discard = false,
    List<String> deadNpcIds = const [],
  }) => _send(
    'DELETE',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}/encounter'
        '${discard ? '?discard=true' : ''}',
    jsonBody: !discard && deadNpcIds.isNotEmpty
        ? {'deadNpcIds': deadNpcIds}
        : null,
  );

  // --- PNJ del Modo DM --------------------------------------------------

  Future<List<NpcEntry>> listNpcs() async {
    final response = await _send('GET', '/api/npcs');
    return [
      for (final json in _json(response)['npcs'] as List)
        NpcEntry.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// `null` si no existe o es de otra cuenta: los dos casos responden igual.
  Future<NpcEntry?> getNpc(String id) async {
    try {
      final response = await _send(
        'GET',
        '/api/npcs/${Uri.encodeComponent(id)}',
      );
      return NpcEntry.fromJson(_json(response));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Crea un PNJ. El id lo asigna el servidor: el que traiga [npc] se ignora.
  /// Un PNJ con ficha de personaje necesita [sheet].
  Future<NpcEntry> createNpc(Npc npc, {Character? sheet}) async {
    final response = await _send(
      'POST',
      '/api/npcs',
      jsonBody: {'npc': npc.toJson(), 'character': ?sheet?.toJson()},
    );
    return NpcEntry.fromJson(_json(response));
  }

  Future<Npc> updateNpc(Npc npc) async {
    final response = await _send(
      'PUT',
      '/api/npcs/${Uri.encodeComponent(npc.id)}',
      jsonBody: {'npc': npc.toJson()},
    );
    return Npc.fromJson(
      (_json(response)['npc'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> deleteNpc(String id) =>
      _send('DELETE', '/api/npcs/${Uri.encodeComponent(id)}');

  Future<String> saveNpcPortrait({
    required String npcId,
    required Uint8List bytes,
  }) async {
    final response = await _send(
      'POST',
      '/api/npcs/${Uri.encodeComponent(npcId)}/portraits',
      jsonBody: {'bytes': base64Encode(bytes)},
    );
    return _json(response)['key'] as String;
  }

  Future<NpcEntry> importNpc(Uint8List zipBytes, {String? campaignId}) async {
    final response = await _send(
      'POST',
      '/api/npcs/import',
      jsonBody: {'bytes': base64Encode(zipBytes), 'campaignId': ?campaignId},
    );
    return NpcEntry.fromJson(_json(response));
  }

  Future<List<CampaignNpcEntry>> listCampaignNpcs(String campaignId) async {
    final response = await _send(
      'GET',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}/npcs',
    );
    return [
      for (final json in _json(response)['npcs'] as List)
        CampaignNpcEntry.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  /// Suma un PNJ a una campaña o le cambia el estado. Sin [status], un vínculo
  /// nuevo nace vivo y uno existente queda como estaba. Devuelve el estado que
  /// quedó.
  Future<NpcStatus> linkCampaignNpc(
    String campaignId,
    String npcId, {
    NpcStatus? status,
  }) async {
    final response = await _send(
      'PUT',
      '/api/campaigns/${Uri.encodeComponent(campaignId)}'
          '/npcs/${Uri.encodeComponent(npcId)}',
      jsonBody: {'status': ?status?.toJson()},
    );
    return NpcStatus.fromJson(_json(response)['status'] as String?);
  }

  Future<void> unlinkCampaignNpc(String campaignId, String npcId) => _send(
    'DELETE',
    '/api/campaigns/${Uri.encodeComponent(campaignId)}'
        '/npcs/${Uri.encodeComponent(npcId)}',
  );

  /// El turno de un personaje propio, para el cartel de la ficha. Nunca
  /// revela el orden completo ni a los monstruos: es deliberadamente uno de
  /// los cuatro valores de [TurnStatus].
  Future<TurnStatus> turnStatus(String characterId) async {
    final response = await _send(
      'GET',
      '/api/characters/${Uri.encodeComponent(characterId)}/turn',
    );
    return TurnStatus.fromJson(_json(response)['turn'] as String?);
  }

  // --- Avisos -----------------------------------------------------------

  Future<List<UserEvent>> listUnseenEvents() async {
    final response = await _send('GET', '/api/events');
    final list = _json(response)['events'] as List;
    return [
      for (final json in list)
        UserEvent.fromJson((json as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> markEventsSeen(List<String> ids) =>
      _send('POST', '/api/events/seen', jsonBody: {'ids': ids});
}
