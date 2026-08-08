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
/// Cómo se puede lanzar un conjuro concedido por un rasgo (linaje, dote…),
/// aparte de la magia de clase.
enum InnateSpellUse {
  /// A voluntad, sin límite. Es el caso de los trucos.
  atWill,

  /// Gratis una vez por descanso largo; además se puede lanzar gastando un
  /// espacio de conjuro, si el personaje tiene.
  oncePerLongRest,

  /// Gratis una vez por descanso **corto o largo**; además se puede lanzar
  /// gastando un espacio de conjuro. Es el caso de los Conjuros
  /// Característicos del Mago.
  oncePerShortRest,

  /// Gratis una cantidad de veces igual al bono de competencia por descanso
  /// largo; además se puede lanzar gastando un espacio de conjuro.
  proficiencyBonusPerLongRest;

  String toJson() => switch (this) {
        InnateSpellUse.atWill => 'atWill',
        InnateSpellUse.oncePerLongRest => 'oncePerLongRest',
        InnateSpellUse.oncePerShortRest => 'oncePerShortRest',
        InnateSpellUse.proficiencyBonusPerLongRest =>
          'proficiencyBonusPerLongRest',
      };

  static InnateSpellUse fromJson(String? v) => switch (v) {
        'oncePerLongRest' => InnateSpellUse.oncePerLongRest,
        'oncePerShortRest' => InnateSpellUse.oncePerShortRest,
        'proficiencyBonusPerLongRest' =>
          InnateSpellUse.proficiencyBonusPerLongRest,
        _ => InnateSpellUse.atWill,
      };
}

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

// --- Conjuros preparados (tablas fijas del PHB 2024) ---
//
// A diferencia de 2014, la cantidad de conjuros preparados NO depende del
// modificador de característica: es una columna fija por clase que escala con el
// nivel. Índice = nivel de personaje (1..20); el 0 es relleno.

/// Lanzadores completos con progresión estándar (Mago, Clérigo, Druida, Bardo).
const List<int> _preparedFull = [
  0,
  4,
  5,
  6,
  7,
  9,
  10,
  11,
  12,
  14,
  15,
  16,
  16,
  17,
  18,
  19,
  21,
  22,
  23,
  24,
  25,
];

/// Hechicero: arranca más bajo (2/4) y luego converge con los completos.
const List<int> _preparedSorcerer = [
  0,
  2,
  4,
  6,
  7,
  9,
  10,
  11,
  12,
  14,
  15,
  16,
  16,
  17,
  18,
  19,
  21,
  22,
  23,
  24,
  25,
];

/// Semi-lanzadores (Paladín, Explorador).
const List<int> _preparedHalf = [
  0,
  2,
  3,
  4,
  5,
  6,
  6,
  7,
  7,
  9,
  9,
  10,
  10,
  11,
  11,
  12,
  12,
  14,
  14,
  15,
  15,
];

/// Magia de Pacto (Brujo).
const List<int> _preparedPact = [
  0,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  10,
  11,
  11,
  12,
  12,
  13,
  13,
  14,
  14,
  15,
  15,
];

/// Un tercio (subclases: Caballero Arcano, Pícaro Arcano). Empiezan a nivel 3.
const List<int> _preparedThird = [
  0,
  0,
  0,
  3,
  4,
  4,
  4,
  5,
  6,
  6,
  7,
  8,
  8,
  9,
  10,
  10,
  11,
  11,
  11,
  12,
  13,
];

/// Conjuros preparados para una [progression] a [level], según las tablas fijas
/// de 2024. [spellList] distingue al Hechicero (progresión propia) del resto de
/// lanzadores completos.
int preparedSpellsFor(
    CasterProgression progression, int level, String spellList) {
  final lv = level.clamp(0, 20);
  final table = switch (progression) {
    CasterProgression.none => const [0],
    CasterProgression.half => _preparedHalf,
    CasterProgression.third => _preparedThird,
    CasterProgression.pact => _preparedPact,
    CasterProgression.full =>
      spellList == 'sorcerer' ? _preparedSorcerer : _preparedFull,
  };
  return lv < table.length ? table[lv] : table.last;
}

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
