import 'data_version.dart';

/// Quién es este combatiente: un jugador vinculado o un monstruo que sumó el
/// DM. Decide qué campos importan (`memberId` vs. `creatureId`/PG) y cómo se
/// pinta en la mesa del DM.
enum CombatantKind {
  player('Jugador'),
  monster('Monstruo');

  const CombatantKind(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Tolerante: un valor desconocido cae a [CombatantKind.monster], que es el
  /// lado que no tiene consecuencias de seguridad si se lee mal (un jugador
  /// mal clasificado sería peor: expondría el turno de alguien que no vino).
  static CombatantKind fromJson(String? v) {
    for (final k in CombatantKind.values) {
      if (k.name == v) return k;
    }
    return CombatantKind.monster;
  }
}

/// Un puesto en el orden de iniciativa.
///
/// Para un jugador, [memberId] es el vínculo (`campaign_members.id`) y no el
/// id del personaje: el mismo personaje tiene un `memberId` distinto por
/// campaña, y es lo que la consulta de turno del jugador puede resolver sin
/// ambigüedad. Para un monstruo, [creatureId] es el id del catálogo y
/// [currentHp]/[maxHp] son el único estado que el DM escribe en toda la fase.
class Combatant {
  final String id;
  final CombatantKind kind;
  final String name;
  final int initiative;
  final String? memberId;
  final String? creatureId;
  final int currentHp;
  final int maxHp;

  /// Qué le está pasando: «Envenenado», «marcado por el pícaro»,
  /// «concentrando en Bendición».
  ///
  /// **Texto libre y no un enum de las condiciones oficiales**, aunque la
  /// pantalla las ofrezca como atajo: la mitad de lo que hay que recordar en
  /// una ronda no es una condición del libro. Un enum cubriría «Envenenado» y
  /// dejaría afuera las otras dos, que son justo las que se olvidan.
  ///
  /// Son del DM y no viajan a la ficha de nadie: el jugador sabe lo que le
  /// pasa a su personaje porque se lo dijeron en la mesa.
  final List<String> tags;

  const Combatant({
    required this.id,
    required this.kind,
    required this.name,
    required this.initiative,
    this.memberId,
    this.creatureId,
    this.currentHp = 0,
    this.maxHp = 0,
    this.tags = const [],
  });

  /// Un monstruo a 0 PG está inconsciente o muerto: no le toca actuar y su
  /// turno se salta solo (ver `Encounter.next`). Nunca es cierto para un
  /// jugador — sus PG no se llevan acá, así que [maxHp] siempre da 0 y la
  /// condición no puede dispararse por accidente.
  bool get isDown =>
      kind == CombatantKind.monster && maxHp > 0 && currentHp <= 0;

  Combatant copyWith({int? currentHp, List<String>? tags, int? initiative}) =>
      Combatant(
        id: id,
        kind: kind,
        name: name,
        initiative: initiative ?? this.initiative,
        memberId: memberId,
        creatureId: creatureId,
        currentHp: currentHp ?? this.currentHp,
        maxHp: maxHp,
        tags: tags ?? this.tags,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.toJson(),
        'name': name,
        'initiative': initiative,
        if (memberId != null) 'memberId': memberId,
        if (creatureId != null) 'creatureId': creatureId,
        if (maxHp != 0) 'currentHp': currentHp,
        if (maxHp != 0) 'maxHp': maxHp,
        if (tags.isNotEmpty) 'tags': tags,
      };

  factory Combatant.fromJson(Map<String, dynamic> j) => Combatant(
        id: j['id'] as String,
        kind: CombatantKind.fromJson(j['kind'] as String?),
        name: j['name'] as String? ?? '',
        initiative: j['initiative'] as int? ?? 0,
        memberId: j['memberId'] as String?,
        creatureId: j['creatureId'] as String?,
        currentHp: j['currentHp'] as int? ?? 0,
        maxHp: j['maxHp'] as int? ?? 0,
        // Se descarta lo que no sea texto en vez de romper el combate entero:
        // un tag mal formado no vale perder el orden de iniciativa a mitad de
        // una ronda.
        tags: [
          for (final t in (j['tags'] as List? ?? const []))
            if (t is String && t.trim().isNotEmpty) t.trim(),
        ],
      );
}

/// El turno de un jugador, visto desde su propia ficha.
///
/// Deliberadamente los cuatro únicos valores que un jugador puede llegar a
/// ver: nunca el orden completo, nunca a los monstruos. Ver el orden
/// delataría cuántos enemigos hay antes de que aparezcan en la mesa real.
enum TurnStatus {
  /// No hay combate abierto para este personaje, o no está vinculado a uno.
  none,

