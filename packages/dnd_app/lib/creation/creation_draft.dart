import 'package:dnd_engine/dnd_engine.dart';

/// Las 18 habilidades de 2024, tomadas del catálogo del motor.
final allSkills2024 = Skill.allIds;

/// Opciones reales de una elección de habilidad: una lista vacía significa
/// "cualquiera de las 18" (p.ej. el Bardo en 2024), no "ninguna". Es el único
/// lugar donde vive esa regla: los pickers y el gating la comparten.
List<String> skillOptions(List<String> from) =>
    from.isEmpty ? allSkills2024 : from;

/// Modo de reparto del aumento de característica del trasfondo 2024.
enum AbilitySpreadMode { twoOne, oneOneOne }

/// Método de puntuación de características (brief §3.A.4). `manual` no reparte
/// un pool: el usuario
/// escribe cada número, para digitalizar un personaje que ya existe en papel.
enum ScoreMethod { standardArray, roll4d6, manual }

/// Rango aceptado al escribir a mano. Es el rango absoluto de 5e, no el de
/// generación: si el valor sale de 3-18 el motor ya avisa (sin bloquear).
const manualScoreMin = 1;
const manualScoreMax = 30;

/// Pasos del wizard de creación, en orden. Fijos (ya no dependen de si la clase
/// lanza conjuros: los conjuros viven dentro de [equipo]).
enum CreationStep {
  raza('Raza'),
  clase('Clase'),
  trasfondo('Trasfondo'),
  puntuaciones('Puntuaciones'),
  aptitudes('Aptitudes'),
  equipo('Equipo'),
  detalles('Detalles'),
  resumen('Resumen');

  const CreationStep(this.label);
  final String label;
}

/// Estado mutable del wizard de creación. Acumula las elecciones y sabe
/// construir un [Character] con todo resuelto. La UI solo lee/escribe esto.
class CreationDraft {
  final ContentRepository repo;
  CreationDraft(this.repo);

