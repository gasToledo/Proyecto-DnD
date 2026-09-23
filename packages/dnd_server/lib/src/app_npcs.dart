part of 'app.dart';

// --- PNJ del Modo DM ---
//
// Todo lo que sigue es de un solo dueño: ningún jugador lee nada de acá, por
// ninguna ruta. La autorización vive en el `WHERE` de cada consulta de
// `NpcRepository`, y lo ajeno responde igual que lo inexistente.

Map<String, dynamic> _storedNpcJson(StoredNpc stored) => {
  'npc': stored.npc.toJson(),
  'campaigns': [for (final c in stored.campaigns) c.toJson()],
  if (stored.sheet != null) 'character': stored.sheet!.toJson(),
};

Npc _npcFromRequestJson(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Falta "npc".');
  }
  final Npc npc;
  try {
    npc = Npc.fromJson(json);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('PNJ inválido: $error');
  }
  if (npc.name.trim().isEmpty) {
    throw const FormatException('El PNJ necesita un nombre.');
  }
  return npc;
}

/// Lo que cada tipo de PNJ puede traer, y nada más: un PNJ sin estadísticas no
/// guarda bloque, uno con bloque no guarda ficha. El `characterId` nunca lo
/// decide el cliente: sale de la fila que crea el servidor.
Npc _normalizedNpc(Npc npc, {required String id, String? characterId}) {
  final json = npc.toJson()
    ..['id'] = id
    ..remove('characterId');
  if (npc.sheetKind != NpcSheetKind.block) {
    json
      ..remove('block')
      ..remove('baseCreatureId')
      ..remove('baseCreatureName');
  }
  if (characterId != null) json['characterId'] = characterId;
  return Npc.fromJson(json);
}

/// Un id nuevo que no choca con ningún personaje ni PNJ de la cuenta: los dos
/// comparten el espacio de claves del almacén de retratos.
String _newStorageId(String prefix, Set<String> taken) {
  final random = Random();
  String candidate() =>
      '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${random.nextInt(1 << 30).toRadixString(36)}';
  return resolveStorageId(
    requestedId: candidate(),
    existingIds: taken,
    fallbackId: candidate,
  );
}

Future<Map<String, dynamic>> _readOptionalJsonBody(Request request) async {
  final bytes = await _readBody(request, _defaultJsonBodyBytes);
  if (utf8.decode(bytes).trim().isEmpty) return const {};
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Se esperaba un objeto JSON.');
  }
  return decoded;
}

Future<Response> _listNpcsHandler(Request request, NpcRepository npcs) async {
  final all = await npcs.listForDm(request.userId);
  return _jsonOk({
    'npcs': [for (final stored in all) _storedNpcJson(stored)],
  });
}

Future<Response> _getNpcHandler(Request request, NpcRepository npcs) async {
  final id = requireSafePathSegment(request.params['id']!, label: 'id de PNJ');
  final stored = await npcs.find(request.userId, id);
  if (stored == null) return _notFound('PNJ no encontrado.');
  return _jsonOk(_storedNpcJson(stored));
}

/// Crea un PNJ. El id lo asigna el servidor; si es un PNJ con ficha de
/// personaje, la ficha se crea en la misma transacción con `kind = 'npc'`,
/// así nunca queda un PNJ sin ficha ni una ficha huérfana en «Mis personajes».
Future<Response> _createNpcHandler(
  Request request,
  RepositoryTransactionRunner transactions,
) async {
  final body = await _readJsonBody(request);
  final requested = _npcFromRequestJson(body['npc']);
  final rawSheet = body['character'];
  final wantsSheet = requested.sheetKind == NpcSheetKind.character;
  if (wantsSheet && rawSheet is! Map<String, dynamic>) {
    throw const FormatException('Un PNJ con ficha necesita "character".');
  }
  final sheet = wantsSheet
      ? _characterFromRequestJson(rawSheet as Map<String, dynamic>)
      : null;

  final stored = await transactions.run((repositories) async {
    final taken = {
      ...await repositories.characters.existingIds(request.userId),
      ...await repositories.npcs.existingIds(request.userId),
    };
    final id = _newStorageId('npc-', taken);
    Character? storedSheet;
    if (sheet != null) {
      storedSheet = await repositories.characters.createNpcSheet(
        request.userId,
        Character.fromJson(
          sheet.toJson()..['id'] = _newStorageId('npc-ficha-', {...taken, id}),
        ),
      );
    }
    final npc = _normalizedNpc(requested, id: id, characterId: storedSheet?.id);
    await repositories.npcs.insert(request.userId, npc);
    return StoredNpc(npc: npc, sheet: storedSheet);
  });
  return _jsonOk(_storedNpcJson(stored));
}