  /// Hay combate, pero todavía no es su turno ni el siguiente.
  waiting,

  /// Es el turno de quien lo precede: "preparate, seguís vos".
  next,

  /// Es su turno.
  active;

  String toJson() => name;

  /// Tolerante: ausente o desconocido cae a [TurnStatus.none], el lado que no
  /// filtra nada — un servidor más nuevo que el cliente no puede hacer que
  /// una ficha vieja invente un aviso de turno que no entiende.
  static TurnStatus fromJson(String? v) {
    for (final s in TurnStatus.values) {
      if (s.name == v) return s;
    }
    return TurnStatus.none;
  }
}

/// En qué momento está un encuentro.
///
/// Existe porque armar la mesa y jugarla son dos cosas distintas, y hasta que
/// se separaron el jugador lo notaba: apenas el DM lo sumaba al orden, su
/// ficha le decía «Es tu turno» mientras el DM seguía cargando goblins.
enum EncounterStage {
  /// Se está armando: entran jugadores y monstruos, todavía sin iniciativa.
  /// No hay ronda, no hay turno, y **el jugador no ve nada**.
  preparing('Preparando'),

  /// Ya se tiró iniciativa y la mesa está jugando.
  running('En curso');

  const EncounterStage(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// **Un documento sin etapa se lee como [running]**, no como [preparing].
  ///
  /// Es al revés que el valor por defecto del constructor, y a propósito: los
  /// combates que ya estaban guardados cuando esto no existía estaban en
  /// curso —tenían iniciativa tirada y una ronda corriendo—, así que leerlos
  /// como «preparando» les borraría el turno a mitad de una sesión.
  static EncounterStage fromJson(String? v) {
    for (final s in EncounterStage.values) {
      if (s.name == v) return s;
    }
    return EncounterStage.running;
  }
}

/// El estado compartido de una mesa en combate.
///
/// Se llama `Encounter` y no `Combat` porque [CombatState]/`CombatOps` ya
/// existen y significan otra cosa: el estado de sesión de **un** personaje
/// (PG, espacios de conjuro, concentración). Un encuentro es el estado de
/// **la mesa entera** — jugadores y monstruos juntos — y vive en el
/// servidor porque el aviso de turno lo necesitan las dos cuentas a la vez.
///
/// La lista de [combatants] se guarda **ya ordenada** por iniciativa
/// descendente: así [turnIndex] indexa directo sobre ella y no hay forma de
/// que cliente y servidor discrepen sobre el orden.
class Encounter {
  /// Versión del formato de este documento. Mismo contrato que
  /// `Character.currentSchemaVersion` y `Campaign.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;
  final int round;
  final int turnIndex;
  final List<Combatant> combatants;

  /// Armándose o jugándose. Ver [EncounterStage] — el valor por defecto de acá
  /// es [EncounterStage.preparing] y el de `fromJson` es
  /// [EncounterStage.running], y esa asimetría es deliberada.
  final EncounterStage stage;

  const Encounter({
    required this.id,
    this.round = 1,
    this.turnIndex = 0,
    this.combatants = const [],
    this.stage = EncounterStage.preparing,
  });

  bool get isPreparing => stage == EncounterStage.preparing;

  /// La primera posición a partir de [start] (**sin** acotar a la lista)
  /// cuyo combatiente no está [Combatant.isDown], o `null` si todos lo
  /// están. Se devuelve sin aplicar `% length` a propósito: así el llamador
  /// puede distinguir "encontrado sin dar la vuelta" (posición < length) de
  /// "encontrado después de cruzar el final de la lista" (posición >=
  /// length), que es exactamente lo que separa una ronda de la siguiente.
  int? _nextStandingPosition(int start) {
    final n = combatants.length;
    if (n == 0) return null;
    for (var offset = 0; offset < n; offset++) {
      final position = start + offset;
      if (!combatants[position % n].isDown) return position;
    }
    return null;
  }

  /// Índice real del turno actual: [turnIndex] si sigue en pie, o el primer
  /// combatiente en pie a partir de ahí. Si no queda ninguno en pie, cae de
  /// vuelta en [turnIndex] tal cual — no hay nadie mejor a quién señalar.
  int get _currentIndex {
    final position = _nextStandingPosition(turnIndex);
    return (position ?? turnIndex) % combatants.length;
  }

