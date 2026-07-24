import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// L3, Tier A: verifica el contenido real de los linajes de Elfo, Gnomo y
/// Tiflin contra el pack, para que un id mal escrito no pase silencioso.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character _pj(String raceId, String lineageId, {int level = 5}) => Character(
        id: 'x',
        name: 'P',
        raceId: raceId,
        classId: 'fighter',
        backgroundId: 'soldier',
        lineageId: lineageId,
        level: level,
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: List.filled(level, 10),
      );

  test('cada especie con linaje ofrece exactamente sus opciones', () {
    expect(repo.lineagesForRace('elf').map((l) => l.id).toSet(),
        {'elf-high', 'elf-drow', 'elf-wood'});
    expect(repo.lineagesForRace('gnome').map((l) => l.id).toSet(),
        {'gnome-forest', 'gnome-rock'});
    expect(repo.lineagesForRace('tiefling').length, 3);
    // Las especies sin linaje no ofrecen ninguno.
    expect(repo.lineagesForRace('human'), isEmpty);
    expect(repo.lineagesForRace('dwarf'), isEmpty);
  });

  test('todo conjuro que concede un linaje existe en el pack', () {
    final missing = <String>[];
    for (final l in repo.lineages.values) {
      for (final f in l.features) {
        for (final e in f.effects) {
          if (e is GrantSpellEffect && repo.spell(e.spellId) == null) {
            missing.add('${l.id} → ${e.spellId}');
          }
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'linajes que conceden conjuros inexistentes: $missing');
  });

  test('cada linaje pertenece a una especie que existe', () {
    for (final l in repo.lineages.values) {
      expect(repo.race(l.raceId), isNotNull,
          reason: '${l.id} apunta a la especie inexistente ${l.raceId}');
    }
  });

  test('los tres legados del Tiflin dan resistencia y truco a nivel 1', () {
    final cases = {
      'tiefling-infernal': ('fire', 'fire-bolt'),
      'tiefling-abyssal': ('poison', 'poison-spray'),
      'tiefling-chthonic': ('necrotic', 'chill-touch'),
    };
    cases.forEach((lineageId, expected) {
      final s = CharacterCompiler(repo).compile(_pj('tiefling', lineageId, level: 1));
      expect(s.resistances, contains(expected.$1), reason: lineageId);
      // El truco del legado + la Taumaturgia base del Tiflin.
      final ids = s.innateSpells.map((x) => x.spellId);
      expect(ids, contains(expected.$2), reason: lineageId);
      expect(ids, contains('thaumaturgy'),
          reason: 'la Taumaturgia del Tiflin base ahora es real');
    });
  });

  test('el Drow tiene visión superior; el Elfo del Bosque, +velocidad', () {
    final drow = CharacterCompiler(repo).compile(_pj('elf', 'elf-drow', level: 1));
    expect(drow.darkvision, 120);
    final wood = CharacterCompiler(repo).compile(_pj('elf', 'elf-wood', level: 1));
    expect(wood.speed, 35);
  });

  test('los conjuros de nivel 3 y 5 aparecen al subir, con su recurso', () {
    final low =
        CharacterCompiler(repo).compile(_pj('tiefling', 'tiefling-infernal', level: 1));
    expect(low.innateSpells.map((s) => s.spellId), isNot(contains('hellish-rebuke')));

    final high =
        CharacterCompiler(repo).compile(_pj('tiefling', 'tiefling-infernal', level: 5));
    final ids = high.innateSpells.map((s) => s.spellId);
    expect(ids, containsAll(['fire-bolt', 'hellish-rebuke', 'darkness']));
    // Los dos conjuros con nivel traen su uso gratuito por descanso largo.
    expect(high.resources.where((r) => r.id.startsWith('innate-')).length, 2);
  });
}
