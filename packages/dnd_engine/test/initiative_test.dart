import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// La iniciativa de la ficha: el mod. de Destreza más lo que declaren los
/// efectos. Existe por la dote Alerta, que durante meses fue solo texto y
/// dejaba al Guardia con la iniciativa de cualquiera.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  ComputedSheet sheet({
    required String backgroundId,
    String classId = 'fighter',
    int level = 1,
    List<String> forms = const [],
  }) =>
      CharacterCompiler(repo).compile(
        Character(
          id: 'probe',
          name: 'Prueba',
          raceId: 'dwarf',
          classId: classId,
          backgroundId: backgroundId,
          level: level,
          wildShapeForms: forms,
          // DES 14 (+2). Ninguno de los dos trasfondos la sube.
          assignedScores: {
            Ability.strength: 15,
            Ability.dexterity: 14,
            Ability.constitution: 13,
            Ability.intelligence: 8,
            Ability.wisdom: 12,
            Ability.charisma: 10,
          },
          hpPerLevel: List.filled(level, 6),
        ),
      );

  test('el Guardia trae Alerta, y Alerta es la que declara el bono', () {
    expect(repo.background('guard')!.originFeatId, 'alert');
    expect(
      repo.feat('alert')!.effects,
      contains(isA<InitiativeBonusEffect>()
          .having((e) => e.addProficiency, 'addProficiency', isTrue)),
    );
  });

  test('sin Alerta, la iniciativa es solo la Destreza', () {
    // El Soldado da Atacante Salvaje, que no toca la iniciativa.
    expect(sheet(backgroundId: 'soldier').initiative, 2);
  });

  test('Alerta suma el bonificador por competencia a la Destreza', () {
    final s = sheet(backgroundId: 'guard');
    expect(s.initiative, 2 + s.proficiencyBonus);
    expect(s.initiative, 4);
  });

  test('el bono de Alerta sube con el nivel', () {
    // A nivel 5 el bonificador pasa a +3: un bono guardado como número fijo
    // se habría quedado en +2.
    final s = sheet(backgroundId: 'guard', level: 5);
    expect(s.proficiencyBonus, 3);
    expect(s.initiative, 5);
  });

  test('en Forma Salvaje la Destreza es de la bestia y Alerta sigue', () {
    final base = sheet(
      backgroundId: 'guard',
      classId: 'druid',
      level: 4,
      forms: ['wolf'],
    );
    final wolf = base.wildShape!.chosen.single;
    final shaped = applyWildShape(base, wolf);
    // Lobo DES 15 (+2) más el bonificador del druida (+2).
    expect(
      shaped.initiative,
      wolf.abilityModifierFor(Ability.dexterity) + base.proficiencyBonus,
    );
  });

  group('Emboscador Temible (Acechador en la Penumbra)', () {
    ComputedSheet stalker({required int level, required int wisdom}) =>
        CharacterCompiler(repo).compile(
          Character(
            id: 'probe',
            name: 'Prueba',
            raceId: 'dwarf',
            classId: 'ranger',
            subclassId: 'gloom-stalker',
            backgroundId: 'soldier',
            level: level,
            assignedScores: {
              Ability.strength: 12,
              Ability.dexterity: 14,
              Ability.constitution: 13,
              Ability.intelligence: 10,
              Ability.wisdom: wisdom,
              Ability.charisma: 8,
            },
            hpPerLevel: List.filled(level, 6),
          ),
        );

    test('suma el modificador de Sabiduría a la iniciativa', () {
      // DES +2 y SAB 16 (+3).
      expect(stalker(level: 3, wisdom: 16).initiative, 5);
    });

    test('llega con la subclase: a nivel 2 todavía no está', () {
      expect(stalker(level: 2, wisdom: 16).initiative, 2);
    });

    test('una Sabiduría negativa no resta, porque sumarla es optativo', () {
      expect(stalker(level: 3, wisdom: 8).initiative, 2);
    });
  });

  test('el efecto ida y vuelta por JSON conserva sus tres partes', () {
    const e = InitiativeBonusEffect(
      amount: 1,
      addProficiency: true,
      fromAbility: Ability.wisdom,
    );
    final back = Effect.fromJson(e.toJson()) as InitiativeBonusEffect;
    expect(back.amount, 1);
    expect(back.addProficiency, isTrue);
    expect(back.fromAbility, Ability.wisdom);
  });
}
