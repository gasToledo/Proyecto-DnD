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

/// Una campaña vista desde la ficha del jugador, tal como la devuelve
/// `GET /api/characters/<id>/campaigns`.
///
/// Es una **proyección**, no la campaña del DM: el servidor arma la respuesta
/// campo por campo y deja afuera la descripción de cada capítulo, los capítulos
/// que todavía no se cerraron, las notas del cuaderno y los ids de la campaña y
/// del DM. Todo lo que llega acá es lo que el jugador puede ver.
///
/// Mismo molde que [Notebook]: modelo de transporte del lado de la app,
/// reusando los tipos del engine en vez de duplicarlos.
class PlayerCampaign {
  /// El vínculo entre este personaje y esta campaña. Es la clave estable del
  /// bloque —dos campañas pueden llamarse igual— y además es lo que tomaría un
  /// futuro «salir de la campaña», que ya existe como `deleteCampaignLink`.
  final String memberId;

  /// Nombre, premisa y estado. **Sin `id`**: no viaja desde el servidor, así
  /// que acá llega en blanco y no hay que usarlo para nada.
  final Campaign campaign;

  /// Los otros personajes de la mesa, sin este.
  final List<String> party;

  /// Solo los capítulos ya cerrados, y **sin descripción**.
  final List<Chapter> chapters;

  /// Los combates cerrados de la campaña, del más nuevo al más viejo.
  ///
  /// Son los de la mesa entera y no solo aquellos en los que peleó este
  /// personaje: el registro guarda nombres, y filtrar por nombre haría que
  /// renombrar un personaje le borrara el pasado.
  final List<EncounterLog> battles;

  const PlayerCampaign({
    required this.memberId,
    required this.campaign,
    this.party = const [],
    this.chapters = const [],
    this.battles = const [],
  });

  factory PlayerCampaign.fromJson(Map<String, dynamic> json) => PlayerCampaign(
    memberId: json['memberId'] as String? ?? '',
    campaign: Campaign.fromJson({
      // El servidor no manda el id y `Campaign.fromJson` lo exige. Se completa
      // con el del vínculo, que es el identificador que el jugador sí tiene.
      'id': json['memberId'] as String? ?? '',
      ...(json['campaign'] as Map? ?? const {}).cast<String, dynamic>(),
    }),
    party: [
      for (final name in (json['party'] as List? ?? const [])) name as String,
    ],
    chapters: [
      for (final c in (json['chapters'] as List? ?? const []))
        Chapter.fromJson((c as Map).cast<String, dynamic>()),
    ],
    battles: [
      for (final b in (json['battles'] as List? ?? const []))
        EncounterLog.fromJson((b as Map).cast<String, dynamic>()),
    ],
  );

  /// Las batallas de un capítulo, de la más vieja a la más nueva: se leen como
  /// un relato, igual que en el Cuaderno del DM.
  List<EncounterLog> battlesOf(String chapterId) => [
    for (final b in battles.reversed)
      if (b.chapterId == chapterId) b,
  ];

  /// Las batallas que no caen bajo ninguno de los capítulos que se muestran.
  ///
  /// Son tres casos distintos que acá dan lo mismo, y por eso van juntas en vez
  /// de tener cada una su grupo: las que se pelearon sin ningún capítulo en
  /// marcha, las del capítulo que **todavía está en marcha** (que no se
  /// muestra, pero cuyas peleas ya pasaron), y las de un capítulo que el DM
  /// borró — un combate no se borra con su capítulo, a diferencia de una nota.
  ///
  /// Sin esto desaparecerían sin dejar rastro, que es peor que mostrarlas
  /// sueltas.
  List<EncounterLog> get looseBattles {
    final shown = {for (final c in chapters) c.id};
    return [
      for (final b in battles.reversed)
        if (!shown.contains(b.chapterId)) b,
    ];
  }
}