/// Edita el documento de un PNJ propio. El tipo no se cambia: cada uno se
/// edita con otro constructor y pasar de uno a otro perdería datos.
Future<Response> _updateNpcHandler(Request request, NpcRepository npcs) async {
  final id = requireSafePathSegment(request.params['id']!, label: 'id de PNJ');
  final body = await _readJsonBody(request);
  final requested = _npcFromRequestJson(body['npc']);
  if (requested.id != id) {
    throw const FormatException('El id del PNJ no coincide con la ruta.');
  }
  final existing = await npcs.find(request.userId, id);
  if (existing == null) return _notFound('PNJ no encontrado.');
  if (existing.npc.sheetKind != requested.sheetKind) {
    throw const FormatException('El tipo de un PNJ no se cambia.');
  }
  final npc = _normalizedNpc(
    requested,
    id: id,
    characterId: existing.npc.characterId,
  );
  await npcs.update(request.userId, npc);
  return _jsonOk({'npc': npc.toJson()});
}

/// Borra un PNJ de la biblioteca y de todas sus campañas, con su ficha si la
/// tiene. Los combates ya archivados lo siguen nombrando: el registro guarda
/// nombres, no referencias.
Future<Response> _deleteNpcHandler(
  Request request,
  RepositoryTransactionRunner transactions,
  PortraitBlobStore portraits,
) async {
  final id = requireSafePathSegment(request.params['id']!, label: 'id de PNJ');
  final deleted = await transactions.run((repositories) async {
    final existing = await repositories.npcs.find(request.userId, id);
    if (existing == null) return null;
    await repositories.npcs.delete(request.userId, id);
    final sheetId = existing.npc.characterId;
    if (sheetId != null) {
      await repositories.characters.deleteNpcSheet(request.userId, sheetId);
    }
    return existing.npc;
  });
  if (deleted == null) return _jsonOk({'status': 'ok'});

  // Igual que al borrar un personaje: los retratos no entran en la
  // transacción, así que se borran con el PNJ ya borrado.
  final sheetId = deleted.characterId;
  for (final owner in {id, if (sheetId != null) sheetId}) {
    try {
      await portraits.deleteAllFor(userId: request.userId, characterId: owner);
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print(
        'No se pudieron borrar los retratos de "$owner": $error\n$stackTrace',
      );
    }
  }
  return _jsonOk({'status': 'ok'});
}

/// Guarda un retrato de un PNJ sin ficha de personaje. El de un PNJ con ficha
/// va por la ruta de la ficha, que ya existe y es la que usa el taller.
Future<Response> _createNpcPortraitHandler(
  Request request,
  NpcRepository npcs,
  PortraitBlobStore portraits,
) async {
  final id = requireSafePathSegment(request.params['id']!, label: 'id de PNJ');
  final stored = await npcs.find(request.userId, id);
  if (stored == null || stored.npc.sheetKind == NpcSheetKind.character) {
    return _notFound('PNJ no encontrado.');
  }
  final body = await _readJsonBody(
    request,
    maxBytes: _base64JsonLimit(portraits.maxBytes),
  );
  final bytesBase64 = body['bytes'];
  if (bytesBase64 is! String || bytesBase64.isEmpty) {
    throw const FormatException('Falta "bytes".');
  }
  final bytes = _decodeBase64(
    bytesBase64,
    maxBytes: portraits.maxBytes,
    label: 'La imagen',
  );
  final key = await portraits.save(
    userId: request.userId,
    characterId: id,
    bytes: bytes,
  );
  return _jsonOk({'key': key});
}

