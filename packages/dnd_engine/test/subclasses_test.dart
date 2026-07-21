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
    test('cada clase tiene al menos una subclase y todas apuntan a su clase', () {
      for (final classId in repo.classes.keys) {
        final subs = repo.subclassesForClass(classId);
        expect(subs, isNotEmpty, reason: '$classId no tiene subclases');
        for (final s in subs) {
          expect(s.classId, classId);
        }
      }
    });

    test('round-trip JSON de una subclase', () {
      final champ = repo.subclass('champion')!;
      final back = Subclass.fromJson(champ.toJson());
      expect(back.id, 'champion');
      expect(back.classId, 'fighter');
      expect(back.features.length, champ.features.length);
    });
  });

  group('Aplicación de rasgos de subclase en el compilador', () {
    test('sin subclase no aparecen sus pasivas', () {
      final s = compiler.compile(_char(classId: 'fighter', level: 3, hp: [10, 6, 6]));
      expect(s.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty);
    });

    test('el Campeón suma Crítico Mejorado a partir de nivel 3', () {
      final l2 = compiler.compile(
          _char(classId: 'fighter', level: 2, hp: [10, 6], subclassId: 'champion'));
      expect(l2.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty,
          reason: 'la subclase se elige a nivel 3');
      final l3 = compiler.compile(_char(
          classId: 'fighter', level: 3, hp: [10, 6, 6], subclassId: 'champion'));
      expect(l3.passives.map((p) => p.name), contains('Crítico Mejorado'));
    });

    test('una subclase de otra clase se ignora', () {
      // 'champion' es de fighter; asignada a un bárbaro no debe aplicar nada.
      final s = compiler.compile(_char(
          classId: 'barbarian', level: 3, hp: [12, 7, 7], subclassId: 'champion'));
      expect(s.passives.where((p) => p.name == 'Crítico Mejorado'), isEmpty);
    });

    test('Resistencia Dracónica suma 1 PG por nivel de Hechicero', () {
      final base = compiler.compile(_char(
          classId: 'sorcerer', level: 4, hp: [6, 4, 4, 4]));
      final draco = compiler.compile(_char(
          classId: 'sorcerer',
          level: 4,
          hp: [6, 4, 4, 4],
          subclassId: 'draconic-sorcery'));
      expect(draco.maxHp - base.maxHp, 4); // +1 por cada uno de los 4 niveles
    });

    test('Dominio de la Vida concede competencia con armadura pesada', () {
      final s = compiler.compile(_char(
          classId: 'cleric', level: 3, hp: [8, 5, 5], subclassId: 'life-domain'));
      expect(s.armorProficiencies, contains('heavy'));
    });
  });

  group('Validación de subclase', () {
    test('advierte si falta subclase al alcanzar el nivel de subclase', () {
      final w = validator.validate(
          _char(classId: 'fighter', level: 3, hp: [10, 6, 6]));
      expect(w.map((x) => x.code), contains('subclass_pending'));
    });

    test('no advierte por subclase antes del nivel correspondiente', () {
      final w = validator.validate(
          _char(classId: 'fighter', level: 2, hp: [10, 6]));
      expect(w.map((x) => x.code), isNot(contains('subclass_pending')));
    });

    test('no advierte si la subclase está elegida', () {
      final w = validator.validate(_char(
          classId: 'fighter', level: 3, hp: [10, 6, 6], subclassId: 'champion'));
      expect(w.map((x) => x.code), isNot(contains('subclass_pending')));
    });

    test('advierte si la subclase no pertenece a la clase', () {
      final w = validator.validate(_char(
          classId: 'barbarian', level: 3, hp: [12, 7, 7], subclassId: 'champion'));
      expect(w.map((x) => x.code), contains('subclass_wrong_class'));
    });

    test('advierte si la subclase no existe', () {
      final w = validator.validate(_char(
          classId: 'fighter', level: 3, hp: [10, 6, 6], subclassId: 'inexistente'));
      expect(w.map((x) => x.code), contains('subclass_missing'));
    });
  });
}
