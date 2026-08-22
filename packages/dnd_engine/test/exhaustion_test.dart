import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Cansancio: la capa situacional que se aplica **sobre** la ficha ya
/// calculada.
///
/// La regla 2024 son dos frases —la prueba con d20 baja 2 × nivel y la
/// velocidad 5 pies × nivel— y el valor de este archivo está tanto en fijar lo
/// que baja como en fijar **lo que no**: descontarlo de `abilityModifiers`
/// habría sido más corto y habría bajado también el daño, la CD de conjuros,
/// los PG máximos y la CA.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Un clérigo con maza y monedas: tiene ataque, magia, bono de habilidad por
  /// Orden Divina y mochila con peso. Sirve para mirar todo de una.
  ComputedSheet clerigo() => CharacterCompiler(repo).compile(Character(
        id: 'cansado',
        name: 'Prueba',
        raceId: 'human',
        classId: 'cleric',
        backgroundId: 'hermit',
        level: 5,
        assignedScores: const {
          Ability.strength: 14,
          Ability.dexterity: 12,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 16,
          Ability.charisma: 8,
        },
        hpPerLevel: const [8, 5, 5, 5, 5],
        featureChoices: const {
          'divine-order': ['divine-order-thaumaturge'],
        },
        inventory: const [
          InventoryEntry(entryId: 'maza', itemId: 'mace', equipped: true),
        ],
        coins: const {'gp': 250},
      ));

  group('Nivel 0 no cuesta nada', () {
    test('devuelve la misma ficha, no una copia', () {
      final base = clerigo();
      // Por identidad y no por igualdad: la pantalla llama a esto en cada
      // build y el personaje descansado no tiene que pagar una copia.
      expect(applyExhaustion(base, 0), same(base));
    });
  });

  group('Nivel 3 resta 6 a toda prueba con d20', () {
    test('características, salvaciones, habilidades y percepción pasiva', () {
      final base = clerigo();
      final cansado = applyExhaustion(base, 3);

      for (final a in Ability.values) {
        expect(cansado.abilityCheck(a), base.abilityCheck(a) - 6,
            reason: 'prueba de ${a.name}');
        expect(cansado.savingThrow(a), base.savingThrow(a) - 6,
            reason: 'salvación de ${a.name}');
      }
      for (final s in Skill.values) {
        expect(cansado.skillModifier(s.id), base.skillModifier(s.id) - 6,
            reason: s.id);
      }
      // Cae sola, y que caiga sola es la señal de que el enganche está bien
      // puesto: es una prueba de Percepción resuelta como si sacaras 10.
      expect(cansado.passivePerception, base.passivePerception - 6);
    });

    test('iniciativa y ataques', () {
      final base = clerigo();
      final cansado = applyExhaustion(base, 3);

      expect(cansado.initiative, base.initiative - 6);
      expect(base.attacks, isNotEmpty);
      for (var i = 0; i < base.attacks.length; i++) {
        expect(cansado.attacks[i].attackBonus, base.attacks[i].attackBonus - 6,
            reason: base.attacks[i].name);
      }
      expect(cansado.spellcasting!.attackBonus,
          base.spellcasting!.attackBonus - 6);
    });

    test('la velocidad baja 5 pies por nivel', () {
      final base = clerigo();
      expect(applyExhaustion(base, 3).speed, base.speed - 15);
    });
  });

  group('Lo que el Cansancio no toca', () {
    /// La contraprueba, y es la que defiende la decisión de diseño: si alguien
    /// "simplifica" descontando el cansancio de `abilityModifiers`, todo esto
    /// se cae junto.
    test('puntuaciones, modificadores, PG, CA y carga quedan iguales', () {
      final base = clerigo();
      final cansado = applyExhaustion(base, 3);

      expect(cansado.abilityScores, base.abilityScores);
      expect(cansado.abilityModifiers, base.abilityModifiers);
      expect(cansado.maxHp, base.maxHp);
      expect(cansado.armorClass, base.armorClass);
      expect(cansado.carryingCapacity, base.carryingCapacity);
      expect(cansado.carriedWeight, base.carriedWeight);
    });

    test('la CD de conjuros no baja', () {
      // El que tira el d20 contra una CD es quien se salva, no el lanzador.
      final base = clerigo();
      expect(applyExhaustion(base, 3).spellcasting!.saveDc,
          base.spellcasting!.saveDc);
    });

    test('el daño de los ataques no baja', () {
      final base = clerigo();
      final cansado = applyExhaustion(base, 3);
      for (var i = 0; i < base.attacks.length; i++) {
        expect(cansado.attacks[i].damage, base.attacks[i].damage,
            reason: base.attacks[i].name);
        expect(cansado.attacks[i].damageType, base.attacks[i].damageType);
      }
    });

    test('el resto del ataque llega entero', () {
      // `copyWith` es lo que garantiza esto; reconstruir a mano fue como se
      // perdieron campos antes.
      final base = clerigo();
      final cansado = applyExhaustion(base, 3);
      for (var i = 0; i < base.attacks.length; i++) {
        final a = base.attacks[i];
        final c = cansado.attacks[i];
        expect(c.name, a.name);
        expect(c.weaponId, a.weaponId);
        expect(c.proficient, a.proficient);
        expect(c.abilityUsed, a.abilityUsed);
        expect(c.mastery, a.mastery);
        expect(c.offHand, a.offHand);
        expect(c.action, a.action);
        expect(c.attacksPerAction, a.attacksPerAction);
      }
    });
  });

  group('Los bordes del contador', () {
    test('la velocidad tiene piso en 0 y no se va a negativo', () {
      final base = clerigo();
      expect(base.speed, 30);
      expect(applyExhaustion(base, 6).speed, 0);
    });

    test('un nivel imposible se topea en 6', () {
      // Un documento tocado a mano puede traer cualquier cosa; la capa no es
      // el lugar para reventar.
      final base = clerigo();
      expect(applyExhaustion(base, 9).initiative,
          applyExhaustion(base, 6).initiative);
    });

    test('un nivel negativo no regala bonificadores', () {
      final base = clerigo();
      expect(applyExhaustion(base, -2), same(base));
    });
  });

  group('Sin doble conteo', () {
    test('el getter ya lo trae y no hay que volver a restarlo', () {
      final base = clerigo();
      final cansado = applyExhaustion(base, 2);

      expect(cansado.d20Modifier, -4);
      // La salvación de Sabiduría del clérigo es competente: mod + PB + lo
      // situacional, una sola vez.
      expect(cansado.savingThrow(Ability.wisdom),
          cansado.abilityModifiers[Ability.wisdom]! + 3 + cansado.d20Modifier);
    });
  });

  group('Con la Forma Salvaje encima', () {
    ComputedSheet druida() => CharacterCompiler(repo).compile(Character(
          id: 'druida-cansado',
          name: 'Prueba',
          raceId: 'human',
          classId: 'druid',
          backgroundId: 'sage',
          level: 4,
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
        ));

    test('el cansancio se resta sobre los números de la bestia', () {
      // El orden importa: al revés, la bestia pisaría velocidad, iniciativa y
      // ataques, y el cansancio desaparecería a mitad del combate.
      final base = druida();
      final lobo = base.wildShape!.chosen.single;
      final transformado = applyWildShape(base, lobo);
      final cansado = applyExhaustion(transformado, 2);

      expect(transformado.speed, 40);
      expect(cansado.speed, 30);
      expect(transformado.attacks, isNotEmpty);
      for (var i = 0; i < transformado.attacks.length; i++) {
        expect(cansado.attacks[i].attackBonus,
            transformado.attacks[i].attackBonus - 4);
      }
      expect(cansado.initiative, transformado.initiative - 4);
    });
  });
}
