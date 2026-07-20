/// Tipo de progresión de espacios de conjuro de una clase.
enum CasterProgression {
  /// No lanza (o solo trucos sin espacios).
  none,

  /// Lanzador completo: Mago, Clérigo, Druida, Bardo, Hechicero.
  full,

  /// Semi-lanzador: Paladín, Explorador.
  half,

  /// Un tercio: subclases (Caballero Arcano, Embaucador Arcano).
  third,

  /// Magia de Pacto: Brujo (espacios pocos pero siempre del nivel más alto).
  pact;

  static CasterProgression fromJson(String? v) => switch (v) {
        'full' => CasterProgression.full,
        'half' => CasterProgression.half,
        'third' => CasterProgression.third,
        'pact' => CasterProgression.pact,
        _ => CasterProgression.none,
      };

  String toJson() => name;
}

/// Cómo obtiene sus conjuros la clase.
enum SpellPreparation {
  /// Prepara conjuros de toda la lista de clase tras un descanso (Clérigo, Druida, Mago…).
  prepared,

  /// Conoce un número fijo de conjuros (Hechicero, Bardo, Brujo 2024…).
  known;

  static SpellPreparation fromJson(String? v) =>
      v == 'known' ? SpellPreparation.known : SpellPreparation.prepared;

  String toJson() => name;
}

/// Tabla del lanzador completo: nivel de personaje → espacios por nivel de
/// conjuro (índices 0..8 = niveles 1..9).
const List<List<int>> _fullTable = [
  [0, 0, 0, 0, 0, 0, 0, 0, 0], // (relleno para índice 0)
  [2, 0, 0, 0, 0, 0, 0, 0, 0],
  [3, 0, 0, 0, 0, 0, 0, 0, 0],
  [4, 2, 0, 0, 0, 0, 0, 0, 0],
  [4, 3, 0, 0, 0, 0, 0, 0, 0],
  [4, 3, 2, 0, 0, 0, 0, 0, 0],
  [4, 3, 3, 0, 0, 0, 0, 0, 0],
  [4, 3, 3, 1, 0, 0, 0, 0, 0],
  [4, 3, 3, 2, 0, 0, 0, 0, 0],
  [4, 3, 3, 3, 1, 0, 0, 0, 0],
  [4, 3, 3, 3, 2, 0, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

/// Tabla del semi-lanzador (Paladín/Explorador): niveles de conjuro 1..5.
/// Reglas 2024: obtienen lanzamiento y espacios ya a nivel 1.
const List<List<int>> _halfTable = [
  [0, 0, 0, 0, 0], // 0
  [2, 0, 0, 0, 0],
  [2, 0, 0, 0, 0],
  [3, 0, 0, 0, 0],
  [3, 0, 0, 0, 0],
  [4, 2, 0, 0, 0],
  [4, 2, 0, 0, 0],
  [4, 3, 0, 0, 0],
  [4, 3, 0, 0, 0],
  [4, 3, 2, 0, 0],
  [4, 3, 2, 0, 0],
  [4, 3, 3, 0, 0],
  [4, 3, 3, 0, 0],
  [4, 3, 3, 1, 0],
  [4, 3, 3, 1, 0],
  [4, 3, 3, 2, 0],
  [4, 3, 3, 2, 0],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2],
];

/// Tabla de un tercio (subclases): niveles de conjuro 1..4.
const List<List<int>> _thirdTable = [
  [0, 0, 0, 0], // 0
  [0, 0, 0, 0], // 1
  [0, 0, 0, 0], // 2 (obtiene lanzamiento a nivel 3)
  [2, 0, 0, 0],
  [3, 0, 0, 0],
  [3, 0, 0, 0],
  [3, 0, 0, 0],
  [4, 2, 0, 0],
  [4, 2, 0, 0],
  [4, 2, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 2, 0],
  [4, 3, 2, 0],
  [4, 3, 2, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 1],
  [4, 3, 3, 1],
];

/// Magia de Pacto (Brujo): nivel de personaje → (cantidad, nivel de espacio).
const List<(int count, int slotLevel)> _pactTable = [
  (0, 0), // 0
  (1, 1),
  (2, 1),
  (2, 2),
  (2, 2),
  (2, 3),
  (2, 3),
  (2, 4),
  (2, 4),
  (2, 5),
  (2, 5),
  (3, 5),
  (3, 5),
  (3, 5),
  (3, 5),
  (3, 5),
  (3, 5),
  (4, 5),
  (4, 5),
  (4, 5),
  (4, 5),
];

/// Espacios de conjuro disponibles para una [progression] a [level].
///
/// Devuelve un mapa **nivel de conjuro → cantidad** (solo entradas > 0). Para
/// [CasterProgression.pact] la única entrada es el nivel de espacio de pacto.
Map<int, int> spellSlotsFor(CasterProgression progression, int level) {
  final lv = level.clamp(0, 20);
  switch (progression) {
    case CasterProgression.none:
      return const {};
    case CasterProgression.pact:
      final (count, slotLevel) = _pactTable[lv];
      return count == 0 ? const {} : {slotLevel: count};
    case CasterProgression.full:
    case CasterProgression.half:
    case CasterProgression.third:
      final table = switch (progression) {
        CasterProgression.half => _halfTable,
        CasterProgression.third => _thirdTable,
        _ => _fullTable,
      };
      final row = table[lv];
      return {
        for (var i = 0; i < row.length; i++)
          if (row[i] > 0) i + 1: row[i],
      };
  }
}
