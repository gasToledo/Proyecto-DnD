import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Forma Salvaje: el pozo de formas que da cada nivel, la ficha transformada y
/// las dos operaciones de partida.
///
/// Corre contra el contenido real del SRD y no contra un druida de mentira: lo
/// que se quiere fijar es que la tabla del rasgo esté bien declarada en
/// `classes.json` y que el filtro dé sobre las bestias de verdad.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  ComputedSheet druid(
    int level, {
    List<String> forms = const [],
    ContentRepository? using,
  }) =>
      CharacterCompiler(using ?? repo).compile(
        Character(
          id: 'probe',
          name: 'Prueba',
          raceId: 'human',
          classId: 'druid',
          backgroundId: 'sage',
          level: level,
          wildShapeForms: forms,
          assignedScores: {
            Ability.strength: 8,
            Ability.dexterity: 12,
            Ability.constitution: 14,
            Ability.intelligence: 13,
            Ability.wisdom: 16,
            Ability.charisma: 10,
          },
          hpPerLevel: List.filled(level, 5),
        ),
      );

  group('El pozo de formas sale del nivel', () {
    test('a nivel 2 son 4 formas de hasta VD 1/4 y sin vuelo', () {
      final slot = druid(2).wildShape!;
      expect(slot.count, 4);
      expect(slot.options, isNotEmpty);
      for (final beast in slot.options) {
        expect(beast.cr, lessThanOrEqualTo(0.25), reason: beast.id);
        expect(beast.canFly, isFalse, reason: beast.id);
      }
      // El lobo entra por VD y el halcón queda afuera por volar, aunque su VD
      // sea 0.
      expect(slot.options.map((b) => b.id), contains('wolf'));
      expect(slot.options.map((b) => b.id), isNot(contains('hawk')));
    });

    test('a nivel 8 son 8 formas de hasta VD 1 y ya se puede volar', () {
      final slot = druid(8).wildShape!;
      expect(slot.count, 8);
      expect(slot.options.map((b) => b.id), contains('hawk'));
      expect(slot.options.map((b) => b.id), contains('dire-wolf'));
      for (final beast in slot.options) {
        expect(beast.cr, lessThanOrEqualTo(1), reason: beast.id);
      }
    });

    test('a nivel 4 son 6 formas y el pozo crece con el techo de VD', () {
      final dos = druid(2).wildShape!;
      final cuatro = druid(4).wildShape!;
      expect(cuatro.count, 6);
      expect(cuatro.options.length, greaterThan(dos.options.length));
      // El oso negro es VD 1/2: no estaba a nivel 2 y aparece a nivel 4.
      expect(dos.options.map((b) => b.id), isNot(contains('black-bear')));
      expect(cuatro.options.map((b) => b.id), contains('black-bear'));
    });

    test('una bestia homebrew entra al pozo solo si se declara disponible',
        () async {
      // Repositorio propio: el compartido lo usan los demás tests y una
      // criatura de más le cambiaría los conteos por la espalda.
      final conHomebrew = await ContentRepository.loadFromDirectory(
        'lib/assets/srd_2024',
      );
      Creature bestia(String id, {required bool available}) => Creature(
            id: id,
            name: id,
            source: ContentSource.homebrew,
            type: CreatureType.beast,
            ac: '12',
            hp: '10',
            speed: '30 pies',
            cr: 0.25,
            availableToCharacters: available,
          );
      conHomebrew.creatures['sapo-gigante-hb'] = bestia(
        'sapo-gigante-hb',
        available: true,
      );
      conHomebrew.creatures['monstruo-del-dm'] = bestia(
        'monstruo-del-dm',
        available: false,
      );

      final ids =
          druid(2, using: conHomebrew).wildShape!.options.map((b) => b.id);
      expect(ids, contains('sapo-gigante-hb'));
      // El monstruo del DM cumple todo lo demás —bestia, VD 1/4, sin vuelo— y
      // queda afuera solo por el interruptor: es lo único que lo separa.
      expect(ids, isNot(contains('monstruo-del-dm')));
    });

    test('un druida de nivel 1 todavía no tiene el rasgo', () {
      expect(druid(1).wildShape, isNull);
    });

    test('un personaje que no es druida no tiene formas', () {
      final sheet = CharacterCompiler(repo).compile(
        Character(
          id: 'probe',
          name: 'Prueba',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'sage',
          level: 8,
          assignedScores: {
            for (final a in Ability.values) a: 12,
          },
          hpPerLevel: const [5, 5, 5, 5, 5, 5, 5, 5],
        ),
      );
      expect(sheet.wildShape, isNull);
    });
  });

  group('Lo anotado se revalida contra el pozo', () {
    test('una forma guardada que califica llega al cupo', () {
      final slot = druid(2, forms: ['wolf']).wildShape!;
      expect(slot.chosen.single.id, 'wolf');
      expect(slot.pending, 3);
    });

    test('una forma que dejó de calificar no llega', () {
      // El lobo huargo es VD 1: legal a nivel 8, no a nivel 2. Un druida que
      // bajó de nivel lo tiene guardado y no debe poder usarlo.
      expect(druid(8, forms: ['dire-wolf']).wildShape!.chosen, hasLength(1));
      expect(druid(2, forms: ['dire-wolf']).wildShape!.chosen, isEmpty);
    });

    test('lo repetido y lo que sobra del cupo se descartan', () {
      final slot =
          druid(2, forms: ['wolf', 'wolf', 'boar', 'panther', 'elk', 'camel'])
              .wildShape!;
      expect(slot.chosen.map((b) => b.id), ['wolf', 'boar', 'panther', 'elk']);
      expect(slot.pending, 0);
    });
  });

  group('La ficha transformada', () {
    test('toma de la bestia la CA, la velocidad, los sentidos y el físico', () {
      final base = druid(4, forms: ['wolf']);
      final wolf = base.wildShape!.chosen.single;
      final shaped = applyWildShape(base, wolf);

      expect(shaped.armorClass, 12);
      expect(shaped.speed, 40);
      expect(shaped.darkvision, 60);
      expect(shaped.size, 'Mediano');
      expect(shaped.abilityScores[Ability.strength], 14);
      expect(shaped.abilityScores[Ability.dexterity], 15);
      expect(shaped.abilityScores[Ability.constitution], 12);
      expect(shaped.abilityModifiers[Ability.strength], 2);
      // La iniciativa es la DES de la bestia, no la del druida.
      expect(shaped.initiative, 2);
    });

    test('conserva PG, dados de golpe, lo mental y los rasgos de clase', () {
      final base = druid(4, forms: ['wolf']);
      final shaped = applyWildShape(base, base.wildShape!.chosen.single);

      expect(shaped.maxHp, base.maxHp);
      expect(shaped.hitDie, base.hitDie);
      expect(shaped.level, base.level);
      expect(shaped.proficiencyBonus, base.proficiencyBonus);
      for (final a in [
        Ability.intelligence,
        Ability.wisdom,
        Ability.charisma
      ]) {
        expect(shaped.abilityScores[a], base.abilityScores[a], reason: a.name);
        expect(shaped.abilityModifiers[a], base.abilityModifiers[a]);
      }
      expect(shaped.passives, base.passives);
      expect(shaped.resources, base.resources);
      expect(shaped.skillProficiencies, base.skillProficiencies);
      expect(shaped.spellcasting, base.spellcasting);
      // Las salvaciones mentales del druida siguen siendo suyas: SAB con
      // competencia.
      expect(
          shaped.savingThrow(Ability.wisdom), base.savingThrow(Ability.wisdom));
    });

    test('los ataques son los de la bestia, con su bono', () {
      final base = druid(4, forms: ['wolf']);
      final shaped = applyWildShape(base, base.wildShape!.chosen.single);

      expect(shaped.attacks, hasLength(1));
      final bite = shaped.attacks.single;
      expect(bite.name, 'Mordisco');
      expect(bite.attackBonus, 4);
      expect(bite.damage, '1d6+2');
    });

    test('las habilidades se recalculan solas desde el nuevo físico', () {
      final base = druid(4, forms: ['panther']);
      final shaped = applyWildShape(base, base.wildShape!.chosen.single);
      // La pantera tiene DES 16 (+3) y el druida 12 (+1): el Sigilo sube sin
      // que nadie toque la tabla de habilidades.
      expect(
          shaped.skillModifier('stealth'), base.skillModifier('stealth') + 2);
    });
  });

  group('Transformarse y volver', () {
    test('gasta un uso y suma PG temporales iguales al nivel', () {
      final sheet = druid(4, forms: ['wolf']);
      final combat = CombatState(currentHp: sheet.maxHp);

      expect(
        CombatOps.enterWildShape(combat, sheet, sheet.wildShape!.chosen.single),
        isTrue,
      );
      expect(combat.wildShapeCreatureId, 'wolf');
      expect(combat.resourceUsage[CombatOps.wildShapeResourceId], 1);
      expect(combat.tempHp, 4);
    });

    test('sin usos no se transforma', () {
      final sheet = druid(4, forms: ['wolf']);
      final combat = CombatState(
        currentHp: sheet.maxHp,
        resourceUsage: {CombatOps.wildShapeResourceId: 2},
      );
      expect(
        CombatOps.enterWildShape(combat, sheet, sheet.wildShape!.chosen.single),
        isFalse,
      );
      expect(combat.wildShapeCreatureId, isNull);
      expect(combat.tempHp, 0);
    });

    test('volver limpia la forma y deja los PG temporales', () {
      final sheet = druid(4, forms: ['wolf']);
      final combat = CombatState(currentHp: sheet.maxHp);
      CombatOps.enterWildShape(combat, sheet, sheet.wildShape!.chosen.single);

      CombatOps.leaveWildShape(combat);
      expect(combat.wildShapeCreatureId, isNull);
      expect(combat.tempHp, 4);
      // El uso gastado no vuelve.
      expect(combat.resourceUsage[CombatOps.wildShapeResourceId], 1);
    });

    test('a 0 PG se vuelve solo', () {
      final sheet = druid(4, forms: ['wolf']);
      final combat = CombatState(currentHp: sheet.maxHp);
      CombatOps.enterWildShape(combat, sheet, sheet.wildShape!.chosen.single);

      CombatOps.applyDamage(combat, 500);
      expect(combat.currentHp, 0);
      expect(combat.wildShapeCreatureId, isNull);
    });

    test('el descanso largo devuelve la forma propia y los usos', () {
      final sheet = druid(4, forms: ['wolf']);
      final combat = CombatState(currentHp: sheet.maxHp);
      CombatOps.enterWildShape(combat, sheet, sheet.wildShape!.chosen.single);

      CombatOps.longRest(combat, sheet.maxHp, sheet.resources, 4);
      expect(combat.wildShapeCreatureId, isNull);
      expect(combat.resourceUsage[CombatOps.wildShapeResourceId], 0);
    });
  });

  group('Lo que la transformación no puede perder', () {
    /// Regresión de un bug real: `applyWildShape` reconstruía la ficha campo
    /// por campo y se olvidaba de dos, que son opcionales en el constructor y
    /// por eso caían a su valor por defecto sin que el compilador dijera nada.
    /// Ahora se construye con `copyWith` y nombra solo lo que la bestia
    /// reemplaza.
    ComputedSheet naturalista(int level) => CharacterCompiler(repo).compile(
          Character(
            id: 'naturalista',
            name: 'Prueba',
            raceId: 'human',
            classId: 'druid',
            backgroundId: 'sage',
            level: level,
            wildShapeForms: const ['wolf'],
            assignedScores: const {
              Ability.strength: 8,
              Ability.dexterity: 12,
              Ability.constitution: 14,
              Ability.intelligence: 13,
              Ability.wisdom: 16,
              Ability.charisma: 10,
            },
            hpPerLevel: const [5, 5, 5, 5],
            // Naturalista suma el modificador de Sabiduría a las pruebas de
            // Arcanos y Naturaleza: es lo que llena `skillBonuses`.
            featureChoices: const {
              'primal-order': ['primal-order-magician'],
            },
            coins: const {'gp': 300},
          ),
        );

    test('el bono de Orden Primordial sigue en la ficha de la bestia', () {
      final base = naturalista(4);
      expect(base.skillBonuses, isNotEmpty);

      final shaped = applyWildShape(base, base.wildShape!.chosen.single);
      expect(shaped.skillBonuses, base.skillBonuses);
    });

    test('la mochila sigue pesando lo que pesaba', () {
      final base = naturalista(4);
      expect(base.carriedWeight, greaterThan(0));

      final shaped = applyWildShape(base, base.wildShape!.chosen.single);
      expect(shaped.carriedWeight, base.carriedWeight);
    });
  });
}
