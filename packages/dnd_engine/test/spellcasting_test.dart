import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Clase lanzadora sintética (homebrew) para probar el motor sin depender de
/// que existan las clases lanzadoras oficiales (Fase E).
CharacterClass _mageClass() => const CharacterClass(
      id: 'testmage',
      name: 'Mago de prueba',
      source: ContentSource.homebrew,
      hitDie: 6,
      savingThrows: [Ability.intelligence, Ability.wisdom],
      features: [
        ClassFeature(
          level: 1,
          name: 'Lanzamiento de Conjuros',
          effects: [
            SpellcastingEffect(
              ability: Ability.intelligence,
              progression: CasterProgression.full,
              preparation: SpellPreparation.prepared,
              spellList: 'wizard',
              cantripsKnown: 3,
            ),
          ],
        ),
      ],
    );

Character _caster({required int level, required List<int> hp}) => Character(
      id: 'c',
      name: 'Prueba',
      raceId: '',
      classId: 'testmage',
      backgroundId: '',
      level: level,
      assignedScores: {
        Ability.strength: 8,
        Ability.dexterity: 14,
        Ability.constitution: 12,
        Ability.intelligence: 16,
        Ability.wisdom: 12,
        Ability.charisma: 10,
      },
      hpPerLevel: hp,
    );

