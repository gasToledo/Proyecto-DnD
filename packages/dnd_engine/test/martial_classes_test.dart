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
      final s = compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(s.hitDie, 12);
      expect(s.maxHp, 14); // 12 + CON(+2)
    });

    test('nivel 1: Defensa sin Armadura = 10 + DES + CON', () {
      final s = compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(s.armorClass, 14); // 10 + DES(2) + CON(2)
    });

    test('con armadura equipada NO aplica Defensa sin Armadura', () {
      final s = compiler.compile(_char(
          classId: 'barbarian', level: 1, hp: [12], armorId: 'chain-shirt'));
      // Camisa de malla: 13 + min(DES, 2) = 15
      expect(s.armorClass, 15);
    });

    test('conserva la Defensa sin Armadura con escudo (a diferencia del Monje)', () {
      final s = compiler.compile(
          _char(classId: 'barbarian', level: 1, hp: [12], shield: true));
      // 10 + DES(2) + CON(2) + escudo(2) = 16
      expect(s.armorClass, 16);
    });

    test('Furia escala: 2 usos a nivel 1, 4 a nivel 6', () {
      final l1 = compiler.compile(_char(classId: 'barbarian', level: 1, hp: [12]));
      expect(l1.resources.firstWhere((r) => r.id == 'rage').max, 2);
      final l6 = compiler.compile(_char(
          classId: 'barbarian', level: 6, hp: [12, 7, 7, 7, 7, 7]));
      expect(l6.resources.firstWhere((r) => r.id == 'rage').max, 4);
    });

    test('nivel 5: Ataque Adicional y Movimiento Rápido', () {
      final s = compiler.compile(
          _char(classId: 'barbarian', level: 5, hp: [12, 7, 7, 7, 7]));
      expect(s.attacksPerAction, 2);
      expect(s.speed, 40); // 30 + 10
      expect(s.weaponMasterySlots, 2);
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
      final s =
          compiler.compile(_char(classId: 'rogue', level: 5, hp: [8, 5, 5, 5, 5]));
      expect(s.attacksPerAction, 1);
    });

    test('tiene nivel de ASI extra en 10', () {
      expect(repo.characterClass('rogue')!.asiLevels, contains(10));
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

    test('nivel 5: Ataque Adicional', () {
      final s =
          compiler.compile(_char(classId: 'monk', level: 5, hp: [8, 5, 5, 5, 5]));
      expect(s.attacksPerAction, 2);
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
      final sinEscudo =
          compiler.compile(_char(classId: 'monk', level: 2, hp: [8, 5], scores: scores));
      expect(sinEscudo.armorClass, 17); // 10 + DES(3) + SAB(4)
      final conEscudo = compiler.compile(
          _char(classId: 'monk', level: 2, hp: [8, 5], scores: scores, shield: true));
      // Anulada por el escudo: 10 + DES(3) + escudo(2), sin SAB.
      expect(conEscudo.armorClass, 15);
    });
  });
}
