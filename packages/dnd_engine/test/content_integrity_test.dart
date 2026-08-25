import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Chequeos de integridad sobre el contenido real del SRD 2024. Atrapa datos
/// mal referenciados (una dote inexistente, una maestría inválida) apenas se
/// cargan, sin necesidad de recorrer la app.
/// Las dotes que el SRD 5.2.1 sí publica y que el catálogo tenía etiquetadas
/// `phb_2024`. Se comparte entre los dos tests que miran procedencia de dotes.
const srdFeatIds = {
  'druid-land-arid',
  'druid-land-polar',
  'druid-land-temperate',
  'druid-land-tropical',
  'alert',
  'savage-attacker',
  'skilled',
  'magic-initiate-wizard',
  'magic-initiate-cleric',
  'magic-initiate-druid',
  // Apresador se divide por característica, así que aporta dos entradas.
  'grappler-strength',
  'grappler-dexterity',
  'fs-defense',
  'fs-archery',
  'fs-great-weapon',
  'fs-two-weapon-fighting',
  // Alternativas de clase "en lugar de una dote de Estilo de Combate".
  'fs-blessed-warrior',
  'fs-druidic-warrior',
  'ability-score-improvement',
  'boon-of-combat-prowess',
  'boon-of-truesight',
  'boon-of-irresistible-offense',
  'boon-of-fate',
  'boon-of-the-night-spirit',
  'boon-of-spell-recall',
  'boon-of-dimensional-travel',
};

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('inventario del catálogo', () {
    // Un alta, una baja o un duplicado accidental se ve acá antes que en
    // ninguna otra prueba. Los números salen de la auditoría del catálogo.
    Map<ContentSource, int> porFuente(Iterable<dynamic> entradas) {
      final c = <ContentSource, int>{};
      for (final e in entradas) {
        c[e.source as ContentSource] = (c[e.source as ContentSource] ?? 0) + 1;
      }
      return c;
    }

    test('las cantidades por bloque no se mueven', () {
      expect(repo.classes, hasLength(13));
      expect(repo.subclasses, hasLength(53));
      expect(repo.races, hasLength(15));
      expect(repo.lineages, hasLength(28));
      expect(repo.backgrounds, hasLength(33));
      // 187 dotes canónicas + Blessed Warrior y Druidic Warrior, que son
      // opciones de clase "en lugar de una dote de Estilo de Combate".
      expect(repo.feats, hasLength(189));
      expect(repo.weapons, hasLength(38));
      expect(repo.armor, hasLength(13));
      // 78 de equipo de aventurero (61 sueltos + 10 contenedores + 7 paquetes),
      // 23 herramientas + 14 variantes de juego e instrumento, 5 municiones y
      // 11 canalizadores y símbolos sagrados, libro de conjuros, 261 entradas
      // mágicas SRD y 9 EFA.
      expect(repo.items, hasLength(402));
      expect(repo.spells, hasLength(392));
      // 330 perfiles del capítulo «Monstruos» y del apéndice «Animales» del
      // SRD 5.2.1, más las 37 que no salen de ahí: 31 invocaciones por fórmula
      // (espíritus, cañones, corceles) escritas a mano desde los conjuros, y 6
      // de PHB/EFA. Las genera `tool/generate_bestiary.dart`.
      expect(repo.creatures, hasLength(367));
    });

    // --- Dados de golpe ---
    //
    // Existen para que el DM pueda tirarlos al sumar varias copias de un
    // monstruo. Salen del mismo paréntesis del PDF que el promedio, así que la
    // prueba que importa no es cuántos hay sino que cada criatura se haya
    // quedado con **los suyos**.

    test('los perfiles del SRD declaran sus dados de golpe', () {
      final conDados = repo.creatures.values.where((c) => c.hitDice != null);
      expect(conDados, hasLength(330));
    });

    test('los únicos sin dados son los que no salen del PDF', () {
      final sinDados = repo.creatures.values.where((c) => c.hitDice == null);
      expect(sinDados, hasLength(37));
      // 31 invocaciones cuyos PG son una fórmula por nivel de conjuro, y 6
      // compañeros de clase que escalan con el nivel del personaje. Ninguno de
      // los dos tira dados de golpe, así que no tenerlos es lo correcto.
      expect(
        sinDados.where((c) => c.scalesWithSpellLevel),
        hasLength(31),
      );
      expect(
        sinDados.where((c) => !c.scalesWithSpellLevel).map((c) => c.name),
        containsAll(['Defensor de Acero', 'Bestia de la Tierra']),
      );
    });

    // LA prueba de esta importación: el promedio derivado de los dados tiene
    // que dar exactamente el `hp` que imprime el libro. Un regex que le hubiera
    // robado los dados a la criatura de al lado seguiría pareciendo una
    // fórmula válida, pero el promedio dejaría de coincidir.
    test('los dados de cada criatura promedian sus propios PG', () {
      for (final creature in repo.creatures.values) {
        if (creature.hitDice case final dice?) {
          final formula = DiceFormula.tryParse(dice);
          expect(formula, isNotNull, reason: '${creature.name}: «$dice»');
          expect(
            formula!.average,
            int.parse(creature.hp),
            reason: '${creature.name}: $dice debería promediar ${creature.hp}',
          );
        }
      }
    });

    test('las procedencias coinciden con el cruce contra el SRD 5.2.1', () {
      expect(porFuente(repo.lineages.values), {
        ContentSource.srd2024: 24,
        ContentSource.foa2025: 4,
      });
      expect(porFuente(repo.weapons.values), {ContentSource.srd2024: 38});
      expect(porFuente(repo.items.values), {
        ContentSource.srd2024: 393,
        ContentSource.foa2025: 9,
      });
      expect(porFuente(repo.spells.values), {
        ContentSource.srd2024: 339,
        ContentSource.phb2024: 52,
        ContentSource.foa2025: 1,
      });
      expect(porFuente(repo.feats.values), {
        ContentSource.srd2024: 26,
        ContentSource.phb2024: 135,
        ContentSource.foa2025: 28,
      });
      // Las criaturas se generan desde el PDF del SRD 5.2.1, que es CC-BY
      // entero: por eso todo lo importado cae en `srd2024` y no hay forma de
      // que se cuele un perfil de otro libro sin que este número se mueva.
      expect(porFuente(repo.creatures.values), {
        ContentSource.srd2024: 338,
        ContentSource.phb2024: 25,
        ContentSource.foa2025: 4,
      });
    });
  });

  group('objetos, peso y precio', () {
    test('los tres catálogos de la mochila no comparten ids', () {
      // Una entrada de inventario guarda un id pelado y `catalogEntry` lo
      // resuelve en cascada. Si dos catálogos usaran el mismo id, la ficha
      // mostraría una cosa distinta de la que el compilador calcula.
      final weapons = repo.weapons.keys.toSet();
      final armor = repo.armor.keys.toSet();
      final items = repo.items.keys.toSet();
      expect(weapons.intersection(armor), isEmpty);
      expect(weapons.intersection(items), isEmpty);
      expect(armor.intersection(items), isEmpty);
    });

    test('todas las armas y armaduras tienen precio', () {
      for (final w in repo.weapons.values) {
        expect(w.costCp, greaterThan(0), reason: 'arma sin precio: ${w.id}');
      }
      for (final a in repo.armor.values) {
        expect(a.costCp, greaterThan(0),
            reason: 'armadura sin precio: ${a.id}');
      }
    });

    test('el único peso despreciable del equipo es el de la honda', () {
      // El manual escribe "—" cuando el peso no cuenta, y la honda es el único
      // caso entre armas y armaduras. Fijarlo detecta un parcheo a medias.
      expect(
        [
          for (final w in repo.weapons.values)
            if (w.weight == 0) w.id
        ],
        ['sling'],
      );
      expect(repo.armor.values.where((a) => a.weight == 0), isEmpty);
    });

    test('todo objeto tiene precio y una categoría conocida', () {
      const categories = {
        'gear',
        'tool',
        'ammunition',
        'focus',
        'pack',
        'container',
        'magic',
      };
      for (final i in repo.items.values) {
        expect(categories, contains(i.category), reason: i.id);
        expect(
          i.costCp,
          i.rarity == 'artifact' ? greaterThanOrEqualTo(0) : greaterThan(0),
          reason: 'objeto sin precio: ${i.id}',
        );
        expect(i.weight, greaterThanOrEqualTo(0), reason: i.id);
      }
    });

    test('la munición conserva cuántas unidades trae cada paquete', () {
      expect(
        {
          for (final i in repo.items.values.where(
            (i) => i.category == 'ammunition',
          ))
            i.id: i.bundleSize,
        },
        {
          'arrows': 20,
          'bolts': 20,
          'bullets-firearm': 10,
          'bullets-sling': 20,
          'needles': 50,
        },
      );
      expect(Item.fromJson(repo.item('arrows')!.toJson()).bundleSize, 20);
    });

    test('los siete paquetes detallan su contenido en español', () {
      final packs =
          repo.items.values.where((i) => i.category == 'pack').toList();
      expect(packs, hasLength(7));
      for (final pack in packs) {
        expect(pack.description, startsWith('Contiene: '), reason: pack.id);
      }
      expect(repo.item('burglars-pack')!.description, contains('10 × Vela'));
      expect(
        repo.item('dungeoneers-pack')!.description,
        contains('10 × Antorcha'),
      );
    });

    test('la rareza y la sintonización solo existen en objetos mágicos', () {
      const rarities = {
        'common',
        'uncommon',
        'rare',
        'very-rare',
        'legendary',
        'artifact',
      };
      for (final i in repo.items.values) {
        if (i.rarity != null) {
          expect(rarities, contains(i.rarity), reason: i.id);
        }
        if (i.requiresAttunement) {
          expect(i.rarity, isNotNull, reason: 'mundano sintonizable: ${i.id}');
        }
      }
      expect(repo.items.values.where((i) => i.isMagic), hasLength(270));
      expect(
        repo.items.values.where((i) => i.isMagic && i.category != 'magic'),
        isEmpty,
      );
    });

    test('el objeto herramienta y su competencia se llaman igual', () {
      // Comparten id a propósito, así que un cambio de nombre en un lado sin el
      // otro dejaría la ficha diciendo dos cosas distintas de la misma cosa.
      for (final i in repo.items.values.where((i) => i.category == 'tool')) {
        expect(knownToolLabel(i.id), i.name, reason: i.id);
      }
    });

    test('el único nombre repetido es el que repite el propio SRD', () {
      // "Vara" traduce tanto *Pole* (equipo) como *Rod* (canalizador arcano).
      // Los nombres visibles salen del SRD en español y no se inventan, así que
      // la colisión se acepta y se resuelve mostrando la categoría en la lista.
      // Fijarla acá evita que aparezca una segunda sin que nadie se entere.
      final porNombre = <String, List<String>>{};
      for (final i in repo.items.values) {
        porNombre.putIfAbsent(i.name, () => []).add(i.id);
      }
      final repetidos = {
        for (final e in porNombre.entries)
          if (e.value.length > 1) e.key: (e.value..sort()),
      };
      expect(repetidos, {
        'Vara': ['pole', 'rod'],
      });
    });
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
    // Los cuatro terrenos del Círculo de la Tierra se suman aparte: no son
    // dotes del capítulo 5, son el catálogo de una elección abierta que reusa
    // `Feat`, y el texto de sus tablas sale del SRD igual que la subclase.
    final tagged = repo.feats.values
        .where((f) => f.source == ContentSource.srd2024)
        .map((f) => f.id)
        .toSet();
    expect(tagged, equals(srdFeatIds));
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
      // Ídem: los cuatro terrenos del Círculo de la Tierra. Viven acá y no como
      // rasgos repetidos de la subclase porque `subclasses_test` prohíbe repetir
      // nombre de rasgo salvo que sea *solo* tabla de conjuros, y estos además
      // conceden resistencia.
      'druid-land',
    };
    for (final f in repo.feats.values) {
      expect(validCategories, contains(f.category),
          reason: '${f.id}: categoría de dote desconocida "${f.category}"');
    }
  });

  test('el catálogo incluye las 21 dotes del PHB que faltaban', () {
    const expected = {
      'ability-score-improvement': ('Mejora de Característica', 'general'),
      'martial-weapon-training-strength': (
        'Entrenamiento con Armas Marciales (Fuerza)',
        'general',
      ),
      'weapon-master-strength': ('Maestro de Armas (Fuerza)', 'general'),
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
      expect(
        feat.source,
        srdFeatIds.contains(entry.key)
            ? ContentSource.srd2024
            : ContentSource.phb2024,
        reason: entry.key,
      );
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
              featCategories.contains(f.category) &&
              // Blessed Warrior y Druidic Warrior no son dotes del capítulo 5:
              // son la alternativa de clase "en lugar de una dote de Estilo de
              // Combate", y por eso son las únicas con `requiredClassId`.
              f.prerequisite?.requiredClassId == null,
        )
        .toList();
    // Son 127 registros para 75 dotes del capítulo porque las que dejan elegir
    // el bono de característica se cargan como una variante por opción, con el
    // mismo `exclusiveGroup`: es la única forma de que el jugador elija sin
    // inventar un efecto nuevo. Iniciado en la Magia aporta 3 por sus listas.
    //
    // El desglose: 33 familias con elección (Resiliente ×6, Experto en
    // Habilidades ×6, siete ×3 y veinticuatro ×2) más Iniciado en la Magia ×3.
    expect(phb, hasLength(127));
    expect(phb.where((f) => f.category == 'origin'), hasLength(12));
    expect(phb.where((f) => f.category == 'general'), hasLength(93));
    expect(phb.where((f) => f.category == 'fighting-style'), hasLength(10));
    expect(phb.where((f) => f.category == 'epic-boon'), hasLength(12));

    // Toda variante declara su grupo, que es lo que impide tomar dos.
    final conVariantes = phb.where((f) => f.exclusiveGroup != null);
    expect(conVariantes, hasLength(greaterThan(60)));
    for (final grupo in conVariantes.map((f) => f.exclusiveGroup!).toSet()) {
      final delGrupo = phb.where((f) => f.exclusiveGroup == grupo);
      expect(delGrupo.length, greaterThan(1), reason: 'grupo $grupo con una');
      // Cada variante concede exactamente el +1 que la distingue.
      for (final f in delGrupo.where((f) => f.category == 'general')) {
        final asi = f.effects.whereType<AbilityScoreBonusEffect>();
        expect(asi, hasLength(1), reason: f.id);
        expect(f.id, endsWith(asi.first.ability.name), reason: f.id);
      }
    }
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
      'charger-strength': 'Atacante a la Carga (Fuerza)',
      'mage-slayer-strength': 'Azote de Magos (Fuerza)',
      'dual-wielder-strength': 'Combatiente con Dos Armas (Fuerza)',
      'crossbow-expert': 'Experto en Ballestas',
      'war-caster-intelligence': 'Lanzador en Combate (Inteligencia)',
      'spell-sniper-intelligence': 'Lanzador Preciso (Inteligencia)',
      'ritual-caster-intelligence': 'Lanzador Ritual (Inteligencia)',
      'medium-armor-master-strength': 'Maestro en Armaduras Medias (Fuerza)',
      'heavy-armor-master-constitution':
          'Maestro en Armaduras Pesadas (Constitución)',
      'polearm-master-dexterity': 'Maestro en Armas de Asta (Destreza)',
      'great-weapon-master': 'Maestro en Armas Pesadas',
      'shield-master': 'Maestro en Escudos',
      'heavily-armored-constitution': 'Muy Acorazado (Constitución)',
      'telepathic-intelligence': 'Telepático (Inteligencia)',
      'sharpshooter': 'Tirador de Primera',
      'elemental-adept-intelligence': 'Versado en un Elemento (Inteligencia)',
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

    expect(armaduras('lightly-armored-strength'),
        containsAll(['light', 'shield']));
    expect(armaduras('moderately-armored-strength'), ['medium']);
    expect(armaduras('heavily-armored-constitution'), ['heavy']);
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

  test('los estilos de combate exigen el rasgo Estilo de Combate', () {
    final styles =
        repo.feats.values.where((f) => f.category == 'fighting-style').toList();
    // 10 dotes del capítulo 5 + las dos opciones de clase que XPHB ofrece "en
    // lugar de una dote de Estilo de Combate".
    expect(styles, hasLength(12));
    for (final feat in styles) {
      expect(
        feat.prerequisite?.requiredClassFeature,
        'Estilo de Combate',
        reason: feat.id,
      );
    }
  });

  test('Blessed Warrior y Druidic Warrior son de una sola clase', () {
    const esperado = {
      'fs-blessed-warrior': ('paladin', 'cleric'),
      'fs-druidic-warrior': ('ranger', 'druid'),
    };
    for (final entry in esperado.entries) {
      final feat = repo.feat(entry.key);
      expect(feat, isNotNull, reason: entry.key);
      expect(feat!.source, ContentSource.srd2024, reason: entry.key);
      expect(feat.category, 'fighting-style', reason: entry.key);
      expect(feat.prerequisite?.requiredClassId, entry.value.$1,
          reason: entry.key);
      // Los dos trucos salen de la lista de la clase que corresponde.
      final choice = feat.effects.whereType<SpellChoiceEffect>().single;
      expect(choice.count, 2, reason: entry.key);
      expect(choice.maxLevel, 0, reason: entry.key);
      expect(choice.fromClasses, [entry.value.$2], reason: entry.key);
      expect(choice.replaceable, isTrue, reason: entry.key);
    }
    // Y ninguna otra opción declara clase: el resto las ve cualquier clase con
    // el rasgo.
    final conClase = repo.feats.values
        .where((f) => f.prerequisite?.requiredClassId != null)
        .map((f) => f.id)
        .toSet();
    expect(conClase, esperado.keys.toSet());
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
    expect(repo.feat('elemental-adept-intelligence')!.repeatable, isTrue);
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
    expect(
        or('athlete-strength'), {Ability.strength: 13, Ability.dexterity: 13});
    expect(or('observant-intelligence'),
        {Ability.intelligence: 13, Ability.wisdom: 13});
    expect(or('speedy-dexterity'),
        {Ability.dexterity: 13, Ability.constitution: 13});
    expect(or('ritual-caster-intelligence'), {
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

  test('el alcance está exactamente en las armas que lo tienen', () {
    // La columna "Alcance" del cap. 6 solo existe para las armas que se
    // disparan o se arrojan; en las demás el alcance sale de `reach` y es el
    // mismo para todas. Cargar un alcance en un arma melé, u olvidarlo en una
    // a distancia, es el defecto que este test ataja.
    const conAlcance = {
      'dagger': (20, 60),
      'handaxe': (20, 60),
      'javelin': (30, 120),
      'light-hammer': (20, 60),
      'spear': (20, 60),
      'dart': (20, 60),
      'light-crossbow': (80, 320),
      'shortbow': (80, 320),
      'sling': (30, 120),
      'trident': (20, 60),
      'hand-crossbow': (30, 120),
      'heavy-crossbow': (100, 400),
      'longbow': (150, 600),
      'blowgun': (25, 100),
      'musket': (40, 120),
      'pistol': (30, 90),
    };
    for (final w in repo.weapons.values) {
      final aDistancia =
          w.properties.contains('ranged') || w.properties.contains('thrown');
      expect(conAlcance.containsKey(w.id), aDistancia,
          reason: '${w.id}: alcance y propiedades no coinciden');
      final esperado = conAlcance[w.id];
      expect((w.rangeNormal, w.rangeLong), esperado ?? (0, 0), reason: w.id);
      expect(w.rangeLabel,
          esperado == null ? isNull : '${esperado.$1}/${esperado.$2} pies',
          reason: w.id);
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

  group('la Lanza de caballería solo exige dos manos desmontada', () {
    // XPHB: "You have Disadvantage when you use a Lance to attack a target
    // within 5 feet. You also must use two hands to attack with it unless
    // you're mounted." Se modela calificando `two-handed`, no borrándola.
    test('el arma declara la propiedad y su condición', () {
      final lance = repo.weapons['lance']!;
      expect(lance.properties, contains('two-handed'));
      expect(lance.twoHandedUnlessMounted, isTrue);
    });

    test('desmontado la exige, montado no', () {
      final lance = repo.weapons['lance']!;
      expect(lance.requiresTwoHands(), isTrue);
      expect(lance.requiresTwoHands(mounted: true), isFalse);
    });

    test('las demás armas a dos manos siguen siendo incondicionales', () {
      final otras = repo.weapons.values.where(
        (w) => w.id != 'lance' && w.properties.contains('two-handed'),
      );
      expect(otras, isNotEmpty);
      for (final w in otras) {
        expect(w.twoHandedUnlessMounted, isFalse, reason: w.id);
        expect(w.requiresTwoHands(mounted: true), isTrue, reason: w.id);
      }
    });

    test('round-trip JSON con y sin la condición', () {
      final lance = repo.weapons['lance']!;
      expect(Weapon.fromJson(lance.toJson()).twoHandedUnlessMounted, isTrue);

      final greatsword = repo.weapons['greatsword']!;
      expect(greatsword.toJson().containsKey('twoHandedUnlessMounted'), isFalse,
          reason: 'no ensuciar el JSON de las armas que no usan la condición');
      expect(
          Weapon.fromJson(greatsword.toJson()).twoHandedUnlessMounted, isFalse);

      // Un arma homebrew vieja, sin el campo, sigue siendo estricta.
      final vieja = Weapon.fromJson({
        'id': 'homebrew-pike',
        'name': 'Pica casera',
        'source': 'homebrew',
        'category': 'martial',
        'damageDice': '1d10',
        'damageType': 'piercing',
        'properties': ['two-handed'],
      });
      expect(vieja.twoHandedUnlessMounted, isFalse);
      expect(vieja.requiresTwoHands(mounted: true), isTrue);
    });
  });

  test('el Pico de guerra es versátil 1d8/1d10', () {
    final pick = repo.weapons['war-pick']!;
    expect(pick.properties, contains('versatile'));
    expect(pick.damageDice, '1d8');
    expect(pick.versatileDice, '1d10');
    // La corrección no toca ni el tipo de daño ni la maestría.
    expect(pick.damageType, 'piercing');
    expect(pick.mastery, 'sap');
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

  group('Criaturas invocables', () {
    /// Recorre todos los efectos del catálogo, incluidos los envueltos en un
    /// [LeveledEffect]: un compañero declarado por nivel no debe escaparse del
    /// chequeo solo por estar anidado.
    Iterable<Effect> allEffects() sync* {
      Iterable<Effect> flat(List<Effect> effects) sync* {
        for (final e in effects) {
          yield e;
          if (e is LeveledEffect) yield* flat(e.effects);
        }
      }

      for (final k in repo.classes.values) {
        for (final f in k.features) {
          yield* flat(f.effects);
        }
      }
      for (final s in repo.subclasses.values) {
        for (final f in s.features) {
          yield* flat(f.effects);
        }
      }
      for (final f in repo.feats.values) {
        yield* flat(f.effects);
      }
      for (final r in repo.races.values) {
        yield* flat(r.effects);
      }
      for (final l in repo.lineages.values) {
        for (final f in l.features) {
          yield* flat(f.effects);
        }
      }
    }

    test('el catálogo trae las formas de familiar y los compañeros de clase',
        () {
      expect(repo.creatures.length, greaterThanOrEqualTo(30));
      for (final id in const [
        'eldritch-cannon',
        'steel-defender',
        'beast-of-the-land',
        'beast-of-the-sea',
        'beast-of-the-sky',
        'homunculus-servant',
        'otherworldly-steed',
      ]) {
        expect(repo.creature(id), isNotNull, reason: id);
      }
    });

    test('todo creatureId referenciado existe en el catálogo', () {
      final referenced = <String>{};
      for (final e in allEffects().whereType<CompanionEffect>()) {
        expect(e.creatureIds, isNotEmpty, reason: e.id);
        expect(e.maxActive, greaterThan(0), reason: e.id);
        referenced.addAll(e.creatureIds);
      }
      expect(referenced, isNotEmpty);
      for (final id in referenced) {
        expect(repo.creature(id), isNotNull, reason: id);
      }
    });

    test('todo requiresSpell apunta a un conjuro real', () {
      for (final e in allEffects().whereType<CompanionEffect>()) {
        if (e.requiresSpell == null) continue;
        expect(repo.spell(e.requiresSpell!), isNotNull, reason: e.id);
      }
    });

    /// Nivel mínimo de espacio con el que cada criatura se puede invocar: el
    /// del conjuro que la concede. Sin ese piso, las fórmulas que cuentan
    /// niveles por encima del propio dan números negativos.
    Map<String, int> minSpellLevelByCreature() {
      final mins = <String, int>{};
      for (final e in allEffects().whereType<CompanionEffect>()) {
        final level =
            e.requiresSpell == null ? 0 : repo.spell(e.requiresSpell!)!.level;
        for (final id in e.creatureIds) {
          mins[id] = level;
        }
      }
      return mins;
    }

    test('toda fórmula evalúa de nivel 1 a 20 y con cualquier espacio', () {
      final mins = minSpellLevelByCreature();
      for (final creature in repo.creatures.values) {
        for (var level = 1; level <= 20; level++) {
          for (var slot = mins[creature.id] ?? 0; slot <= 9; slot++) {
            final vars = CreatureVars.from(
              level: level,
              proficiencyBonus: proficiencyBonusForLevel(level),
              abilityModifiers: {for (final a in Ability.values) a: 3},
              spellAttackBonus: 6,
              spellSaveDc: 14,
              spellLevel: creature.scalesWithSpellLevel ? slot : 0,
            );
            expect(
              () => creature.resolve(vars),
              returnsNormally,
              reason: '${creature.id} a nivel $level con espacio $slot',
            );
            if (!creature.scalesWithSpellLevel) break;
          }
        }
      }
    });

    test('nadie se invoca con PG o CA que no se puedan llevar', () {
      final mins = minSpellLevelByCreature();
      for (final creature in repo.creatures.values) {
        final min = mins[creature.id] ?? 0;
        for (final level in const [1, 5, 11, 20]) {
          for (var slot = min; slot <= 9; slot++) {
            final resolved = creature.resolve(
              CreatureVars.from(
                level: level,
                proficiencyBonus: proficiencyBonusForLevel(level),
                abilityModifiers: {for (final a in Ability.values) a: 3},
                spellAttackBonus: 6,
                spellSaveDc: 14,
                spellLevel: creature.scalesWithSpellLevel ? slot : 0,
              ),
            );
            final where = '${creature.id} a nivel $level con espacio $slot';
            expect(resolved.maxHp, greaterThan(0), reason: where);
            expect(resolved.armorClass, greaterThan(0), reason: where);
            if (!creature.scalesWithSpellLevel) break;
          }
        }
      }
    });

    test('los tipos de daño de las acciones son válidos', () {
      for (final creature in repo.creatures.values) {
        for (final action in creature.actions) {
          if (action.damageType == null) continue;
          expect(
            DamageType.fromId(action.damageType!),
            isNotNull,
            reason: '${creature.id}: ${action.name}',
          );
        }
      }
    });

    test('el tipo y el tamaño de cada perfil se resuelven', () {
      // `creatureType` y `creatureSize` caen a parsear `kind` cuando la entrada
      // no trae los campos estructurados, que hoy es todo el catálogo. Si un
      // perfil nuevo se escribe con otra forma, se cae acá y no en la ficha.
      for (final c in repo.creatures.values) {
        expect(c.creatureSize, isNotNull, reason: '${c.id}: «${c.kind}»');
      }

      // Los únicos sin tipo son los que no tienen uno solo, y está bien que
      // queden en null en vez de inventarles uno:
      //
      // - los cañones del artífice, que son «Objeto» y eso no es un tipo del
      //   SRD (además son invocaciones, afuera del Modo DM por
      //   `creaturesSorted`);
      // - los enjambres, que son «Enjambre Mediano de bestias Diminutas». Que
      //   den null los mantiene fuera del pozo de Forma Salvaje, que es lo
      //   correcto: un enjambre no es una bestia en la que transformarse.
      final sinTipo = [
        for (final c in repo.creatures.values)
          if (c.creatureType == null) c.id,
      ]..sort();
      expect(sinTipo, [
        'eldritch-cannon',
        'eldritch-cannon-explosive',
        'swarm-of-bats',
        'swarm-of-crawling-claws',
        'swarm-of-insects',
        'swarm-of-piranhas',
        'swarm-of-rats',
        'swarm-of-ravens',
        'swarm-of-venomous-snakes',
      ]);
    });

    test('una etiqueta en medio del perfil no se come el tamaño', () {
      // El pteranodon es «Bestia Mediana (dinosaurio), sin alineamiento»:
      // sacar el tamaño de la última palabra daba «alineamiento» y la forma
      // salvaje se quedaba con el tamaño del druida. Todo el apéndice de
      // animales tiene esta forma, así que la regla protege ~84 entradas.
      final p = repo.creature('pteranodon')!;
      expect(p.kind, contains('(dinosaurio)'));
      expect(p.kind, endsWith('sin alineamiento'));
      expect(p.creatureSize, CreatureSize.medium);
    });

    /// El pozo de Forma Salvaje: bestias **con** valor de desafío. Los
    /// espíritus invocados son de tipo Bestia pero el libro les pone «Desafío:
    /// ninguno», y el rasgo pide un VD máximo — sin VD no califican, que es
    /// justo lo que corresponde: no son animales, son conjuros.
    Iterable<Creature> beastForms() =>
        repo.creatures.values.where((c) => c.isBeast && c.cr != null);

    test('las bestias traen VD y sus números se leen del texto', () {
      expect(beastForms().length, greaterThanOrEqualTo(60));

      for (final beast in beastForms()) {
        // Derivar en vez de duplicar solo se sostiene si el texto siempre
        // parsea: acá se cae si alguien escribe una velocidad de otra forma.
        expect(beast.walkSpeed, greaterThan(0), reason: beast.id);
      }

      // Y los espíritus quedan afuera aunque sean bestias.
      expect(repo.creature('bestial-spirit-air')!.isBeast, isTrue);
      expect(repo.creature('bestial-spirit-air')!.cr, isNull);
    });

    test('el bestiario completo no le agranda el pozo al druida', () {
      // Esta prueba antes decía «ninguna bestia pasa de VD 1», y eso valía
      // solo mientras el catálogo era el pozo de Forma Salvaje y nada más. Al
      // importar el bestiario entraron elefantes, cocodrilos gigantes y
      // dinosaurios: bestias de VD 2 a 5 que existen como enemigos.
      //
      // Lo que aquella aserción protegía de verdad era el pozo del druida, y
      // eso es lo que se comprueba ahora. El tope de VD lo aplica
      // `character_compiler.dart`, así que las bestias grandes nunca se
      // ofrecen; acá se fija que el conjunto elegible no se movió.
      final grandes = beastForms().where((c) => c.cr! > 1);
      expect(grandes, isNotEmpty, reason: 'el import trajo bestias de VD alto');

      // 64 es el mismo número que había antes del import: el catálogo ya tenía
      // todas las bestias de VD 1 o menos, porque para eso se había armado.
      expect(beastForms().where((c) => c.cr! <= 1), hasLength(64));
    });

    test('el pozo por nivel de druida sale de VD y vuelo', () {
      Iterable<Creature> pool(num maxCr, {required bool allowFly}) =>
          beastForms().where(
            (c) => c.cr! <= maxCr && (allowFly || !c.canFly),
          );

      // Cada tramo de la tabla suma formas sobre el anterior.
      final atTwo = pool(0.25, allowFly: false).length;
      final atFour = pool(0.5, allowFly: false).length;
      final atEight = pool(1, allowFly: true).length;
      expect(atTwo, greaterThan(20));
      expect(atFour, greaterThan(atTwo));
      expect(atEight, greaterThan(atFour));

      // Y hasta nivel 8 no entra nada que vuele.
      expect(pool(0.5, allowFly: false).any((c) => c.canFly), isFalse);
      expect(pool(1, allowFly: true).any((c) => c.canFly), isTrue);
    });

    test('una criatura hace round-trip por JSON', () {
      final original = repo.creature('steel-defender')!;
      final back = Creature.fromJson(original.toJson());
      expect(back.ac, original.ac);
      expect(back.hp, original.hp);
      expect(back.abilityScores, original.abilityScores);
      expect(back.actions.first.damage, original.actions.first.damage);
      expect(back.traits.length, original.traits.length);
    });
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
