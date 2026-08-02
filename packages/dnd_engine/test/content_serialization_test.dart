import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Round-trip de contenido (toJson/fromJson)', () {
    test('Weapon conserva sus campos', () {
      const w = Weapon(
        id: 'hb-espada',
        name: 'Espada rúnica',
        source: ContentSource.homebrew,
        category: 'martial',
        damageDice: '1d8',
        damageType: 'slashing',
        properties: ['versatile', 'finesse'],
        versatileDice: '1d10',
        mastery: 'sap',
      );
      final r = Weapon.fromJson(w.toJson());
      expect(r.name, w.name);
      expect(r.source, ContentSource.homebrew);
      expect(r.properties, w.properties);
      expect(r.versatileDice, '1d10');
      expect(r.mastery, 'sap');
    });

    test('Race conserva efectos tipados', () {
      const race = Race(
        id: 'hb-drakonido',
        name: 'Drakónido custom',
        source: ContentSource.homebrew,
        speed: 35,
        effects: [
          DarkvisionEffect(60),
          AbilityScoreBonusEffect(ability: Ability.strength, amount: 1),
          ResistanceEffect('fire'),
        ],
      );
      final r = Race.fromJson(race.toJson());
      expect(r.speed, 35);
      expect(r.effects.whereType<DarkvisionEffect>().single.range, 60);
      expect(r.effects.whereType<ResistanceEffect>().single.damageType, 'fire');
    });

    test('Feat y Armor round-trip', () {
      const feat = Feat(
        id: 'hb-dote',
        name: 'Dote propia',
        source: ContentSource.homebrew,
        category: 'general',
        effects: [BonusMaxHpPerLevelEffect(1)],
      );
      expect(Feat.fromJson(feat.toJson()).effects.single,
          isA<BonusMaxHpPerLevelEffect>());

      const armor = Armor(
        id: 'hb-armadura',
        name: 'Coraza rúnica',
        source: ContentSource.homebrew,
        category: 'heavy',
        baseAc: 18,
      );
      expect(Armor.fromJson(armor.toJson()).baseAc, 18);
    });

    test('OffHandAbilityDamageEffect sobrevive el round-trip', () {
      // Es el efecto por el que el motor sabe del estilo Combate con Dos Armas
      // sin preguntar por el id de la dote, así que un homebrew puede concederlo.
      const feat = Feat(
        id: 'hb-ambidiestro',
        name: 'Ambidiestro',
        source: ContentSource.homebrew,
        category: 'general',
        effects: [OffHandAbilityDamageEffect()],
      );
      expect(Feat.fromJson(feat.toJson()).effects.single,
          isA<OffHandAbilityDamageEffect>());
    });
  });

  test('una dote homebrew fusionada afecta la ficha compilada', () {
    final repo = ContentRepository(feats: {
      'hb-fuerza': const Feat(
        id: 'hb-fuerza',
        name: 'Fuerza homebrew',
        source: ContentSource.homebrew,
        category: 'general',
        effects: [
          AbilityScoreBonusEffect(ability: Ability.strength, amount: 2)
        ],
      ),
    });
    final c = Character(
      id: 'x',
      name: 'Prueba',
      raceId: '',
      classId: '',
      backgroundId: '',
      assignedScores: {for (final a in Ability.values) a: 10},
      featIds: ['hb-fuerza'],
      hpPerLevel: [8],
    );
    final sheet = CharacterCompiler(repo).compile(c);
    expect(sheet.abilityScores[Ability.strength], 12);
  });
}
