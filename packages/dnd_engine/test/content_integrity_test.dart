import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Chequeos de integridad sobre el contenido real del SRD 2024. Atrapa datos
/// mal referenciados (una dote inexistente, una maestría inválida) apenas se
/// cargan, sin necesidad de recorrer la app.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  // Las 8 propiedades de Maestría de Armas del PHB 2024.
  const validMasteries = {
    'cleave',
    'graze',
    'nick',
    'push',
    'sap',
    'slow',
    'topple',
    'vex',
  };
  const validWeaponCategories = {'simple', 'martial'};
  const validArmorCategories = {'light', 'medium', 'heavy', 'shield'};

  const casterClasses = {
    'wizard',
    'sorcerer',
    'bard',
    'warlock',
    'cleric',
    'druid',
    'paladin',
    'ranger',
    'artificer',
  };

  test('el catálogo se cargó con volumen razonable', () {
    expect(repo.weapons.length, greaterThanOrEqualTo(30));
    expect(repo.armor.length, greaterThanOrEqualTo(12));
    expect(repo.races.length, greaterThanOrEqualTo(10));
    expect(repo.backgrounds.length, greaterThanOrEqualTo(12));
    expect(repo.spells.length, greaterThanOrEqualTo(150));
    expect(repo.feats.length, greaterThanOrEqualTo(50));
  });

  test('los conjuros cubren los niveles 0 a 9', () {
    final levels = repo.spells.values.map((s) => s.level).toSet();
    for (var l = 0; l <= 9; l++) {
      expect(levels, contains(l),
          reason: 'falta al menos un conjuro de nivel $l');
    }
  });

  test('cada conjuro tiene nivel válido y clases lanzadoras conocidas', () {
    for (final s in repo.spells.values) {
      expect(s.level, inInclusiveRange(0, 9),
          reason: '${s.id}: nivel inválido');
      expect(s.classes, isNotEmpty, reason: '${s.id}: sin clases');
      for (final c in s.classes) {
        expect(casterClasses, contains(c),
            reason: '${s.id}: clase lanzadora desconocida "$c"');
      }
    }
  });

  test('ningún contenido oficial cae en homebrew ni en una edición vieja', () {
    // `ContentSource.fromJson` degrada cualquier etiqueta desconocida a
    // homebrew sin avisar. Este test es la red que convierte una etiqueta mal
    // escrita en un fallo visible en vez de una degradación silenciosa: el
    // Aasimar ya venía marcado `phb_2024` y se cargaba como homebrew.
    final sources = <String, ContentSource>{
      for (final e in repo.races.values) 'raza ${e.id}': e.source,
      for (final e in repo.classes.values) 'clase ${e.id}': e.source,
      for (final e in repo.subclasses.values) 'subclase ${e.id}': e.source,
      for (final e in repo.lineages.values) 'linaje ${e.id}': e.source,
      for (final e in repo.backgrounds.values) 'trasfondo ${e.id}': e.source,
      for (final e in repo.feats.values) 'dote ${e.id}': e.source,
      for (final e in repo.weapons.values) 'arma ${e.id}': e.source,
      for (final e in repo.armor.values) 'armadura ${e.id}': e.source,
      for (final e in repo.spells.values) 'conjuro ${e.id}': e.source,
    };
    sources.forEach((label, source) {
      expect(
          source,
          anyOf(ContentSource.srd2024, ContentSource.phb2024,
              ContentSource.foa2025),
          reason: '$label: procedencia inesperada');
    });
  });

  test('el SRD 5.2.1 aporta exactamente una subclase por clase', () {
    // El SRD incluye 12 subclases; las otras 36 son PHB 2024 y no están
    // cubiertas por la atribución CC BY 4.0.
    const srdSubclasses = {
      'champion',
      'berserker',
      'college-lore',
      'life-domain',
      'circle-land',
      'open-hand',
      'oath-devotion',
      'hunter',
      'thief',
      'draconic-sorcery',
      'fiend-patron',
      'evoker',
    };
    final tagged = repo.subclasses.values
        .where((s) => s.source == ContentSource.srd2024)
        .map((s) => s.id)
        .toSet();
    expect(tagged, equals(srdSubclasses));
    // Solo las clases del SRD tienen que aportar una: el Artífice de Forge of
    // the Artificer es foa_2025 y no tiene ninguna subclase srd_2024.
    for (final klass in repo.classes.values
        .where((c) => c.source == ContentSource.srd2024)) {
      final srdForClass = repo
          .subclassesForClass(klass.id)
          .where((s) => s.source == ContentSource.srd2024);
      expect(srdForClass, hasLength(1),
          reason: '${klass.id} debe tener exactamente una subclase del SRD');
    }
  });

  test('solo las dotes del SRD 5.2.1 quedan etiquetadas como tales', () {
    // El SRD trae 17 dotes; de esas, 9 están en este catálogo.
    const srdFeats = {
      'alert',
      'savage-attacker',
      'skilled',
      'magic-initiate-wizard',
      'magic-initiate-cleric',
      'grappler',
      'fs-defense',
      'fs-archery',
      'fs-great-weapon',
    };
    final tagged = repo.feats.values
        .where((f) => f.source == ContentSource.srd2024)
        .map((f) => f.id)
        .toSet();
    expect(tagged, equals(srdFeats));
  });

  test('solo los trasfondos del SRD 5.2.1 quedan etiquetados como tales', () {
    // El SRD trae exactamente estos 4 trasfondos; los otros 12 son PHB 2024
    // y no están cubiertos por la atribución CC BY 4.0.
    const srdBackgrounds = {'criminal', 'soldier', 'acolyte', 'sage'};
    final tagged = repo.backgrounds.values
        .where((b) => b.source == ContentSource.srd2024)
        .map((b) => b.id)
        .toSet();
    expect(tagged, equals(srdBackgrounds));
  });

  test('cada conjuro declara una de las ocho escuelas', () {
    // El catálogo tenía "Necromancia" conviviendo con "Nigromancia": un solo
    // conjuro con la escuela mal escrita y ningún test que lo viera.
    const validSchools = {
      'Abjuración',
      'Adivinación',
      'Conjuración',
      'Encantamiento',
      'Evocación',
      // El PHB 2024 en español dice "Ilusionismo", no "Ilusión".
      'Ilusionismo',
      'Nigromancia',
      'Transmutación',
    };
    for (final s in repo.spells.values) {
      expect(validSchools, contains(s.school),
          reason: '${s.id}: escuela desconocida "${s.school}"');
    }
  });

  test('los tiempos de lanzamiento usan la convención 2024', () {
    // 2024 dice "Acción", no "1 acción" como en 2014.
    final duration = RegExp(r'^\d+ (minuto|minutos|hora|horas)$');
    for (final s in repo.spells.values) {
      final ct = s.castingTime;
      final ok = ct == 'Acción' ||
          ct == 'Acción Adicional' ||
          ct.startsWith('Reacción') ||
          duration.hasMatch(ct);
      expect(ok, isTrue,
          reason: '${s.id}: tiempo de lanzamiento fuera de convención "$ct"');
    }
  });

  test('los alcances de conjuro están en pies, no en metros', () {
    // Había un único "Personal (9 m)" entre 177 conjuros en pies.
    final metric = RegExp(r'\d+\s?m\b');
    for (final s in repo.spells.values) {
      expect(metric.hasMatch(s.range), isFalse,
          reason: '${s.id}: alcance en métrico "${s.range}"');
    }
  });

  test('un conjuro con concentración no puede ser instantáneo', () {
    for (final s in repo.spells.values.where((s) => s.concentration)) {
      expect(s.duration, isNot('Instantánea'),
          reason: '${s.id}: concentración con duración instantánea');
    }
  });

  test('cada dote general con prerrequisito de competencia lo referencia bien',
      () {
    const knownProfs = {
      'light',
      'medium',
      'heavy',
      'shield',
      'simple',
      'martial',
      'spellcasting',
    };
    for (final f in repo.feats.values) {
      final prof = f.prerequisite?.requiredProficiency;
      if (prof == null) continue;
      expect(knownProfs, contains(prof),
          reason: '${f.id}: prerrequisito de competencia desconocido "$prof"');
    }
  });

  test('cada dote declara una categoría conocida', () {
    const validCategories = {
      'origin',
      'general',
      'fighting-style',
      'dragonmark',
      'epic-boon',
      // No es una dote que se tome en un ASI: es el catálogo de opciones de una
      // elección abierta, que reusa `Feat` para no duplicar prerrequisitos.
      'warlock-invocation',
    };
    for (final f in repo.feats.values) {
      expect(validCategories, contains(f.category),
          reason: '${f.id}: categoría de dote desconocida "${f.category}"');
    }
  });

  test('el catálogo incluye las 21 dotes del PHB que faltaban', () {
    const expected = {
      'ability-score-improvement': ('Mejora de Característica', 'general'),
      'martial-weapon-training': (
        'Entrenamiento con Armas Marciales',
        'general',
      ),
      'weapon-master': ('Maestro de Armas', 'general'),
      'fs-blind-fighting': ('Lucha a Ciegas', 'fighting-style'),
      'fs-interception': ('Intercepción', 'fighting-style'),
      'fs-protection': ('Protección', 'fighting-style'),
      'fs-thrown-weapon-fighting': (
        'Combate con Armas Arrojadizas',
        'fighting-style',
      ),
      'fs-two-weapon-fighting': (
        'Combate con Dos Armas',
        'fighting-style',
      ),
      'fs-unarmed-fighting': ('Combate sin Armas', 'fighting-style'),
      'boon-of-fortitude': ('Don de la Fortaleza', 'epic-boon'),
      'boon-of-skill': ('Don de la Habilidad', 'epic-boon'),
      'boon-of-combat-prowess': (
        'Don de la Pericia en Combate',
        'epic-boon',
      ),
      'boon-of-recovery': ('Don de la Recuperación', 'epic-boon'),
      'boon-of-energy-resistance': (
        'Don de la Resistencia a Energías',
        'epic-boon',
      ),
      'boon-of-speed': ('Don de la Velocidad', 'epic-boon'),
      'boon-of-truesight': ('Don de la Visión Verdadera', 'epic-boon'),
      'boon-of-irresistible-offense': (
        'Don del Ataque Imparable',
        'epic-boon',
      ),
      'boon-of-fate': ('Don del Destino', 'epic-boon'),
      'boon-of-the-night-spirit': (
        'Don del Espíritu de la Noche',
        'epic-boon',
      ),
      'boon-of-spell-recall': (
        'Don del Recuerdo de Conjuros',
        'epic-boon',
      ),
      'boon-of-dimensional-travel': (
        'Don del Viaje Dimensional',
        'epic-boon',
      ),
    };

    for (final entry in expected.entries) {
      final feat = repo.feat(entry.key);
      expect(feat, isNotNull, reason: 'falta ${entry.key}');
      expect(feat!.name, entry.value.$1, reason: entry.key);
      expect(feat.category, entry.value.$2, reason: entry.key);
      expect(feat.source, ContentSource.phb2024, reason: entry.key);
    }
    expect(repo.feat('mobile'), isNull,
        reason: 'Ágil/Mobile es la dote 2014 reemplazada por Veloz en 2024');
  });

  test('las 75 dotes canónicas del PHB están representadas', () {
    // Solo las categorías que son **dotes**: `warlock-invocation` reusa `Feat`
    // como catálogo de una elección abierta, pero no es una dote y no entra en
    // este conteo. Sin este filtro, cargar invocaciones rompería el test.
    const featCategories = {
      'origin',
      'general',
      'fighting-style',
      'epic-boon',
    };
    final phb = repo.feats.values
        .where(
          (f) =>
              (f.source == ContentSource.phb2024 ||
                  f.source == ContentSource.srd2024) &&
              featCategories.contains(f.category),
        )
        .toList();
    // Son 90 registros porque Iniciado en la Magia se divide en 3 listas
    // (+2), Resiliente en 6 características (+5), y Chef, Triturador,
    // Perforador y Rebanador en 2 características cada uno (+4) e Influencia
    // Feérica/Sombría en 3 cada uno (+4): sus bonos de característica eran
    // a elegir en el libro, no fijos.
    expect(phb, hasLength(90));
    expect(phb.where((f) => f.category == 'origin'), hasLength(12));
    expect(phb.where((f) => f.category == 'general'), hasLength(56));
    expect(phb.where((f) => f.category == 'fighting-style'), hasLength(10));
    expect(phb.where((f) => f.category == 'epic-boon'), hasLength(12));
  });

  test('las dotes usan el nombre del capítulo 5, no una traducción propia', () {
    // Una tanda de verificación contra el manual encontró 33 dotes con nombre
    // inventado. El id sigue siendo el nombre en inglés y es la clave que viaja
    // en los personajes guardados, así que renombrar es seguro; lo que hace
    // falta es que no se vuelva a desviar.
    //
    // Se fijan los casos que estaban mal, incluidos los dos pares que se
    // parecen lo bastante como para intercambiarse: Maestro en Armaduras
    // Pesadas (Heavy Armor Master) y Maestro en Armas Pesadas (Great Weapon
    // Master); Combate con Dos Armas (estilo) y Combatiente con Dos Armas
    // (dote general).
    const oficiales = <String, String>{
      'tough': 'Duro',
      'crafter': 'Fabricante',
      'skilled': 'Habilidoso',
      'charger': 'Atacante a la Carga',
      'mage-slayer': 'Azote de Magos',
      'dual-wielder': 'Combatiente con Dos Armas',
      'crossbow-expert': 'Experto en Ballestas',
      'war-caster': 'Lanzador en Combate',
      'spell-sniper': 'Lanzador Preciso',
      'ritual-caster': 'Lanzador Ritual',
      'medium-armor-master': 'Maestro en Armaduras Medias',
      'heavy-armor-master': 'Maestro en Armaduras Pesadas',
      'polearm-master': 'Maestro en Armas de Asta',
      'great-weapon-master': 'Maestro en Armas Pesadas',
      'shield-master': 'Maestro en Escudos',
      'heavily-armored': 'Muy Acorazado',
      'telepathic': 'Telepático',
      'sharpshooter': 'Tirador de Primera',
      'elemental-adept': 'Versado en un Elemento',
      'fs-great-weapon': 'Combate con Armas a Dos Manos',
      'fs-two-weapon-fighting': 'Combate con Dos Armas',
      'fs-defense': 'Defensa',
      'fs-dueling': 'Duelo',
      'fs-archery': 'Tiro con Arco',
    };
    for (final e in oficiales.entries) {
      expect(repo.feat(e.key)?.name, e.value, reason: e.key);
    }
    // El trasfondo Artesano existía a la vez que una dote homónima; renombrar
    // la dote a Fabricante deshizo esa colisión.
    expect(repo.background('artisan')?.name, 'Artesano');
  });

  test('Ligeramente y Moderadamente Acorazado reparten bien los escudos', () {
    // Los escudos estaban en la dote equivocada: el manual los da con la
    // armadura ligera, no con la media.
    List<String> armaduras(String id) => repo
        .feat(id)!
        .effects
        .whereType<ArmorProficiencyEffect>()
        .map((e) => e.category)
        .toList();

    expect(armaduras('lightly-armored'), containsAll(['light', 'shield']));
    expect(armaduras('moderately-armored'), ['medium']);
    expect(armaduras('heavily-armored'), ['heavy']);
  });

  test('están las 28 invocaciones del capítulo 3', () {
    final invocations = repo.featsByCategory('warlock-invocation');
    expect(invocations, hasLength(28));

    // Los tres pactos. El del Talismán es de 2014 y no está en 2024.
    expect(
        invocations.map((f) => f.id),
        containsAll(<String>[
          'pact-of-the-chain',
          'pact-of-the-blade',
          'pact-of-the-tome',
        ]));
    expect(
      invocations.map((f) => f.name).where((n) => n.contains('Talismán')),
      isEmpty,
    );

    // Se etiquetan phb_2024: no está verificado cuáles cubre el SRD 5.2.1 y
    // reclamar cobertura sin certeza es el error que la licencia no perdona.
    for (final f in invocations) {
      expect(f.source, ContentSource.phb2024, reason: f.id);
    }

    // Las cuatro repetibles del capítulo, ni una más.
    expect(
      invocations.where((f) => f.repeatable).map((f) => f.id).toSet(),
      {
        'agonizing-blast',
        'repelling-blast',
        'eldritch-spear',
        'lessons-of-the-first-ones',
      },
    );
  });

  test('los prerrequisitos entre invocaciones apuntan a ids reales', () {
    // Una cadena rota no rompe nada visible: la opción simplemente nunca se
    // ofrece, que es la clase de error que no avisa.
    final invocations = repo.featsByCategory('warlock-invocation');
    final ids = invocations.map((f) => f.id).toSet();
    for (final f in invocations) {
      for (final required in f.prerequisite?.requiredFeatIds ?? const []) {
        expect(ids, contains(required), reason: '${f.id} exige "$required"');
      }
    }
    // Y la cadena más larga del capítulo se sostiene.
    expect(
      repo.feat('devouring-blade')!.prerequisite!.requiredFeatIds,
      ['thirsting-blade'],
    );
    expect(
      repo.feat('thirsting-blade')!.prerequisite!.requiredFeatIds,
      ['pact-of-the-blade'],
    );
  });

  test('los conjuros que conceden las invocaciones existen', () {
    for (final f in repo.featsByCategory('warlock-invocation')) {
      for (final e in f.effects.whereType<GrantSpellEffect>()) {
        expect(repo.spell(e.spellId), isNotNull,
            reason: '${f.id} concede "${e.spellId}"');
      }
    }
  });

  test('los diez estilos exigen el rasgo Estilo de Combate', () {
    final styles =
        repo.feats.values.where((f) => f.category == 'fighting-style').toList();
    expect(styles, hasLength(10));
    for (final feat in styles) {
      expect(
        feat.prerequisite?.requiredClassFeature,
        'Estilo de Combate',
        reason: feat.id,
      );
    }
  });

  test('Resiliente ofrece las seis características pero solo permite una', () {
    final resilient =
        repo.feats.values.where((f) => f.id.startsWith('resilient-')).toList();
    expect(resilient, hasLength(6));
    expect(resilient.map((f) => f.exclusiveGroup).toSet(), {'resilient'});
  });

  test('Resiliente y Resistente no se pisan el nombre', () {
    // El capítulo 5 trae las dos como dotes distintas: Resiliente da +1 a una
    // característica y competencia en su salvación; Resistente (Durable) da +1
    // a Constitución, ventaja en salvaciones contra muerte y Recuperación
    // rápida. Tres variantes de Resiliente estaban cargadas con el nombre de
    // Resistente, y por eso `durable` había quedado con un sufijo inventado.
    for (final feat in repo.feats.values.where(
      (f) => f.id.startsWith('resilient-'),
    )) {
      expect(
        feat.name,
        startsWith('Resiliente ('),
        reason: '${feat.id}: Resistente es el nombre de otra dote',
      );
    }
    expect(repo.feat('durable')!.name, 'Resistente');
  });

  test('ninguna dote comparte nombre con otra', () {
    // Una colisión de nombre no la delata ninguna tabla: el id apunta bien y lo
    // que engaña es la etiqueta visible. Ya pasó con conjuros (`feeblemind`
    // cargado como Mente en Blanco) y con Resiliente/Resistente.
    final byName = <String, List<String>>{};
    for (final feat in repo.feats.values) {
      byName.putIfAbsent(feat.name, () => []).add(feat.id);
    }
    final repeated = byName.entries.where((e) => e.value.length > 1).toList();
    expect(
      repeated,
      isEmpty,
      reason: 'nombres repetidos: '
          '${repeated.map((e) => '"${e.key}" -> ${e.value}').join(', ')}',
    );
  });

  test('las dotes repetibles respetan sus elecciones internas', () {
    expect(repo.feat('ability-score-improvement')!.repeatable, isTrue);
    expect(repo.feat('elemental-adept')!.repeatable, isTrue);
    expect(repo.feat('skilled')!.repeatable, isTrue);
    for (final id in [
      'magic-initiate-cleric',
      'magic-initiate-druid',
      'magic-initiate-wizard',
    ]) {
      expect(repo.feat(id)!.repeatable, isFalse, reason: id);
    }
  });

  test('los prerrequisitos de característica del PHB 2024 están cargados', () {
    // Muestra de las tres formas que usa el capítulo 5: una sola característica,
    // dos alternativas y tres alternativas. Antes todas estas dotes tenían el
    // mapa vacío, así que la validación no podía detectar nada.
    Map<Ability, int> and(String id) =>
        repo.feats[id]!.prerequisite!.minAbilityScores;
    Map<Ability, int> or(String id) =>
        repo.feats[id]!.prerequisite!.anyAbilityScores;

    expect(and('great-weapon-master'), {Ability.strength: 13});
    expect(and('keen-mind'), {Ability.intelligence: 13});
    expect(or('athlete'), {Ability.strength: 13, Ability.dexterity: 13});
    expect(or('observant'), {Ability.intelligence: 13, Ability.wisdom: 13});
    expect(or('speedy'), {Ability.dexterity: 13, Ability.constitution: 13});
    expect(or('ritual-caster'), {
      Ability.intelligence: 13,
      Ability.wisdom: 13,
      Ability.charisma: 13,
    });
    // Una alternativa nunca se guarda como exigencia conjunta.
    for (final f in repo.feats.values) {
      final p = f.prerequisite;
      if (p == null) continue;
      expect(p.minAbilityScores.length <= 1, isTrue,
          reason: '${f.id}: dos exigencias conjuntas suelen ser una disyunción '
              'mal cargada; usar anyAbilityScores');
    }
  });

  test('toda dote general exige nivel 4', () {
    for (final f in repo.feats.values.where((f) => f.category == 'general')) {
      expect(f.prerequisite?.minLevel, 4, reason: f.id);
    }
  });

  test('las dotes de origen no piden nivel ni dan característica', () {
    // SRD 5.2.1: las dotes de origen se obtienen a nivel 1 por el trasfondo y
    // no otorgan aumentos de característica. Iniciado en la Magia figuraba mal
    // como general con nivel 4.
    for (final f in repo.feats.values.where((f) => f.category == 'origin')) {
      expect(f.prerequisite?.minLevel, isNull,
          reason: '${f.id}: una dote de origen no puede exigir nivel');
      expect(f.effects.whereType<AbilityScoreBonusEffect>(), isEmpty,
          reason: '${f.id}: una dote de origen no otorga característica');
    }
  });

  test('las dotes generales exigen nivel 4', () {
    for (final f in repo.feats.values.where((f) => f.category == 'general')) {
      expect(f.prerequisite?.minLevel, 4,
          reason: '${f.id}: toda dote general requiere nivel 4 o más');
    }
  });

  test('las dotes de marca dracónica se pueden tomar a nivel 1', () {
    // Igual que las de origen: el trasfondo de casa las concede en la creación,
    // así que no pueden exigir nivel ni traer un aumento de característica.
    for (final f
        in repo.feats.values.where((f) => f.category == 'dragonmark')) {
      expect(f.prerequisite?.minLevel, isNull,
          reason: '${f.id}: una dote de marca no puede exigir nivel');
      expect(f.effects.whereType<AbilityScoreBonusEffect>(), isEmpty,
          reason: '${f.id}: una dote de marca no otorga característica');
    }
  });

  test('las dotes de bendición épica exigen nivel 19', () {
    for (final f in repo.feats.values.where((f) => f.category == 'epic-boon')) {
      expect(f.prerequisite?.minLevel, 19, reason: f.id);
    }
  });

  test('toda dote exigida como prerrequisito existe', () {
    for (final f in repo.feats.values) {
      for (final id in f.prerequisite?.requiredFeatIds ?? const <String>[]) {
        expect(repo.feat(id), isNotNull,
            reason: '${f.id}: exige la dote "$id", que no existe');
      }
      final cat = f.prerequisite?.requiredFeatCategory;
      if (cat == null) continue;
      expect(repo.feats.values.any((o) => o.category == cat), isTrue,
          reason: '${f.id}: exige la categoría "$cat", que no tiene dotes');
    }
  });

  test('todas las dotes hacen round-trip por JSON (efectos y prerrequisitos)',
      () {
    for (final f in repo.feats.values) {
      final r = Feat.fromJson(f.toJson());
      expect(r.id, f.id);
      expect(r.effects.length, f.effects.length,
          reason: '${f.id}: se perdieron efectos en el round-trip');
    }
  });

  test('cada arma tiene categoría y maestría válidas', () {
    for (final w in repo.weapons.values) {
      expect(validWeaponCategories, contains(w.category),
          reason: '${w.id}: categoría inválida "${w.category}"');
      if (w.mastery != null) {
        expect(validMasteries, contains(w.mastery),
            reason: '${w.id}: maestría inválida "${w.mastery}"');
      }
    }
  });

  test('cada arma versátil declara su dado a dos manos', () {
    for (final w in repo.weapons.values) {
      if (w.properties.contains('versatile')) {
        expect(w.versatileDice, isNotNull,
            reason: '${w.id}: versátil sin versatileDice');
      }
    }
  });

  test('las 38 armas de la tabla del PHB están cargadas', () {
    // Faltaban las tres últimas de Armas Marciales a Distancia. La Cerbatana
    // hace 1 de daño fijo, no un dado: `damageDice` es una cadena de display y
    // nunca se parsea, así que "1" es un valor legítimo.
    expect(repo.weapons, hasLength(38));

    const esperadas = {
      'blowgun': ('Cerbatana', '1', 'vex'),
      'musket': ('Mosquete', '1d12', 'slow'),
      'pistol': ('Pistola', '1d10', 'vex'),
    };
    for (final entry in esperadas.entries) {
      final w = repo.weapons[entry.key];
      expect(w, isNotNull, reason: '${entry.key}: no está en el catálogo');
      expect(w!.name, entry.value.$1);
      expect(w.damageDice, entry.value.$2, reason: entry.key);
      expect(w.mastery, entry.value.$3, reason: entry.key);
      expect(w.damageType, 'piercing', reason: entry.key);
      expect(w.category, 'martial', reason: entry.key);
      expect(w.properties, containsAll(['ammunition', 'loading', 'ranged']),
          reason: entry.key);
    }
    expect(repo.weapons['musket']!.properties, contains('two-handed'));
  });

  test('cada armadura tiene categoría válida', () {
    for (final a in repo.armor.values) {
      expect(validArmorCategories, contains(a.category),
          reason: '${a.id}: categoría inválida "${a.category}"');
    }
  });

  test('cada trasfondo referencia una dote de nivel 1 existente', () {
    // Los trasfondos de casa dracomarcada conceden una dote de Marca Dracónica
    // en lugar de una de origen: Forge of the Artificer dice que tomar ese
    // trasfondo es la única forma de tener una marca a nivel 1.
    const grantable = {'origin', 'dragonmark'};
    for (final b in repo.backgrounds.values) {
      final id = b.originFeatId;
      if (id == null) continue;
      expect(repo.feat(id), isNotNull,
          reason: '${b.id}: dote de origen "$id" no existe');
      expect(grantable, contains(repo.feat(id)!.category),
          reason: '${b.id}: la dote "$id" no se puede conceder a nivel 1');
    }
  });

  test('cada trasfondo ofrece exactamente 3 opciones de característica (2024)',
      () {
    for (final b in repo.backgrounds.values) {
      expect(b.abilityOptions, hasLength(3),
          reason: '${b.id}: debería ofrecer 3 características');
    }
  });

  test('todas las especies compilan sobre un Guerrero sin lanzar', () {
    for (final race in repo.races.values) {
      final c = Character(
        id: 'probe-${race.id}',
        name: 'Prueba',
        raceId: race.id,
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: const [10],
      );
      expect(() => CharacterCompiler(repo).compile(c), returnsNormally,
          reason: 'La especie ${race.id} no compila');
    }
  });

  test('FeatPrerequisite hace round-trip por JSON', () {
    const feat = Feat(
      id: 'hb-grappler',
      name: 'Forcejeador',
      source: ContentSource.homebrew,
      category: 'general',
      exclusiveGroup: 'prueba',
      prerequisite: FeatPrerequisite(
        minAbilityScores: {Ability.strength: 13},
        requiredClassFeature: 'Estilo de Combate',
        minLevel: 4,
      ),
    );
    final r = Feat.fromJson(feat.toJson());
    expect(r.prerequisite, isNotNull);
    expect(r.prerequisite!.minAbilityScores[Ability.strength], 13);
    expect(r.prerequisite!.requiredClassFeature, 'Estilo de Combate');
    expect(r.prerequisite!.minLevel, 4);
    expect(r.exclusiveGroup, 'prueba');
  });
}
