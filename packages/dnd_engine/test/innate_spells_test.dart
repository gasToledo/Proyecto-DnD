import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// L2: conjuros concedidos por rasgos (linajes, dotes), fuera de la magia de
/// clase. El truco se lanza a voluntad; el conjuro de linaje trae además un
/// recurso de un uso gratuito por descanso largo.
ContentRepository _repo() => ContentRepository.fromJsonPacks(
      races: [
        {'id': 'tiefling', 'name': 'Tiflin', 'source': 'srd_2024'},
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
      spells: [
        {
          'id': 'fire-bolt',
          'name': 'Rayo de Fuego',
          'source': 'srd_2024',
          'level': 0,
          'school': 'evocation',
          'classes': ['wizard'],
        },
        {
          'id': 'hellish-rebuke',
          'name': 'Represalia Infernal',
          'source': 'srd_2024',
          'level': 1,
          'school': 'evocation',
          'classes': ['warlock'],
        },
      ],
      lineages: [
        {
          'id': 'tiefling-infernal',
          'name': 'Legado Infernal',
          'raceId': 'tiefling',
          'source': 'srd_2024',
          'features': [
            {
              'level': 1,
              'name': 'Legado Infernal',
              'effects': [
                {'type': 'resistance', 'damageType': 'fire'},
                {
                  'type': 'grantSpell',
                  'spellId': 'fire-bolt',
                  'ability': 'charisma',
                  'use': 'atWill'
                },
              ],
            },
            {
              'level': 3,
              'name': 'Represalia',
              'effects': [
                {
                  'type': 'grantSpell',
                  'spellId': 'hellish-rebuke',
                  'ability': 'charisma',
                  'use': 'oncePerLongRest'
                },
              ],
            },
          ],
        },
      ],
    );

Character _tiefling({int level = 1, int cha = 16}) => Character(
      id: 'x',
      name: 'Prueba',
      raceId: 'tiefling',
      classId: 'fighter',
      backgroundId: 'soldier',
      lineageId: 'tiefling-infernal',
      level: level,
      assignedScores: {
        for (final a in Ability.values) a: a == Ability.charisma ? cha : 10,
      },
      hpPerLevel: List.filled(level, 10),
    );

void main() {
  test('el truco del linaje se concede a voluntad y sin recurso', () {
    final s = CharacterCompiler(_repo()).compile(_tiefling());
    expect(s.innateSpells, hasLength(1));
    final bolt = s.innateSpells.single;
    expect(bolt.name, 'Rayo de Fuego');
    expect(bolt.isCantrip, isTrue);
    expect(bolt.use, InnateSpellUse.atWill);
    expect(s.resources.where((r) => r.id.startsWith('innate-')), isEmpty);
    // Y la resistencia del mismo rasgo también entra.
    expect(s.resistances, contains('fire'));
  });

  test('la CD sale de la característica que fija el rasgo', () {
    // CAR 16 (+3), competencia +2 a nivel 1 → CD 8+2+3 = 13.
    final s = CharacterCompiler(_repo()).compile(_tiefling());
    expect(s.innateSpells.single.saveDc, 13);
    expect(s.innateSpells.single.attackBonus, 5);
    // Con CAR 10 (+0) baja a 10.
    final flat = CharacterCompiler(_repo()).compile(_tiefling(cha: 10));
    expect(flat.innateSpells.single.saveDc, 10);
  });

  test('el conjuro de nivel 3 aparece al subir, con su uso gratuito', () {
    final low = CharacterCompiler(_repo()).compile(_tiefling());
    expect(low.innateSpells.map((s) => s.spellId), ['fire-bolt']);

    final s = CharacterCompiler(_repo()).compile(_tiefling(level: 3));
    expect(s.innateSpells.map((x) => x.spellId),
        containsAll(['fire-bolt', 'hellish-rebuke']));

    final rebuke =
        s.innateSpells.firstWhere((x) => x.spellId == 'hellish-rebuke');
    expect(rebuke.use, InnateSpellUse.oncePerLongRest);
    expect(rebuke.level, 1);

    // El uso gratuito se modela como recurso, así la ficha lo gasta como
    // cualquier otro y el descanso largo lo recarga.
    final res = s.resources.firstWhere((r) => r.id == 'innate-hellish-rebuke');
    expect(res.max, 1);
    expect(res.recharge, RechargeOn.longRest);
    expect(res.name, 'Represalia Infernal');
  });

  test('un conjuro que no está en el repositorio se ignora sin romper', () {
    final repo = ContentRepository.fromJsonPacks(
      races: [
        {'id': 'tiefling', 'name': 'Tiflin', 'source': 'srd_2024'},
      ],
      classes: [
        {'id': 'fighter', 'name': 'Guerrero', 'source': 'srd_2024', 'hitDie': 10},
      ],
      backgrounds: [
        {'id': 'soldier', 'name': 'Soldado', 'source': 'srd_2024'},
      ],
      lineages: [
        {
          'id': 'tiefling-infernal',
          'name': 'Legado Infernal',
          'raceId': 'tiefling',
          'source': 'srd_2024',
          'features': [
            {
              'level': 1,
              'name': 'Legado Infernal',
              'effects': [
                {
                  'type': 'grantSpell',
                  'spellId': 'inexistente',
                  'ability': 'charisma'
                },
              ],
            },
          ],
        },
      ],
    );
    final s = CharacterCompiler(repo).compile(_tiefling());
    expect(s.innateSpells, isEmpty);
  });

  test('GrantSpellEffect hace round-trip por JSON', () {
    const e = GrantSpellEffect(
      spellId: 'fire-bolt',
      ability: Ability.charisma,
      use: InnateSpellUse.oncePerLongRest,
    );
    final back = Effect.fromJson(e.toJson()) as GrantSpellEffect;
    expect(back.spellId, 'fire-bolt');
    expect(back.ability, Ability.charisma);
    expect(back.use, InnateSpellUse.oncePerLongRest);
    // Por defecto, a voluntad.
    final plain = Effect.fromJson({
      'type': 'grantSpell',
      'spellId': 'fire-bolt',
      'ability': 'intelligence',
    }) as GrantSpellEffect;
    expect(plain.use, InnateSpellUse.atWill);
  });
}