  factory CreationDraft.fromJson(
    ContentRepository repo,
    Map<String, dynamic> json,
  ) {
    final draft = CreationDraft(repo);
    final classId = json['classId'];
    if (classId is String && repo.characterClass(classId) != null) {
      draft.classId = classId;
    }
    final raceId = json['raceId'];
    if (raceId is String && repo.race(raceId) != null) draft.raceId = raceId;
    final lineageId = json['lineageId'];
    if (lineageId is String) {
      final lineage = repo.lineage(lineageId);
      if (lineage != null && lineage.raceId == draft.raceId) {
        draft.lineageId = lineageId;
      }
    }
    final speciesSpellcastingAbility = _ability(
      json['speciesSpellcastingAbility'],
    );
    if (const {
      Ability.intelligence,
      Ability.wisdom,
      Ability.charisma,
    }.contains(speciesSpellcastingAbility)) {
      draft.speciesSpellcastingAbility = speciesSpellcastingAbility;
    }
    final backgroundId = json['backgroundId'];
    if (backgroundId is String && repo.background(backgroundId) != null) {
      draft.backgroundId = backgroundId;
    }

    // `fightingStyleId` es el formato viejo del borrador: se lee al grupo que
    // le corresponde para no perder un borrador guardado antes del cambio.
    final legacyStyle = json['fightingStyleId'];
    if (legacyStyle is String && repo.feat(legacyStyle) != null) {
      draft.featureChoices[Character.fightingStyleGroup] = [legacyStyle];
    }
    final rawChoices = json['featureChoices'];
    if (rawChoices is Map) {
      for (final e in rawChoices.entries) {
        if (e.key is! String || e.value is! List) continue;
        final ids = (e.value as List)
            .whereType<String>()
            .where((id) => repo.feat(id) != null)
            .toList();
        if (ids.isNotEmpty) draft.featureChoices[e.key as String] = ids;
      }
    }
    draft.classSkills.addAll(
      _stringList(json['classSkills']).where(allSkills2024.contains),
    );
    draft.raceSkills.addAll(
      _stringList(json['raceSkills']).where(allSkills2024.contains),
    );
    draft.weaponMasteries.addAll(
      _stringList(
        json['weaponMasteries'],
      ).where((id) => repo.weapon(id) != null),
    );
    final raceFeatId = json['raceFeatId'];
    if (raceFeatId is String && repo.feat(raceFeatId) != null) {
      draft.raceFeatId = raceFeatId;
    }
    draft.cantrips.addAll(
      _stringList(json['cantrips']).where((id) => repo.spell(id) != null),
    );
    draft.spells.addAll(
      _stringList(json['spells']).where((id) => repo.spell(id) != null),
    );

    draft.spreadMode = _enumByName(
      AbilitySpreadMode.values,
      json['spreadMode'],
      draft.spreadMode,
    );
    draft.spreadPlusTwo = _ability(json['spreadPlusTwo']);
    draft.spreadPlusOne = _ability(json['spreadPlusOne']);
    draft.scoreMethod = _enumByName(
      ScoreMethod.values,
      json['scoreMethod'],
      draft.scoreMethod,
    );
    final rawPool = json['pool'];
    final pool = rawPool is List
        ? rawPool
              .whereType<num>()
              .map((value) => value.toInt())
              .where((value) => value >= 3 && value <= 18)
              .toList()
        : null;
    if (pool != null && pool.length == 6) draft.pool = pool;

    final rawScores = json['assignedScores'];
    if (rawScores is Map) {
      if (draft.scoreMethod == ScoreMethod.manual) {
        // Sin pool que respetar: solo se acota el rango.
        for (final ability in Ability.values) {
          final value = rawScores[ability.name];
          if (value is num) draft.setManualScore(ability, value.toInt());
        }
      } else {
        final available = List<int>.of(draft.pool);
        for (final ability in Ability.values) {
          final value = rawScores[ability.name];
          if (value is num && available.remove(value.toInt())) {
            draft.assignedScores[ability] = value.toInt();
          }
        }
      }
    }

    final armorId = json['equippedArmorId'];
    if (armorId is String && repo.armorPiece(armorId) != null) {
      draft.equippedArmorId = armorId;
    }
    draft.shieldEquipped = json['shieldEquipped'] == true;
    // `weaponId` (una sola arma) es el formato viejo del borrador; se lee para
    // no perder borradores guardados antes de permitir varias armas.
    final legacyWeaponId = json['weaponId'];
    if (legacyWeaponId is String && repo.weapon(legacyWeaponId) != null) {
      draft.weaponIds.add(legacyWeaponId);
    }
    for (final id in _stringList(json['weaponIds'])) {
      if (repo.weapon(id) != null && !draft.weaponIds.contains(id)) {
        draft.weaponIds.add(id);
      }
    }
    // Cómo se empuña cada arma. Solo se leen banderas de armas realmente
    // elegidas: un borrador viejo no las trae y un id suelto no debe colarse.
    for (final entry in [
      (json['weaponOffHand'], draft.weaponOffHand),
      (json['weaponTwoHanded'], draft.weaponTwoHanded),
    ]) {
      final raw = entry.$1;
      if (raw is! Map) continue;
      for (final e in raw.entries) {
        if (e.key is String &&
            e.value is bool &&
            draft.weaponIds.contains(e.key)) {
          entry.$2[e.key as String] = e.value as bool;
        }
      }
    }
    final name = json['name'];
    if (name is String) draft.name = name;
    final alignment = json['alignment'];
    draft.alignment = CharacterAlignment.fromJson(
      alignment is String ? alignment : null,
    );
    final personalityTrait = json['personalityTrait'];
    if (personalityTrait is String) {
      draft.personalityTrait = personalityTrait;
    }
    return draft;
  }

  // Clase (por ahora, única del MVP).
  String classId = 'fighter';

  /// Elecciones abiertas resueltas: id de grupo → ids de opción.
  final Map<String, List<String>> featureChoices = {};
  final Set<String> classSkills = {};
  final List<String> weaponMasteries = [];

  // Orígenes.
  String? raceId;
  String? lineageId;
  Ability? speciesSpellcastingAbility;
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

  /// Armas equipadas, en orden. Varias son legítimas (por ejemplo un pícaro con
  /// dos dagas): el motor genera un ataque por cada una.
  final List<String> weaponIds = [];

  /// Cómo se empuña cada arma elegida. Cambian el ataque que produce el motor,
  /// así que viajan con el borrador como cualquier otra elección.
  final Map<String, bool> weaponOffHand = {};
  final Map<String, bool> weaponTwoHanded = {};

