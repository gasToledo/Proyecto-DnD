import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Lo que encontró la observación del Brujo gnomo (24/09/2026): usos de Pasos
/// del Feérico, elecciones del Pacto del Grimorio, el truco de Descarga
/// Agónica y los cupos de trucos y preparados que quedaban sin avisar.
///
/// Todo contra el contenido real: el error del punto 1 era de dato, y un repo
/// armado a mano lo habría escondido.
Character _warlock({
  int level = 3,
  int charisma = 17,
  String? subclassId = 'archfey-patron',
  List<String> invocations = const [],
  List<String> cantrips = const [],
  List<String> spells = const [],
  Map<String, List<String>> spellChoices = const {},
  String backgroundId = 'soldier',
  String raceId = 'gnome',
}) =>
    Character(
      id: 'brujo',
      name: 'Nimble Fizzwick',
      raceId: raceId,
      lineageId: raceId == 'gnome' ? 'gnome-forest' : null,
      speciesSpellcastingAbility: Ability.charisma,
      classId: 'warlock',
      subclassId: level >= 3 ? subclassId : null,
      backgroundId: backgroundId,
      level: level,
      hpPerLevel: [8, for (var i = 1; i < level; i++) 5],
      assignedScores: {
        Ability.strength: 8,
        Ability.dexterity: 14,
        Ability.constitution: 13,
        Ability.intelligence: 12,
        Ability.wisdom: 10,
        Ability.charisma: charisma,
      },
      featureChoices: {'warlock-invocation': invocations},
      cantripIds: cantrips,
      spellIds: spells,
      spellChoices: spellChoices,
    );

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;
  late CharacterValidator validator;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
    validator = CharacterValidator(repo);
  });

  CharacterResource? resource(ComputedSheet sheet, String spellId) =>
      sheet.resources
          .where((r) => r.id == innateSpellResourceId(spellId))
          .firstOrNull;

  SpellChoiceSlot slot(ComputedSheet sheet, String groupId) =>
      sheet.spellChoiceSlots.singleWhere((s) => s.groupId == groupId);

  group('Pasos del Feérico usa el modificador de Carisma', () {
    test('con Carisma 17 son tantos usos como el modificador', () {
      final sheet = compiler.compile(_warlock(charisma: 17));
      final mod = sheet.abilityModifiers[Ability.charisma]!;
      expect(mod, greaterThan(sheet.proficiencyBonus),
          reason: 'si fueran iguales, el test no distinguiría el defecto');
      expect(resource(sheet, 'misty-step')!.max, mod);
    });

    test('el máximo sigue a la característica', () {
      final base = compiler.compile(_warlock(charisma: 17));
      final subida = compiler.compile(_warlock(charisma: 19));
      expect(
        resource(subida, 'misty-step')!.max,
        resource(base, 'misty-step')!.max + 1,
      );
    });

    test('con modificador nulo o negativo queda un uso', () {
      final sheet = compiler.compile(_warlock(charisma: 8));
      expect(sheet.abilityModifiers[Ability.charisma], lessThanOrEqualTo(0));
      expect(resource(sheet, 'misty-step')!.max, 1);
    });

    test('la ficha expone los usos gratis en el conjuro innato', () {
      final sheet = compiler.compile(_warlock(charisma: 17));
      final innate =
          sheet.innateSpells.singleWhere((s) => s.spellId == 'misty-step');
      expect(innate.use, InnateSpellUse.abilityModifierPerLongRest);
      expect(innate.freeUses, resource(sheet, 'misty-step')!.max);
    });

    test('Hablar con los Animales del Gnomo del Bosque sigue por competencia',
        () {
      final sheet = compiler.compile(_warlock(level: 4));
      expect(
          resource(sheet, 'speak-with-animals')!.max, sheet.proficiencyBonus);
    });

    test('el valor nuevo hace round-trip por JSON', () {
      const effect = GrantSpellEffect(
        spellId: 'misty-step',
        ability: Ability.charisma,
        use: InnateSpellUse.abilityModifierPerLongRest,
      );
      final back = Effect.fromJson(effect.toJson()) as GrantSpellEffect;
      expect(back.use, InnateSpellUse.abilityModifierPerLongRest);
    });
  });

  group('Pacto del Grimorio', () {
    test('expone tres trucos y dos rituales, sin elegir', () {
      final sheet = compiler.compile(_warlock(
        level: 1,
        invocations: ['pact-of-the-tome'],
      ));
      final trucos = slot(sheet, 'pact-of-the-tome:cantrips');
      final rituales = slot(sheet, 'pact-of-the-tome:rituals');
      expect(trucos.count, 3);
      expect(rituales.count, 2);
      expect(trucos.chosen, isEmpty);
      expect(rituales.chosen, isEmpty);
    });

    test('el pozo de rituales es de nivel 1 con la etiqueta Ritual', () {
      final sheet = compiler.compile(_warlock(
        level: 1,
        invocations: ['pact-of-the-tome'],
      ));
      final rituales = slot(sheet, 'pact-of-the-tome:rituals');
      expect(rituales.options, isNotEmpty);
      for (final id in rituales.options) {
        final s = repo.spell(id)!;
        expect(s.level, 1, reason: id);
        expect(s.ritual, isTrue, reason: id);
      }
      // De cualquier lista, no solo la de Brujo.
      expect(
        rituales.options
            .any((id) => !repo.spell(id)!.classes.contains('warlock')),
        isTrue,
      );
    });

    test('lo elegido queda siempre preparado y no mueve los cupos de clase',
        () {
      final sin = compiler.compile(_warlock(
        level: 1,
        invocations: ['pact-of-the-tome'],
      ));
      final trucos = slot(sin, 'pact-of-the-tome:cantrips').options.take(3);
      final rituales = slot(sin, 'pact-of-the-tome:rituals').options.take(2);
      final con = compiler.compile(_warlock(
        level: 1,
        invocations: ['pact-of-the-tome'],
        spellChoices: {
          'pact-of-the-tome:cantrips': [...trucos],
          'pact-of-the-tome:rituals': [...rituales],
        },
      ));
      expect(con.alwaysPreparedSpellIds, containsAll([...trucos, ...rituales]));
      expect(con.spellcasting!.cantripsKnown, sin.spellcasting!.cantripsKnown);
      expect(con.spellcasting!.preparedCount, sin.spellcasting!.preparedCount);
    });
  });

  group('Descarga Agónica', () {
    Character agonico({
      List<String> invocations = const ['agonizing-blast'],
      List<String> cantrips = const ['eldritch-blast', 'mind-sliver'],
      List<String> elegidos = const [],
      int charisma = 18,
      String backgroundId = 'soldier',
      Map<String, List<String>> otrasElecciones = const {},
    }) =>
        _warlock(
          level: 4,
          charisma: charisma,
          invocations: invocations,
          cantrips: cantrips,
          backgroundId: backgroundId,
          spellChoices: {
            ...otrasElecciones,
            'agonizing-blast:cantrips': elegidos,
          },
        );

    test('suma el modificador de Carisma al truco elegido', () {
      final sheet = compiler.compile(agonico(elegidos: ['eldritch-blast']));
      final bonos = sheet.spellDamageBonuses['eldritch-blast']!;
      expect(bonos.single.bonus, sheet.abilityModifiers[Ability.charisma]);
      expect(bonos.single.source, 'Descarga Agónica');
      expect(sheet.spellDamageBonuses.containsKey('mind-sliver'), isFalse);
    });

    test('el pozo son los trucos de Brujo que ya conoce, por cualquier vía',
        () {
      final sheet = compiler.compile(agonico());
      final cupo = slot(sheet, 'agonizing-blast:cantrips');
      // Ilusión Menor no es de clase: la concede el Gnomo del Bosque. Entra
      // porque está en la lista de Brujo y el personaje la conoce.
      expect(repo.spell('minor-illusion')!.classes, contains('warlock'));
      expect(
        cupo.options,
        unorderedEquals(['eldritch-blast', 'mind-sliver', 'minor-illusion']),
      );
      expect(cupo.grantsSpells, isFalse);
    });

    test('un truco conocido de otra lista no entra al pozo', () {
      // Guía llega por Iniciado en la Magia (Clérigo) y no es de Brujo.
      expect(repo.spell('guidance')!.classes, isNot(contains('warlock')));
      final c = agonico(
        backgroundId: 'acolyte',
        otrasElecciones: {
          'magic-initiate-cleric:cantrips': ['guidance', 'light'],
        },
      );
      final sheet = compiler.compile(c);
      expect(sheet.alwaysPreparedSpellIds, contains('guidance'));
      expect(slot(sheet, 'agonizing-blast:cantrips').options,
          isNot(contains('guidance')));
    });

    test('elegir el truco no lo concede', () {
      final sin = compiler.compile(agonico(cantrips: const ['eldritch-blast']));
      final con = compiler.compile(agonico(
        cantrips: const ['eldritch-blast'],
        elegidos: ['eldritch-blast'],
      ));
      expect(con.alwaysPreparedSpellIds, sin.alwaysPreparedSpellIds);
      expect(con.alwaysPreparedSpellIds, isNot(contains('eldritch-blast')));
    });

    test('tomada dos veces son dos trucos distintos', () {
      final sheet = compiler.compile(agonico(
        invocations: ['agonizing-blast', 'agonizing-blast'],
        elegidos: ['eldritch-blast', 'eldritch-blast', 'mind-sliver'],
      ));
      final cupo = slot(sheet, 'agonizing-blast:cantrips');
      expect(cupo.count, 2);
      expect(cupo.chosen, ['eldritch-blast', 'mind-sliver']);
      expect(sheet.spellDamageBonuses.keys,
          unorderedEquals(['eldritch-blast', 'mind-sliver']));
    });

    test('si deja de conocer el truco, el bono se va y la validación avisa',
        () {
      final c = agonico(
        cantrips: const ['mind-sliver'],
        elegidos: ['eldritch-blast'],
      );
      final sheet = compiler.compile(c);
      expect(sheet.spellDamageBonuses, isEmpty);
      final codes = validator.validate(c).map((w) => w.code);
      expect(codes, contains('spell_choice_invalid'));
    });

    test('sin trucos de Brujo conocidos, el cupo no queda imposible', () {
      // Los dos linajes de gnomo dan un truco de la lista de Brujo, así que
      // se usa un Humano sin trucos de clase.
      final c = _warlock(
        level: 4,
        raceId: 'human',
        invocations: ['agonizing-blast'],
      );
      final cupo = slot(compiler.compile(c), 'agonizing-blast:cantrips');
      expect(cupo.options, isEmpty);
      expect(cupo.count, 0);
      expect(cupo.pending, 0);
    });

    test('sin elegir, la validación lo marca pendiente', () {
      final codes = validator.validate(agonico()).map((w) => w.code);
      expect(codes, contains('spell_choice_pending'));
    });

    test('el efecto hace round-trip por JSON', () {
      const effect = SpellDamageBonusEffect(
        groupId: 'g',
        name: 'Rótulo',
        ability: Ability.charisma,
        fromClasses: ['warlock'],
      );
      final back = Effect.fromJson(effect.toJson()) as SpellDamageBonusEffect;
      expect(back.groupId, 'g');
      expect(back.name, 'Rótulo');
      expect(back.ability, Ability.charisma);
      expect(back.fromClasses, ['warlock']);
    });
  });

  group('Trucos y preparados sin elegir', () {
    test('un truco de clase por debajo del cupo avisa, informativo', () {
      final c = _warlock(
        level: 4,
        cantrips: ['eldritch-blast'],
        spells: ['hex'],
      );
      final warnings = validator.validate(c);
      final truco = warnings.singleWhere((w) => w.code == 'cantrips_pending');
      expect(truco.severity, WarningSeverity.info);
      final cupo = compiler.compile(c).spellcasting!.cantripsKnown;
      expect(truco.message, contains('1 de $cupo'));
    });

    test('un conjuro preparado por debajo del cupo avisa, informativo', () {
      final c =
          _warlock(level: 4, cantrips: ['eldritch-blast'], spells: ['hex']);
      final w = validator
          .validate(c)
          .singleWhere((w) => w.code == 'prepared_pending');
      expect(w.severity, WarningSeverity.info);
    });

    test('con los cupos llenos no avisa', () {
      final probe = compiler.compile(_warlock(level: 4));
      final sc = probe.spellcasting!;
      final lista = repo.spellsForList(sc.spellList);
      final trucos = [
        for (final s in lista)
          if (s.isCantrip && !probe.alwaysPreparedSpellIds.contains(s.id)) s.id
      ].take(sc.cantripsKnown).toList();
      final maxNivel = sc.slotsByLevel.keys.reduce((a, b) => a > b ? a : b);
      final conjuros = [
        for (final s in lista)
          if (!s.isCantrip &&
              s.level <= maxNivel &&
              !probe.alwaysPreparedSpellIds.contains(s.id) &&
              !probe.innateSpells.any((i) => i.spellId == s.id))
            s.id
      ].take(sc.preparedCount).toList();
      final codes = validator
          .validate(_warlock(level: 4, cantrips: trucos, spells: conjuros))
          .map((w) => w.code);
      expect(codes, isNot(contains('cantrips_pending')));
      expect(codes, isNot(contains('prepared_pending')));
    });
  });
}
