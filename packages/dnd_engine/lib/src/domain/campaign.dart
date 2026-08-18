import 'data_version.dart';

/// En qué momento de su vida está una campaña.
///
/// Existe para que el tablero del DM no se llene de campañas viejas: lo que
/// terminó o está en pausa se puede apartar sin borrarlo, porque una campaña
/// cerrada sigue siendo el registro de lo que se jugó.
enum CampaignState {
  active('En curso'),
  paused('En pausa'),
  finished('Terminada');

  const CampaignState(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Tolerante: ausente o desconocido devuelve [CampaignState.active], que es
  /// el estado en que nace toda campaña.
  static CampaignState fromJson(String? v) {
    for (final s in CampaignState.values) {
      if (s.name == v) return s;
    }
    return CampaignState.active;
  }
}

/// Una mesa que dirige un DM.
///
/// Es el contenedor de todo lo que el Modo DM va a colgar después (capítulos,
/// cuaderno, combates) y de los personajes que los jugadores le compartan.
///
/// Igual que [Character], el documento **no** dice de quién es: la propiedad la
/// establece la fila que lo guarda, no el JSON. Así el mismo documento viaja
/// entre servidor y cliente sin arrastrar una identidad que el cliente podría
/// falsificar.
class Campaign {
  /// Versión del formato de este documento. Se incrementa cuando un cambio
  /// obliga a reescribir campañas ya guardadas, con el mismo contrato que
  /// `Character.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;

  /// Premisa corta: el pitch de dos líneas que distingue una campaña de otra en
  /// el tablero. El trasfondo largo no vive acá sino en el cuaderno de campaña,
  /// para no tener dos lugares donde escribir lo mismo.
  final String premise;

  final CampaignState state;

  const Campaign({
    required this.id,
    required this.name,
    this.premise = '',
    this.state = CampaignState.active,
  });

  Campaign copyWith({String? name, String? premise, CampaignState? state}) =>
      Campaign(
        id: id,
        name: name ?? this.name,
        premise: premise ?? this.premise,
        state: state ?? this.state,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'premise': premise,
        'state': state.toJson(),
      };

  factory Campaign.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Campaign(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      premise: j['premise'] as String? ?? '',
      state: CampaignState.fromJson(j['state'] as String?),
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión de la campaña debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Lleva una campaña histórica al esquema actual **sin modificar el mapa de
  /// entrada**, igual que `Character.migrateJson`.
  ///
  /// Hoy no hay ningún paso que aplicar porque el formato va por su primera
  /// versión. Lo que sí hace desde el día uno es rechazar una versión futura:
  /// un servidor viejo que abriera una campaña escrita por uno nuevo la
  /// guardaría de vuelta perdiendo los campos que no entiende, y eso es
  /// justamente lo que esta puerta impide.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'campaña',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
