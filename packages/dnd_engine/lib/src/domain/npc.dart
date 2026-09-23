import 'creature.dart';
import 'data_version.dart';

/// Qué ficha de juego lleva un PNJ. Se elige al crearlo y **no cambia**: cada
/// tipo se edita con un constructor distinto (ninguno, el editor de bloques o
/// el creador de personajes), y pasar de uno a otro no tiene una conversión
/// que no pierda datos.
enum NpcSheetKind {
  /// El tabernero: nombre, trasfondo y nada que tirar. En combate entra fijo
  /// como neutral, sin PG.
  none('Sin estadísticas'),

  /// Un bloque como los del bestiario, **copiado** y propio del PNJ.
  block('Bloque propio'),

  /// Una ficha de personaje real, con clase, niveles y dotes.
  character('Ficha de personaje');

  const NpcSheetKind(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Un valor desconocido cae en [none], que es el tipo que no promete nada:
  /// leerlo como `block` o `character` haría buscar una ficha que no está.
  static NpcSheetKind fromJson(String? v) {
    for (final k in NpcSheetKind.values) {
      if (k.name == v) return k;
    }
    return NpcSheetKind.none;
  }
}

/// Estado de un PNJ **dentro de una campaña**. No es del PNJ: el mismo puede
/// estar muerto en una mesa y vivo en otra, por eso vive en el vínculo y no en
/// [Npc].
enum NpcStatus {
  alive('Vivo'),
  dead('Muerto'),
  unknown('Desconocido');

  const NpcStatus(this.label);

  final String label;

  String toJson() => name;

  /// Tolerante hacia [alive], que es el estado con el que nace todo vínculo.
  static NpcStatus fromJson(String? v) {
    for (final s in NpcStatus.values) {
      if (s.name == v) return s;
    }
    return NpcStatus.alive;
  }
}

/// Una nota del DM sobre un PNJ. Es **global**: se ve igual desde cualquier
/// campaña donde esté el PNJ, decisión del usuario — lo anotado sobre alguien
/// sirve en todas las mesas.
class NpcNote {
  final String id;
  final DateTime date;
  final String text;

  const NpcNote({required this.id, required this.date, required this.text});

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'text': text,
      };

  factory NpcNote.fromJson(Map<String, dynamic> j) => NpcNote(
        id: j['id'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        text: j['text'] as String? ?? '',
      );
}

/// Un personaje no jugador de la biblioteca del DM.
///
/// Es un **documento de usuario** y no contenido de catálogo, aunque su bloque
/// se parezca a una criatura: guarda texto del DM (trasfondo, notas) que hay
/// que poder migrar. Por eso lleva [currentSchemaVersion] y [migrateJson],
/// igual que [Note].
///
/// No dice nada de campañas: en qué mesas está y si sigue vivo en cada una es
/// del vínculo (`campaign_npcs`), no del PNJ.
class Npc {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Note.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;
  final NpcSheetKind sheetKind;

  /// El bloque de juego, solo para [NpcSheetKind.block].
  ///
  /// **Es una copia, no una referencia.** Si apuntara a la criatura del
  /// catálogo, regenerar el bestiario o borrar el homebrew de origen cambiaría
  /// o rompería al PNJ sin avisar — y exportarlo obligaría a llevarse la
  /// criatura atrás.
  final Creature? block;

  /// De qué criatura se copió [block], o null si se armó de cero. Es lo que el
  /// jugador ve en sus batallas en lugar del nombre propio del PNJ.
  final String? baseCreatureId;
  final String? baseCreatureName;

  /// La ficha real, solo para [NpcSheetKind.character]: una fila de
  /// `characters` marcada como PNJ.
  final String? characterId;

  /// Una o dos líneas para interpretarlo en la mesa.
  final String speech;

  /// Cómo se ve. Es lo único escrito a mano que viaja al generador de
  /// retratos; el trasfondo y las notas nunca.
  final String appearance;

  final String background;

  /// Tags libres, ya normalizados por [normalizeTags].
  final List<String> tags;

  final List<NpcNote> notes;

  /// Retratos propios, para [NpcSheetKind.none] y [NpcSheetKind.block]. Un PNJ
  /// con ficha de personaje usa los de su ficha.
  final List<String> portraitPaths;
  final Map<String, String> portraitPrompts;