  String name = '';

  // Detalles de sabor.
  CharacterAlignment? alignment;
  String personalityTrait = '';

  Map<String, dynamic> toJson() => {
    'classId': classId,
    'featureChoices': featureChoices,
    'classSkills': classSkills.toList(),
    'weaponMasteries': weaponMasteries,
    'raceId': raceId,
    'lineageId': lineageId,
    'speciesSpellcastingAbility': speciesSpellcastingAbility?.name,
    'raceSkills': raceSkills.toList(),
    'raceFeatId': raceFeatId,
    'backgroundId': backgroundId,
    'cantrips': cantrips.toList(),
    'spells': spells.toList(),
    'spreadMode': spreadMode.name,
    'spreadPlusTwo': spreadPlusTwo?.name,
    'spreadPlusOne': spreadPlusOne?.name,
    'scoreMethod': scoreMethod.name,
    'pool': pool,
    'assignedScores': {
      for (final entry in assignedScores.entries) entry.key.name: entry.value,
    },
    'equippedArmorId': equippedArmorId,
    'shieldEquipped': shieldEquipped,
    'weaponIds': weaponIds,
    'weaponOffHand': weaponOffHand,
    'weaponTwoHanded': weaponTwoHanded,
    'name': name,
    'alignment': alignment?.toJson(),
    'personalityTrait': personalityTrait,
  };

  CharacterClass? get klass => repo.characterClass(classId);
  Race? get race => raceId == null ? null : repo.race(raceId!);
  List<Lineage> get lineageOptions =>
      raceId == null ? const [] : repo.lineagesForRace(raceId!);
  Lineage? get lineage {
    final value = lineageId == null ? null : repo.lineage(lineageId!);
    return value?.raceId == raceId ? value : null;
  }

  bool get lineageUsesSpellcastingAbility =>
      lineage?.features.any(
        (feature) =>
            feature.effects.any((effect) => effect is GrantSpellEffect),
      ) ??
      false;

  Background? get background =>
      backgroundId == null ? null : repo.background(backgroundId!);

  /// Armas con las que la clase elegida es competente. La Maestría de Armas
  /// 2024 solo puede aplicarse a estas.
  List<Weapon> get proficientWeapons {
    final k = klass;
    if (k == null) return const [];
    return repo.weaponsSorted
        .where((w) => w.isProficientWith(k.weaponProficiencies))
        .toList();
  }

  /// Si la clase elegida lanza conjuros (tiene un SpellcastingEffect a nivel 1).
  bool get isCaster =>
      klass
          ?.featuresUpTo(1)
          .any((f) => f.effects.any((e) => e is SpellcastingEffect)) ??
      false;

  ComputedSheet? _sheetCache;
  String? _sheetSig;

  /// Ficha compilada de previsualización, memoizada según lo que la afecta.
  ///
  /// Es la única fuente de lo derivado que necesita el wizard: cupos de
  /// conjuros, espacios de maestría y elecciones abiertas salen de acá, no de
  /// recorrer los rasgos de la clase a mano. Antes había tres cachés que
  /// compilaban por separado y cada consumidor rearmaba su propia regla.
  ComputedSheet get previewSheet {
    final sig = [
      classId,
      raceId,
      lineageId,
      speciesSpellcastingAbility?.name,
      backgroundId,
      raceFeatId,
      spreadMode.name,
      spreadPlusTwo?.name,
      spreadPlusOne?.name,
      for (final e in featureChoices.entries) '${e.key}:${e.value.join(",")}',
      for (final a in Ability.values) assignedScores[a] ?? 10,
    ].join('|');
    if (sig != _sheetSig) {
      _sheetCache = CharacterCompiler(repo).compile(build());
      _sheetSig = sig;
    }
    return _sheetCache!;
  }

  /// Espacios de Maestría de Armas que otorga la clase a nivel 1 (Guerrero 3,
  /// Bárbaro/Pícaro 2, Monje 0…).
  int get weaponMasterySlots => previewSheet.weaponMasterySlots;

