import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Personaje de prueba parametrizable con subclase opcional.
Character _char({
  required String classId,
  required int level,
  required List<int> hp,
  String? subclassId,
  Map<Ability, int>? scores,
}) =>
    Character(
      id: 'probe-$classId',
      name: 'Prueba',
      raceId: 'human',
      classId: classId,
      backgroundId: 'soldier',
      subclassId: subclassId,
      level: level,
      assignedScores: scores ??
          {
            Ability.strength: 15,
            Ability.dexterity: 14,
            Ability.constitution: 14,
            Ability.intelligence: 12,
            Ability.wisdom: 10,
            Ability.charisma: 8,
          },
      hpPerLevel: hp,
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

  group('Carga y consulta de subclases', () {
    test('cada clase tiene sus subclases y todas apuntan a su clase', () {
      // El Artífice de Forge of the Artificer trae 5 subclases; el resto, 4.
      for (final classId in repo.classes.keys) {
        final subs = repo.subclassesForClass(classId);
        final esperado = classId == 'artificer' ? 5 : 4;
        expect(subs.length, esperado,
            reason: '$classId debería tener $esperado subclases');
        for (final s in subs) {
          expect(s.classId, classId);
        }
      }
    });

    test(
        'todos los rasgos de subclase empiezan en el subclassLevel de su clase',
        () {
      for (final s in repo.subclasses.values) {
        final klass = repo.characterClass(s.classId)!;
        final minLevel =
            s.features.map((f) => f.level).reduce((a, b) => a < b ? a : b);
        expect(minLevel, greaterThanOrEqualTo(klass.subclassLevel),
            reason: '${s.id} tiene rasgos antes del nivel de subclase');
      }
    });

    test('ninguna subclase repite el mismo rasgo en dos niveles', () {
      // Excepción a propósito: las tablas de conjuros de subclase declaran una
      // fila por nivel bajo el mismo nombre ("Conjuros de Alquimista"), que es
      // como las presenta el manual. Solo se exceptúa si el rasgo es
      // *únicamente* esa tabla; cualquier otro nombre repetido sigue siendo un
      // error de copiado.
      //
      // Es también la razón por la que las cuatro tablas del Círculo de la
      // Tierra viven en dotes `druid-land` y no como cuatro "Conjuros de
      // Círculo" a nivel 3: además de conjuros conceden resistencia, así que
      // no calificarían para esta exención. Ver `circle_land_test.dart`.
      bool esTablaDeConjuros(ClassFeature f) =>
          f.effects.isNotEmpty &&
          f.effects.every((e) => e is AlwaysPreparedSpellEffect);

      for (final s in repo.subclasses.values) {
        final names = s.features
            .where((f) => !esTablaDeConjuros(f))
            .map((f) => f.name)
            .toList();
        expect(names.toSet().length, names.length,
            reason: '${s.id} tiene rasgos con nombre duplicado: $names');

        // Y la tabla, cuando existe, no puede repetir nivel.
        final niveles =
            s.features.where(esTablaDeConjuros).map((f) => f.level).toList();
        expect(niveles.toSet().length, niveles.length,
            reason: '${s.id} declara dos tablas de conjuros al mismo nivel');
      }
    });

    test('la Escuela de Evocación sigue la progresión 2024', () {
      final evoker = repo.subclass('evoker')!;
      String? levelOf(String name) => evoker.features
          .where((f) => f.name == name)
          .map((f) => '${f.level}')
          .firstOrNull;
      // 2024: nivel 3 Truco Potente + Experto en Evocación; nivel 6 Esculpir
      // Conjuros. Antes Esculpir estaba a 3 y el "Adepto" (Savant de 2014) a 6.
      expect(levelOf('Truco Potente'), '3');
      expect(levelOf('Experto en Evocación'), '3');
      expect(levelOf('Esculpir Conjuros'), '6');
      expect(levelOf('Evocación Potenciada'), '10');
      expect(levelOf('Sobrecanalizar'), '14');
      expect(evoker.features.map((f) => f.name),
          isNot(contains('Adepto de la Evocación')));
    });

    test('round-trip JSON de una subclase', () {
      final champ = repo.subclass('champion')!;
      final back = Subclass.fromJson(champ.toJson());
      expect(back.id, 'champion');
      expect(back.classId, 'fighter');
      expect(back.features.length, champ.features.length);
    });

    test('Campeón usa Atleta Sobresaliente de 2024', () {
      final champ = repo.subclass('champion')!;
      final athlete =
          champ.features.singleWhere((f) => f.name == 'Atleta Sobresaliente');
      final description =
          athlete.effects.whereType<PassiveTraitEffect>().single.description;
      expect(description, contains('Ventaja en iniciativa'));
      expect(description, contains('Fuerza (Atletismo)'));
      expect(description, contains('después de causar un crítico'));
      expect(
          champ.features.map((f) => f.name), isNot(contains('Atleta Notable')));
    });

    test('los críticos del Campeón incluyen ataques sin armas', () {
      final champ = repo.subclass('champion')!;
      for (final name in ['Crítico Mejorado', 'Crítico Superior']) {
        final description = champ.features
            .singleWhere((f) => f.name == name)
            .effects
            .whereType<PassiveTraitEffect>()
            .single
            .description;
        expect(description, contains('ataques sin armas'), reason: name);
      }
    });
  });

  group('Aplicación de rasgos de subclase en el compilador', () {
    test('sin subclase no aparecen sus pasivas', () {
      final s =
          compiler.compile(_char(classId: 'fighter', level: 3, hp: [10, 6, 6]));
      expect(s.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty);
    });

    test('el Campeón suma Crítico Mejorado a partir de nivel 3', () {
      final l2 = compiler.compile(_char(
          classId: 'fighter', level: 2, hp: [10, 6], subclassId: 'champion'));
      expect(l2.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty,
          reason: 'la subclase se elige a nivel 3');
      final l3 = compiler.compile(_char(
          classId: 'fighter',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'champion'));
      expect(l3.passives.map((p) => p.name), contains('Crítico Mejorado'));
    });

    test('una subclase de otra clase se ignora', () {
      // 'champion' es de fighter; asignada a un bárbaro no debe aplicar nada.
      final s = compiler.compile(_char(
          classId: 'barbarian',
          level: 3,
          hp: [12, 7, 7],
          subclassId: 'champion'));
      expect(s.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty);
    });

    test('Resistencia Dracónica suma 1 PG por nivel de Hechicero', () {
      final base = compiler
          .compile(_char(classId: 'sorcerer', level: 4, hp: [6, 4, 4, 4]));
      final draco = compiler.compile(_char(
          classId: 'sorcerer',
          level: 4,
          hp: [6, 4, 4, 4],
          subclassId: 'draconic-sorcery'));
      expect(draco.maxHp - base.maxHp, 4); // +1 por cada uno de los 4 niveles
    });

    test('Dominio de la Vida concede competencia con armadura pesada', () {
      final s = compiler.compile(_char(
          classId: 'cleric',
          level: 3,
          hp: [8, 5, 5],
          subclassId: 'life-domain'));
      expect(s.armorProficiencies, contains('heavy'));
    });

    test('el Caballero Arcano se vuelve semi-lanzador a nivel 3', () {
      final base =
          compiler.compile(_char(classId: 'fighter', level: 3, hp: [10, 6, 6]));
      expect(base.spellcasting, isNull);
      final ek = compiler.compile(_char(
          classId: 'fighter',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'eldritch-knight'));
      expect(ek.spellcasting, isNotNull);
      expect(ek.spellcasting!.progression, CasterProgression.third);
      expect(ek.spellcasting!.spellList, 'wizard');
    });

    test('el de un tercio usa la tabla fija 2024, no el modificador', () {
      // Tabla de un tercio (Caballero/Pícaro Arcano): nivel 3 = 3, nivel 10 = 7.
      final l3 = compiler.compile(_char(
          classId: 'fighter',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'eldritch-knight'));
      expect(l3.spellcasting!.preparedCount, 3);
      final l10 = compiler.compile(_char(
          classId: 'fighter',
          level: 10,
          hp: List.filled(10, 6),
          subclassId: 'eldritch-knight'));
      expect(l10.spellcasting!.preparedCount, 7);
    });

    test('el de un tercio solo gana +1 truco a nivel 10, no a nivel 4', () {
      // Pícaro Arcano: base 3 trucos.
      final l4 = compiler.compile(_char(
          classId: 'rogue',
          level: 4,
          hp: List.filled(4, 6),
          subclassId: 'arcane-trickster'));
      expect(l4.spellcasting!.cantripsKnown, 3); // sin +1 antes de nivel 10
      final l10 = compiler.compile(_char(
          classId: 'rogue',
          level: 10,
          hp: List.filled(10, 6),
          subclassId: 'arcane-trickster'));
      expect(l10.spellcasting!.cantripsKnown, 4); // base 3 + 1 a nivel 10
    });

    test('el Acechador de la Penumbra otorga visión en la oscuridad 90', () {
      final s = compiler.compile(_char(
          classId: 'ranger',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'gloom-stalker'));
      expect(s.darkvision, 90);
    });

    test('el Colegio del Valor da armadura media y Ataque Adicional a nivel 6',
        () {
      final l3 = compiler.compile(_char(
          classId: 'bard',
          level: 3,
          hp: [8, 5, 5],
          subclassId: 'college-valor'));
      expect(l3.armorProficiencies, contains('medium'));
      expect(l3.attacksPerAction, 1);
      final l6 = compiler.compile(_char(
          classId: 'bard',
          level: 6,
          hp: [8, 5, 5, 5, 5, 5],
          subclassId: 'college-valor'));
      expect(l6.attacksPerAction, 2);
    });

    test('el Dominio de la Guerra concede competencia con armas marciales', () {
      final s = compiler.compile(_char(
          classId: 'cleric',
          level: 3,
          hp: [8, 5, 5],
          subclassId: 'war-domain'));
      expect(s.weaponProficiencies, contains('martial'));
      expect(s.armorProficiencies, contains('heavy'));
    });

    test('Luz Sanadora es 1 + nivel de Brujo', () {
      // La queja que originó esto: en nivel 4 la pantalla mostraba 2 curas.
      // La descripción del rasgo siempre dijo "pozo = 1 + nivel de Brujo" y el
      // dato tenía un 2 fijo, porque `maxPerLevel` reemplazaba en vez de sumar.
      int pozo(int level) => compiler
          .compile(_char(
            classId: 'warlock',
            level: level,
            hp: List.filled(level, 5),
            subclassId: 'celestial-patron',
          ))
          .resources
          .firstWhere((r) => r.id == 'healing_light')
          .max;

      expect(pozo(3), 4);
      expect(pozo(4), 5);
      expect(pozo(20), 21);
    });

    test('Energía Psiónica es dos veces el bonif. por competencia', () {
      int dados(String classId, String subclassId, int level) => compiler
          .compile(_char(
            classId: classId,
            level: level,
            hp: List.filled(level, 6),
            subclassId: subclassId,
          ))
          .resources
          .firstWhere((r) => r.id == 'psionic_energy')
          .max;

      // Bonif. 2 a nivel 3, 3 a nivel 5, 6 a nivel 17.
      expect(dados('fighter', 'psi-warrior', 3), 4);
      expect(dados('fighter', 'psi-warrior', 5), 6);
      expect(dados('fighter', 'psi-warrior', 17), 12);
      // El mismo recurso en la otra subclase que lo tiene.
      expect(dados('rogue', 'soulknife', 3), 4);
      expect(dados('rogue', 'soulknife', 17), 12);
    });

    test('los recursos que ya escalaban por nivel no cambiaron', () {
      // Regresión de volver `maxPerLevel` aditivo: los dos usuarios previos
      // declaran `max: 0`, así que siguen dando el nivel pelado.
      int recurso(String classId, int level, String id) => compiler
          .compile(_char(
            classId: classId,
            level: level,
            hp: List.filled(level, 6),
          ))
          .resources
          .firstWhere((r) => r.id == id)
          .max;

      expect(recurso('monk', 6, 'focus_points'), 6);
      expect(recurso('monk', 20, 'focus_points'), 20);
      expect(recurso('sorcerer', 5, 'sorcery_points'), 5);
    });

    test('Sacerdote Guerrero escala con Sabiduría, con piso de 1', () {
      // La descripción del rasgo siempre dijo "usos = mod. de Sabiduría" y el
      // dato tenía un 2 fijo. Con Sabiduría 10 (mod. 0) el piso deja 1 uso.
      int usos(int wisdom) => compiler
          .compile(_char(
            classId: 'cleric',
            level: 3,
            hp: [8, 5, 5],
            subclassId: 'war-domain',
            scores: {
              Ability.strength: 15,
              Ability.dexterity: 14,
              Ability.constitution: 14,
              Ability.intelligence: 12,
              Ability.wisdom: wisdom,
              Ability.charisma: 8,
            },
          ))
          .resources
          .firstWhere((r) => r.id == 'war_priest')
          .max;

      expect(usos(10), 1, reason: 'mod. 0 pero mínimo un uso');
      expect(usos(16), 3);
      expect(usos(20), 5);
    });

    test('la competencia de escudo usa la misma categoría que la armadura', () {
      final fighter =
          compiler.compile(_char(classId: 'fighter', level: 1, hp: [10]));
      final shield = repo.armorPiece('shield')!;
      // El Guerrero es competente con escudos y la categoría coincide (antes:
      // "shields" en la clase vs "shield" en la armadura).
      expect(fighter.armorProficiencies, contains(shield.category));
    });
  });

  group('Validación de subclase', () {
    test('advierte si falta subclase al alcanzar el nivel de subclase', () {
      final w = validator
          .validate(_char(classId: 'fighter', level: 3, hp: [10, 6, 6]));
      expect(w.map((x) => x.code), contains('subclass_pending'));
    });

    test('no advierte por subclase antes del nivel correspondiente', () {
      final w =
          validator.validate(_char(classId: 'fighter', level: 2, hp: [10, 6]));
      expect(w.map((x) => x.code), isNot(contains('subclass_pending')));
    });

    test('no advierte si la subclase está elegida', () {
      final w = validator.validate(_char(
          classId: 'fighter',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'champion'));
      expect(w.map((x) => x.code), isNot(contains('subclass_pending')));
    });

    test('advierte si la subclase no pertenece a la clase', () {
      final w = validator.validate(_char(
          classId: 'barbarian',
          level: 3,
          hp: [12, 7, 7],
          subclassId: 'champion'));
      expect(w.map((x) => x.code), contains('subclass_wrong_class'));
    });

    test('advierte si la subclase no existe', () {
      final w = validator.validate(_char(
          classId: 'fighter',
          level: 3,
          hp: [10, 6, 6],
          subclassId: 'inexistente'));
      expect(w.map((x) => x.code), contains('subclass_missing'));
    });
  });
}