  Npc({
    required this.id,
    required this.name,
    required this.sheetKind,
    this.block,
    this.baseCreatureId,
    this.baseCreatureName,
    this.characterId,
    this.speech = '',
    this.appearance = '',
    this.background = '',
    List<String> tags = const [],
    this.notes = const [],
    this.portraitPaths = const [],
    this.portraitPrompts = const {},
  }) : tags = normalizeTags(tags);

  /// Tiene números con los que pelear. Un PNJ sin estadísticas entra al
  /// combate igual, pero fijo como neutral y sin PG.
  bool get hasStats => sheetKind != NpcSheetKind.none;

  /// Sin vacíos y sin dos tags que solo difieran en mayúsculas: «waterdeep»
  /// y «Waterdeep» son el mismo grupo, y el que queda es el primero que se
  /// escribió. Sin esto, la biblioteca terminaba con tres Waterdeep.
  static List<String> normalizeTags(Iterable<String> tags) {
    final seen = <String>{};
    return [
      for (final raw in tags)
        if (raw.trim() case final t when t.isNotEmpty)
          if (seen.add(t.toLowerCase())) t,
    ];
  }

  /// Compara tags sin distinguir mayúsculas, que es lo que usan los filtros.
  bool hasTag(String tag) =>
      tags.any((t) => t.toLowerCase() == tag.trim().toLowerCase());

  /// El tipo no se puede cambiar, así que no hay `sheetKind` acá.
  Npc copyWith({
    String? name,
    Creature? block,
    String? characterId,
    String? speech,
    String? appearance,
    String? background,
    List<String>? tags,
    List<NpcNote>? notes,
    List<String>? portraitPaths,
    Map<String, String>? portraitPrompts,
  }) =>
      Npc(
        id: id,
        name: name ?? this.name,
        sheetKind: sheetKind,
        block: block ?? this.block,
        baseCreatureId: baseCreatureId,
        baseCreatureName: baseCreatureName,
        characterId: characterId ?? this.characterId,
        speech: speech ?? this.speech,
        appearance: appearance ?? this.appearance,
        background: background ?? this.background,
        tags: tags ?? this.tags,
        notes: notes ?? this.notes,
        portraitPaths: portraitPaths ?? this.portraitPaths,
        portraitPrompts: portraitPrompts ?? this.portraitPrompts,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'sheetKind': sheetKind.toJson(),
        if (block != null) 'block': block!.toJson(),
        if (baseCreatureId != null) 'baseCreatureId': baseCreatureId,
        if (baseCreatureName != null) 'baseCreatureName': baseCreatureName,
        if (characterId != null) 'characterId': characterId,
        if (speech.isNotEmpty) 'speech': speech,
        if (appearance.isNotEmpty) 'appearance': appearance,
        if (background.isNotEmpty) 'background': background,
        if (tags.isNotEmpty) 'tags': tags,
        if (notes.isNotEmpty) 'notes': [for (final n in notes) n.toJson()],
        if (portraitPaths.isNotEmpty) 'portraitPaths': portraitPaths,
        if (portraitPrompts.isNotEmpty) 'portraitPrompts': portraitPrompts,
      };

  factory Npc.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    final block = j['block'];
    return Npc(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      sheetKind: NpcSheetKind.fromJson(j['sheetKind'] as String?),
      block: block is Map
          ? Creature.fromJson(block.cast<String, dynamic>())
          : null,
      baseCreatureId: j['baseCreatureId'] as String?,
      baseCreatureName: j['baseCreatureName'] as String?,
      characterId: j['characterId'] as String?,
      speech: j['speech'] as String? ?? '',
      appearance: j['appearance'] as String? ?? '',
      background: j['background'] as String? ?? '',
      // Lo que no sea texto se descarta en vez de romper la biblioteca entera.
      tags: [
        for (final t in (j['tags'] as List? ?? const []))
          if (t is String) t,
      ],
      notes: [
        for (final n in (j['notes'] as List? ?? const []))
          if (n is Map) NpcNote.fromJson(n.cast<String, dynamic>()),
      ],
      portraitPaths: [
        for (final p in (j['portraitPaths'] as List? ?? const []))
          if (p is String) p,
      ],
      portraitPrompts: {
        for (final e in ((j['portraitPrompts'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del PNJ debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Note.migrateJson`: no muta la entrada, y rechaza una
  /// versión futura en vez de guardarla de vuelta perdiendo los campos que
  /// esta versión no entiende.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'PNJ',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
