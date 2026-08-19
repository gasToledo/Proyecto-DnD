import 'data_version.dart';

/// En qué punto de su vida está un capítulo.
///
/// El nombre "capítulo" y no "misión" es deliberado: describe una campaña que
/// avanza en el tiempo, no una lista de encargos paralelos que se cumplen o se
/// fallan. Por eso los estados son una línea y no un resultado.
enum ChapterState {
  planned('Próximamente'),
  active('En marcha'),
  completed('Completado');

  const ChapterState(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Tolerante: ausente o desconocido devuelve [ChapterState.planned], que es
  /// el estado en que nace todo capítulo.
  static ChapterState fromJson(String? v) {
    for (final s in ChapterState.values) {
      if (s.name == v) return s;
    }
    return ChapterState.planned;
  }
}

/// Un tramo de una campaña, tal como lo planifica y lo cierra el DM.
///
/// Es el eje temporal del que va a colgar el cuaderno de campaña y el
/// archivado de los combates: por eso existe antes que ellos.
///
/// Igual que [Campaign], el documento **no** dice de quién es ni a qué campaña
/// pertenece: eso lo establece la fila que lo guarda, no el JSON.
class Chapter {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Character.currentSchemaVersion` y `Campaign.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;

  /// Descripción libre, de varias líneas: qué pasa en este tramo de la
  /// historia. La escribe el DM y **no la ve ningún jugador** — de un capítulo
  /// solo se entera cuando ya está cerrado, y ni siquiera entonces se le
  /// muestra este texto.
  final String summary;

  final ChapterState state;

  /// Al cerrar este capítulo, a los personajes de la mesa les corresponde
  /// subir de nivel.
  ///
  /// Es **solo un aviso**: la app nunca sube a nadie de nivel. El nivel y los
  /// PG por nivel de un personaje son dos listas que el asistente de subida
  /// mantiene en sincronía, y ese asistente es del jugador. Que el DM lo
  /// ejecutara rompería tanto la ficha como la frontera de "el DM no toca
  /// construcción".
  final bool grantsLevel;

  const Chapter({
    required this.id,
    required this.name,
    this.summary = '',
    this.state = ChapterState.planned,
    this.grantsLevel = false,
  });

  Chapter copyWith({
    String? name,
    String? summary,
    ChapterState? state,
    bool? grantsLevel,
  }) =>
      Chapter(
        id: id,
        name: name ?? this.name,
        summary: summary ?? this.summary,
        state: state ?? this.state,
        grantsLevel: grantsLevel ?? this.grantsLevel,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'summary': summary,
        'state': state.toJson(),
        'grantsLevel': grantsLevel,
      };

  factory Chapter.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Chapter(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      state: ChapterState.fromJson(j['state'] as String?),
      grantsLevel: j['grantsLevel'] as bool? ?? false,
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del capítulo debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Campaign.migrateJson`: no muta la entrada, y rechaza
  /// una versión futura en vez de guardarla de vuelta perdiendo los campos que
  /// esta versión no entiende.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'capítulo',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
