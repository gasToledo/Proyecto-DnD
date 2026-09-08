import 'package:test/test.dart';

import '../tool/generate_bestiary.dart' as generator;

void main() {
  const ids = {
    'detectar magia': 'detect-magic',
    'palabra de poder: matar': 'power-word-kill',
    'cambiar de forma': 'shapechange',
    'bola de fuego': 'fireball',
  };

  test('estructura usos, nivel y notas sin partir comas internas', () {
    final parsed = generator.parseCreatureSpellcasting(
      'que no requiere componentes  somáticos o materiales y utiliza la '
      'Inteligencia como aptitud mágica '
      '(CD de salvación de conjuros 17, +9 a acertar con ataques de conjuro): '
      'A voluntad: cambiar de forma (solo bestia o humanoide, sin PG temporales), '
      'detectar magia 1/día cada uno: bola de fuego (versión de nivel 6), '
      'palabra de poder: matar',
      ids,
    );

    expect(parsed['ability'], 'intelligence');
    expect(parsed['saveDc'], 17);
    expect(parsed['attackBonus'], 9);
    expect(
      parsed['componentRule'],
      'No requiere componentes somáticos o materiales.',
    );
    final groups = (parsed['groups'] as List).cast<Map>();
    expect(groups, hasLength(2));
    expect(groups.first.containsKey('usesPerDay'), isFalse);
    expect(groups.last['usesPerDay'], 1);
    final atWill = (groups.first['spells'] as List).cast<Map>();
    expect(atWill.first['note'], 'solo bestia o humanoide, sin PG temporales');
    final daily = (groups.last['spells'] as List).cast<Map>();
    expect(daily.first['castAtLevel'], 6);
    expect(daily.first.containsKey('note'), isFalse);
    expect(daily.last['spellId'], 'power-word-kill');
  });

  test('rechaza referencias desconocidas y repetidas', () {
    expect(
      () => generator.parseCreatureSpellcasting(
        'Utiliza la Sabiduría como aptitud mágica: A voluntad: inventado',
        ids,
      ),
      throwsFormatException,
    );
    expect(
      () => generator.parseCreatureSpellcasting(
        'Utiliza la Sabiduría como aptitud mágica: '
        'A voluntad: detectar magia 1/día: detectar magia',
        ids,
      ),
      throwsFormatException,
    );
  });

  test('separa Provocar pesadillas del bloque anterior', () {
    final entries = generator.parseEntries([
      'Acciones',
      'Lanzamiento de conjuros. A voluntad: detectar magia,',
      'desplazamiento entre planos (solo lanzador) Provocar pesadillas (1/día; requiere una bolsa de',
      'almas). Mientras está en el Plano Etéreo, la saga lanza ensueño.',
    ]);

    expect(entries.map((entry) => entry.name), [
      'Lanzamiento de conjuros',
      'Provocar pesadillas (1/día)',
    ]);
    expect(entries.last.text, startsWith('Requiere una bolsa de almas.'));
  });
}
