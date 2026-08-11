import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Guardián contra una clase entera de defecto: **el rasgo cuya prosa promete
/// una mecánica que sus efectos no entregan**.
///
/// El contenido declara cada rasgo con una descripción en castellano y una
/// lista de efectos. Cuando la mecánica no se modela, la costumbre es dejar un
/// `passiveTrait` con el texto y seguir: el jugador lee que tiene Pericia, o
/// que un conjuro está siempre preparado, y la ficha no se lo da. Así
/// aparecieron las tres quejas que originaron estos tests (Pericia del Bardo
/// sin elegir, conjuros de subclase invisibles, Luz Sanadora con el pozo fijo),
/// y así había otros catorce hermanos sin reportar.
///
/// La forma de cada lint es siempre la misma y las tres partes importan:
///
/// 1. **cruzar prosa contra efectos**: si el texto lo promete, el efecto tiene
///    que estar;
/// 2. **fijar el conteo de coincidencias**: un regex sobre prosa escrita a mano
///    es frágil, y de las dos formas de fallar solo una importa. Un falso
///    positivo cuesta una línea de lista y se ve enseguida. Un falso *negativo*
///    —alguien reescribe una descripción y el patrón deja de coincidir— dejaría
///    el test en verde mientras el defecto se publica, que es exactamente la
///    degradación silenciosa que venimos a matar, reintroducida un nivel más
///    arriba. El conteo la vuelve ruidosa;
/// 3. **exigir que las listas de exención estén agotadas**: si una entrada ya
///    no coincide con su lint (rasgo renombrado, deuda pagada) el test falla.
///    Es lo que mantiene las listas como registro y no como basurero.
///
/// Preferir `contains` de frase fija sobre regex, y derivar el patrón del
/// código cuando se puede (`Ability.label` ya trae "Sabiduría", así que
/// iterarlo no se puede desincronizar de los nombres).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Todos los rasgos de clase y subclase, con una etiqueta estable que sirve
  /// de clave en las listas de exención y de mensaje cuando algo falla.
  List<({String where, ClassFeature feature})> todosLosRasgos() => [
        for (final c in repo.classes.values)
          for (final f in c.features)
            (where: 'clase ${c.id} n${f.level} "${f.name}"', feature: f),
        for (final s in repo.subclasses.values)
          for (final f in s.features)
            (where: 'subclase ${s.id} n${f.level} "${f.name}"', feature: f),
      ];

  /// La prosa donde el contenido esconde lo que promete: nombre y descripción
  /// del rasgo, más el nombre y la descripción de sus `passiveTrait`. El nombre
  /// hace falta: la Pericia del Pícaro y la del Bardo se llaman "Pericia" y su
  /// descripción solo dice "duplicás tu bonif. de competencia".
  String prosa(ClassFeature f) => [
        f.name,
        f.description,
        for (final e in f.effects.whereType<PassiveTraitEffect>()) ...[
          e.name,
          e.description,
        ],
      ].join(' ');

  /// Comprueba un lint: cada rasgo que coincide con [promete] tiene que
  /// satisfacer [entrega], salvo los de [falsosPositivos] (la prosa menciona la
  /// mecánica sin concederla) y los de [deuda] (la concede de verdad y todavía
  /// no se modela). Fija el total de coincidencias y exige que las dos listas
  /// estén agotadas.
  void lint({
    required String nombre,
    required bool Function(String prosa) promete,
    required bool Function(ClassFeature f) entrega,
    required int coincidencias,
    Set<String> falsosPositivos = const {},
    Map<String, String> deuda = const {},
  }) {
    final vistos = <String>[];
    final incumplen = <String>[];
    for (final (:where, :feature) in todosLosRasgos()) {
      if (!promete(prosa(feature))) continue;
      vistos.add(where);
      if (entrega(feature)) continue;
      if (falsosPositivos.contains(where) || deuda.containsKey(where)) continue;
      incumplen.add(where);
    }

    expect(incumplen, isEmpty,
        reason: '$nombre: la prosa promete la mecánica y los efectos no la '
            'declaran. Si de verdad no se puede modelar todavía, agregalo a '
            '`deuda` con el motivo.\n${incumplen.join('\n')}');

    expect(vistos, hasLength(coincidencias),
        reason: '$nombre: cambió la cantidad de rasgos que coinciden con el '
            'patrón. Si bajó, probablemente alguien reescribió una descripción '
            'y el patrón dejó de verla: revisá el patrón antes de tocar este '
            'número.');

    for (final e in {...falsosPositivos, ...deuda.keys}) {
      expect(vistos, contains(e),
          reason: '$nombre: "$e" está exento pero ya no coincide con el lint. '
              'Si se renombró o se pagó la deuda, sacalo de la lista.');
    }
  }

  /// Si estos efectos dejan algún conjuro siempre preparado, sea cual sea el
  /// camino: declarado, elegido de un pozo, escalonado por nivel o traído por
  /// una elección abierta.
  ///
  /// La elección abierta exige que **todas** las opciones del catálogo
  /// concedan uno. Sin ese "todas", cualquier rasgo con Estilo de Combate
  /// satisfaría el lint por accidente, porque la categoría existe y tiene
  /// dotes; lo que importa es que el jugador no pueda elegir una que lo deje
  /// sin la mecánica que la prosa le prometió.
  bool concedeSiemprePreparado(List<Effect> effects) => effects.any((e) =>
      e is AlwaysPreparedSpellEffect ||
      e is SpellChoiceEffect ||
      (e is LeveledEffect && concedeSiemprePreparado(e.effects)) ||
      (e is FeatureChoiceEffect &&
          repo.featsByCategory(e.featCategory).isNotEmpty &&
          repo
              .featsByCategory(e.featCategory)
              .every((f) => concedeSiemprePreparado(f.effects))));

  test('todo rasgo que promete Pericia la concede', () {
    lint(
      nombre: 'Pericia',
      // "Pericia"/"pericia", o la mecánica dicha en largo: duplicar el
      // bonificador por competencia.
      promete: (p) =>
          p.contains('ericia') ||
          RegExp('[Dd]uplica[sn]?|duplicás').hasMatch(p) &&
              p.contains('competencia'),
      entrega: (f) => f.effects
          .whereType<ProficiencyChoiceEffect>()
          .any((e) => e.expertise),
      coincidencias: 9,
      falsosPositivos: {
        // Recomienda la dote "Don de la Pericia en Combate" por su nombre; no
        // concede Pericia.
        'clase fighter n19 "Don Épico"',
        // "el daño se duplica" más la CD, que nombra el bonificador por
        // competencia: coincide el patrón, no la mecánica.
        'subclase assassin n17 "Golpe Mortal"',
      },
    );
  });

  test('todo rasgo que promete conjuros siempre preparados los declara', () {
    lint(
      nombre: 'conjuros siempre preparados',
      promete: (p) => RegExp(
        'siempre (?:preparad|tienes preparad|tenés preparad|los ten)'
        '|preparados? (?:adicional|extra)',
        caseSensitive: false,
      ).hasMatch(p),
      entrega: (f) => concedeSiemprePreparado(f.effects),
      // Bajó uno respecto de la tanda anterior a propósito: la descripción de
      // Recuperación Natural decía "y siempre tienes preparados tus conjuros de
      // círculo", que no es lo que dice la regla. Al corregirla dejó de
      // coincidir, que es lo correcto: ese rasgo no concede ninguno.
      coincidencias: 123,
    );
  });

  test('la descripción de cada recurso coincide con su escalado', () {
    // Recorre todo el contenido que puede declarar recursos, no solo clases y
    // subclases: especies, linajes y dotes también tienen.
    final recursos = <({String where, ResourceEffect e})>[
      for (final c in repo.classes.values)
        for (final f in c.features)
          for (final e in f.effects.whereType<ResourceEffect>())
            (where: 'clase ${c.id} n${f.level} ${e.id}', e: e),
      for (final s in repo.subclasses.values)
        for (final f in s.features)
          for (final e in f.effects.whereType<ResourceEffect>())
            (where: 'subclase ${s.id} n${f.level} ${e.id}', e: e),
      for (final r in repo.races.values)
        for (final e in r.effects.whereType<ResourceEffect>())
          (where: 'especie ${r.id} ${e.id}', e: e),
      for (final l in repo.lineages.values)
        for (final f in l.features)
          for (final e in f.effects.whereType<ResourceEffect>())
            (where: 'linaje ${l.id} ${e.id}', e: e),
      for (final f in repo.feats.values)
        for (final e in f.effects.whereType<ResourceEffect>())
          (where: 'dote ${f.id} ${e.id}', e: e),
    ];
    expect(recursos, hasLength(45));

    var porCaracteristica = 0;
    var porNivel = 0;
    var porDobleCompetencia = 0;

    for (final (:where, :e) in recursos) {
      // El nombre de la característica sale de `Ability.label`, así que este
      // patrón no puede desincronizarse del catálogo.
      for (final a in Ability.values) {
        if (e.description.contains('mod. de ${a.label}')) {
          porCaracteristica++;
          expect(e.maxFromAbility, a,
              reason: '$where: la descripción dice "mod. de ${a.label}" y el '
                  'recurso no escala con esa característica');
        }
      }
      // Frases ajustadas a propósito: "nivel de " suelto aparece en prosa que
      // no habla del tamaño del pozo (Recuperación Arcana dice "ninguno de
      // nivel 6+", Forma Salvaje habla de niveles de conjuro).
      if (e.description.contains('pozo = 1 + nivel de') ||
          e.description.contains('iguales a tu nivel') ||
          e.description.contains('igual a tu nivel')) {
        porNivel++;
        expect(e.maxPerLevel, isTrue,
            reason: '$where: la descripción ata el pozo al nivel y el recurso '
                'tiene un máximo fijo');
      }
      if (e.description.contains('dos veces tu bonif. por competencia')) {
        porDobleCompetencia++;
        expect(e.maxFromProficiency && e.proficiencyMultiplier == 2, isTrue,
            reason: '$where: la descripción dice el doble del bonificador por '
                'competencia');
      }
    }

    expect(porCaracteristica, 2,
        reason: 'Chispa de Genialidad, Sacerdote Guerrero');
    expect(porNivel, 3,
        reason: 'Puntos de Enfoque, Puntos de Hechicería, Luz Sanadora');
    expect(porDobleCompetencia, 2, reason: 'los dos Energía Psiónica');
  });

  test('no crecen los rasgos que solo se describen y no se modelan', () {
    final soloTexto = [
      for (final (:where, :feature) in todosLosRasgos())
        if (feature.effects.isNotEmpty &&
            feature.effects.every((e) => e is PassiveTraitEffect))
          where,
    ];

    // ponytail: trinquete, no inventario. Un rasgo nuevo que solo describe su
    // mecánica en vez de declararla hace fallar esto. Si de verdad no se puede
    // modelar todavía, bajá el número a mano y explicá por qué en el commit:
    // el historial de este número es el registro de deuda, y sale más barato
    // que marcar 311 entradas con un motivo que nadie va a leer.
    // Hoy son exactamente 301. Va como cota y no como igualdad para que pagar
    // deuda no haga fallar el test: lo que tiene que doler es *sumar*.
    expect(soloTexto, hasLength(lessThanOrEqualTo(301)),
        reason: 'hay más rasgos que solo son texto que antes:\n'
            '${soloTexto.join('\n')}');
  });

  group('Reglas de dote reescritas contra XPHB (apartado 8.2)', () {
    String prosa(String featId) {
      final f = repo.feat(featId)!;
      return f.effects
          .whereType<PassiveTraitEffect>()
          .map((e) => '${e.name} ${e.description}')
          .join(' ');
    }

    const casos = <(String, List<String>, List<String>)>[
      (
        'healer',
        ['Dados de Golpe', 'bonificador por competencia', 'volver a tirar'],
        []
      ),
      (
        'observant-wisdom',
        ['Perspicacia, Investigación o Percepción', 'acción adicional'],
        ['+5']
      ),
      (
        'heavy-armor-master-strength',
        ['bonificador por competencia'],
        ['no mágico']
      ),
      (
        'ritual-caster-charisma',
        ['etiqueta Ritual', 'siempre preparados', 'descanso largo'],
        []
      ),
      (
        'shield-master',
        ['Golpe de Escudo', 'salvación de Fuerza', 'no recibir ningún daño'],
        []
      ),
      ('speedy-dexterity', ['10 pies', 'terreno difícil', 'desventaja'], []),
      ('spell-sniper-charisma', ['60 pies', 'no se duplica'], []),
      (
        'great-weapon-master',
        ['propiedad Pesada', 'Tajo', 'acción adicional'],
        []
      ),
      (
        'crossbow-expert',
        ['ballesta de mano', 'mano libre', 'propiedad Ligera'],
        []
      ),
      ('charger-strength', ['1d8', '10 pies'], []),
      (
        'chef-wisdom',
        ['4 + tu bonificador por competencia', '1d8', '8 horas'],
        []
      ),
      ('poisoner-dexterity', ['50 po', '2d8', 'envenenada'], []),
    ];

    for (final (featId, debe, noDebe) in casos) {
      test(featId, () {
        final p = prosa(featId);
        for (final f in debe) {
          expect(p, contains(f), reason: featId);
        }
        for (final f in noDebe) {
          expect(p, isNot(contains(f)), reason: featId);
        }
      });
    }

    test('Observador declara la elección de habilidad, no solo el texto', () {
      for (final id in ['observant-intelligence', 'observant-wisdom']) {
        final e =
            repo.feat(id)!.effects.whereType<ProficiencyChoiceEffect>().single;
        expect(e.skills, ['insight', 'investigation', 'perception'],
            reason: id);
        // "competencia, o Pericia si ya eras competente".
        expect(e.expertise, isTrue, reason: id);
        expect(e.allowNewProficiency, isTrue, reason: id);
      }
    });

    test('Chef y Envenenador conceden sus herramientas', () {
      for (final (id, tool) in const [
        ('chef-wisdom', 'cooks-utensils'),
        ('chef-constitution', 'cooks-utensils'),
        ('poisoner-dexterity', 'poisoner-kit'),
        ('poisoner-intelligence', 'poisoner-kit'),
      ]) {
        expect(
          repo.feat(id)!.effects.whereType<ToolProficiencyEffect>().single.tool,
          tool,
          reason: id,
        );
      }
    });

    test('Lanzador Ritual abre un cupo real de rituales de nivel 1', () {
      final e = repo
          .feat('ritual-caster-wisdom')!
          .effects
          .whereType<SpellChoiceEffect>()
          .single;
      expect(e.ritualOnly, isTrue);
      expect(e.countFromProficiency, isTrue);
      expect(e.minLevel, 1);
      expect(e.maxLevel, 1);
    });
  });

  group('Promesas mecánicas del apartado 8.4', () {
    late CharacterCompiler compiler;
    setUpAll(() => compiler = CharacterCompiler(repo));

    Character conDote(
      String featId, {
      Ability? ability,
      Map<String, List<String>> spellChoices = const {},
      int level = 4,
      String classId = 'fighter',
    }) =>
        Character(
          id: 'dotado',
          name: 'Prueba',
          raceId: 'human',
          classId: classId,
          backgroundId: 'soldier',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 14},
          hpPerLevel: List.filled(level, 8),
          featIds: [featId],
          featSpellcastingAbilities:
              ability == null ? const {} : {featId: ability},
          spellChoices: spellChoices,
        );

    test('Iniciado en la Magia abre dos cupos: trucos y conjuro de nivel 1',
        () {
      final s = compiler.compile(conDote('magic-initiate-wizard'));
      final slots = {
        for (final x in s.spellChoiceSlots) x.groupId: x,
      };
      expect(slots['magic-initiate-wizard:cantrips']!.count, 2);
      expect(slots['magic-initiate-wizard:cantrips']!.replaceable, isTrue);
      expect(slots['magic-initiate-wizard:spell']!.count, 1);
      expect(slots['magic-initiate-wizard:spell']!.replaceable, isTrue);
      // El pozo sale de la lista que nombra la dote.
      for (final id in slots['magic-initiate-wizard:cantrips']!.options) {
        expect(repo.spell(id)!.level, 0);
        expect(repo.spell(id)!.classes, contains('wizard'));
      }
    });

    test('la característica elegida manda sobre la del contenido', () {
      final elegido = conDote(
        'magic-initiate-wizard',
        ability: Ability.charisma,
        spellChoices: const {
          'magic-initiate-wizard:spell': ['magic-missile'],
        },
      );
      final s = compiler.compile(elegido);
      final innato =
          s.innateSpells.firstWhere((x) => x.spellId == 'magic-missile');
      expect(innato.ability, Ability.charisma);
      expect(s.alwaysPreparedSpellIds, contains('magic-missile'));

      // Sin elección cae en la del contenido, que es Inteligencia.
      final sinElegir = compiler.compile(conDote(
        'magic-initiate-wizard',
        spellChoices: const {
          'magic-initiate-wizard:spell': ['magic-missile'],
        },
      ));
      expect(
        sinElegir.innateSpells
            .firstWhere((x) => x.spellId == 'magic-missile')
            .ability,
        Ability.intelligence,
      );
    });

    test('las Marcas Dracónicas conceden sus conjuros, no solo el texto', () {
      // Tormenta: truco Tronar a voluntad, y a nivel 3 Ráfaga de Viento gratis.
      final n1 = compiler.compile(conDote('mark-of-storm', level: 1));
      expect(n1.innateSpells.map((s) => s.spellId), contains('thunderclap'));
      expect(n1.innateSpells.map((s) => s.spellId),
          isNot(contains('gust-of-wind')));

      final n3 = compiler.compile(conDote('mark-of-storm', level: 3));
      final rafaga =
          n3.innateSpells.firstWhere((s) => s.spellId == 'gust-of-wind');
      expect(rafaga.use, InnateSpellUse.oncePerLongRest);
    });

    test('la característica de la marca la elige el personaje', () {
      final s = compiler.compile(conDote(
        'mark-of-storm',
        ability: Ability.charisma,
        level: 3,
      ));
      for (final innato in s.innateSpells) {
        expect(innato.ability, Ability.charisma, reason: innato.spellId);
      }
    });

    test('las doce marcas conceden al menos un conjuro cada una', () {
      final marcas = repo.feats.values.where(
          (f) => f.category == 'dragonmark' && f.id != 'aberrant-dragonmark');
      for (final m in marcas) {
        final innatos = m.effects.expand(
          (e) => e is LeveledEffect
              ? e.effects.whereType<GrantSpellEffect>()
              : e is GrantSpellEffect
                  ? [e]
                  : const <GrantSpellEffect>[],
        );
        expect(innatos, isNotEmpty, reason: m.id);
        for (final g in innatos) {
          expect(repo.spell(g.spellId), isNotNull,
              reason: '${m.id}: ${g.spellId}');
        }
      }
    });

    test('la Marca Aberrante usa Constitución y descanso corto', () {
      final s = compiler.compile(conDote(
        'aberrant-dragonmark',
        spellChoices: const {
          'aberrant-dragonmark:spell': ['magic-missile'],
        },
      ));
      final innato =
          s.innateSpells.firstWhere((x) => x.spellId == 'magic-missile');
      expect(innato.ability, Ability.constitution);
      expect(innato.use, InnateSpellUse.oncePerShortRest);
    });

    test('Marca Dracónica Potente sube la característica de su marca', () {
      final base = compiler.compile(
          conDote('mark-of-storm', ability: Ability.charisma, level: 4));
      final conPotente = compiler.compile(Character(
        id: 'potente',
        name: 'Prueba',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 4,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [6, 4, 4, 4],
        featIds: const ['mark-of-storm', 'potent-dragonmark'],
        featSpellcastingAbilities: const {'mark-of-storm': Ability.charisma},
      ));
      expect(conPotente.abilityScores[Ability.charisma],
          base.abilityScores[Ability.charisma]! + 1);
    });

    test('Marca Dracónica Potente deja preparados los conjuros de la marca',
        () {
      final sinPotente = compiler.compile(Character(
        id: 'sin',
        name: 'Prueba',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 4,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [6, 4, 4, 4],
        featIds: const ['mark-of-storm'],
      ));
      expect(sinPotente.alwaysPreparedSpellIds, isNot(contains('levitate')));

      final conPotente = compiler.compile(Character(
        id: 'con',
        name: 'Prueba',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 4,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [6, 4, 4, 4],
        featIds: const ['mark-of-storm', 'potent-dragonmark'],
      ));
      // Los nueve Conjuros de la Marca quedan siempre preparados.
      expect(conPotente.alwaysPreparedSpellIds, contains('levitate'));
      expect(conPotente.alwaysPreparedSpellIds, contains('conjure-elemental'));
    });

    test('Don de la Habilidad da las 18 competencias y un cupo de Pericia', () {
      final s = compiler.compile(conDote('boon-of-skill', level: 19));
      expect(s.skillProficiencies, hasLength(18));
      expect(
        s.expertiseChoiceSlots
            .where((x) => x.groupId == 'boon-of-skill:expertise'),
        hasLength(1),
      );
    });
  });
}
