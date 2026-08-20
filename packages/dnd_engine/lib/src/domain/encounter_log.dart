import 'data_version.dart';

/// Un grupo de monstruos de un combate cerrado, ya juntado por criatura: no
/// interesa que el tercer goblin llegara a 0 PG, sino que cayeron dos de tres.
class EncounterLogMonsters {
  final String name;
  final int count;
  final int defeated;

  const EncounterLogMonsters({
    required this.name,
    this.count = 1,
    this.defeated = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'defeated': defeated,
      };

  factory EncounterLogMonsters.fromJson(Map<String, dynamic> j) =>
      EncounterLogMonsters(
        name: j['name'] as String? ?? '',
        count: j['count'] as int? ?? 1,
        defeated: j['defeated'] as int? ?? 0,
      );
}

/// Lo que queda de un combate al cerrarlo, y que el Cuaderno de campaña
/// muestra como entrada automática.
///
/// **Lo que este registro puede decir es todo lo que el servidor sabe.**
/// Quiénes pelearon, contra qué y cuántos enemigos cayeron. Nunca quién hizo
/// cuánto daño ni quién mató a quién: los PG de un personaje los anota su
/// jugador en su propia ficha, así que el combat tracker del DM jamás se entera
/// del daño. Ampliar esto pediría que el DM escribiera la ficha ajena, que es
/// exactamente la frontera que el Modo DM decidió no cruzar.
///
/// Es de **solo lectura** por naturaleza: nace al cerrar un combate y nadie lo
/// edita. Por eso no tiene `copyWith` ni id propio de negocio.
class EncounterLog {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Encounter.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  /// Id de la fila, que asigna la base al archivar.
  final String id;

  /// Capítulo en el que se jugó, o null si no se pudo saber: los combates
  /// archivados antes de que existiera el Cuaderno no lo declaran, y una mesa
  /// puede pelear sin ningún capítulo en marcha.
  ///
  /// A diferencia de una nota, **no se borra con su capítulo**: la nota es un
  /// borrador y el combate ya pasó.
  final String? chapterId;

  /// Cuántas rondas duró.
  final int rounds;

  /// Nombres de los personajes que participaron.
  final List<String> players;

  final List<EncounterLogMonsters> monsters;

  /// Cuándo se cerró. La pone la base, igual que en [Note].
  final DateTime? endedAt;

  const EncounterLog({
    this.id = '',
    this.chapterId,
    this.rounds = 1,
    this.players = const [],
    this.monsters = const [],
    this.endedAt,
  });

  /// Cuántos enemigos cayeron sobre el total, para el resumen del capítulo.
  int get totalMonsters => monsters.fold(0, (sum, m) => sum + m.count);
  int get totalDefeated => monsters.fold(0, (sum, m) => sum + m.defeated);

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        if (id.isNotEmpty) 'id': id,
        if (chapterId != null) 'chapterId': chapterId,
        'rounds': rounds,
        'players': players,
        'monsters': [for (final m in monsters) m.toJson()],
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      };

  factory EncounterLog.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return EncounterLog(
      id: j['id'] as String? ?? '',
      chapterId: j['chapterId'] as String?,
      rounds: j['rounds'] as int? ?? 1,
      players: [
        for (final p in (j['players'] as List? ?? const [])) p as String,
      ],
      monsters: [
        for (final m in (j['monsters'] as List? ?? const []))
          EncounterLogMonsters.fromJson((m as Map).cast<String, dynamic>()),
      ],
      endedAt: DateTime.tryParse(j['endedAt'] as String? ?? ''),
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del log de combate debe ser un entero positivo.',
      );
    }
    return value;
  }

  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'log de combate',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