  /// El combatiente cuyo turno es ahora, o null si no hay nadie en la mesa.
  ///
  /// Salta cualquier monstruo a 0 PG a partir de [turnIndex]: está
  /// inconsciente o muerto, no actúa.
  Combatant? get current =>
      combatants.isEmpty || isPreparing ? null : combatants[_currentIndex];

  /// El siguiente en pie después de [current], envolviendo al final de la
  /// ronda. Es a quien le llega el aviso "preparate, seguís vos" — por eso
  /// también salta caídos: avisarle a alguien que en realidad va después de
  /// un monstruo inconsciente sería mentirle sobre cuánto falta.
  Combatant? get onDeck {
    if (combatants.length < 2 || isPreparing) return null;
    final currentIndex = _currentIndex;
    final position = _nextStandingPosition(currentIndex + 1);
    if (position == null) return null;
    final index = position % combatants.length;
    return index == currentIndex ? null : combatants[index];
  }

  /// Avanza al siguiente combatiente en pie, saltando cualquier monstruo a
  /// 0 PG en el camino. Al cruzar el final de la lista vuelve al principio y
  /// suma una ronda.
  ///
  /// Si nadie sigue en pie (todos caídos), no hay a quién pasarle el turno:
  /// el encuentro queda tal cual, porque avanzar no tendría destino. Le toca
  /// al DM sacar a los caídos de la mesa o cerrar el combate.
  Encounter next() {
    // Mientras se arma no hay turno que avanzar.
    if (combatants.isEmpty || isPreparing) return this;
    final currentIndex = _currentIndex;
    final position = _nextStandingPosition(currentIndex + 1);
    if (position == null) return this;
    final wrapped = position >= combatants.length;
    return Encounter(
      id: id,
      round: wrapped ? round + 1 : round,
      turnIndex: position % combatants.length,
      combatants: combatants,
      stage: stage,
    );
  }

  /// Suma o reemplaza un combatiente (mismo [Combatant.id] = reemplazo) y
  /// reordena por iniciativa descendente. En un empate, gana quien ya estaba
  /// en la mesa: se compara también la posición original, en vez de confiar
  /// en que `List.sort` sea estable (no lo garantiza), para que sumar un
  /// segundo goblin con la misma iniciativa que el primero no lo salte
  /// adelante.
  ///
  /// [turnIndex] se recalcula buscando el id del combatiente que tenía el
  /// turno, para no perderlo en el reordenamiento — salvo que ese mismo
  /// combatiente sea el que se está reemplazando, en cuyo caso el turno se
  /// queda donde está.
  ///
  /// **Mientras se arma la mesa el orden es otro**: todavía nadie tiró
  /// iniciativa, así que ordenar por ella dejaría a todos empatados en cero y
  /// la lista saltaría sola en cuanto se tirara. En [EncounterStage.preparing]
  /// van los jugadores primero y los monstruos después, cada bando en el orden
  /// en que se cargó — así el «Goblin 2» aparece pegado al «Goblin».
  Encounter withCombatant(Combatant combatant) {
    final currentId = isPreparing || combatants.isEmpty ? null : current?.id;
    final withIndex = [
      for (final (i, c) in combatants.indexed)
        if (c.id != combatant.id) (index: i, combatant: c),
      (index: combatants.length, combatant: combatant),
    ]..sort((a, b) {
        if (isPreparing) {
          final bySide = a.combatant.kind.index.compareTo(
            b.combatant.kind.index,
          );
          return bySide != 0 ? bySide : a.index.compareTo(b.index);
        }
        final byInitiative =
            b.combatant.initiative.compareTo(a.combatant.initiative);
        return byInitiative != 0 ? byInitiative : a.index.compareTo(b.index);
      });
    final next = [for (final e in withIndex) e.combatant];
    final newIndex =
        currentId == null ? 0 : next.indexWhere((c) => c.id == currentId);
    return Encounter(
      id: id,
      round: round,
      turnIndex: newIndex < 0 ? 0 : newIndex,
      combatants: next,
      stage: stage,
    );
  }

  /// Arranca el combate con la iniciativa ya tirada: `{id del combatiente:
  /// valor}`.
  ///
  /// Es la transición de armar a jugar, y hace las tres cosas juntas a
  /// propósito — fijar los números, ordenar y pasar de etapa— porque un
  /// combate a medio arrancar no es un estado que valga la pena representar.
  ///
  /// A quien no aparezca en [initiatives] le queda la que ya tenía. El orden
  /// resultante es el de siempre: iniciativa descendente, y en un empate gana
  /// quien ya estaba en la mesa.
  Encounter start(Map<String, int> initiatives) {
    final withIndex = [
      for (final (i, c) in combatants.indexed)
        (index: i, combatant: c.copyWith(initiative: initiatives[c.id])),
    ]..sort((a, b) {
        final byInitiative =
            b.combatant.initiative.compareTo(a.combatant.initiative);
        return byInitiative != 0 ? byInitiative : a.index.compareTo(b.index);
      });

    return Encounter(
      id: id,
      round: 1,
      turnIndex: 0,
      combatants: [for (final e in withIndex) e.combatant],
      stage: EncounterStage.running,
    );
  }

