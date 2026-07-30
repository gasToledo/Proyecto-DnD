import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Los 4 trasfondos que faltaban del capítulo 4: Acólito y Erudito (SRD),
/// Guía y Marinero (PHB 2024). Los campos se verificaron contra el bloque de
/// características del propio trasfondo en el manual, no contra la tabla
/// resumen de la creación de personaje (esa quedó cortada por columnas en la
/// extracción del PDF).
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Background background(String id) => repo.background(id)!;
  Feat feat(String id) => repo.feat(id)!;

  test('el catálogo tiene los 16 trasfondos del capítulo 4', () {
    // Solo los del PHB: Forge of the Artificer suma otros 17, que se cuentan
    // aparte en `foa_2025_test.dart`.
    final phb =
        repo.backgrounds.values.where((b) => b.source != ContentSource.foa2025);
    expect(phb, hasLength(16));
  });

  test('Acólito: Perspicacia y Religión, Iniciado en la Magia (Clérigo)', () {
    final b = background('acolyte');
    expect(b.source, ContentSource.srd2024);
    expect(b.abilityOptions,
        containsAll([Ability.intelligence, Ability.wisdom, Ability.charisma]));
    expect(b.skillProficiencies, containsAll(['insight', 'religion']));
    expect(b.toolProficiencies, contains('calligraphers-supplies'));
    expect(b.originFeatId, 'magic-initiate-cleric');
  });

  test('Erudito: Arcanos e Historia, Iniciado en la Magia (Mago)', () {
    final b = background('sage');
    expect(b.source, ContentSource.srd2024);
    expect(
        b.abilityOptions,
        containsAll(
            [Ability.constitution, Ability.intelligence, Ability.wisdom]));
    expect(b.skillProficiencies, containsAll(['arcana', 'history']));
    expect(b.originFeatId, 'magic-initiate-wizard');
  });

  test('Guía: Sigilo y Supervivencia, Iniciado en la Magia (Druida)', () {
    final b = background('guide');
    expect(b.source, ContentSource.phb2024);
    expect(b.abilityOptions,
        containsAll([Ability.dexterity, Ability.constitution, Ability.wisdom]));
    expect(b.skillProficiencies, containsAll(['stealth', 'survival']));
    expect(b.toolProficiencies, contains('cartographers-tools'));
    expect(b.originFeatId, 'magic-initiate-druid');
  });

  test('Marinero: Acrobacias y Percepción, Matón de Taberna', () {
    final b = background('sailor');
    expect(b.source, ContentSource.phb2024);
    expect(b.abilityOptions,
        containsAll([Ability.strength, Ability.dexterity, Ability.wisdom]));
    expect(b.skillProficiencies, containsAll(['acrobatics', 'perception']));
    expect(b.toolProficiencies, contains('navigators-tools'));
    expect(b.originFeatId, 'tavern-brawler');
  });

  test('las dos dotes de origen nuevas existen y no piden nivel', () {
    for (final id in ['magic-initiate-druid', 'tavern-brawler']) {
      final f = feat(id);
      expect(f.category, 'origin');
      expect(f.prerequisite?.minLevel, isNull);
    }
  });

  test('cada variante de Iniciado en la Magia se elige una sola vez', () {
    // La dote canónica es repetible solo si se escoge una lista diferente.
    // Como el catálogo modela cada lista como una dote separada, cada variante
    // individual debe ser no repetible.
    for (final id in [
      'magic-initiate-cleric',
      'magic-initiate-druid',
      'magic-initiate-wizard',
    ]) {
      expect(feat(id).repeatable, isFalse, reason: id);
    }
  });
}