Future<Response> _listCampaignNpcsHandler(
  Request request,
  CampaignRepository campaigns,
  NpcRepository npcs,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  if (await campaigns.find(request.userId, campaignId) == null) {
    return _notFound('Campaña no encontrada.');
  }
  final all = await npcs.listForCampaign(request.userId, campaignId);
  return _jsonOk({
    'npcs': [
      for (final entry in all)
        {
          'npc': entry.npc.toJson(),
          'status': entry.status.toJson(),
          if (entry.sheet != null) 'character': entry.sheet!.toJson(),
        },
    ],
  });
}

/// Suma un PNJ a una campaña o le cambia el estado. Sin `status` en el cuerpo,
/// un vínculo nuevo nace vivo y uno existente queda como estaba.
Future<Response> _linkCampaignNpcHandler(
  Request request,
  NpcRepository npcs,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final npcId = requireSafePathSegment(
    request.params['npcId']!,
    label: 'id de PNJ',
  );
  final body = await _readOptionalJsonBody(request);
  final rawStatus = body['status'];
  NpcStatus? status;
  if (rawStatus != null) {
    status = NpcStatus.values.where((s) => s.name == rawStatus).firstOrNull;
    if (status == null) throw const FormatException('Estado inválido.');
  }
  final result = await npcs.link(
    request.userId,
    campaignId,
    npcId,
    status: status,
  );
  if (result == null) return _notFound('PNJ o campaña no encontrados.');
  return _jsonOk({'status': result.toJson()});
}

/// JSON con las claves ordenadas, para comparar dos documentos por contenido
/// sin que el orden en que se escribieron los campos los haga distintos.
String _canonicalJson(Object? value) {
  Object? sorted(Object? v) => switch (v) {
    Map() => {
      for (final key in (v.keys.map((k) => '$k').toList()..sort()))
        key: sorted(v[key]),
    },
    List() => [for (final item in v) sorted(item)],
    _ => v,
  };
  return jsonEncode(sorted(value));
}

/// Los homebrew del paquete cuyo id ya existe en la cuenta **con otro
/// contenido**. Uno idéntico no choca: se reusa.
List<String> _homebrewConflicts(
  Map<String, List<Map<String, dynamic>>> existing,
  Map<String, List<Map<String, dynamic>>> incoming,
) => [
  for (final category in incoming.entries)
    for (final document in category.value)
      for (final current in existing[category.key] ?? const [])
        if (current['id'] == document['id'] &&
            _canonicalJson(current) != _canonicalJson(document))
          '${document['name'] ?? document['id']} (${category.key})',
];

/// Remapea una lista de claves de retrato y sus prompts con [keys]; lo que no
/// esté en el mapa (un retrato que no viajó) se descarta.
({List<String> paths, Map<String, String> prompts}) _remapPortraits(
  List<String> paths,
  Map<String, String> prompts,
  Map<String, String> keys,
) => (
  paths: [
    for (final path in paths)
      if (keys[path] case final next?) next,
  ],
  prompts: {
    for (final entry in prompts.entries)
      if (keys[entry.key] case final next?) next: entry.value,
  },
);

