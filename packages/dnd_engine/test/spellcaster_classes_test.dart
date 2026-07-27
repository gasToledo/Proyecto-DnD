import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Progresiones de las seis clases lanzadoras contra las tablas del PHB 2024.
///
/// El catálogo guardaba solo el valor de nivel 1 de columnas que escalan, así
/// que un Clérigo de nivel 18 mostraba 2 usos de Canalizar Divinidad en vez de
/// 4. Estas aserciones fijan cada escalón de la tabla.
void main() {
  late CharacterCompiler compiler;

  setUpAll(() async {
    final repo =
        await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  ComputedSheet at(String classId, int level) => compiler.compile(
        Character(
          id: 'probe-$classId',
          name: 'Prueba',
          raceId: 'human',
          classId: classId,
          // Trasfondo real del catálogo: uno inexistente se ignora en silencio
          // (`background != null` en el compilador) y dejaría el caso sin premisa.
          backgroundId: 'hermit',
          level: level,
          assignedScores: const {
            Ability.strength: 10,
            Ability.dexterity: 14,
            Ability.constitution: 14,
            Ability.intelligence: 15,
            Ability.wisdom: 15,
            Ability.charisma: 15,
          },
          hpPerLevel: List.filled(level, 5),
        ),
      );

  int resourceMax(String classId, int level, String id) =>
      at(classId, level).resources.firstWhere((r) => r.id == id).max;

  test('Clérigo: Canalizar Divinidad va 2 / 3 / 4', () {
    expect(resourceMax('cleric', 2, 'channel_divinity'), 2);
    expect(resourceMax('cleric', 5, 'channel_divinity'), 2);
    expect(resourceMax('cleric', 6, 'channel_divinity'), 3);
    expect(resourceMax('cleric', 17, 'channel_divinity'), 3);
    expect(resourceMax('cleric', 18, 'channel_divinity'), 4);
    expect(resourceMax('cleric', 20, 'channel_divinity'), 4);
  });

  test('Druida: Forma Salvaje va 2 / 3 / 4', () {
    expect(resourceMax('druid', 2, 'wild_shape'), 2);
    expect(resourceMax('druid', 5, 'wild_shape'), 2);
    expect(resourceMax('druid', 6, 'wild_shape'), 3);
    expect(resourceMax('druid', 16, 'wild_shape'), 3);
    expect(resourceMax('druid', 17, 'wild_shape'), 4);
    expect(resourceMax('druid', 20, 'wild_shape'), 4);
  });

  test('Hechicero: Hechicería Innata se queda en 2 usos toda la progresión',
      () {
    // No es una columna congelada: el PHB la deja fija en 2 por descanso largo.
    expect(resourceMax('sorcerer', 1, 'innate_sorcery'), 2);
    expect(resourceMax('sorcerer', 20, 'innate_sorcery'), 2);
  });

  test('Los trucos conocidos suben a nivel 4 y 10 en las seis lanzadoras', () {
    const base = {
      'wizard': 3,
      'cleric': 3,
      'druid': 2,
      'bard': 2,
      'sorcerer': 4,
      'warlock': 2,
    };
    for (final e in base.entries) {
      expect(at(e.key, 1).spellcasting!.cantripsKnown, e.value, reason: e.key);
      expect(at(e.key, 4).spellcasting!.cantripsKnown, e.value + 1,
          reason: e.key);
      expect(at(e.key, 10).spellcasting!.cantripsKnown, e.value + 2,
          reason: e.key);
    }
  });

  test('Druida: en 2024 pierde la armadura media, conserva ligera y escudo',
      () {
    final p = at('druid', 1).armorProficiencies;
    expect(p, contains('light'));
    expect(p, contains('shield'));
    expect(p, isNot(contains('medium')));
  });

  test('Bardo: el texto de Inspiración Bárdica nombra los cuatro dados', () {
    final d = at('bard', 1)
        .passives
        .firstWhere((p) => p.name == 'Inspiración Bárdica')
        .description;
    for (final die in ['d6', 'd8', 'd10', 'd12']) {
      expect(d, contains(die));
    }
  });
}
