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

  // Conjuros elegidos (para clases lanzadoras).
  final Set<String> cantrips = {};
  final Set<String> spells = {};

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

  /// Espacios de Maestría de Armas que otorga la clase a nivel 1 (Guerrero 3,
  /// Bárbaro/Pícaro 2, Monje 0…). Se lee de los efectos de la clase, no se
  /// hardcodea.
  int get weaponMasterySlots {
    final k = klass;
    if (k == null) return 0;
    var slots = 0;
    for (final f in k.featuresUpTo(1)) {
      for (final e in f.effects) {
        if (e is WeaponMasterySlotsEffect && e.count > slots) slots = e.count;
      }
    }
    return slots;
  }

  /// Si la clase concede una elección de Estilo de Combate (dato de la clase).
  bool get grantsFightingStyle => klass?.grantsFightingStyle ?? false;

  /// Si la clase elegida lanza conjuros (tiene un SpellcastingEffect a nivel 1).
  bool get isCaster => klass?.featuresUpTo(1).any(
          (f) => f.effects.any((e) => e is SpellcastingEffect)) ??
      false;

  Spellcasting? _scCache;
  String? _scSig;

  /// Bloque de lanzamiento derivado de las elecciones actuales (para saber
  /// cupos de trucos/preparados y CD en el paso de conjuros). Se memoiza según
  /// las entradas que lo afectan (clase, características, trasfondo/dote): elegir
  /// trucos/conjuros no cambia el bloque, así que no recompila la ficha.
  Spellcasting? get spellcasting {
    if (!isCaster) return null;
    final sig = [
      classId, raceId, backgroundId, raceFeatId,
      spreadMode.name, spreadPlusTwo?.name, spreadPlusOne?.name,
      for (final a in Ability.values) assignedScores[a] ?? 10,
    ].join('|');
    if (sig != _scSig) {
      _scCache = CharacterCompiler(repo).compile(build()).spellcasting;
      _scSig = sig;
    }
    return _scCache;
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

  /// Asigna [v] a la característica [a]. Si [v] ya está tomada por otra y no
  /// queda una copia libre en el pool, **intercambia**: la otra recibe el valor
  /// que tenía [a] (o queda sin asignar si [a] no tenía). Así se puede reordenar
  /// libremente aunque estén las 6 asignadas.
  void assignScore(Ability a, int v) {
    if (availableFor(a).contains(v)) {
      assignedScores[a] = v;
      return;
    }
    final previous = assignedScores[a];
    Ability? holder;
    for (final e in assignedScores.entries) {
      if (e.key != a && e.value == v) {
        holder = e.key;
        break;
      }
    }
    assignedScores[a] = v;
    if (holder != null) {
      if (previous != null) {
        assignedScores[holder] = previous;
      } else {
        assignedScores.remove(holder);
      }
    }
  }

  /// Borra todas las asignaciones (conserva método y pool). Escape para
  /// reordenar de cero.
  void clearScores() => assignedScores.clear();

  /// Elecciones obligatorias que faltan en [stepTitle]. Lista vacía = el paso
  /// está completo y se puede avanzar. La UI la usa para bloquear "Siguiente" y
  /// explicar qué falta.
  List<String> pendingFor(String stepTitle) {
    switch (stepTitle) {
      case 'Clase':
        final k = klass;
        if (k == null) return const ['Elegí una clase.'];
        final out = <String>[];
        if (grantsFightingStyle && fightingStyleId == null) {
          out.add('Elegí un estilo de combate.');
        }
        if (classSkills.length < k.skillChoiceCount) {
          out.add('Habilidades de clase: ${classSkills.length}/'
              '${k.skillChoiceCount}.');
        }
        final slots = weaponMasterySlots;
        if (slots > 0 && weaponMasteries.length < slots) {
          out.add('Maestría de armas: ${weaponMasteries.length}/$slots.');
        }
        return out;
      case 'Especie':
        final r = race;
        if (r == null) return const ['Elegí una especie.'];
        final out = <String>[];
        if (r.skillChoiceCount > 0 && raceSkills.length < r.skillChoiceCount) {
          out.add('Habilidades de especie: ${raceSkills.length}/'
              '${r.skillChoiceCount}.');
        }
        final grantsFeat = r.effects.any((e) => e is GrantFeatEffect);
        if (grantsFeat && raceFeatId == null) {
          out.add('Elegí una dote de origen.');
        }
        return out;
      case 'Trasfondo':
        if (background == null) return const ['Elegí un trasfondo.'];
        if (spreadMode == AbilitySpreadMode.twoOne &&
            (spreadPlusTwo == null || spreadPlusOne == null)) {
          return const ['Asigná el +2 y el +1 de característica.'];
        }
        return const [];
      case 'Características':
        if (!allScoresAssigned) {
          final n = Ability.values.where(assignedScores.containsKey).length;
          return ['Asigná las 6 características ($n/6).'];
        }
        return const [];
      case 'Conjuros':
        final sc = spellcasting;
        if (sc == null) return const [];
        final out = <String>[];
        if (cantrips.length < sc.cantripsKnown) {
          out.add('Trucos: ${cantrips.length}/${sc.cantripsKnown}.');
        }
        if (spells.length < sc.preparedCount) {
          out.add('Conjuros: ${spells.length}/${sc.preparedCount}.');
        }
        return out;
      default: // Equipo, Nombre: sin elecciones obligatorias.
        return const [];
    }
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
      cantripIds: cantrips.toList(),
      spellIds: spells.toList(),
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
