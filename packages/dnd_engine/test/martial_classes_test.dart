import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Personaje de prueba parametrizable para las clases marciales nuevas.
Character _char({
  required String classId,
  required int level,
  required List<int> hp,
  Map<Ability, int>? scores,
  String? armorId,
  bool shield = false,
  List<String> weapons = const [],
}) =>
    Character(
      id: 'probe-$classId',
      name: 'Prueba',
      raceId: 'human',
      classId: classId,
      backgroundId: 'soldier',
      level: level,
      assignedScores: scores ??
          {
            Ability.strength: 16,
            Ability.dexterity: 14,
            Ability.constitution: 15,
            Ability.intelligence: 10,
            Ability.wisdom: 12,
            Ability.charisma: 8,
          },
      hpPerLevel: hp,
      equippedArmorId: armorId,
      shieldEquipped: shield,
      equippedWeaponIds: weapons,
    );

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  group('Bárbaro', () {
    test('nivel 1: dado de golpe d12 y PG con CON', () {
      final s =
          compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(s.hitDie, 12);
      expect(s.maxHp, 14); // 12 + CON(+2)
    });

    test('nivel 1: Defensa sin Armadura = 10 + DES + CON', () {
      final s =
          compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(s.armorClass, 14); // 10 + DES(2) + CON(2)
    });

    test('con armadura equipada NO aplica Defensa sin Armadura', () {
      final s = compiler.compile(_char(
          classId: 'barbarian', level: 1, hp: [12], armorId: 'chain-shirt'));
      // Camisa de malla: 13 + min(DES, 2) = 15
      expect(s.armorClass, 15);
    });

    test('conserva la Defensa sin Armadura con escudo (a diferencia del Monje)',
        () {
      final s = compiler.compile(
          _char(classId: 'barbarian', level: 1, hp: [12], shield: true));
      // 10 + DES(2) + CON(2) + escudo(2) = 16
      expect(s.armorClass, 16);
    });

    test('Furia escala: 2 usos a nivel 1, 4 a nivel 6', () {
      final l1 =
          compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(l1.resources.firstWhere((r) => r.id == 'rage').max, 2);
      final l6 = compiler.compile(
          _char(classId: 'barbarian', level: 6, hp: [12, 7, 7, 7, 7, 7]));
      expect(l6.resources.firstWhere((r) => r.id == 'rage').max, 4);
    });

    test('nivel 5: Ataque Adicional y Movimiento Rápido', () {
      final s = compiler
          .compile(_char(classId: 'barbarian', level: 5, hp: [12, 7, 7, 7, 7]));
      expect(s.attacksPerAction, 2);
      expect(s.speed, 40); // 30 + 10
      // La columna de maestría sube a 3 en el nivel 4.
      expect(s.weaponMasterySlots, 3);
    });

    test('Movimiento Rápido: solo la armadura pesada lo anula', () {
      Character bar({String? armorId, bool shield = false}) => _char(
          classId: 'barbarian',
          level: 5,
          hp: [12, 7, 7, 7, 7],
          armorId: armorId,
          shield: shield);
      // Media conservada; escudo no lo anula (a diferencia del Monje).
      expect(compiler.compile(bar(armorId: 'chain-shirt')).speed, 40);
      expect(compiler.compile(bar(shield: true)).speed, 40);
      // Pesada sí lo anula.
      expect(compiler.compile(bar(armorId: 'chain-mail')).speed, 30);
    });
  });

  group('Explorador', () {
    test('Errante (nivel 6) se comporta como el Movimiento Rápido del Bárbaro',
        () {
      // Es la misma regla del manual con los mismos números, y la tenía el
      // Bárbaro y no el Explorador: el rasgo estaba cargado solo como texto.
      Character ranger({String? armorId, bool shield = false}) => _char(
          classId: 'ranger',
          level: 6,
          hp: [10, 6, 6, 6, 6, 6],
          armorId: armorId,
          shield: shield);

      expect(compiler.compile(ranger()).speed, 40); // 30 + 10
      // Media y escudo lo conservan; solo la pesada lo anula.
      expect(compiler.compile(ranger(armorId: 'chain-shirt')).speed, 40);
      expect(compiler.compile(ranger(shield: true)).speed, 40);
      expect(compiler.compile(ranger(armorId: 'chain-mail')).speed, 30);
    });

    test('antes del nivel 6 no hay bono de velocidad', () {
      final l5 = _char(classId: 'ranger', level: 5, hp: [10, 6, 6, 6, 6]);
      expect(compiler.compile(l5).speed, 30);
    });
  });

  group('Pícaro', () {
    test('competente con estoque (marcial sutil) pero no con mandoble', () {
      final s = compiler.compile(_char(classId: 'rogue', level: 1, hp: [8]));
      expect(s.weaponProficiencies, contains('rapier'));
      expect(s.weaponProficiencies, isNot(contains('martial')));
    });

    test('estoque equipado suma competencia; mandoble no', () {
      final conRapier = compiler.compile(
          _char(classId: 'rogue', level: 1, hp: [8], weapons: ['rapier']));
      final conGreatsword = compiler.compile(
          _char(classId: 'rogue', level: 1, hp: [8], weapons: ['greatsword']));
      // Estoque: finesse → mayor de FUE(+3)/DES(+2) = +3. Competente → +2 comp = 5.
      expect(conRapier.attacks.single.attackBonus, 5);
      // Mandoble: FUE(+3), sin competencia → sin bono de competencia = 3.
      expect(conGreatsword.attacks.single.attackBonus, 3);
    });

    test('sin Ataque Adicional a nivel 5', () {
      final s = compiler
          .compile(_char(classId: 'rogue', level: 5, hp: [8, 5, 5, 5, 5]));
      expect(s.attacksPerAction, 1);
    });

    test('tiene nivel de ASI extra en 10', () {
      expect(repo.characterClass('rogue')!.asiLevels, contains(10));
    });

    test('Golpes Taimados incluye las tres opciones de nivel 14', () {
      final trait = repo
          .characterClass('rogue')!
          .features
          .singleWhere((f) => f.name == 'Golpes Taimados')
          .effects
          .whereType<PassiveTraitEffect>()
          .single
          .description;
      for (final option in ['Confundir', 'Noquear', 'Ofuscar']) {
        expect(trait, contains(option));
      }
    });
  });

  group('Monje', () {
    test('nivel 2: Defensa sin Armadura = 10 + DES + SAB', () {
      final s = compiler.compile(_char(
        classId: 'monk',
        level: 2,
        hp: [8, 5],
        scores: {
          Ability.strength: 12,
          Ability.dexterity: 16,
          Ability.constitution: 12,
          Ability.intelligence: 10,
          Ability.wisdom: 14,
          Ability.charisma: 10,
        },
      ));
      expect(s.armorClass, 15); // 10 + DES(3) + SAB(2)
    });

    test('Puntos de Enfoque = nivel de Monje', () {
      final l2 = compiler.compile(_char(classId: 'monk', level: 2, hp: [8, 5]));
      expect(l2.resources.firstWhere((r) => r.id == 'focus_points').max, 2);
      final l6 = compiler
          .compile(_char(classId: 'monk', level: 6, hp: [8, 5, 5, 5, 5, 5]));
      expect(l6.resources.firstWhere((r) => r.id == 'focus_points').max, 6);
    });

    test('nivel 1 no tiene Puntos de Enfoque todavía', () {
      final l1 = compiler.compile(_char(classId: 'monk', level: 1, hp: [8]));
      expect(l1.resources.where((r) => r.id == 'focus_points'), isEmpty);
    });

    test('Movimiento sin Armadura acumula: +10 a nivel 2, +15 a nivel 6', () {
      final l2 = compiler.compile(_char(classId: 'monk', level: 2, hp: [8, 5]));
      expect(l2.speed, 40); // 30 + 10
      final l6 = compiler
          .compile(_char(classId: 'monk', level: 6, hp: [8, 5, 5, 5, 5, 5]));
      expect(l6.speed, 45); // 30 + 10 + 5
    });

    test('Movimiento sin Armadura aparece como rasgo pasivo', () {
      final l2 = compiler.compile(_char(classId: 'monk', level: 2, hp: [8, 5]));
      expect(
          l2.passives.map((p) => p.name), contains('Movimiento sin Armadura'));
    });

    test('con armadura o escudo el Monje pierde el bono de velocidad', () {
      final conArmadura = compiler.compile(
          _char(classId: 'monk', level: 2, hp: [8, 5], armorId: 'chain-shirt'));
      expect(conArmadura.speed, 30); // media anula el bono en el Monje
      final conEscudo = compiler
          .compile(_char(classId: 'monk', level: 2, hp: [8, 5], shield: true));
      expect(conEscudo.speed, 30); // el escudo también lo anula
    });

    test('nivel 5: Ataque Adicional', () {
      final s = compiler
          .compile(_char(classId: 'monk', level: 5, hp: [8, 5, 5, 5, 5]));
      expect(s.attacksPerAction, 2);
    });

    test('Golpe Aturdidor conserva límite y efecto de salvación exitosa', () {
      final trait = repo
          .characterClass('monk')!
          .features
          .singleWhere((f) => f.name == 'Golpe Aturdidor')
          .effects
          .whereType<PassiveTraitEffect>()
          .single
          .description;
      expect(trait, contains('Una vez por turno'));
      expect(trait, contains('velocidad se reduce a la mitad'));
      expect(trait, contains('tiene ventaja'));
    });

    test('con escudo pierde la Defensa sin Armadura (regla 2024)', () {
      final scores = {
        Ability.strength: 12,
        Ability.dexterity: 16,
        Ability.constitution: 12,
        Ability.intelligence: 10,
        Ability.wisdom: 18,
        Ability.charisma: 10,
      };
      final sinEscudo = compiler.compile(
          _char(classId: 'monk', level: 2, hp: [8, 5], scores: scores));
      expect(sinEscudo.armorClass, 17); // 10 + DES(3) + SAB(4)
      final conEscudo = compiler.compile(_char(
          classId: 'monk', level: 2, hp: [8, 5], scores: scores, shield: true));
      // Anulada por el escudo: 10 + DES(3) + escudo(2), sin SAB.
      expect(conEscudo.armorClass, 15);
    });
  });

  group('Progresiones por nivel de la tabla de clase (PHB 2024)', () {
    /// Compila la clase al nivel pedido con PG de relleno.
    ComputedSheet at(String classId, int level) => compiler.compile(
          _char(classId: classId, level: level, hp: List.filled(level, 6)),
        );

    int masteries(String classId, int level) =>
        at(classId, level).weaponMasterySlots;

    int resourceMax(String classId, int level, String id) =>
        at(classId, level).resources.firstWhere((r) => r.id == id).max;

    test('Guerrero: la maestría con armas va 3 / 4 / 5 / 6', () {
      expect(masteries('fighter', 1), 3);
      expect(masteries('fighter', 3), 3);
      expect(masteries('fighter', 4), 4);
      expect(masteries('fighter', 9), 4);
      expect(masteries('fighter', 10), 5);
      expect(masteries('fighter', 15), 5);
      expect(masteries('fighter', 16), 6);
      expect(masteries('fighter', 20), 6);
    });

    test('Guerrero: Tomar Aliento va 2 / 3 / 4', () {
      expect(resourceMax('fighter', 1, 'second_wind'), 2);
      expect(resourceMax('fighter', 4, 'second_wind'), 3);
      expect(resourceMax('fighter', 10, 'second_wind'), 4);
      expect(resourceMax('fighter', 20, 'second_wind'), 4);
    });

    test('Guerrero: Tomar Aliento recupera uno en descanso corto', () {
      final resource =
          at('fighter', 10).resources.singleWhere((r) => r.id == 'second_wind');
      expect(resource.recharge, RechargeOn.longRest);
      expect(resource.shortRestRecovery, 1);
    });

    test('Guerrero: Acción Súbita excluye la acción de Magia', () {
      final resource =
          at('fighter', 2).resources.singleWhere((r) => r.id == 'action_surge');
      expect(resource.description, contains('salvo la acción de Magia'));
    });

    test('Bárbaro: la maestría con armas va 2 / 3 / 4', () {
      expect(masteries('barbarian', 1), 2);
      expect(masteries('barbarian', 4), 3);
      expect(masteries('barbarian', 10), 4);
      expect(masteries('barbarian', 20), 4);
    });

    test('Bárbaro: las furias van 2 / 3 / 4 / 5 / 6', () {
      expect(resourceMax('barbarian', 1, 'rage'), 2);
      expect(resourceMax('barbarian', 3, 'rage'), 3);
      expect(resourceMax('barbarian', 6, 'rage'), 4);
      expect(resourceMax('barbarian', 12, 'rage'), 5);
      expect(resourceMax('barbarian', 17, 'rage'), 6);
    });

    test('Monje: el movimiento sin armadura llega a +30 pies', () {
      // Velocidad base 30 del Humano.
      expect(at('monk', 2).speed, 40);
      expect(at('monk', 6).speed, 45);
      expect(at('monk', 10).speed, 50);
      expect(at('monk', 14).speed, 55);
      expect(at('monk', 18).speed, 60);
    });

    test('Pícaro y Monje son competentes con la ballesta de mano', () {
      // Es marcial y ligera, así que entra en "marciales ligeras o sutiles".
      expect(at('rogue', 1).weaponProficiencies, contains('hand-crossbow'));
      expect(at('monk', 1).weaponProficiencies, contains('hand-crossbow'));
    });
  });
}
