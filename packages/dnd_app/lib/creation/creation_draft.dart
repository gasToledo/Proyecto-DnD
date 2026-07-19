import 'package:dnd_engine/dnd_engine.dart';

/// Modo de reparto del aumento de característica del trasfondo 2024.
enum AbilitySpreadMode { twoOne, oneOneOne }

/// Método de puntuación de características (brief §3.A.4).
enum ScoreMethod { standardArray, roll4d6 }

/// Estado mutable del wizard de creación. Acumula las elecciones y sabe
/// construir un [Character] con todo resuelto. La UI solo lee/escribe esto.
class CreationDraft {
  final ContentRepository repo;
  CreationDraft(this.repo);

  // Clase (por ahora, única del MVP).
  String classId = 'fighter';
  String? fightingStyleId;
  final Set<String> classSkills = {};
  final List<String> weaponMasteries = [];

  // Orígenes.
  String? raceId;
  final Set<String> raceSkills = {};
  String? raceFeatId; // dote de origen de la especie (p.ej. Humano "Versátil")
  String? backgroundId;

  // Reparto de característica del trasfondo.
  AbilitySpreadMode spreadMode = AbilitySpreadMode.twoOne;
  Ability? spreadPlusTwo; // en modo +2/+1
  Ability? spreadPlusOne;

  // Puntuaciones.
  ScoreMethod scoreMethod = ScoreMethod.standardArray;
  List<int> pool = List.of(standardArray);
  final Map<Ability, int> assignedScores = {};

  // Equipo.
  String? equippedArmorId;
  bool shieldEquipped = false;
  String? weaponId;

  String name = '';

  CharacterClass? get klass => repo.characterClass(classId);
  Race? get race => raceId == null ? null : repo.race(raceId!);
  Background? get background =>
      backgroundId == null ? null : repo.background(backgroundId!);

  /// Armas con las que la clase elegida es competente. La Maestría de Armas
  /// 2024 solo puede aplicarse a estas.
  List<Weapon> get proficientWeapons {
    final k = klass;
    if (k == null) return const [];
    final profs = k.weaponProficiencies.toSet();
    return repo.weapons.values
        .where((w) => profs.contains(w.category) || profs.contains(w.id))
        .toList();
  }

  int get hitDie => klass?.hitDie ?? 10;

  /// Reparto resultante según el modo elegido y las 3 opciones del trasfondo.
  Map<Ability, int> get abilitySpread {
    final opts = background?.abilityOptions ?? const [];
    if (opts.isEmpty) return {};
    if (spreadMode == AbilitySpreadMode.oneOneOne) {
      return {for (final a in opts) a: 1};
    }
    final m = <Ability, int>{};
    if (spreadPlusTwo != null) m[spreadPlusTwo!] = 2;
    if (spreadPlusOne != null && spreadPlusOne != spreadPlusTwo) {
      m[spreadPlusOne!] = (m[spreadPlusOne!] ?? 0) + 1;
    }
    return m;
  }

  /// Fija el pool de puntuaciones según el método (array o tirada).
  void applyScoreMethod(ScoreMethod method, {Dice? dice}) {
    scoreMethod = method;
    assignedScores.clear();
    pool = method == ScoreMethod.standardArray
        ? List.of(standardArray)
        : (dice ?? Dice()).rollAbilityScoreSet();
  }

  /// Valores del pool aún no asignados (para poblar los dropdowns).
  List<int> availableFor(Ability a) {
    final used = <int>[];
    for (final e in assignedScores.entries) {
      if (e.key != a) used.add(e.value);
    }
    final remaining = List.of(pool);
    for (final v in used) {
      remaining.remove(v);
    }
    return remaining..sort((x, y) => y.compareTo(x));
  }

  /// Puntuación final de una característica (asignada + reparto de trasfondo),
  /// para previsualizar en vivo durante la asignación.
  int previewScore(Ability a) =>
      (assignedScores[a] ?? 0) + (abilitySpread[a] ?? 0);

  bool get allScoresAssigned =>
      Ability.values.every(assignedScores.containsKey);

  /// Construye el personaje final. Los PG actuales se fijan luego compilando.
  Character build() {
    return Character(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Sin nombre' : name.trim(),
      raceId: raceId ?? '',
      classId: classId,
      backgroundId: backgroundId ?? '',
      level: 1,
      assignedScores: {
        for (final a in Ability.values) a: assignedScores[a] ?? 10,
      },
      backgroundAbilityBonuses: abilitySpread,
      chosenSkills: [...classSkills, ...raceSkills],
      fightingStyleId: fightingStyleId,
      weaponMasteryChoices: List.of(weaponMasteries),
      featIds: [?raceFeatId],
      hpPerLevel: [hitDie],
      equippedArmorId: equippedArmorId,
      shieldEquipped: shieldEquipped,
      equippedWeaponIds: [?weaponId],
    );
  }
}
