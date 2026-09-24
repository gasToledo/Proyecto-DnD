import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  // El asistente guarda los conjuros de una ficha monoclase en las listas
  // planas; la subida de nivel y la ficha los editan por clase. Sin una sola
  // regla, la primera subida mostraba «0 de N» y lo reemplazado seguía
  // preparado porque el compilador sumaba las dos listas.
  final created = Character(
    id: 'p',
    name: 'Ssarak',
    raceId: 'dragonborn',
    classId: 'paladin',
    backgroundId: 'noble',
    assignedScores: {for (final a in Ability.values) a: 10},
    spellIds: ['bless', 'cure-wounds'],
  );

  test('una ficha recién creada lee sus conjuros por clase', () {
    expect(created.spellIdsFor('paladin'), ['bless', 'cure-wounds']);
    expect(created.spellIdsFor('ranger'), isEmpty);
  });

  test('reemplazar por clase no deja las listas planas sumando', () {
    final edited = created.withClassSpells(
      'paladin',
      cantrips: const [],
      spells: ['bless', 'shield-of-faith'],
    );
    expect(edited.spellIds, isEmpty);
    expect(edited.spellIdsFor('paladin'), ['bless', 'shield-of-faith']);
    expect(edited.classSpellIds, {
      'paladin': ['bless', 'shield-of-faith'],
    });
  });

  test('sumar una segunda clase conserva los de la primera', () {
    final multi = created.withClassSpells(
      'ranger',
      cantrips: const [],
      spells: ['hunters-mark'],
    );
    expect(multi.spellIdsFor('paladin'), ['bless', 'cure-wounds']);
    expect(multi.spellIdsFor('ranger'), ['hunters-mark']);
    expect(multi.spellIds, isEmpty);
  });
}
