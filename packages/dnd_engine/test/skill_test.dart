import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  test('son 18, con id y etiqueta únicos', () {
    expect(Skill.values, hasLength(18));
    expect(Skill.allIds.toSet(), hasLength(18));
    expect(Skill.values.map((s) => s.label).toSet(), hasLength(18));
  });

  test('fromId y labelFor', () {
    expect(Skill.fromId('sleight-of-hand'), Skill.sleightOfHand);
    expect(Skill.labelFor('animal-handling'), 'Trato con Animales');
    expect(Skill.fromId('inexistente'), isNull);
    // Un id fuera del catálogo (homebrew) no rompe: se muestra capitalizado.
    expect(Skill.labelFor('mi-habilidad'), 'Mi Habilidad');
  });

  test('cada habilidad declara la característica correcta (SRD 5.2)', () {
    expect(Skill.athletics.ability, Ability.strength);
    expect(Skill.stealth.ability, Ability.dexterity);
    expect(Skill.arcana.ability, Ability.intelligence);
    expect(Skill.perception.ability, Ability.wisdom);
    expect(Skill.persuasion.ability, Ability.charisma);
    // Ninguna habilidad depende de Constitución.
    expect(Skill.values.any((s) => s.ability == Ability.constitution), isFalse);
  });

  test('el catálogo cubre todas las habilidades del contenido oficial',
      () async {
    final repo =
        await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    final referenced = <String>{
      for (final b in repo.backgrounds.values) ...b.skillProficiencies,
      for (final k in repo.classes.values) ...k.skillChoiceFrom,
      for (final r in repo.races.values) ...r.skillChoiceFrom,
    };
    final unknown = referenced.where((s) => Skill.fromId(s) == null).toList();
    expect(unknown, isEmpty,
        reason: 'el contenido referencia habilidades fuera del catálogo');
  });
}