  /// Elecciones abiertas a resolver a nivel 1 (Estilo de Combate del Guerrero,
  /// Invocaciones del Brujo). Las declara el contenido, así que sumar una clase
  /// o un catálogo nuevo no toca este archivo.
  List<FeatureChoiceSlot> get featureChoiceSlots =>
      previewSheet.featureChoiceSlots;

  /// Bloque de lanzamiento derivado (cupos de trucos/preparados y CD).
  Spellcasting? get spellcasting => isCaster ? previewSheet.spellcasting : null;

  /// Ids de conjuros ya concedidos por rasgos (linaje, dote de origen), fuera
  /// de la magia de clase. No deben poder elegirse de nuevo: el rasgo ya los da
  /// "siempre preparados" y gratis, así que gastar un cupo de clase en ellos no
  /// suma nada. Cubre trucos (Prestidigitación del Alto Elfo) y conjuros con
  /// nivel (Detectar Magia a nivel 3, Paso Brumoso a nivel 5).
  Set<String> get grantedSpellIds => {
    for (final s in previewSheet.innateSpells) s.spellId,
  };

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

  /// Fija el pool de puntuaciones según el método. En `manual` no hay pool que
  /// repartir: se deja el anterior intacto (queda sin usar) para que volver a
  /// un método con pool no obligue a tirar de nuevo sin querer.
  void applyScoreMethod(ScoreMethod method, {Dice? dice}) {
    scoreMethod = method;
    assignedScores.clear();
    switch (method) {
      case ScoreMethod.standardArray:
        pool = List.of(standardArray);
      case ScoreMethod.roll4d6:
        pool = (dice ?? Dice()).rollAbilityScoreSet();
      case ScoreMethod.manual:
        break;
    }
  }

