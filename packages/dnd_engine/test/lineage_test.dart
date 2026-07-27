import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Mecanismo de linajes de especie (L1): un linaje aporta rasgos por nivel a su
/// especie, igual que una subclase a su clase.
ContentRepository _repo() => ContentRepository.fromJsonPacks(
      races: [
        {
          'id': 'elf',
          'name': 'Elfo',
          'source': 'srd_2024',
          'speed': 30,
          'effects': [
            {'type': 'darkvision', 'range': 60}
          ],
        },
        {'id': 'dwarf', 'name': 'Enano', 'source': 'srd_2024'},
      ],
      classes: [
        {
          'id': 'fighter',
          'name': 'Guerrero',
          'source': 'srd_2024',
          'hitDie': 10,
        },
      ],
      backgrounds: [
        {'id': 'soldier', 'name': 'Soldado', 'source': 'srd_2024'},
      ],
      lineages: [
        {
          'id': 'elf-wood',
          'name': 'Elfo del Bosque',
          'raceId': 'elf',
          'source': 'srd_2024',
          'features': [
            {
              'level': 1,
              'name': 'Paso del Bosque',
              'effects': [
                {'type': 'setSpeed', 'feet': 35}
              ],
            },
            {
              'level': 5,
              'name': 'Resistencia tardía',
              'effects': [
                {'type': 'resistance', 'damageType': 'poison'}
              ],
            },
          ],
        },
        {
          'id': 'elf-high',
          'name': 'Alto Elfo',
          'raceId': 'elf',
          'source': 'srd_2024',
        },
        {
          'id': 'dwarf-hill',
          'name': 'Enano de las Colinas',
          'raceId': 'dwarf',
          'source': 'srd_2024',
        },
      ],
    );

Character _elf({String? lineageId, int level = 1}) => Character(
      id: 'x',
      name: 'Prueba',
      raceId: 'elf',
      classId: 'fighter',
      backgroundId: 'soldier',
      lineageId: lineageId,
      level: level,
      assignedScores: {for (final a in Ability.values) a: 10},
      hpPerLevel: List.filled(level, 10),
    );

void main() {
  group('repositorio', () {
    test('lineagesForRace filtra por especie y ordena por nombre', () {
      final repo = _repo();
      expect(repo.lineagesForRace('elf').map((l) => l.name),
          ['Alto Elfo', 'Elfo del Bosque']);
      expect(repo.lineagesForRace('dwarf').map((l) => l.id), ['dwarf-hill']);
      expect(repo.lineagesForRace('halfling'), isEmpty);
    });
  });

  group('compilador', () {
    test('sin linaje, la especie sola', () {
      final s = CharacterCompiler(_repo()).compile(_elf());
      expect(s.speed, 30);
    });

    test('el linaje aporta sus rasgos de nivel 1', () {
      final s = CharacterCompiler(_repo()).compile(_elf(lineageId: 'elf-wood'));
      expect(s.speed, 35, reason: 'Paso del Bosque fija la velocidad');
      expect(s.resistances, isEmpty, reason: 'la de nivel 5 todavía no');
    });

    test('los rasgos de nivel superior entran al subir', () {
      final s = CharacterCompiler(_repo())
          .compile(_elf(lineageId: 'elf-wood', level: 5));
      expect(s.resistances, contains('poison'));
    });

    test('un linaje de otra especie se ignora', () {
      final s =
          CharacterCompiler(_repo()).compile(_elf(lineageId: 'dwarf-hill'));
      expect(s.speed, 30, reason: 'no debe aplicar nada ajeno');
    });
  });

  group('validación', () {
    test('avisa si la especie ofrece linajes y no se eligió', () {
      final w = CharacterValidator(_repo()).validate(_elf());
      expect(w.map((x) => x.code), contains('lineage_pending'));
    });

    test('no avisa si la especie no ofrece linajes', () {
      final repo = _repo();
      final c = Character(
        id: 'y',
        name: 'P',
        raceId: 'dwarf',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {for (final a in Ability.values) a: 10},
        hpPerLevel: const [10],
        lineageId: 'dwarf-hill',
      );
      final codes = CharacterValidator(repo).validate(c).map((x) => x.code);
      expect(codes, isNot(contains('lineage_pending')));
      expect(codes, isNot(contains('lineage_wrong_race')));
    });

    test('avisa si el linaje es de otra especie o no existe', () {
      final repo = _repo();
      expect(
          CharacterValidator(repo)
              .validate(_elf(lineageId: 'dwarf-hill'))
              .map((x) => x.code),
          contains('lineage_wrong_race'));
      expect(
          CharacterValidator(repo)
              .validate(_elf(lineageId: 'inexistente'))
              .map((x) => x.code),
          contains('lineage_missing'));
    });
  });

  test('linaje y aptitud mágica sobreviven al round-trip', () {
    final c = Character(
      id: 'elf-choice',
      name: 'Elfo',
      raceId: 'elf',
      classId: 'fighter',
      backgroundId: 'soldier',
      lineageId: 'elf-wood',
      speciesSpellcastingAbility: Ability.charisma,
      assignedScores: {for (final ability in Ability.values) ability: 10},
      hpPerLevel: const [10],
    );
    final restored = Character.fromJson(c.toJson());
    expect(restored.lineageId, 'elf-wood');
    expect(restored.speciesSpellcastingAbility, Ability.charisma);
    expect(c.copyWith(name: 'Otro').lineageId, 'elf-wood');
    expect(
      c.copyWith(speciesSpellcastingAbility: null).speciesSpellcastingAbility,
      isNull,
    );
    expect(c.copyWith(lineageId: null).lineageId, isNull);
    // Una ficha anterior al campo se lee sin romperse.
    final old = c.toJson()..remove('lineageId');
    expect(Character.fromJson(old).lineageId, isNull);
  });
}