void main() {
  group('Tablas de espacios de conjuro', () {
    test('lanzador completo escala correctamente', () {
      expect(spellSlotsFor(CasterProgression.full, 1), {1: 2});
      expect(spellSlotsFor(CasterProgression.full, 3), {1: 4, 2: 2});
      expect(spellSlotsFor(CasterProgression.full, 5), {1: 4, 2: 3, 3: 2});
      expect(spellSlotsFor(CasterProgression.full, 20),
          {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 2, 8: 1, 9: 1});
    });

    test('semi-lanzador no lanza a nivel 1 y escala más lento', () {
      expect(spellSlotsFor(CasterProgression.half, 1), isEmpty);
      expect(spellSlotsFor(CasterProgression.half, 2), {1: 2});
      expect(spellSlotsFor(CasterProgression.half, 5), {1: 4, 2: 2});
      expect(spellSlotsFor(CasterProgression.half, 20), {1: 4, 2: 3, 3: 3, 4: 3, 5: 2});
    });

    test('un tercio empieza a nivel 3', () {
      expect(spellSlotsFor(CasterProgression.third, 2), isEmpty);
      expect(spellSlotsFor(CasterProgression.third, 3), {1: 2});
      expect(spellSlotsFor(CasterProgression.third, 7), {1: 4, 2: 2});
    });

    test('magia de pacto: pocos espacios, siempre del nivel más alto', () {
      expect(spellSlotsFor(CasterProgression.pact, 1), {1: 1});
      expect(spellSlotsFor(CasterProgression.pact, 5), {3: 2});
      expect(spellSlotsFor(CasterProgression.pact, 11), {5: 3});
      expect(spellSlotsFor(CasterProgression.pact, 20), {5: 4});
    });

    test('none no da espacios', () {
      expect(spellSlotsFor(CasterProgression.none, 10), isEmpty);
    });
  });

  group('Serialización', () {
    test('SpellcastingEffect round-trip', () {
      const e = SpellcastingEffect(
        ability: Ability.charisma,
        progression: CasterProgression.pact,
        preparation: SpellPreparation.known,
        spellList: 'warlock',
        cantripsKnown: 2,
      );
      final r = Effect.fromJson(e.toJson()) as SpellcastingEffect;
      expect(r.ability, Ability.charisma);
      expect(r.progression, CasterProgression.pact);
      expect(r.preparation, SpellPreparation.known);
      expect(r.spellList, 'warlock');
      expect(r.cantripsKnown, 2);
    });

    test('Spell round-trip', () {
      const s = Spell(
        id: 'hb', name: 'Conjuro propio', source: ContentSource.homebrew,
        level: 3, school: 'Evocación', concentration: true, ritual: false,
        classes: ['wizard', 'sorcerer'],
      );
      final r = Spell.fromJson(s.toJson());
      expect(r.level, 3);
      expect(r.concentration, isTrue);
      expect(r.classes, ['wizard', 'sorcerer']);
    });
  });

  group('Compilación de un lanzador', () {
    final repo = ContentRepository(classes: {'testmage': _mageClass()});
    final compiler = CharacterCompiler(repo);

    test('CD, ataque y espacios a nivel 5', () {
      final s = compiler.compile(_caster(level: 5, hp: [6, 4, 4, 4, 4]));
      final sc = s.spellcasting;
      expect(sc, isNotNull);
      expect(sc!.ability, Ability.intelligence);
      expect(sc.saveDc, 14); // 8 + prof(3) + INT(+3)
      expect(sc.attackBonus, 6); // prof(3) + INT(+3)
      expect(sc.slotsByLevel, {1: 4, 2: 3, 3: 2});
      expect(sc.cantripsKnown, 3);
      expect(sc.preparedCount, 8); // nivel(5) + INT(+3)
    });

    test('un no-lanzador no tiene bloque de lanzamiento', () {
      final noCaster = Character(
        id: 'n', name: 'X', raceId: '', classId: 'nope', backgroundId: '',
        assignedScores: {for (final a in Ability.values) a: 10},
        hpPerLevel: const [10],
      );
      expect(compiler.compile(noCaster).spellcasting, isNull);
    });
  });

  group('Estado de combate: espacios y concentración', () {
    final repo = ContentRepository(classes: {'testmage': _mageClass()});
    final compiler = CharacterCompiler(repo);

    test('gastar y recuperar espacios respeta el máximo', () {
      final c = _caster(level: 5, hp: [6, 4, 4, 4, 4]);
      final sc = compiler.compile(c).spellcasting!;
      // Nivel 3: hay 2 espacios.
      expect(CombatOps.spendSpellSlot(c.combat, sc, 3), isTrue);
      expect(CombatOps.spendSpellSlot(c.combat, sc, 3), isTrue);
      expect(CombatOps.spendSpellSlot(c.combat, sc, 3), isFalse); // agotado
      expect(CombatOps.spellSlotsRemaining(c.combat, sc, 3), 0);
      CombatOps.recoverSpellSlot(c.combat, 3);
      expect(CombatOps.spellSlotsRemaining(c.combat, sc, 3), 1);
    });

    test('descanso largo recupera espacios y corta concentración', () {
      final c = _caster(level: 5, hp: [6, 4, 4, 4, 4]);
      final sc = compiler.compile(c).spellcasting!;
      CombatOps.spendSpellSlot(c.combat, sc, 1);
      CombatOps.startConcentration(c.combat, 'Bendición');
      CombatOps.longRest(c.combat, 30, const [], 5);
      expect(c.combat.spellSlotsUsed, isEmpty);
      expect(c.combat.concentratingOn, isNull);
    });

    test('el estado de combate hace round-trip por JSON', () {
      final c = _caster(level: 5, hp: [6, 4, 4, 4, 4]);
      c.combat.spellSlotsUsed[2] = 1;
      c.combat.concentratingOn = 'Invisibilidad';
      final restored = Character.fromJson(c.toJson());
      expect(restored.combat.spellSlotsUsed[2], 1);
      expect(restored.combat.concentratingOn, 'Invisibilidad');
    });
  });

  group('Selección de conjuros: round-trip y validación', () {
    late ContentRepository realRepo;
    setUpAll(() async {
      realRepo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
      realRepo.classes['testmage'] = _mageClass();
    });

    test('cantripIds/spellIds sobreviven copyWith y JSON', () {
      final c = _caster(level: 5, hp: [6, 4, 4, 4, 4]);
      final withSpells =
          c.copyWith(cantripIds: ['fire-bolt'], spellIds: ['magic-missile']);
      // copyWith de otra cosa NO debe perder los conjuros.
      final renamed = withSpells.copyWith(name: 'Otro');
      expect(renamed.cantripIds, ['fire-bolt']);
      expect(renamed.spellIds, ['magic-missile']);
      final restored = Character.fromJson(renamed.toJson());
      expect(restored.spellIds, ['magic-missile']);
    });

    test('advierte truco fuera de lista y conjuro de nivel demasiado alto', () {
      final c = _caster(level: 3, hp: [6, 4, 4]).copyWith(
        cantripIds: ['sacred-flame'], // truco de Clérigo, no de Mago
        spellIds: ['fireball'], // nivel 3, sin espacio (máx nivel 2)
      );
      final codes =
          CharacterValidator(realRepo).validate(c).map((x) => x.code).toSet();
      expect(codes, contains('cantrip_wrong_list'));
      expect(codes, contains('spell_level_too_high'));
    });

    test('un lanzador válido no dispara advertencias de conjuros', () {
      final c = _caster(level: 5, hp: [6, 4, 4, 4, 4]).copyWith(
        cantripIds: ['fire-bolt'],
        spellIds: ['magic-missile', 'fireball'],
      );
      final codes =
          CharacterValidator(realRepo).validate(c).map((x) => x.code).toSet();
      expect(codes.any((x) => x.startsWith('cantrip') || x.startsWith('spell')),
          isFalse);
    });
  });

  group('Lista de conjuros del repositorio real', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    test('la lista del Mago incluye conjuros conocidos y ordenados por nivel', () {
      final wizard = repo.spellsForList('wizard');
      expect(wizard.map((s) => s.id), contains('fire-bolt'));
      expect(wizard.map((s) => s.id), contains('fireball'));
      // Ordenados por nivel ascendente.
      for (var i = 1; i < wizard.length; i++) {
        expect(wizard[i].level, greaterThanOrEqualTo(wizard[i - 1].level));
      }
    });

    test('el Clérigo y el Mago tienen listas distintas', () {
      final clericIds = repo.spellsForList('cleric').map((s) => s.id).toSet();
      expect(clericIds, contains('sacred-flame'));
      expect(clericIds, isNot(contains('fireball')));
    });
  });
}
