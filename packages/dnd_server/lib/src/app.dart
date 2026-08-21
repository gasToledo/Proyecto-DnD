import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'ai/portrait_generation_service.dart';
import 'auth/auth_middleware.dart';
import 'auth/oidc_service.dart';
import 'auth/session_cookie.dart';
import 'auth/session_store.dart';
import 'import/backup_bundle.dart';
import 'import/import_service.dart';
import 'portraits/portrait_blob_store.dart';
import 'repositories/campaign_repository.dart';
import 'repositories/chapter_repository.dart';
import 'repositories/character_repository.dart';
import 'repositories/encounter_repository.dart';
import 'repositories/event_repository.dart';
import 'repositories/homebrew_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/settings_repository.dart';
import 'util/safe_path.dart';

/// Categorías de homebrew válidas: la misma partición que
/// `ContentRepository.fromJsonPacks` y que ya usa `HomebrewRepository`.
const _homebrewCategories = {
  'weapons',
  'armor',
  'items',
  'feats',
  'races',
  'backgrounds',
  'spells',
};

/// Ejecuta la importación ya decodificada para [userId]. Se recibe como
/// función (no como `Pool` concreto) por la misma razón que [AuthDependencies]:
/// el enrutado se prueba con un doble, sin una base de datos real.
typedef ImportBackupFn =
    Future<ImportResult> Function({
      required String userId,
      required BackupBundle bundle,
    });

/// Dependencias de autenticación que el router necesita, ya resueltas contra
/// OIDC y la base de datos. Se reciben como funciones (no como `Pool` u
/// `OidcService` concretos) para que el enrutado se pueda probar con dobles,
/// sin una base de datos ni un proveedor OIDC reales.
class AuthDependencies {
  /// Token de la cookie → id de cuenta dueña de la sesión, o `null` si no
  /// existe o expiró.
  final Future<String?> Function(String token) resolveUserId;

  /// Arranca un login nuevo y devuelve a dónde redirigir al navegador.
  final Uri Function() beginLogin;

  /// Completa el login: intercambia el código, verifica la aserción y
  /// devuelve la identidad OIDC verificada. Lanza si la aserción no es válida
  /// o el `state` no se reconoce.
  final Future<OidcIdentity> Function(Map<String, String> callbackParams)
  completeLogin;

  /// Mapea la identidad OIDC verificada a una cuenta (creándola si hace falta)
  /// y abre una sesión de servidor. Devuelve el token de la cookie.
  final Future<String> Function(OidcIdentity identity) createSessionForIdentity;

  /// Perfil cacheado de la sesión, o `null` si el token no vale. Es lo que
  /// `/api/me` muestra como "la cuenta con la que entraste".
  final Future<SessionProfile?> Function(String token) sessionProfile;

  final Future<void> Function(String token) invalidateSession;

  const AuthDependencies({
    required this.resolveUserId,
    required this.beginLogin,
    required this.completeLogin,
    required this.createSessionForIdentity,
    required this.sessionProfile,
    required this.invalidateSession,
  });
}

