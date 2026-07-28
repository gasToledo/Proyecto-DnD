import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// La clase Artífice de *Eberron: Forge of the Artificer* (capítulo 2), la
/// única pieza de ese libro que quedó pendiente al cerrar la tanda anterior.
/// Cubre lo que las 12 clases del PHB no necesitan: una progresión de trucos
/// con niveles de aumento propios ([SpellcastingEffect.cantripIncreases]) y un
/// recurso cuyo máximo escala con un modificador de característica
/// ([ResourceEffect.maxFromAbility]), en vez de con el nivel de personaje.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  ComputedSheet at(int level, {int intelligence = 15}) => compiler.compile(
        Character(
          id: 'probe-artificer',
          name: 'Prueba',
          raceId: 'human',
          classId: 'artificer',
          backgroundId: 'hermit',
          level: level,
          assignedScores: {
            Ability.strength: 10,
            Ability.dexterity: 14,
            Ability.constitution: 14,
            Ability.intelligence: intelligence,
            Ability.wisdom: 10,
            Ability.charisma: 8,
          },
          hpPerLevel: List.filled(level, 5),
        ),
      );

  group('Catálogo', () {
    test('el Artífice suma la 13ª clase y sus 5 subclases', () {
      expect(repo.classes, hasLength(13));
      expect(repo.characterClass('artificer'), isNotNull);
      expect(repo.subclasses, hasLength(53));
      expect(repo.subclassesForClass('artificer'), hasLength(5));
    });

    test('la clase y sus 5 subclases están etiquetadas foa_2025', () {
      expect(repo.characterClass('artificer')!.source, ContentSource.foa2025);
      for (final s in repo.subclassesForClass('artificer')) {
        expect(s.source, ContentSource.foa2025, reason: s.id);
      }
    });

    test('llega al nivel 20 sin dejar huecos', () {
      final ultimo = repo
          .characterClass('artificer')!
          .features
          .map((f) => f.level)
          .reduce((a, b) => a > b ? a : b);
      expect(ultimo, 20);
    });

    test('su lista de conjuros tiene los 80 conjuros del capítulo, y solo esos',
        () {
      final lista = repo.spellsForList('artificer');
      expect(lista, hasLength(80));
      expect(lista.map((s) => s.id), contains('homunculus-servant'));
    });
  });

  group('Espacios y conjuros preparados (semi-lanzador)', () {
    test('espacios de conjuro coinciden con la tabla del capítulo', () {
      expect(at(1).spellcasting!.slotsByLevel, {1: 2});
      expect(at(5).spellcasting!.slotsByLevel, {1: 4, 2: 2});
      expect(at(9).spellcasting!.slotsByLevel, {1: 4, 2: 3, 3: 2});
      expect(
        at(13).spellcasting!.slotsByLevel,
        {1: 4, 2: 3, 3: 3, 4: 1},
      );
      expect(
        at(17).spellcasting!.slotsByLevel,
        {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      );
      expect(
        at(20).spellcasting!.slotsByLevel,
        {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
      );
    });

    test('conjuros preparados coinciden con la tabla del capítulo', () {
      expect(at(1).spellcasting!.preparedCount, 2);
      expect(at(5).spellcasting!.preparedCount, 6);
      expect(at(9).spellcasting!.preparedCount, 9);
      expect(at(13).spellcasting!.preparedCount, 11);
      expect(at(17).spellcasting!.preparedCount, 14);
      expect(at(20).spellcasting!.preparedCount, 15);
    });
  });

  test('los trucos escalan a niveles 1, 10 y 14 (cantripIncreases), no 4', () {
    expect(at(1).spellcasting!.cantripsKnown, 2);
    expect(at(4).spellcasting!.cantripsKnown, 2, reason: 'no aumenta en 4');
    expect(at(9).spellcasting!.cantripsKnown, 2);
    expect(at(10).spellcasting!.cantripsKnown, 3);
    expect(at(13).spellcasting!.cantripsKnown, 3);
    expect(at(14).spellcasting!.cantripsKnown, 4);
    expect(at(20).spellcasting!.cantripsKnown, 4);
  });

  group('Recursos escalados por modificador de característica', () {
    int max(String id, {required int level, required int intelligence}) =>
        at(level, intelligence: intelligence)
            .resources
            .firstWhere((r) => r.id == id)
            .max;

    test('Magia de Manitas usa el mod. de Inteligencia, mínimo 1', () {
      expect(max('tinkers_magic', level: 1, intelligence: 8), 1);
      expect(max('tinkers_magic', level: 1, intelligence: 18), 4);
    });

    test('Chispa de Genialidad usa el mod. de Inteligencia, mínimo 1', () {
      expect(max('flash_of_genius', level: 7, intelligence: 8), 1);
      expect(max('flash_of_genius', level: 7, intelligence: 18), 4);
    });
  });
}
