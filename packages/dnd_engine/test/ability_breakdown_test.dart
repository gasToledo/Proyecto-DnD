import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El caso que originó esto: en la mesa el DM preguntó por qué Inteligencia
/// daba +7 y la ficha no tenía con qué responder, porque el motor sumaba todo
/// en un solo acumulador y tiraba la procedencia.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  /// Artífice Artillero khoravar de nivel 4, con trasfondo Artesano y la dote
  /// Tirador de Primera tomada en la mejora de nivel 4. Es el personaje real
  /// que disparó el pedido.
  Character verloren() => Character(
        id: 'test',
        name: 'Verloren Ausfall',
        raceId: 'khoravar',
        classId: 'artificer',
        backgroundId: 'artisan',
        subclassId: 'artillerist',
        level: 4,
        assignedScores: const {
          Ability.strength: 9,
          Ability.dexterity: 13,
          Ability.constitution: 15,
          Ability.intelligence: 18,
          Ability.wisdom: 11,
          Ability.charisma: 9,
        },
        backgroundAbilityBonuses: const {
          Ability.dexterity: 1,
          Ability.intelligence: 2,
        },
        featIds: const ['sharpshooter'],
        asiChoices: const [AsiChoice(level: 4, featId: 'sharpshooter')],
        hpPerLevel: const [8, 5, 5, 3],
      );

  test('Inteligencia 20 se explica: 18 asignada + 2 del trasfondo', () {
    final sheet = compiler.compile(verloren());

    expect(sheet.abilityScores[Ability.intelligence], 20);
    expect(sheet.baseAbilityScore(Ability.intelligence), 18);

    final bonuses = sheet.bonusesFor(Ability.intelligence);
    expect(bonuses, hasLength(1));
    expect(bonuses.single.amount, 2);
    expect(bonuses.single.source, contains('Artesano'));
  });

  test('el +7 del ataque con conjuros cierra con el desglose', () {
    final sheet = compiler.compile(verloren());

    // 18 + 2 = 20 → modificador +5; competencia +2 a nivel 4.
    expect(sheet.abilityModifiers[Ability.intelligence], 5);
    expect(sheet.proficiencyBonus, 2);
    expect(sheet.spellcasting?.attackBonus, 7);
  });

  test('un bonus que llega por una dote nombra a la dote, no al nivel', () {
    final sheet = compiler.compile(verloren());

    // Tirador de Primera da +1 a Destreza como efecto de la dote. El bonus del
    // trasfondo a Destreza es otro aporte distinto, y los dos tienen que
    // aparecer por separado en vez de fundirse en un "+2" sin explicación.
    final dex = sheet.bonusesFor(Ability.dexterity);
    expect(dex.map((b) => b.amount), containsAll([1, 1]));
    expect(
      dex.any((b) => b.source.contains('Tirador')),
      isTrue,
      reason: 'el aporte de la dote debe nombrar la dote: $dex',
    );
    expect(sheet.abilityScores[Ability.dexterity], 15);
  });

  test('lo asignado sin bonus no inventa fuentes', () {
    final sheet = compiler.compile(verloren());

    expect(sheet.bonusesFor(Ability.charisma), isEmpty);
    expect(sheet.baseAbilityScore(Ability.charisma), 9);
    expect(sheet.abilityScores[Ability.charisma], 9);
  });

  test('el desglose siempre reconstruye el total, para toda característica',
      () {
    final sheet = compiler.compile(verloren());

    for (final a in Ability.values) {
      final sum = sheet.bonusesFor(a).fold<int>(0, (acc, b) => acc + b.amount);
      expect(
        sheet.baseAbilityScore(a) + sum,
        sheet.abilityScores[a],
        reason: 'el desglose de ${a.label} no cierra con su total',
      );
    }
  });
}