/// Arma el handler raíz de la API: enrutado más los middleware de logging y
/// de captura de errores no manejados. Separado de `bin/server.dart` para que
/// las pruebas puedan invocar el handler directamente, sin levantar un socket.
Handler buildHandler({
  required AuthDependencies auth,
  required PortraitBlobStore portraits,
  required PortraitGenerationService generation,
  required ImportBackupFn importBackup,
  required CharacterRepository characters,
  required CampaignRepository campaigns,
  required ChapterRepository chapters,
  required NoteRepository notes,
  required EncounterRepository encounters,
  required EventRepository events,
  required HomebrewRepository homebrew,
  required SettingsRepository settings,

  /// Sirve el build web (`flutter build web`) para todo lo que el enrutado de
  /// arriba no reconozca. `null` lo deshabilita (pruebas, o correr la API
  /// suelta): las rutas de arriba siguen funcionando igual, simplemente no
  /// hay nada detrás para el resto de las peticiones.
  Handler? webStaticHandler,
}) {
  final router = Router()
    ..get('/health', _healthHandler)
    ..get('/auth/login', (request) => _loginHandler(request, auth))
    ..get('/auth/callback', (request) => _callbackHandler(request, auth))
    ..post('/auth/logout', (request) => _logoutHandler(request, auth))
    ..get(
      '/api/me',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _meHandler(request, auth)),
    )
    ..get(
      '/api/characters',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _listCharactersHandler(request, characters)),
    )
    ..post(
      '/api/characters',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _createCharacterHandler(request, characters),
          ),
    )
    ..put(
      '/api/characters/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _upsertCharacterHandler(request, characters),
          ),
    )
    ..delete(
      '/api/characters/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _deleteCharacterHandler(request, characters, campaigns, events),
          ),
    )
    ..post(
      '/api/characters/<id>/share',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _shareCharacterHandler(request, characters, campaigns),
          ),
    )
    ..get(
      '/api/characters/<id>/shares',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _listCharacterSharesHandler(request, characters, campaigns),
          ),
    )
    ..get(
      '/api/characters/<id>/campaigns',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _listPlayerCampaignsHandler(
              request,
              characters,
              campaigns,
              chapters,
              encounters,
            ),
          ),
    )
    ..get(
      '/api/campaigns',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _listCampaignsHandler(request, campaigns)),
    )
    ..post(
      '/api/campaigns',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _createCampaignHandler(request, campaigns)),
    )
    ..put(
      '/api/campaigns/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _upsertCampaignHandler(request, campaigns)),
    )
    ..delete(
      '/api/campaigns/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _deleteCampaignHandler(request, campaigns)),
    )
    ..get(
      '/api/campaigns/<id>/members',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _listCampaignMembersHandler(request, campaigns),
          ),
    )
    ..post(
      '/api/campaigns/<id>/members',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _redeemShareCodeHandler(request, campaigns, characters, events),
          ),
    )
    ..get(
      '/api/campaigns/<campaignId>/members/<memberId>/portrait/<fileName>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _memberPortraitHandler(request, campaigns, portraits),
          ),
    )
    ..delete(
      '/api/campaign-links/<memberId>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _deleteCampaignLinkHandler(
              request,
              campaigns,
              characters,
              events,
            ),
          ),
    )
    ..get(
      '/api/campaigns/<id>/chapters',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _listChaptersHandler(request, campaigns, chapters),
          ),
    )
    ..post(
      '/api/campaigns/<id>/chapters',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _createChapterHandler(request, campaigns, chapters),
          ),
    )
    ..put(
      '/api/campaigns/<id>/chapters/<chapterId>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _upsertChapterHandler(request, campaigns, chapters),
          ),
    )
    ..delete(
      '/api/campaigns/<id>/chapters/<chapterId>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _deleteChapterHandler(request, campaigns, chapters),
          ),
    )
    ..post(
      '/api/campaigns/<id>/chapters/<chapterId>/close',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _closeChapterHandler(request, campaigns, chapters, events),
          ),
    )
    ..get(
      '/api/campaigns/<id>/notebook',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _listNotebookHandler(request, campaigns, notes, encounters),
          ),
    )
    ..post(
      '/api/campaigns/<id>/notes',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _createNoteHandler(request, campaigns, chapters, notes),
          ),
    )
    ..put(
      '/api/campaigns/<id>/notes/<noteId>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _upsertNoteHandler(request, campaigns, chapters, notes),
          ),
    )
    ..delete(
      '/api/campaigns/<id>/notes/<noteId>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _deleteNoteHandler(request, campaigns, notes),
          ),
    )
    ..get(
      '/api/campaigns/<id>/encounter',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _getEncounterHandler(request, campaigns, encounters),
          ),
    )
    ..put(
      '/api/campaigns/<id>/encounter',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _saveEncounterHandler(request, campaigns, encounters),
          ),
    )
    ..delete(
      '/api/campaigns/<id>/encounter',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) =>
                _endEncounterHandler(request, campaigns, chapters, encounters),
          ),
    )
    ..get(
      '/api/characters/<id>/turn',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _turnHandler(request, characters, encounters),
          ),
    )
    ..get(
      '/api/events',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _listEventsHandler(request, events)),
    )
    ..post(
      '/api/events/seen',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _markEventsSeenHandler(request, events)),
    )
    ..get(
      '/api/homebrew',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _listHomebrewHandler(request, homebrew)),
    )
    ..put(
      '/api/homebrew/<category>/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _upsertHomebrewHandler(request, homebrew)),
    )
    ..delete(
      '/api/homebrew/<category>/<id>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _deleteHomebrewHandler(request, homebrew)),
    )
    ..get(
      '/api/settings',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _getSettingsHandler(request, settings)),
    )
    ..put(
      '/api/settings',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _saveSettingsHandler(request, settings)),
    )
    ..get(
      '/api/portraits/<characterId>/<fileName>',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _portraitHandler(request, portraits)),
    )
    ..get(
      '/api/portraits/providers',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _portraitProvidersHandler(generation)),
    )
    ..post(
      '/api/portraits/generate',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler(
            (request) => _generatePortraitHandler(request, generation),
          ),
    )
    ..post(
      '/api/characters/<characterId>/portraits',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _createPortraitHandler(request, portraits)),
    )
    ..post(
      '/api/import',
      Pipeline()
          .addMiddleware(requireSession(auth.resolveUserId))
          .addHandler((request) => _importHandler(request, importBackup)),
    );

  // El router va primero: solo cae al build web estático cuando no reconoce
  // la ruta (404), así que `/api/*` y `/auth/*` nunca pueden resolverse por
  // accidente contra un archivo del cliente.
  final rootHandler = webStaticHandler == null
      ? router.call
      : Cascade().add(router.call).add(webStaticHandler).handler;

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(errorHandlingMiddleware)
      .addHandler(rootHandler);
}

Response _healthHandler(Request request) => Response.ok(
  jsonEncode({'status': 'ok'}),
  headers: {'content-type': 'application/json'},
);

/// Redirige al proveedor OIDC para iniciar sesión. Nunca muestra ninguna
/// ficha: solo arranca el intercambio.
Response _loginHandler(Request request, AuthDependencies auth) =>
    Response.found(auth.beginLogin());

/// Recibe la vuelta del proveedor OIDC, intercambia el código, verifica la
/// aserción y abre una sesión de servidor. Una aserción inválida (emisor,
/// firma, nonce) o un `state` no reconocido MUST NOT abrir sesión: se
/// responde 401 y la petición se trata como no autenticada, nunca se asume
/// identidad sin verificarla.
Future<Response> _callbackHandler(
  Request request,
  AuthDependencies auth,
) async {
  final OidcIdentity identity;
  try {
    identity = await auth.completeLogin(request.requestedUri.queryParameters);
  } catch (error) {
    return Response(
      401,
      body: jsonEncode({'error': 'No se pudo completar el login.'}),
      headers: {'content-type': 'application/json'},
    );
  }

  final token = await auth.createSessionForIdentity(identity);
  return Response.found(
    '/',
    headers: {
      'set-cookie': buildSessionCookieHeader(
        token,
        maxAge: const Duration(hours: 12),
      ),
    },
  );
}

/// Invalida la sesión de servidor y borra la cookie. Una sesión ya cerrada
/// (o inexistente) responde igual: cerrar sesión dos veces no es un error.
///
/// Devuelve además `logoutUrl`: cerrar solo la sesión local no alcanza, porque
/// la cookie de SSO del proveedor sigue viva y el próximo `/auth/login`
/// volvería a entrar sin pedir credenciales. El cliente navega a esa URL para
/// terminar también la sesión del proveedor. Es `null` si no se pudo calcular
/// (sesión sin perfil, o proveedor sin `end_session_endpoint`): entonces la
/// sesión local igual quedó cerrada.
///
/// Sigue siendo POST: cerrar la sesión de alguien no puede ser el efecto de
/// hacerle abrir un enlace.
Future<Response> _logoutHandler(Request request, AuthDependencies auth) async {
  final token = readSessionToken(request.headers['cookie']);
  String? logoutUrl;
  if (token != null) {
    // El perfil se lee antes de invalidar: después la fila ya no está.
    logoutUrl = (await auth.sessionProfile(token))?.logoutUrl;
    await auth.invalidateSession(token);
  }
  return Response.ok(
    jsonEncode({'status': 'ok', 'logoutUrl': logoutUrl}),
    headers: {
      'content-type': 'application/json',
      'set-cookie': buildExpiredSessionCookieHeader(),
    },
  );
}