  /// Saca un combatiente de la mesa, ajustando [turnIndex] para seguir
  /// apuntando al mismo combatiente que tenía el turno (o quedarse quieto si
  /// el que se fue era justo ese).
  Encounter withoutCombatant(String combatantId) {
    final currentId = current?.id;
    final next = [
      for (final c in combatants)
        if (c.id != combatantId) c,
    ];
    if (next.isEmpty) {
      return Encounter(
        id: id,
        round: round,
        turnIndex: 0,
        combatants: next,
        stage: stage,
      );
    }
    final newIndex = currentId == null || currentId == combatantId
        ? turnIndex % next.length
        : next.indexWhere((c) => c.id == currentId);
    return Encounter(
      id: id,
      round: round,
      turnIndex: newIndex < 0 ? 0 : newIndex,
      combatants: next,
      stage: stage,
    );
  }

  /// Los PG actuales de un monstruo, clampeados a `0..maxHp`. Es la única
  /// escritura del DM en toda esta fase: los PG de un jugador nunca se tocan
  /// desde acá.
  Encounter withHp(String combatantId, int hp) => Encounter(
        id: id,
        round: round,
        turnIndex: turnIndex,
        combatants: [
          for (final c in combatants)
            if (c.id == combatantId)
              c.copyWith(currentHp: hp.clamp(0, c.maxHp))
            else
              c,
        ],
        stage: stage,
      );

  /// Reemplaza los tags de un combatiente.
  ///
  /// Se pasa la lista entera y no «sumar» o «sacar» uno por lo mismo que el
  /// combate entero viaja completo en cada guardado: no hay operaciones finas
  /// que puedan desincronizarse entre sí.
  ///
  /// Se normalizan acá —sin repetidos, sin vacíos, respetando el orden en que
  /// se agregaron— para que no haga falta acordarse de hacerlo en la pantalla.
  Encounter withTags(String combatantId, List<String> tags) => Encounter(
        id: id,
        round: round,
        turnIndex: turnIndex,
        combatants: [
          for (final c in combatants)
            if (c.id == combatantId)
              c.copyWith(
                  tags: {
                for (final t in tags)
                  if (t.trim().isNotEmpty) t.trim(),
              }.toList())
            else
              c,
        ],
        stage: stage,
      );

  /// El turno de un jugador puntual, identificado por su [memberId] en esta
  /// campaña. Es la proyección que el servidor le sirve al jugador — nunca
  /// el encuentro entero.
  ///
  /// **Mientras el DM arma la mesa el jugador no ve nada.** Antes de que la
  /// etapa existiera, apenas lo sumaba al orden su ficha ya le decía «Es tu
  /// turno» —era el primero de una lista de uno— mientras el DM seguía
  /// cargando goblins. Enterarse de que hay combate antes de que empiece es
  /// justo lo que el aviso de turno no debe filtrar.
  TurnStatus statusFor(String memberId) {
    if (combatants.isEmpty || isPreparing) return TurnStatus.none;
    if (current?.memberId == memberId) return TurnStatus.active;
    if (onDeck?.memberId == memberId) return TurnStatus.next;
    final known = combatants.any((c) => c.memberId == memberId);
    return known ? TurnStatus.waiting : TurnStatus.none;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'round': round,
        'turnIndex': turnIndex,
        'combatants': [for (final c in combatants) c.toJson()],
        'stage': stage.toJson(),
      };

  factory Encounter.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    return Encounter(
      id: j['id'] as String,
      round: j['round'] as int? ?? 1,
      turnIndex: j['turnIndex'] as int? ?? 0,
      combatants: [
        for (final c in (j['combatants'] as List? ?? const []))
          Combatant.fromJson((c as Map).cast<String, dynamic>()),
      ],
      stage: EncounterStage.fromJson(j['stage'] as String?),
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del encuentro debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Campaign.migrateJson`: no muta la entrada, y
  /// rechaza una versión futura en vez de guardarla de vuelta sin los campos
  /// que esta versión del servidor no entiende.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'encuentro',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source);
  }
}
