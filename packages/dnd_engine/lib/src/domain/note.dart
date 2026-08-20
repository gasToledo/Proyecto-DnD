import 'data_version.dart';

/// Una nota del Cuaderno de campaña: lo que el DM escribe a mano dentro de un
/// capítulo.
///
/// Es la mitad **editable** del cuaderno. La otra —combates cerrados y demás
/// registros— la escribe la app y no se corrige: ver [EncounterLog].
///
/// Igual que [Chapter], el documento **no** dice de quién es ni a qué campaña
/// pertenece: eso lo establece la fila que lo guarda, no el JSON.
class Note {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Chapter.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;

  /// Capítulo al que pertenece. El cuaderno es una línea de tiempo por
  /// capítulo, así que una nota siempre cuelga de uno: no hay notas sueltas de
  /// campaña. Se guarda el id y no el capítulo entero por lo mismo que el resto
  /// del proyecto guarda referencias.
  final String chapterId;

  /// Título corto. Campo aparte y no la primera línea de [body] porque es lo
  /// que se muestra cuando la nota está plegada y en los resultados de
  /// búsqueda.
  final String title;

  /// El texto de la nota, de varias líneas.
  final String body;

  /// Cuándo se guardó por última vez.
  ///
  /// **Lo manda la base, no el cliente**: la columna `updated_at` es la fuente
  /// de verdad y el repositorio la pisa al leer. Viaja adentro del documento
  /// solo para no necesitar un tipo de transporte aparte; lo que quede grabado
  /// acá no lo lee nadie.
  final DateTime? updatedAt;

  const Note({
    required this.id,
    required this.chapterId,
    this.title = '',
    this.body = '',
    this.updatedAt,
  });

  Note copyWith({String? chapterId, String? title, String? body}) => Note(
        id: id,
        chapterId: chapterId ?? this.chapterId,
        title: title ?? this.title,
        body: body ?? this.body,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'chapterId': chapterId,
        'title': title,
        'body': body,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Note(
      id: j['id'] as String,
      chapterId: j['chapterId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión de la nota debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Chapter.migrateJson`: no muta la entrada, y rechaza
  /// una versión futura en vez de guardarla de vuelta perdiendo los campos que
  /// esta versión no entiende.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'nota',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