/// La cuenta de la sesión en curso. El `userId` es el id interno; el resto es
/// lo que el proveedor OIDC afirmó al abrir la sesión, y puede venir en `null`
/// (ver [SessionProfile]).
Future<Response> _meHandler(Request request, AuthDependencies auth) async {
  final token = readSessionToken(request.headers['cookie']);
  final profile = token == null ? null : await auth.sessionProfile(token);
  return Response.ok(
    jsonEncode({
      'userId': request.userId,
      'name': profile?.name,
      'email': profile?.email,
      'pictureUrl': profile?.pictureUrl,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Response _jsonOk(Map<String, dynamic> body) => Response.ok(
  jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

/// Convierte el JSON recibido de un cliente en un [Character]. Cualquier
/// fallo de forma (campos faltantes, tipos incorrectos) se homologa a
/// [FormatException] para que el cliente reciba 400 en vez de un 500
/// genérico; [UnsupportedDataVersionException] se deja pasar tal cual, para
/// que [errorHandlingMiddleware] la traduzca a su propio 400 sin perder el
/// mensaje sobre la versión.
Character _characterFromRequestJson(Map<String, dynamic> json) {
  try {
    return Character.fromJson(json);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('Personaje inválido: $error');
  }
}

Future<Map<String, dynamic>> _readJsonBody(Request request) async {
  final decoded = jsonDecode(await request.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Se esperaba un objeto JSON.');
  }
  return decoded;
}

Future<Response> _listCharactersHandler(
  Request request,
  CharacterRepository characters,
) async {
  final all = await characters.listForUser(request.userId);
  return _jsonOk({
    'characters': [
      for (final stored in all)
        {
          'character': stored.character.toJson(),
          'createdAt': stored.createdAt.toUtc().toIso8601String(),
        },
    ],
  });
}

/// Crea un personaje nuevo. Si el id ya existe en la cuenta, se guarda con
/// uno libre en su lugar (ver capacidad `character-api`): el personaje
/// devuelto es el que efectivamente quedó guardado, no necesariamente el que
/// mandó el cliente.
Future<Response> _createCharacterHandler(
  Request request,
  CharacterRepository characters,
) async {
  final body = await _readJsonBody(request);
  final requested = body['character'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "character".');
  }
  final character = _characterFromRequestJson(requested);
  requireSafePathSegment(character.id, label: 'id de personaje');
  final stored = await characters.create(request.userId, character);
  return _jsonOk({'character': stored.toJson()});
}

/// Actualiza un personaje cuyo id ya se considera asignado a la cuenta: a
/// diferencia de la creación, no reasigna id ante colisión porque acá la
/// colisión es justamente "es el mismo documento" (ver
/// `CharacterRepository.upsert`).
Future<Response> _upsertCharacterHandler(
  Request request,
  CharacterRepository characters,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  final body = await _readJsonBody(request);
  final requested = body['character'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "character".');
  }
  final character = _characterFromRequestJson(requested);
  if (character.id != id) {
    throw const FormatException('El id del personaje no coincide con la ruta.');
  }
  await characters.upsert(request.userId, character);
  return _jsonOk({'status': 'ok'});
}

/// Borra un personaje de la cuenta y avisa a los DM que lo tenían en su mesa.
///
/// El aviso se arma **antes** de borrar: la clave foránea se lleva los vínculos
/// en cascada, así que después ya no hay forma de saber a quién avisarle. Sin
/// esto, el personaje desaparecería del panel del DM sin ninguna explicación.
Future<Response> _deleteCharacterHandler(
  Request request,
  CharacterRepository characters,
  CampaignRepository campaigns,
  EventRepository events,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  final character = await characters.find(request.userId, id);
  final shares = character == null
      ? const <CharacterShare>[]
      : await campaigns.listSharesForCharacter(
          ownerUserId: request.userId,
          characterId: id,
        );

  await characters.delete(request.userId, id);

  for (final share in shares) {
    await events.append(share.dmUserId, 'character_deleted_by_owner', {
      'characterName': character!.name,
      'campaignName': share.campaignName,
    });
  }
  return _jsonOk({'status': 'ok'});
}

// --- Campañas y vínculo con personajes ajenos ---
//
// Es la única parte del servidor donde una cuenta alcanza datos de otra. Dos
// reglas gobiernan todo lo que sigue:
//
// 1. El acceso nace siempre de una acción del dueño del personaje: sin un
//    vínculo creado a partir de un código que él generó, no hay nada que ver.
// 2. Lo ajeno y lo inexistente responden igual (404, mensajes inespecíficos).
//    Distinguirlos convertiría estas rutas en una forma de averiguar qué
//    personajes existen en otras cuentas.

Response _notFound(String message) => Response.notFound(
  jsonEncode({'error': message}),
  headers: {'content-type': 'application/json'},
);

Campaign _campaignFromRequestJson(Map<String, dynamic> json) {
  try {
    return Campaign.fromJson(json);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('Campaña inválida: $error');
  }
}

Future<Response> _listCampaignsHandler(
  Request request,
  CampaignRepository campaigns,
) async {
  final all = await campaigns.listForDm(request.userId);
  return _jsonOk({
    'campaigns': [for (final campaign in all) campaign.toJson()],
  });
}

Future<Response> _createCampaignHandler(
  Request request,
  CampaignRepository campaigns,
) async {
  final body = await _readJsonBody(request);
  final requested = body['campaign'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "campaign".');
  }
  final campaign = _campaignFromRequestJson(requested);
  requireSafePathSegment(campaign.id, label: 'id de campaña');
  final stored = await campaigns.create(request.userId, campaign);
  return _jsonOk({'campaign': stored.toJson()});
}

Future<Response> _upsertCampaignHandler(
  Request request,
  CampaignRepository campaigns,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final body = await _readJsonBody(request);
  final requested = body['campaign'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "campaign".');
  }
  final campaign = _campaignFromRequestJson(requested);
  if (campaign.id != id) {
    throw const FormatException('El id de la campaña no coincide con la ruta.');
  }
  // Editar solo lo propio: sin esta comprobación, el `upsert` crearía la
  // campaña ajena dentro de la cuenta que la pidió.
  if (await campaigns.find(request.userId, id) == null) {
    return _notFound('Campaña no encontrada.');
  }
  await campaigns.upsert(request.userId, campaign);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _deleteCampaignHandler(
  Request request,
  CampaignRepository campaigns,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  await campaigns.delete(request.userId, id);
  return _jsonOk({'status': 'ok'});
}

/// Las fichas que los jugadores compartieron con esta campaña.
///
/// Se leen de la fila real del personaje en cada llamada: el vínculo es una
/// referencia, no una copia, así que el DM siempre ve el estado actual.
Future<Response> _listCampaignMembersHandler(
  Request request,
  CampaignRepository campaigns,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final members = await campaigns.listMembers(request.userId, campaignId);
  return _jsonOk({
    'members': [
      for (final member in members)
        {'memberId': member.memberId, 'character': member.character.toJson()},
    ],
  });
}

/// Canjea el código que el jugador le pasó al DM.
///
/// Un código que no sirve responde siempre lo mismo, sin decir si no existió,
/// si venció o si ya se usó: los tres casos son "ese código no vale" y
/// distinguirlos solo ayudaría a quien esté probando códigos.
Future<Response> _redeemShareCodeHandler(
  Request request,
  CampaignRepository campaigns,
  CharacterRepository characters,
  EventRepository events,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final body = await _readJsonBody(request);
  final code = body['code'];
  if (code is! String || code.isEmpty) {
    throw const FormatException('Falta "code".');
  }

  final campaign = await campaigns.find(request.userId, campaignId);
  if (campaign == null) return _notFound('Campaña no encontrada.');

  final link = await campaigns.redeemShareCode(
    dmUserId: request.userId,
    campaignId: campaignId,
    code: code,
  );
  if (link == null) return _notFound('Código inválido o vencido.');

  final character = await characters.find(link.ownerUserId, link.characterId);
  await events.append(link.ownerUserId, 'character_linked', {
    'characterName': character?.name ?? '',
    'campaignName': campaign.name,
  });

  return _jsonOk({
    'member': {
      'memberId': link.memberId,
      if (character != null) 'character': character.toJson(),
    },
  });
}

/// Sirve el retrato de un personaje vinculado.
///
/// El retrato se lee del almacenamiento de su **dueño**, no del que mira, y
/// solo después de comprobar que el vínculo existe y es de esta campaña. La
/// ruta propia (`_portraitHandler`) queda intacta: deriva la propiedad de la
/// sesión y no tiene por qué aprender sobre campañas.
Future<Response> _memberPortraitHandler(
  Request request,
  CampaignRepository campaigns,
  PortraitBlobStore portraits,
) async {
  final campaignId = requireSafePathSegment(
    request.params['campaignId']!,
    label: 'id de campaña',
  );
  final memberId = request.params['memberId']!;
  if (!isUuid(memberId)) return _notFound('Retrato no encontrado.');

  final link = await campaigns.findMemberLink(
    dmUserId: request.userId,
    campaignId: campaignId,
    memberId: memberId,
  );
  if (link == null) return _notFound('Retrato no encontrado.');

  final width = int.tryParse(request.url.queryParameters['w'] ?? '');
  final blob = await portraits.read(
    userId: link.ownerUserId,
    portraitKey: '${link.characterId}/${request.params['fileName']}',
    width: width != null && width > 0 ? width : null,
  );
  if (blob == null) return _notFound('Retrato no encontrado.');

  return Response.ok(
    blob.bytes,
    headers: {
      'content-type': blob.contentType,
      'cache-control': 'private, max-age=31536000, immutable',
    },
  );
}

/// Emite un código para compartir un personaje propio.
Future<Response> _shareCharacterHandler(
  Request request,
  CharacterRepository characters,
  CampaignRepository campaigns,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  if (await characters.find(request.userId, id) == null) {
    return _notFound('Personaje no encontrado.');
  }
  final code = await campaigns.createShareCode(
    ownerUserId: request.userId,
    characterId: id,
  );
  return _jsonOk({
    'code': code,
    'expiresAt': DateTime.now()
        .toUtc()
        .add(PostgresCampaignRepository.defaultShareTtl)
        .toIso8601String(),
  });
}

/// En qué campañas está metido un personaje propio.
///
/// Se devuelve solo el nombre de la campaña: es lo que el jugador necesita para
/// saber con quién la compartió y decidir si sigue haciéndolo.
Future<Response> _listCharacterSharesHandler(
  Request request,
  CharacterRepository characters,
  CampaignRepository campaigns,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  if (await characters.find(request.userId, id) == null) {
    return _notFound('Personaje no encontrado.');
  }
  final shares = await campaigns.listSharesForCharacter(
    ownerUserId: request.userId,
    characterId: id,
  );
  return _jsonOk({
    'shares': [
      for (final share in shares)
        {'memberId': share.memberId, 'campaignName': share.campaignName},
    ],
  });
}

/// Un capítulo tal como puede verlo el jugador: **sin la descripción**.
///
/// No es una omisión defensiva de más. `Chapter.summary` es lo que el DM
/// escribe adentro del capítulo, y su propia documentación dice que no la ve
/// ningún jugador ni siquiera con el capítulo ya cerrado. Mandarla acá sería
/// publicar las notas del DM en la ficha de cada jugador de la mesa.
///
/// `Chapter.fromJson` la default-ea a vacío, así que del otro lado el campo
/// llega en blanco sin que nadie tenga que acordarse de limpiarlo.
Map<String, dynamic> _playerChapterJson(Chapter chapter) =>
    chapter.toJson()..remove('summary');

/// La campaña vista desde la ficha del jugador: en qué mesa está su personaje,
/// qué capítulos se cerraron y qué batallas se pelearon.
///
/// **Es la única ruta del proyecto por la que un jugador lee una campaña.**
/// Sigue el molde de las otras dos que nacen de su lado (`/shares` y `/turn`):
/// cuelga de `/api/characters/<id>/…` y no de `/api/campaigns/<id>/…`, porque
/// un jugador no tiene por qué nombrar un id de campaña — una ruta que se lo
/// aceptara sería una forma de tantear cuáles existen.
///
/// **De dónde sale la autorización.** `listSharesForCharacter` filtra por
/// `owner_user_id = quien pide`, así que cada fila que devuelve *es* la prueba
/// de que este jugador está vinculado a esa campaña. Recién con el `dmUserId`
/// que sale de ahí se consultan los cuatro repositorios de abajo.
///
/// Ojo con eso, que es la única vez en todo el servidor que pasa: a esos
/// repositorios se les entrega un `dmUserId` **que no es de quien hace la
/// petición**. Está bien porque salió de una fila ya autorizada, pero invierte
/// el supuesto de su contrato («la autorización va adentro del `WHERE` con
/// `dm_user_id`»). Si alguna vez este handler deja de arrancar por
/// `listSharesForCharacter`, deja de estar bien.
///
/// Lo que **no** viaja, y no por olvido: la descripción de los capítulos (ver
/// [_playerChapterJson]), los capítulos que todavía no se cerraron, las notas
/// del cuaderno, el id de la campaña y el del DM. La clave de cada bloque es el
/// `memberId`, que ya es el asa que el jugador tiene sobre el vínculo.
Future<Response> _listPlayerCampaignsHandler(
  Request request,
  CharacterRepository characters,
  CampaignRepository campaigns,
  ChapterRepository chapters,
  EncounterRepository encounters,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  final character = await characters.find(request.userId, id);
  if (character == null) return _notFound('Personaje no encontrado.');

  final shares = await campaigns.listSharesForCharacter(
    ownerUserId: request.userId,
    characterId: id,
  );

  // ponytail: cuatro consultas por campaña. Un personaje está en una o dos, así
  // que no molesta; el día que moleste, es una sola consulta con joins.
  final payload = <Map<String, dynamic>>[];
  for (final share in shares) {
    final campaign = await campaigns.find(share.dmUserId, share.campaignId);
    // La campaña se borró entre el listado y esto. No es un error: el vínculo
    // se va en cascada, así que el bloque simplemente no existe.
    if (campaign == null) continue;

    final members = await campaigns.listMembers(
      share.dmUserId,
      share.campaignId,
    );
    final all = await chapters.listFor(share.dmUserId, share.campaignId);
    final battles = await encounters.logsFor(share.dmUserId, share.campaignId);

    payload.add({
      'memberId': share.memberId,
      'campaign': campaign.toJson()..remove('id'),
      // Los demás de la mesa. Se compara la cuenta **y** el id: los ids de
      // personaje son por cuenta, así que dos jugadores distintos pueden tener
      // los dos un «sagan» y mirar solo el id echaría al ajeno de la lista.
      'party': [
        for (final member in members)
          if (!(member.ownerUserId == request.userId &&
              member.character.id == character.id))
            member.character.name,
      ],
      'chapters': [
        for (final chapter in all)
          if (chapter.state == ChapterState.completed)
            _playerChapterJson(chapter),
      ],
      'battles': [for (final log in battles) log.toJson()],
    });
  }
  return _jsonOk({'campaigns': payload});
}

/// Corta un vínculo desde cualquiera de las dos puntas.
///
/// El aviso va siempre a la otra parte: quien ejecuta la acción ya sabe lo que
/// hizo y recibe la respuesta en el momento.
Future<Response> _deleteCampaignLinkHandler(
  Request request,
  CampaignRepository campaigns,
  CharacterRepository characters,
  EventRepository events,
) async {
  final memberId = request.params['memberId']!;
  if (!isUuid(memberId)) return _notFound('Vínculo no encontrado.');

  final link = await campaigns.deleteMember(request.userId, memberId);
  if (link == null) return _notFound('Vínculo no encontrado.');

  final character = await characters.find(link.ownerUserId, link.characterId);
  final campaign = await campaigns.find(link.dmUserId, link.campaignId);
  final payload = {
    'characterName': character?.name ?? '',
    'campaignName': campaign?.name ?? '',
  };

  final dmActed = request.userId == link.dmUserId;
  await events.append(
    dmActed ? link.ownerUserId : link.dmUserId,
    dmActed ? 'character_unlinked_by_dm' : 'character_unlinked_by_owner',
    payload,
  );
  return _jsonOk({'status': 'ok'});
}

// --- Capítulos ---
//
// Los tramos en que el DM divide una campaña. No los lee ningún jugador: de un
// capítulo solo se enteran cuando se cierra, y por un aviso, nunca leyendo el
// documento.

Chapter _chapterFromRequestJson(Map<String, dynamic> json) {
  try {
    return Chapter.fromJson(json);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('Capítulo inválido: $error');
  }
}

/// Lee `chapter` del cuerpo y comprueba las dos reglas que no puede garantizar
/// el documento por sí solo.
///
/// La primera: **no se cierra un capítulo con un `PUT`**. Cerrar le manda
/// avisos a otras cuentas, y por esta ruta un reguardado idempotente los
/// volvería a disparar. La segunda: **un solo capítulo en marcha por campaña**,
/// comprobado contra los que ya están guardados.
/// Las notas del Cuaderno y los combates ya cerrados de una campaña.
///
/// Van juntos en una respuesta y no en dos rutas porque el Cuaderno los
/// intercala: pedirlos por separado obligaría a la pantalla a esperar dos
/// viajes para poder pintar un solo capítulo.
Future<Response> _listNotebookHandler(
  Request request,
  CampaignRepository campaigns,
  NoteRepository notes,
  EncounterRepository encounters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final all = await notes.listFor(request.userId, campaignId);
  final logs = await encounters.logsFor(request.userId, campaignId);
  return _jsonOk({
    'notes': [for (final n in all) n.toJson()],
    'encounterLogs': [for (final l in logs) l.toJson()],
  });
}

/// Una nota tiene que colgar de un capítulo **de esta campaña**. La clave
/// foránea ya lo garantiza, pero se comprueba acá para responder un 400 que se
/// entienda en vez de dejar que estalle una violación de integridad.
Future<Note> _validNoteFromBody(
  Request request,
  ChapterRepository chapters,
  String userId,
  String campaignId,
) async {
  final body = await _readJsonBody(request);
  final requested = body['note'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "note".');
  }
  final note = Note.fromJson(requested);
  if (note.title.trim().isEmpty) {
    throw const FormatException('La nota necesita un título.');
  }
  if (await chapters.find(userId, campaignId, note.chapterId) == null) {
    throw const FormatException('El capítulo de la nota no existe.');
  }
  return note;
}

Future<Response> _createNoteHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
  NoteRepository notes,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final note = await _validNoteFromBody(
    request,
    chapters,
    request.userId,
    campaignId,
  );
  requireSafePathSegment(note.id, label: 'id de nota');
  final stored = await notes.create(request.userId, campaignId, note);
  return _jsonOk({'note': stored.toJson()});
}

Future<Response> _upsertNoteHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
  NoteRepository notes,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final noteId = requireSafePathSegment(
    request.params['noteId']!,
    label: 'id de nota',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  // Editar solo lo propio: sin esto el `upsert` crearía la nota ajena dentro
  // de esta cuenta, igual que ya cuida `_upsertChapterHandler`.
  if (await notes.find(request.userId, campaignId, noteId) == null) {
    return _notFound('Nota no encontrada.');
  }
  final note = await _validNoteFromBody(
    request,
    chapters,
    request.userId,
    campaignId,
  );
  if (note.id != noteId) {
    throw const FormatException('El id de la nota no coincide con la ruta.');
  }
  await notes.upsert(request.userId, campaignId, note);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _deleteNoteHandler(
  Request request,
  CampaignRepository campaigns,
  NoteRepository notes,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final noteId = requireSafePathSegment(
    request.params['noteId']!,
    label: 'id de nota',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  await notes.delete(request.userId, campaignId, noteId);
  return _jsonOk({'status': 'ok'});
}

Future<Chapter> _validChapterFromBody(
  Request request,
  ChapterRepository chapters,
  String campaignId, {
  required String? replacingId,
}) async {
  final body = await _readJsonBody(request);
  final requested = body['chapter'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "chapter".');
  }
  final chapter = _chapterFromRequestJson(requested);

  if (chapter.state == ChapterState.completed) {
    throw const FormatException(
      'Un capítulo se cierra desde su propia acción, no editándolo.',
    );
  }
  if (chapter.state == ChapterState.active) {
    final running = (await chapters.listFor(request.userId, campaignId))
        .where((c) => c.state == ChapterState.active && c.id != replacingId)
        .firstOrNull;
    if (running != null) {
      throw FormatException(
        'Ya hay un capítulo en marcha: «${running.name}». Cerralo antes de '
        'empezar otro.',
      );
    }
  }
  return chapter;
}

Future<Response> _listChaptersHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final all = await chapters.listFor(request.userId, campaignId);
  return _jsonOk({
    'chapters': [for (final c in all) c.toJson()],
  });
}

Future<Response> _createChapterHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final chapter = await _validChapterFromBody(
    request,
    chapters,
    campaignId,
    replacingId: null,
  );
  requireSafePathSegment(chapter.id, label: 'id de capítulo');
  final stored = await chapters.create(request.userId, campaignId, chapter);
  return _jsonOk({'chapter': stored.toJson()});
}

Future<Response> _upsertChapterHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final chapterId = requireSafePathSegment(
    request.params['chapterId']!,
    label: 'id de capítulo',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  // Editar solo lo propio: sin esto el `upsert` crearía el capítulo ajeno
  // dentro de esta cuenta, igual que ya cuida `_upsertCampaignHandler`.
  final existing = await chapters.find(request.userId, campaignId, chapterId);
  if (existing == null) return _notFound('Capítulo no encontrado.');

  final chapter = await _validChapterFromBody(
    request,
    chapters,
    campaignId,
    replacingId: chapterId,
  );
  if (chapter.id != chapterId) {
    throw const FormatException('El id del capítulo no coincide con la ruta.');
  }
  await chapters.upsert(request.userId, campaignId, chapter);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _deleteChapterHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final chapterId = requireSafePathSegment(
    request.params['chapterId']!,
    label: 'id de capítulo',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  await chapters.delete(request.userId, campaignId, chapterId);
  return _jsonOk({'status': 'ok'});
}

/// Cierra un capítulo y le avisa a cada jugador de la mesa.
///
/// Tiene ruta propia y no es un `PUT` con `state: completed` justamente por
/// esto: es una acción con efecto sobre otras cuentas, y una ruta de edición
/// repetiría los avisos en cada guardado.
///
/// El aviso va al **dueño** de cada personaje vinculado y nunca al DM, que ya
/// ve la respuesta en el momento — la misma regla de todos los avisos del
/// proyecto. Lleva `grantsLevel`, `grantsGold` y `grantsItems` para que el
/// cliente redacte la línea de la recompensa; las tres son **solo texto**. Acá
/// no se sube a nadie de nivel ni se le mete una moneda en la bolsa: el nivel
/// lo toca el asistente de subida del jugador y el inventario lo escribe él.
/// Este handler es el único punto del servidor que le escribe algo a otra
/// cuenta, y lo que le escribe es un aviso en su bandeja, nunca su ficha.
Future<Response> _closeChapterHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
  EventRepository events,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final chapterId = requireSafePathSegment(
    request.params['chapterId']!,
    label: 'id de capítulo',
  );
  final campaign = await campaigns.find(request.userId, campaignId);
  if (campaign == null) return _notFound('Campaña no encontrada.');

  final chapter = await chapters.find(request.userId, campaignId, chapterId);
  if (chapter == null) return _notFound('Capítulo no encontrado.');
  if (chapter.state == ChapterState.completed) {
    // Cerrar dos veces no es un error, pero tampoco vuelve a avisar.
    return _jsonOk({'status': 'ok'});
  }

  await chapters.upsert(
    request.userId,
    campaignId,
    chapter.copyWith(state: ChapterState.completed),
  );

  final members = await campaigns.listMembers(request.userId, campaignId);
  for (final member in members) {
    await events.append(member.ownerUserId, 'chapter_completed', {
      'characterName': member.character.name,
      'campaignName': campaign.name,
      'chapterName': chapter.name,
      'grantsLevel': chapter.grantsLevel,
      'grantsGold': chapter.grantsGold,
      'grantsItems': chapter.grantsItems,
    });
  }
  return _jsonOk({'status': 'ok'});
}

// --- Combate ---
//
// El combate vive en el servidor mientras está abierto: el puntero de turno
// es lo único que la cuenta del DM y la del jugador comparten, y sin esto el
// aviso de "seguís vos" no tendría de dónde salir. Igual que una ficha, se
// guarda como documento entero (`PUT`) — no hay rutas finas de "avanzar
// turno" o "dañar monstruo" que puedan desincronizarse entre sí.

/// El combate abierto de una campaña, si lo hay.
Future<Response> _getEncounterHandler(
  Request request,
  CampaignRepository campaigns,
  EncounterRepository encounters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final encounter = await encounters.find(request.userId, campaignId);
  if (encounter == null) return _notFound('No hay ningún combate en curso.');
  return _jsonOk({'encounter': encounter.toJson()});
}

/// Guarda el combate entero. El cliente del DM es dueño del estado; acá solo
/// se verifica que la campaña sea suya antes de guardarlo.
Future<Response> _saveEncounterHandler(
  Request request,
  CampaignRepository campaigns,
  EncounterRepository encounters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final body = await _readJsonBody(request);
  final requested = body['encounter'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "encounter".');
  }
  final Encounter encounter;
  try {
    encounter = Encounter.fromJson(requested);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('Encuentro inválido: $error');
  }
  await encounters.save(request.userId, campaignId, encounter);
  return _jsonOk({'status': 'ok'});
}

/// Cierra el combate y archiva su log. Sin combate abierto no hace nada —
/// cerrar dos veces no es un error, mismo criterio que cerrar sesión.
///
/// Con `?discard=true` lo descarta **sin archivarlo**: el combate que se abrió
/// por error o se armó mal no tiene por qué figurar en el registro de la
/// campaña como si se hubiera jugado. Cualquier otro valor (o ninguno) archiva,
/// que es lo que corresponde por defecto: perder lo jugado tiene que ser una
/// decisión explícita, nunca lo que pasa si el parámetro viene mal escrito.
Future<Response> _endEncounterHandler(
  Request request,
  CampaignRepository campaigns,
  ChapterRepository chapters,
  EncounterRepository encounters,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }

  if (request.url.queryParameters['discard'] == 'true') {
    await encounters.discard(request.userId, campaignId);
    return _jsonOk({'status': 'ok'});
  }

  final encounter = await encounters.find(request.userId, campaignId);
  if (encounter != null) {
    // El capítulo lo resuelve el servidor y no lo manda el cliente: el DM
    // cierra un combate, no elige dónde archivarlo.
    final active = (await chapters.listFor(
      request.userId,
      campaignId,
    )).where((c) => c.state == ChapterState.active).firstOrNull;
    await encounters.close(
      request.userId,
      campaignId,
      _buildEncounterLog(encounter),
      chapterId: active?.id,
    );
  }
  return _jsonOk({'status': 'ok'});
}

/// El log de un combate cerrado: solo lo que pasó del lado del DM (quiénes
/// pelearon, contra qué, cuántas rondas, qué monstruos cayeron). No puede
/// registrar quién hizo qué daño porque el servidor nunca se entera de eso —
/// cada jugador anota sus propios PG en su ficha, no el DM en el tracker.
Map<String, dynamic> _buildEncounterLog(Encounter encounter) {
  final players = [
    for (final c in encounter.combatants)
      if (c.kind == CombatantKind.player) c.name,
  ];
  final monsterGroups = <String, List<Combatant>>{};
  for (final c in encounter.combatants) {
    if (c.kind != CombatantKind.monster) continue;
    monsterGroups.putIfAbsent(c.creatureId ?? c.name, () => []).add(c);
  }
  return EncounterLog(
    rounds: encounter.round,
    players: players,
    monsters: [
      for (final group in monsterGroups.values)
        EncounterLogMonsters(
          // «Guerrero goblin 3» vuelve a ser «Guerrero goblin»: el número lo
          // puso el tracker para distinguir copias en la mesa.
          name: group.first.name.replaceFirst(RegExp(r'\s+\d+$'), ''),
          count: group.length,
          defeated: group.where((c) => c.currentHp <= 0).length,
        ),
    ],
  ).toJson();
}

/// El turno de un personaje propio, para que su ficha muestre el aviso.
///
/// Nunca revela el orden completo ni a los monstruos: [TurnStatus] es
/// deliberadamente los cuatro únicos valores que un jugador puede ver.
Future<Response> _turnHandler(
  Request request,
  CharacterRepository characters,
  EncounterRepository encounters,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  if (await characters.find(request.userId, id) == null) {
    return _notFound('Personaje no encontrado.');
  }
  final status = await encounters.turnFor(
    userId: request.userId,
    characterId: id,
  );
  return _jsonOk({'turn': status.toJson()});
}

// --- Avisos ---

Future<Response> _listEventsHandler(
  Request request,
  EventRepository events,
) async {
  final pending = await events.listUnseen(request.userId);
  return _jsonOk({
    'events': [for (final event in pending) event.toJson()],
  });
}

Future<Response> _markEventsSeenHandler(
  Request request,
  EventRepository events,
) async {
  final body = await _readJsonBody(request);
  final ids = body['ids'];
  if (ids is! List) throw const FormatException('Falta "ids".');
  // Un id mal formado no puede llegar a la consulta: Postgres lo rechazaría
  // por tipo. Se descarta acá, que además es lo que corresponde — marcar como
  // visto algo que no existe no es un error.
  final valid = [
    for (final id in ids.whereType<String>())
      if (isUuid(id)) id,
  ];
  await events.markSeen(request.userId, valid);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _listHomebrewHandler(
  Request request,
  HomebrewRepository homebrew,
) async {
  final content = await homebrew.listForUser(request.userId);
  return _jsonOk({'content': content});
}

/// Guarda una entidad homebrew de [category]. El documento entero (con su
/// propio `id`) viaja en el cuerpo, igual que produce `Weapon.toJson()` y
/// afines: a este endpoint no le importa su forma interna, solo que el `id`
/// del cuerpo coincida con el de la ruta (misma garantía que
/// `_upsertCharacterHandler`).
Future<Response> _upsertHomebrewHandler(
  Request request,
  HomebrewRepository homebrew,
) async {
  final category = request.params['category']!;
  if (!_homebrewCategories.contains(category)) {
    throw const FormatException('Categoría de homebrew no reconocida.');
  }
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de homebrew',
  );
  final document = await _readJsonBody(request);
  if (document['id'] != id) {
    throw const FormatException('El id del documento no coincide con la ruta.');
  }
  await homebrew.upsert(request.userId, category, id, document);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _deleteHomebrewHandler(
  Request request,
  HomebrewRepository homebrew,
) async {
  final category = request.params['category']!;
  if (!_homebrewCategories.contains(category)) {
    throw const FormatException('Categoría de homebrew no reconocida.');
  }
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de homebrew',
  );
  await homebrew.delete(request.userId, category, id);
  return _jsonOk({'status': 'ok'});
}

Future<Response> _getSettingsHandler(
  Request request,
  SettingsRepository settings,
) async {
  final document = await settings.find(request.userId);
  return _jsonOk({'settings': document});
}

Future<Response> _saveSettingsHandler(
  Request request,
  SettingsRepository settings,
) async {
  final document = await _readJsonBody(request);
  await settings.save(request.userId, document);
  return _jsonOk({'status': 'ok'});
}

/// Sirve el retrato dueño de la sesión actual. Una clave sintácticamente
/// inválida (`..`, segmentos extra) deja que el [FormatException] suba y se
/// convierta en 400 vía [errorHandlingMiddleware]; una clave válida que no
/// resuelve a un archivo propio (ajena o inexistente) responde 404, sin
/// distinguir un caso del otro.
Future<Response> _portraitHandler(
  Request request,
  PortraitBlobStore portraits,
) async {
  final key = '${request.params['characterId']}/${request.params['fileName']}';
  // `w` es el ancho en píxeles físicos en que el cliente va a dibujar el
  // retrato. Un valor que no sea un entero positivo se ignora y se sirve el
  // original, igual que uno fuera de la escalera de anchos: el medallón tiene
  // que aparecer aunque el parámetro venga mal.
  final width = int.tryParse(request.url.queryParameters['w'] ?? '');
  final blob = await portraits.read(
    userId: request.userId,
    portraitKey: key,
    width: width != null && width > 0 ? width : null,
  );
  if (blob == null) {
    return Response.notFound(
      jsonEncode({'error': 'Retrato no encontrado.'}),
      headers: {'content-type': 'application/json'},
    );
  }
  return Response.ok(
    blob.bytes,
    headers: {
      'content-type': blob.contentType,
      // Un retrato es inmutable: se guarda con un nombre nuevo cada vez y
      // nunca se reescribe (ver `DiskPortraitBlobStore.save`), así que la
      // clave identifica el contenido y puede cachearse sin límite. `private`
      // porque la respuesta depende de la sesión: la única caché compartida en
      // el camino es Cloudflare y un retrato no es suyo para repartir (ver
      // `webCacheControl`).
      'cache-control': 'private, max-age=31536000, immutable',
    },
  );
}

/// Lista los proveedores de generación que este servidor puede ofrecer: uno
/// sin credenciales configuradas MUST NOT aparecer acá.
Response _portraitProvidersHandler(PortraitGenerationService generation) =>
    Response.ok(
      jsonEncode({
        'providers': [
          for (final provider in generation.available)
            {
              'id': provider.id,
              'name': provider.name,
              'supportsReference': provider.supportsReference,
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );

/// Genera candidatos de retrato con el proveedor pedido. No persiste nada:
/// devuelve los bytes para que la cuenta elija uno y lo mande a
/// `POST /api/characters/<id>/portraits`. Un proveedor desconocido, sin
/// credenciales o que no admite referencia es un pedido mal formado (400,
/// vía [FormatException]); un proveedor que falla al generar es un fallo
/// propio (502) con un mensaje comprensible, no un 500 genérico.
Future<Response> _generatePortraitHandler(
  Request request,
  PortraitGenerationService generation,
) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final providerId = body['providerId'];
  final prompt = body['prompt'];
  if (providerId is! String || providerId.isEmpty) {
    throw const FormatException('Falta "providerId".');
  }
  if (prompt is! String || prompt.isEmpty) {
    throw const FormatException('Falta "prompt".');
  }
  final referenceBase64 = body['referenceBase64'];
  final reference = referenceBase64 is String && referenceBase64.isNotEmpty
      ? Uint8List.fromList(base64Decode(referenceBase64))
      : null;
  final count = body['count'];

  try {
    final images = await generation.generate(
      providerId: providerId,
      prompt: prompt,
      reference: reference,
      count: count is int ? count : null,
    );
    return Response.ok(
      jsonEncode({
        'images': [for (final image in images) base64Encode(image)],
      }),
      headers: {'content-type': 'application/json'},
    );
  } on PortraitGenerationFailure catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': e.message}),
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Persiste como retrato de [characterId] los bytes que la cuenta eligió: un
/// candidato generado por IA, o un archivo propio subido directamente. Es el
/// mismo camino para los dos casos, y el único que efectivamente escribe en
/// `PortraitBlobStore` (que valida tipo y tamaño, ver capacidad
/// `portrait-storage`).
Future<Response> _createPortraitHandler(
  Request request,
  PortraitBlobStore portraits,
) async {
  final characterId = request.params['characterId']!;
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final bytesBase64 = body['bytes'];
  if (bytesBase64 is! String || bytesBase64.isEmpty) {
    throw const FormatException('Falta "bytes".');
  }
  final bytes = Uint8List.fromList(base64Decode(bytesBase64));
  final key = await portraits.save(
    userId: request.userId,
    characterId: characterId,
    bytes: bytes,
  );
  return Response.ok(
    jsonEncode({'key': key}),
    headers: {'content-type': 'application/json'},
  );
}

/// Importa un respaldo ZIP para la cuenta autenticada. Decodificar y validar
/// el ZIP (versión de formato, rutas internas, tamaños) ocurre antes de tocar
/// la cuenta: un respaldo inválido o de una versión futura se rechaza con 400
/// vía [FormatException] sin haber escrito nada.
Future<Response> _importHandler(
  Request request,
  ImportBackupFn importBackup,
) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final zipBase64 = body['bytes'];
  if (zipBase64 is! String || zipBase64.isEmpty) {
    throw const FormatException('Falta "bytes".');
  }
  final bundle = BackupBundleCodec.decode(base64Decode(zipBase64));
  final result = await importBackup(userId: request.userId, bundle: bundle);
  return Response.ok(
    jsonEncode({
      'charactersImported': result.charactersImported,
      'portraitsImported': result.portraitsImported,
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Convierte cualquier excepción no capturada en un 500 con un cuerpo
/// genérico. El detalle real queda en el log del servidor: una API publicada
/// en internet no debe devolver trazas ni mensajes internos al cliente.
Middleware get errorHandlingMiddleware => (Handler innerHandler) {
  return (Request request) async {
    try {
      return await innerHandler(request);
    } on FormatException catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.message}),
        headers: {'content-type': 'application/json'},
      );
    } on UnsupportedDataVersionException catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        'Error no manejado en ${request.method} ${request.url}: '
        '$e\n$stackTrace',
      );
      return Response.internalServerError(
        body: jsonEncode({'error': 'Error interno del servidor.'}),
        headers: {'content-type': 'application/json'},
      );
    }
  };
};
