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

  /// Oro que le toca a **cada personaje** al cerrarse, ya repartido.
  ///
  /// Ya repartido porque la app no divide botín: no sabe cuántos jugadores
  /// hubo en la mesa esa noche ni cómo acordaron partirlo, y adivinarlo sería
  /// meterse en una discusión que es de la mesa.
  ///
  /// Mismo aviso que [grantsLevel]: **no se le suma a ninguna ficha**. La
  /// bolsa de un personaje la escribe su jugador; que la escribiera el DM
  /// cruzaría la misma frontera, y encima pisaría al jugador que justo está
  /// gastando en la taberna.
  final int grantsGold;

  /// Ítems que se llevan, por nombre libre.
  ///
  /// Texto y no ids del catálogo a propósito: medio botín de una mesa («el
  /// mapa del contrabandista», «tres gemas del cofre») no está en ningún
  /// catálogo, y como el aviso lo copia a mano el jugador en su ficha, un id
  /// no le ahorraría nada.
  final List<String> grantsItems;

  const Chapter({
    required this.id,
    required this.name,
    this.summary = '',
    this.state = ChapterState.planned,
    this.grantsLevel = false,
    this.grantsGold = 0,
    this.grantsItems = const [],
  });

  /// Si el cierre reparte algo además del aviso de subir de nivel.
  bool get grantsRewards => grantsGold > 0 || grantsItems.isNotEmpty;

  /// El botín en una línea, o vacío si no hay ninguno. Sin el nivel: en la
  /// lista de capítulos ese ya se ve como marca aparte.
  String get rewardsLabel => describeRewards(grantsGold, grantsItems);

  /// Todo lo que reparte al cerrarse, el nivel incluido, en una línea sola.
  String get grantsLabel =>
      describeRewards(grantsGold, grantsItems, level: grantsLevel);

  Chapter copyWith({
    String? name,
    String? summary,
    ChapterState? state,
    bool? grantsLevel,
    int? grantsGold,
    List<String>? grantsItems,
  }) =>
      Chapter(
        id: id,
        name: name ?? this.name,
        summary: summary ?? this.summary,
        state: state ?? this.state,
        grantsLevel: grantsLevel ?? this.grantsLevel,
        grantsGold: grantsGold ?? this.grantsGold,
        grantsItems: grantsItems ?? this.grantsItems,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'summary': summary,
        'state': state.toJson(),
        'grantsLevel': grantsLevel,
        'grantsGold': grantsGold,
        'grantsItems': grantsItems,
      };

  factory Chapter.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Chapter(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      state: ChapterState.fromJson(j['state'] as String?),
      grantsLevel: j['grantsLevel'] as bool? ?? false,
      // El botín se limpia acá y no en el constructor porque este es el único
      // borde por el que entra algo escrito afuera. Oro negativo y nombres en
      // blanco se descartan en vez de rechazar el capítulo entero: no hay
      // nada que un DM pueda arreglar leyendo un error sobre eso.
      grantsGold: switch (j['grantsGold']) {
        final int gold when gold > 0 => gold,
        _ => 0,
      },
      grantsItems: [
        for (final item in (j['grantsItems'] as List? ?? const []))
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
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

/// «250 po, Espada larga +1 y Poción de curación»: cómo se nombra un botín en
/// una sola línea.
///
/// Suelta y no método de [Chapter] porque el aviso que le llega al jugador se
/// redacta desde el payload del evento, donde no hay ningún capítulo.
///
/// [level] pone «un nivel» al frente. Es una sola lista y no dos frases para
/// que no queden dos «y» seguidas: «un nivel y 250 po y una espada» se lee mal
/// en cualquier boca.
String describeRewards(int gold, List<String> items, {bool level = false}) {
  final parts = [
    if (level) 'un nivel',
    if (gold > 0) '$gold po',
    ...items,
  ];
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.take(parts.length - 1).join(', ')} y ${parts.last}';
}
