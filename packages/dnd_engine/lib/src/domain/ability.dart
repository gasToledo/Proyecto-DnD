/// Las seis características de D&D 5e y utilidades derivadas.
enum Ability {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  /// Abreviatura de 3 letras usada en la ficha (STR, DEX, ...).
  String get abbr => switch (this) {
        Ability.strength => 'STR',
        Ability.dexterity => 'DEX',
        Ability.constitution => 'CON',
        Ability.intelligence => 'INT',
        Ability.wisdom => 'WIS',
        Ability.charisma => 'CHA',
      };

  /// Nombre en español de la característica (para la UI).
  String get label => switch (this) {
        Ability.strength => 'Fuerza',
        Ability.dexterity => 'Destreza',
        Ability.constitution => 'Constitución',
        Ability.intelligence => 'Inteligencia',
        Ability.wisdom => 'Sabiduría',
        Ability.charisma => 'Carisma',
      };

  /// Descripción corta de qué mide la característica (para tooltips y ayuda).
  String get description => switch (this) {
        Ability.strength =>
          'Potencia física. Pruebas de Atletismo, cargar peso y el daño de la mayoría de armas cuerpo a cuerpo.',
        Ability.dexterity =>
          'Agilidad y reflejos. CA sin armadura pesada, iniciativa, Sigilo y Acrobacias, y los ataques a distancia y con armas sutiles.',
        Ability.constitution =>
          'Salud y aguante. Determina tus puntos de golpe y las salvaciones para mantener la concentración.',
        Ability.intelligence =>
          'Razonamiento y memoria. Arcanos, Historia e Investigación; es la característica de lanzamiento del Mago.',
        Ability.wisdom =>
          'Percepción e intuición. Percepción, Perspicacia y Supervivencia; lanzamiento del Clérigo, el Druida y el Explorador.',
        Ability.charisma =>
          'Fuerza de personalidad. Persuasión, Engaño e Intimidación; lanzamiento del Bardo, el Hechicero, el Brujo y el Paladín.',
      };

  /// Resuelve una característica desde su nombre de enum ("strength") o su
  /// abreviatura ("STR"), sin distinguir mayúsculas.
  static Ability fromKey(String key) {
    final k = key.trim().toLowerCase();
    return Ability.values.firstWhere(
      (a) => a.name == k || a.abbr.toLowerCase() == k,
      orElse: () => throw ArgumentError('Característica desconocida: "$key"'),
    );
  }
}

/// Modificador de característica: floor((score - 10) / 2).
///
/// Se usa `floor` explícito (no la división entera de Dart, que trunca hacia
/// cero) para que las puntuaciones por debajo de 10 den el modificador correcto.
int abilityModifier(int score) => ((score - 10) / 2).floor();

/// Bonificador de competencia por nivel total de personaje (2 en niveles 1-4,
/// 3 en 5-8, etc.).
int proficiencyBonusForLevel(int level) => 2 + ((level - 1) ~/ 4);
