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
      coincidencias: 8,
      falsosPositivos: {
        // Recomienda la dote "Don de la Pericia en Combate" por su nombre; no
        // concede Pericia.
        'clase fighter n19 "Don Épico"',
      },
    );
  });

  test('todo rasgo que promete conjuros siempre preparados los declara', () {
    lint(
      nombre: 'conjuros siempre preparados',
      promete: (p) => RegExp(
        'siempre (?:preparad|tienes preparad|tenés preparad|los ten)'
        '|preparados? (?:adicional|extra)',
      ).hasMatch(p),
      entrega: (f) =>
          f.effects.whereType<AlwaysPreparedSpellEffect>().isNotEmpty,
      coincidencias: 114,
      deuda: {
        'clase wizard n20 "Conjuros Característicos"':
            'son dos conjuros de nivel 3 a elección del jugador y esa elección '
                'no existe en el motor',
        'subclase college-lore n6 "Descubrimientos Mágicos"':
            'dos conjuros de cualquier lista a elección del jugador',
        'subclase circle-land n3 "Conjuros de Círculo"':
            'la tabla depende del terreno elegido (árido, polar, templado o '
                'tropical) y esa elección no existe en el motor',
        'subclase circle-land n6 "Recuperación Natural"':
            'se apoya en la tabla por terreno del nivel 3',
      },
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
    expect(recursos, hasLength(44));

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
    // Hoy son exactamente 304. Va como cota y no como igualdad para que pagar
    // deuda no haga fallar el test: lo que tiene que doler es *sumar*.
    expect(soloTexto, hasLength(lessThanOrEqualTo(304)),
        reason: 'hay más rasgos que solo son texto que antes:\n'
            '${soloTexto.join('\n')}');
  });
}
