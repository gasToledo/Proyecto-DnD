import 'data_version.dart';
import 'encounter.dart';

/// Un grupo de combatientes no jugadores de un combate cerrado, ya juntado por
/// criatura: no interesa que el tercer goblin llegara a 0 PG, sino que cayeron
/// dos de tres.
///
/// El nombre de la clase es de cuando solo había monstruos enemigos; desde la
/// versión 2 también agrupa aliados, neutrales y PNJ, cada uno con su [side].
class EncounterLogMonsters {
  /// El nombre que ve el DM: el propio del PNJ, o el de la criatura.
  final String name;
  final int count;
  final int defeated;
  final CombatantSide side;

  /// Es un PNJ de la biblioteca: su [name] es un nombre propio que el jugador
  /// no tiene por qué conocer.
  final bool npc;

  /// Lo que puede ver el jugador en lugar del nombre de un PNJ: la criatura de
  /// la que partió su bloque, o null si no partió de ninguna. Se resuelve al
  /// cerrar el combate, así que borrar el PNJ después no cambia el pasado.
  final String? publicName;

  const EncounterLogMonsters({
    required this.name,
    this.count = 1,
    this.defeated = 0,
    this.side = CombatantSide.enemy,
    this.npc = false,
    this.publicName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'defeated': defeated,
        'side': side.toJson(),
        if (npc) 'npc': true,
        if (publicName != null) 'publicName': publicName,
      };

  factory EncounterLogMonsters.fromJson(Map<String, dynamic> j) =>
      EncounterLogMonsters(
        name: j['name'] as String? ?? '',
        count: j['count'] as int? ?? 1,
        defeated: j['defeated'] as int? ?? 0,
        side:
            CombatantSide.fromJson(j['side'] as String?) ?? CombatantSide.enemy,
        npc: j['npc'] as bool? ?? false,
        publicName: j['publicName'] as String?,
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
  ///
  /// La 2 suma el bando de cada grupo y marca a los PNJ (ver [migrateJson]).
  static const int currentSchemaVersion = 2;

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

  /// Todos los que no son jugadores, agrupados, con su bando.
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

  List<EncounterLogMonsters> _bySide(CombatantSide side) => [
        for (final m in monsters)
          if (m.side == side) m,
      ];

  List<EncounterLogMonsters> get enemies => _bySide(CombatantSide.enemy);
  List<EncounterLogMonsters> get allies => _bySide(CombatantSide.ally);
  List<EncounterLogMonsters> get neutrals => _bySide(CombatantSide.neutral);

  /// Cuántos enemigos cayeron sobre el total, para el resumen del capítulo.
  ///
  /// Solo enemigos: que caiga la aliada del grupo no es una victoria, y
  /// contarla daría un «cayeron 4 de 4» en un combate que no se ganó.
  int get totalMonsters => enemies.fold(0, (sum, m) => sum + m.count);
  int get totalDefeated => enemies.fold(0, (sum, m) => sum + m.defeated);

  /// Lo que de este combate puede ver un jugador.
  ///
  /// **Ningún nombre de PNJ sale de acá.** Los aliados y los neutrales que no
  /// son jugadores desaparecen, y un PNJ enemigo se muestra con el nombre de la
  /// criatura de la que partió ([EncounterLogMonsters.publicName]) o, si no
  /// partió de ninguna, con el nombre vacío: la pantalla del jugador lo dice
  /// «un enemigo». Los grupos con el mismo nombre visible se juntan, para que
  /// Garrick —un Bandido— y dos bandidos del bestiario sumen «3 Bandido».
  ///
  /// Vive en el engine y no en el servidor para que el doble de pruebas del
  /// cliente pode exactamente igual: un doble más permisivo dejaría pasar una
  /// pantalla que muestra lo que no debe.
  EncounterLog playerView() {
    final groups = <String, ({int count, int defeated})>{};
    for (final m in enemies) {
      final visible = m.npc ? (m.publicName ?? '') : m.name;
      final previous = groups[visible] ?? (count: 0, defeated: 0);
      groups[visible] = (
        count: previous.count + m.count,
        defeated: previous.defeated + m.defeated,
      );
    }
    return EncounterLog(
      id: id,
      chapterId: chapterId,
      rounds: rounds,
      players: players,
      monsters: [
        for (final e in groups.entries)
          EncounterLogMonsters(
            name: e.key,
            count: e.value.count,
            defeated: e.value.defeated,
          ),
      ],
      endedAt: endedAt,
    );
  }

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

  /// **1 → 2**: marca a cada grupo como enemigo, que es lo que eran todos los
  /// monstruos antes de los bandos. No muta la entrada.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'log de combate',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    final j = Map<String, dynamic>.from(source);
    if (version < 2) {
      j['monsters'] = [
        for (final m in (source['monsters'] as List? ?? const []))
          if (m is Map)
            {
              ...m.cast<String, dynamic>(),
              'side': (m['side'] as String?) ?? CombatantSide.enemy.toJson(),
            },
      ];
      j['schemaVersion'] = 2;
    }
    return j;
  }
}
