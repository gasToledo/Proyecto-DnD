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
      expect(source, anyOf(ContentSource.srd2024, ContentSource.phb2024),
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
    for (final classId in repo.classes.keys) {
      final srdForClass = repo
          .subclassesForClass(classId)
          .where((s) => s.source == ContentSource.srd2024);
      expect(srdForClass, hasLength(1),
          reason: '$classId debe tener exactamente una subclase del SRD');
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
    // El SRD trae 4 trasfondos (Acólito, Criminal, Erudito y Soldado) y este
    // catálogo tiene 2 de ellos. Los otros 10 son PHB 2024 y no están cubiertos
    // por la atribución CC BY 4.0.
    const srdBackgrounds = {'criminal', 'soldier'};
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
      'Ilusión',
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
    const validCategories = {'origin', 'general', 'fighting-style'};
    for (final f in repo.feats.values) {
      expect(validCategories, contains(f.category),
          reason: '${f.id}: categoría de dote desconocida "${f.category}"');
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

  test('cada armadura tiene categoría válida', () {
    for (final a in repo.armor.values) {
      expect(validArmorCategories, contains(a.category),
          reason: '${a.id}: categoría inválida "${a.category}"');
    }
  });

  test('cada trasfondo referencia una dote de origen existente', () {
    for (final b in repo.backgrounds.values) {
      final id = b.originFeatId;
      if (id == null) continue;
      expect(repo.feat(id), isNotNull,
          reason: '${b.id}: dote de origen "$id" no existe');
      expect(repo.feat(id)!.category, 'origin',
          reason: '${b.id}: la dote "$id" no es de categoría origin');
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
      prerequisite: FeatPrerequisite(
        minAbilityScores: {Ability.strength: 13},
        minLevel: 4,
      ),
    );
    final r = Feat.fromJson(feat.toJson());
    expect(r.prerequisite, isNotNull);
    expect(r.prerequisite!.minAbilityScores[Ability.strength], 13);
    expect(r.prerequisite!.minLevel, 4);
  });
}