/// Importa un PNJ que exportó otro DM (o el mismo, en otra instalación).
///
/// **Crea siempre una copia nueva y nunca reemplaza nada**: ids nuevos para el
/// PNJ y su ficha, retratos con claves nuevas, y el homebrew que choca con uno
/// existente de otro contenido rechaza la importación entera nombrándolo — se
/// lo resuelve a mano antes que reescribir ids dentro de una ficha. No es la
/// ruta de los respaldos: un respaldo nunca crea PNJ y esto nunca crea
/// personajes jugadores.
Future<Response> _importNpcHandler(
  Request request,
  RepositoryTransactionRunner transactions,
  PortraitBlobStore portraits,
) async {
  final body = await _readJsonBody(
    request,
    maxBytes: _base64JsonLimit(NpcBundleCodec.maxArchiveBytes),
  );
  final zipBase64 = body['bytes'];
  if (zipBase64 is! String || zipBase64.isEmpty) {
    throw const FormatException('Falta "bytes".');
  }
  final rawCampaignId = body['campaignId'];
  final campaignId = rawCampaignId is String && rawCampaignId.isNotEmpty
      ? requireSafePathSegment(rawCampaignId, label: 'id de campaña')
      : null;
  final bundle = NpcBundleCodec.decode(
    _decodeBase64(
      zipBase64,
      maxBytes: NpcBundleCodec.maxArchiveBytes,
      label: 'El archivo del PNJ',
    ),
  );
  final userId = request.userId;

  // Todo lo que puede rechazar la importación se mira antes de guardar un
  // solo retrato: los blobs no entran en la transacción.
  final taken = await transactions.run((repositories) async {
    final conflicts = _homebrewConflicts(
      await repositories.homebrew.listForUser(userId),
      bundle.homebrew,
    );
    if (conflicts.isNotEmpty) {
      throw FormatException(
        'El PNJ trae homebrew que en tu cuenta ya existe con otro contenido: '
        '${conflicts.join(', ')}.',
      );
    }
    if (campaignId != null &&
        await repositories.campaigns.find(userId, campaignId) == null) {
      throw const FormatException('Campaña no encontrada.');
    }
    return {
      ...await repositories.characters.existingIds(userId),
      ...await repositories.npcs.existingIds(userId),
    };
  });

  final npcId = _newStorageId('npc-', taken);
  final sheetId = bundle.sheet == null
      ? null
      : _newStorageId('npc-ficha-', {...taken, npcId});

  final newKeys = <String, String>{};
  for (final portrait in bundle.portraits) {
    final owner = portrait.owner == 'character' ? sheetId : npcId;
    if (owner == null) continue;
    newKeys[portrait.originalKey] = await portraits.save(
      userId: userId,
      characterId: owner,
      bytes: portrait.bytes,
    );
  }

  final npcPortraits = _remapPortraits(
    bundle.npc.portraitPaths,
    bundle.npc.portraitPrompts,
    newKeys,
  );
  final requested = Npc.fromJson({
    ...bundle.npc.toJson(),
    'portraitPaths': npcPortraits.paths,
    'portraitPrompts': npcPortraits.prompts,
  });

  final stored = await transactions.run((repositories) async {
    // Se vuelve a mirar adentro de la transacción: entre la primera lectura y
    // esta pudo aparecer un homebrew con ese id.
    final existing = await repositories.homebrew.listForUser(userId);
    final conflicts = _homebrewConflicts(existing, bundle.homebrew);
    if (conflicts.isNotEmpty) {
      throw FormatException(
        'El PNJ trae homebrew que en tu cuenta ya existe con otro contenido: '
        '${conflicts.join(', ')}.',
      );
    }
    for (final category in bundle.homebrew.entries) {
      for (final document in category.value) {
        final id = document['id'] as String;
        final already = (existing[category.key] ?? const []).any(
          (current) => current['id'] == id,
        );
        if (!already) {
          await repositories.homebrew.upsert(
            userId,
            category.key,
            id,
            document,
          );
        }
      }
    }

    Character? storedSheet;
    final sheet = bundle.sheet;
    if (sheet != null && sheetId != null) {
      final sheetPortraits = _remapPortraits(
        sheet.portraitPaths,
        sheet.portraitPrompts,
        newKeys,
      );
      storedSheet = await repositories.characters.createNpcSheet(
        userId,
        Character.fromJson(
          sheet.toJson()
            ..['id'] = sheetId
            ..['portraitPaths'] = sheetPortraits.paths
            ..['portraitPrompts'] = sheetPortraits.prompts,
        ),
      );
    }
    final npc = _normalizedNpc(
      requested,
      id: npcId,
      characterId: storedSheet?.id,
    );
    await repositories.npcs.insert(userId, npc);

    final campaigns = <NpcCampaignLink>[];
    if (campaignId != null) {
      final status = await repositories.npcs.link(userId, campaignId, npcId);
      if (status == null) throw const FormatException('Campaña no encontrada.');
      final campaign = await repositories.campaigns.find(userId, campaignId);
      campaigns.add(
        NpcCampaignLink(
          campaignId: campaignId,
          campaignName: campaign?.name ?? '',
          status: status,
        ),
      );
    }
    return StoredNpc(npc: npc, sheet: storedSheet, campaigns: campaigns);
  });
  return _jsonOk(_storedNpcJson(stored));
}

Future<Response> _unlinkCampaignNpcHandler(
  Request request,
  NpcRepository npcs,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final npcId = requireSafePathSegment(
    request.params['npcId']!,
    label: 'id de PNJ',
  );
  await npcs.unlink(request.userId, campaignId, npcId);
  return _jsonOk({'status': 'ok'});
}