  /// Escribe [v] directamente en [a] (solo modo manual). `null` la deja sin
  /// asignar. Fuera de [manualScoreMin]-[manualScoreMax] se ignora.
  void setManualScore(Ability a, int? v) {
    if (v == null) {
      assignedScores.remove(a);
      return;
    }
    if (v < manualScoreMin || v > manualScoreMax) return;
    assignedScores[a] = v;
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

  /// Qué otras características tienen tomado cada valor. Una tirada de 4d6
  /// puede repetir valores, y dos "14" en la lista son indistinguibles: con
  /// esto el paso 4 puede etiquetarlos ("14 · en DES") en vez de mostrar dos
  /// entradas idénticas.
  Map<int, List<Ability>> holdersExcept(Ability a) {
    final m = <int, List<Ability>>{};
    for (final e in assignedScores.entries) {
      if (e.key == a) continue;
      (m[e.value] ??= []).add(e.key);
    }
    return m;
  }

  /// Cuántas copias de [v] quedan libres en el pool, ignorando lo que tenga [a].
  int freeCopiesOf(int v, Ability a) {
    final total = pool.where((x) => x == v).length;
    final taken = holdersExcept(a)[v]?.length ?? 0;
    return total - taken;
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

  /// Cuántas habilidades de [from] siguen elegibles tras excluir las ya tomadas
  /// en otro origen ([disabled]).
  int _selectableSkills(List<String> from, Set<String> disabled) =>
      skillOptions(from).toSet().difference(disabled).length;

  /// Elecciones obligatorias que faltan en [step]. Lista vacía = el paso está
  /// completo y se puede avanzar. La UI la usa para bloquear "Siguiente",
  /// explicar qué falta y decidir a qué pasos se puede saltar desde el stepper.
  ///
  /// El requerido de habilidades se acota a lo realmente elegible: si otro
  /// origen ya tomó opciones y quedan menos que el cupo, se exige solo lo
  /// posible (así el gate nunca deja al usuario sin salida).
  List<String> pendingFor(CreationStep step) {
    switch (step) {
      case CreationStep.raza:
        if (race == null) return const ['Elegí una especie.'];
        if (lineageOptions.isNotEmpty && lineage == null) {
          return const ['Elegí un linaje de especie.'];
        }
        if (lineageUsesSpellcastingAbility &&
            speciesSpellcastingAbility == null) {
          return const ['Elegí la aptitud mágica del linaje.'];
        }
        return const [];

      case CreationStep.clase:
        final k = klass;
        if (k == null) return const ['Elegí una clase.'];
        final out = <String>[];
        // Genérico sobre lo que declara el contenido: sumar una clase con otra
        // elección abierta no toca este gating.
        for (final slot in featureChoiceSlots) {
          final chosen = featureChoices[slot.groupId]?.length ?? 0;
          if (chosen < slot.count) {
            out.add('${slot.name}: $chosen/${slot.count}.');
          }
        }
        final slots = weaponMasterySlots;
        if (slots > 0 && weaponMasteries.length < slots) {
          out.add('Maestría de armas: ${weaponMasteries.length}/$slots.');
        }
        return out;

      case CreationStep.trasfondo:
        if (background == null) return const ['Elegí un trasfondo.'];
        if (spreadMode == AbilitySpreadMode.twoOne &&
            (spreadPlusTwo == null || spreadPlusOne == null)) {
          return const ['Asigná el +2 y el +1 de característica.'];
        }
        return const [];

      case CreationStep.puntuaciones:
        if (!allScoresAssigned) {
          final n = Ability.values.where(assignedScores.containsKey).length;
          return ['Asigná las 6 características ($n/6).'];
        }
        return const [];

      case CreationStep.aptitudes:
        final out = <String>[];
        final k = klass;
        if (k != null) {
          final selectable = _selectableSkills(k.skillChoiceFrom, {
            ...raceSkills,
            ...?background?.skillProficiencies,
          });
          final need = k.skillChoiceCount < selectable
              ? k.skillChoiceCount
              : selectable;
          if (classSkills.length < need) {
            out.add(
              'Habilidades de clase: ${classSkills.length}/'
              '${k.skillChoiceCount}.',
            );
          }
        }
        final r = race;
        if (r != null) {
          final selectable = _selectableSkills(r.skillChoiceFrom, {
            ...classSkills,
            ...?background?.skillProficiencies,
          });
          final need = r.skillChoiceCount < selectable
              ? r.skillChoiceCount
              : selectable;
          if (need > 0 && raceSkills.length < need) {
            out.add(
              'Habilidades de especie: ${raceSkills.length}/'
              '${r.skillChoiceCount}.',
            );
          }
          final grantsFeat = r.effects.any((e) => e is GrantFeatEffect);
          if (grantsFeat && raceFeatId == null) {
            out.add('Elegí una dote de origen.');
          }
        }
        return out;

      case CreationStep.equipo:
        // El equipo no obliga (sin arma = puños, sin armadura es válido); los
        // conjuros sí, para las clases lanzadoras.
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

      case CreationStep.detalles:
      case CreationStep.resumen:
        return const [];
    }
  }

  /// Primer paso incompleto (o el último si está todo listo). El wizard lo usa
  /// para no dejar al usuario varado en un paso que dejó de ser alcanzable.
  CreationStep get firstIncompleteStep {
    for (final s in CreationStep.values) {
      if (pendingFor(s).isNotEmpty) return s;
    }
    return CreationStep.values.last;
  }

  /// Se puede entrar a [step] solo si todos los anteriores están completos.
  /// Así el stepper sirve para volver, pero nunca para saltear validaciones.
  bool canGoTo(CreationStep step) {
    for (final s in CreationStep.values) {
      if (s.index >= step.index) break;
      if (pendingFor(s).isNotEmpty) return false;
    }
    return true;
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
      lineageId: lineage?.id,
      speciesSpellcastingAbility: speciesSpellcastingAbility,
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
      featureChoices: {
        for (final e in featureChoices.entries) e.key: List.of(e.value),
      },
      weaponMasteryChoices: List.of(weaponMasteries),
      featIds: [?raceFeatId],
      hpPerLevel: [hitDie],
      equippedArmorId: equippedArmorId,
      shieldEquipped: shieldEquipped,
      equippedWeaponIds: List.of(weaponIds),
      weaponOffHand: Map.of(weaponOffHand),
      weaponTwoHanded: Map.of(weaponTwoHanded),
      alignment: alignment,
      personalityTrait: personalityTrait.trim(),
    );
  }
}

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

Ability? _ability(Object? value) {
  if (value is! String) return null;
  for (final ability in Ability.values) {
    if (ability.name == value) return ability;
  }
  return null;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final value in values) {
      if (value.name == name) return value;
    }
  }
  return fallback;
}
