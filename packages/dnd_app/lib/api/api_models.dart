import 'package:dnd_engine/dnd_engine.dart';

/// Metadatos de un proveedor de generación de retratos, tal como los publica
/// `GET /api/portraits/providers`: ya viene filtrado a los que el servidor
/// tiene configurados (ver capacidad `ai-portrait-generation`). El cliente
/// nunca ve una clave de proveedor, solo esto.
class PortraitProviderInfo {
  final String id;
  final String name;
  final bool supportsReference;

  const PortraitProviderInfo({
    required this.id,
    required this.name,
    required this.supportsReference,
  });

  factory PortraitProviderInfo.fromJson(Map<String, dynamic> json) =>
      PortraitProviderInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        supportsReference: json['supportsReference'] as bool? ?? false,
      );
}

/// La cuenta de la sesión en curso, tal como la publica `GET /api/me`. El
/// perfil sale del proveedor OIDC (Zitadel), no de un registro de usuario
/// propio: acá solo se muestra. Todo menos [userId] puede faltar (cuenta sin
/// esos datos cargados, o sesión abierta antes de que se empezaran a guardar).
class AccountInfo {
  final String userId;
  final String? name;
  final String? email;
  final String? pictureUrl;

  const AccountInfo({
    required this.userId,
    this.name,
    this.email,
    this.pictureUrl,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
    userId: json['userId'] as String,
    name: json['name'] as String?,
    email: json['email'] as String?,
    pictureUrl: json['pictureUrl'] as String?,
  );
}

/// Un personaje tal como lo devuelve `GET /api/characters`, con la fecha de
/// alta que la fila conoce y el documento no: el documento lo manda este
/// cliente, así que no puede declarar su propia antigüedad.
class StoredCharacter {
  final Character character;
  final DateTime createdAt;

  const StoredCharacter({required this.character, required this.createdAt});
}

class ImportSummary {
  final int charactersImported;
  final int portraitsImported;

  const ImportSummary({
    required this.charactersImported,
    required this.portraitsImported,
  });
}

/// Un personaje que un jugador compartió con una campaña del DM.
///
/// [memberId] identifica el **vínculo**, no al personaje: es con lo que se
/// corta y con lo que se pide el retrato, y el mismo personaje tendría uno
/// distinto en otra campaña.
class CampaignMember {
  final String memberId;
  final Character character;

  const CampaignMember({required this.memberId, required this.character});

  factory CampaignMember.fromJson(Map<String, dynamic> json) => CampaignMember(
    memberId: json['memberId'] as String,
    character: Character.fromJson(
      (json['character'] as Map).cast<String, dynamic>(),
    ),
  );
}

/// Una campaña con la que este personaje está compartido, vista desde la ficha
/// del jugador. Solo trae el nombre: es lo que necesita para reconocerla y
/// decidir si sigue compartiéndola.
class CharacterShare {
  final String memberId;
  final String campaignName;

  const CharacterShare({required this.memberId, required this.campaignName});

  factory CharacterShare.fromJson(Map<String, dynamic> json) => CharacterShare(
    memberId: json['memberId'] as String,
    campaignName: json['campaignName'] as String? ?? '',
  );
}

/// El código recién emitido para compartir un personaje, con su vencimiento.
class ShareCode {
  final String code;
  final DateTime expiresAt;

  const ShareCode({required this.code, required this.expiresAt});

  factory ShareCode.fromJson(Map<String, dynamic> json) => ShareCode(
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

/// Algo que pasó mientras esta cuenta no estaba mirando.
///
/// El servidor guarda qué pasó, no cómo se dice: el texto lo arma
/// `user_event_messages.dart` a partir de [kind] y [payload].
class UserEvent {
  final String id;
  final String kind;
  final Map<String, dynamic> payload;

  const UserEvent({
    required this.id,
    required this.kind,
    required this.payload,
  });

  factory UserEvent.fromJson(Map<String, dynamic> json) => UserEvent(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? '',
    payload: (json['payload'] as Map? ?? const {}).cast<String, dynamic>(),
  );
}

/// El Cuaderno de campaña tal como lo devuelve el servidor: las dos mitades
/// juntas.
///
/// [notes] las escribe el DM y se editan; [encounterLogs] las escribe la app al
/// cerrar un combate y no se tocan. La pantalla las intercala por capítulo.
class Notebook {
  final List<Note> notes;
  final List<EncounterLog> encounterLogs;

  const Notebook({this.notes = const [], this.encounterLogs = const []});

  bool get isEmpty => notes.isEmpty && encounterLogs.isEmpty;
}
