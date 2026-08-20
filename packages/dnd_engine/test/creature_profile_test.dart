import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Los campos que el perfil de un monstruo necesita y el catálogo viejo no
/// tenía: tipo y tamaño estructurados, salvaciones, habilidades, percepción
/// pasiva y acciones que no son «acción».
///
/// La regla que gobierna todo este grupo es que el cambio sea **aditivo**: las
/// entradas escritas antes de estos campos tienen que seguir leyéndose igual,
/// sin reescribir el JSON del catálogo.
void main() {
  Creature bare({
    String kind = '',
    CreatureType? type,
    CreatureSize? size,
    String senses = '',
  }) =>
      Creature(
        id: 'x',
        name: 'X',
        source: ContentSource.srd2024,
        kind: kind,
        type: type,
        size: size,
        senses: senses,
        ac: '12',
        hp: '10',
      );

  group('Tipo y tamaño', () {
    test('el campo estructurado manda cuando está', () {
      final c = bare(
        kind: 'Bestia Mediana',
        type: CreatureType.dragon,
        size: CreatureSize.huge,
      );
      expect(c.creatureType, CreatureType.dragon);
      expect(c.creatureSize, CreatureSize.huge);
      // Y por lo tanto deja de ser bestia, aunque el texto diga otra cosa.
      expect(c.isBeast, isFalse);
    });

    test('sin campo estructurado se deducen del texto del perfil', () {
      final c = bare(kind: 'Bestia Mediana');
      expect(c.creatureType, CreatureType.beast);
      expect(c.creatureSize, CreatureSize.medium);
      expect(c.isBeast, isTrue);
    });

    test('el tamaño no es la última palabra del perfil', () {
      // "Gigante Grande, caótico malvado" termina en el alineamiento: buscar
      // por posición daría null, y el Ogro perdería su tamaño.
      final c = bare(kind: 'Gigante Grande, caótico malvado');
      expect(c.creatureType, CreatureType.giant);
      expect(c.creatureSize, CreatureSize.large);
    });

    test('una etiqueta descriptiva entre el tipo y el tamaño no estorba', () {
      final c = bare(kind: 'Feérico Pequeño (trasgo), caótico neutral');
      expect(c.creatureType, CreatureType.fey);
      expect(c.creatureSize, CreatureSize.small);
    });

    test('una etiqueta al final del perfil no se come el tamaño', () {
      // Regresión: el pteranodon del catálogo es "Bestia Mediana (dinosaurio)"
      // y el tamaño se sacaba tomando la última palabra, que acá es
      // "(dinosaurio)". La forma salvaje de pteranodon se quedaba con el
      // tamaño del druida en vez del de la bestia.
      final c = bare(kind: 'Bestia Mediana (dinosaurio)');
      expect(c.creatureSize, CreatureSize.medium);
      expect(c.creatureSize!.label, 'Mediano');
    });

    test('un perfil que ofrece varios tipos a elección no inventa uno', () {
      // No hay respuesta correcta acá, así que se muestra `kind` tal cual en
      // vez de elegir por el usuario.
      final c = bare(kind: 'Objeto Diminuto o Pequeño (a tu elección)');
      expect(c.creatureType, isNull);
      expect(c.isBeast, isFalse);
    });
  });

  group('Percepción pasiva', () {
    test('sale del campo propio cuando está', () {
      final c = Creature(
        id: 'x',
        name: 'X',
        source: ContentSource.srd2024,
        ac: '12',
        hp: '10',
        senses: 'Percepción pasiva 10',
        passivePerception: 15,
      );
      expect(c.passivePerceptionValue, 15);
    });

    test('y si no, se lee del texto de sentidos', () {
      final c = bare(
          senses: 'visión en la oscuridad 60 pies; '
              'Percepción pasiva 16');
      expect(c.passivePerceptionValue, 16);
      expect(c.darkvision, 60);
    });

    test('una criatura sin percepción pasiva declarada devuelve null', () {
      expect(bare(senses: 'ninguno').passivePerceptionValue, isNull);
    });
  });

  group('Acciones', () {
    test('el booleano viejo se sigue leyendo como reacción', () {
      final a = CreatureAction.fromJson({'name': 'Parada', 'reaction': true});
      expect(a.kind, CreatureActionKind.reaction);
      expect(a.reaction, isTrue);
    });

    test('sin tipo ni booleano es una acción común', () {
      final a = CreatureAction.fromJson({'name': 'Reparar'});
      expect(a.kind, CreatureActionKind.action);
      expect(a.reaction, isFalse);
    });

    test('el tipo explícito le gana al booleano viejo', () {
      final a = CreatureAction.fromJson({
        'name': 'Zarpazo',
        'reaction': true,
        'kind': 'legendary',
      });
      expect(a.kind, CreatureActionKind.legendary);
      expect(a.reaction, isFalse);
    });

    test('el tipo sobrevive a resolverse', () {
      const a = CreatureAction(
        name: 'Embestida',
        kind: CreatureActionKind.legendary,
        attackBonus: '7',
        damage: '2d6+4',
      );
      final r = a.resolve(const CreatureVars({}));
      expect(r.kind, CreatureActionKind.legendary);
      expect(r.attackBonus, 7);
    });
  });

  group('Iniciativa', () {
    test('sin bono impreso usa el modificador de Destreza', () {
      final c = Creature(
        id: 'x',
        name: 'X',
        source: ContentSource.srd2024,
        ac: '12',
        hp: '10',
        abilityScores: const {Ability.dexterity: 14},
      );
      expect(c.initiativeModifier, 2);
    });

    test('con bono impreso le gana a Destreza', () {
      // Competencia en iniciativa: la regla 2024 la permite y el perfil
      // imprime un número que no es el modificador de DES.
      final c = Creature(
        id: 'x',
        name: 'X',
        source: ContentSource.srd2024,
        ac: '12',
        hp: '10',
        abilityScores: const {Ability.dexterity: 10},
        initiativeBonus: 6,
      );
      expect(c.initiativeModifier, 6);
    });
  });

  test('los campos nuevos sobreviven a un viaje de ida y vuelta', () {
    final original = Creature(
      id: 'troll',
      name: 'Troll',
      source: ContentSource.srd2024,
      kind: 'Gigante Grande, caótico malvado',
      type: CreatureType.giant,
      size: CreatureSize.large,
      ac: '15',
      hp: '94',
      abilityScores: const {Ability.strength: 18, Ability.dexterity: 13},
      savingThrows: const {Ability.wisdom: 3},
      skills: const {Skill.perception: 5},
      passivePerception: 15,
      legendaryActionsPerRound: 3,
      initiativeBonus: 4,
      cr: 5,
      actions: const [
        CreatureAction(name: 'Desgarrar', attackBonus: '7', damage: '2d6+4'),
        CreatureAction(name: 'Mordisco', kind: CreatureActionKind.bonus),
      ],
    );

    final copy = Creature.fromJson(original.toJson());

    expect(copy.type, CreatureType.giant);
    expect(copy.size, CreatureSize.large);
    expect(copy.savingThrows, {Ability.wisdom: 3});
    expect(copy.skills, {Skill.perception: 5});
    expect(copy.passivePerception, 15);
    expect(copy.legendaryActionsPerRound, 3);
    expect(copy.initiativeBonus, 4);
    expect(copy.actions[1].kind, CreatureActionKind.bonus);
  });

  test('una habilidad que no existe se ignora sin voltear la carga', () {
    // El catálogo entero se carga de una: una habilidad mal escrita no puede
    // costar las otras 116 criaturas.
    final c = Creature.fromJson({
      'id': 'x',
      'name': 'X',
      'source': 'srd_2024',
      'ac': '12',
      'hp': '10',
      'skills': {'perception': 5, 'inventada': 3},
    });
    expect(c.skills, {Skill.perception: 5});
  });

  test('las salvaciones y habilidades llegan al perfil resuelto', () {
    // La ficha pinta compañeros a través de `ResolvedCreature`: si los campos
    // se perdieran al resolver, un compañero con salvaciones no las mostraría.
    final resolved = Creature(
      id: 'x',
      name: 'X',
      source: ContentSource.srd2024,
      ac: '12',
      hp: '10',
      savingThrows: const {Ability.dexterity: 4},
      skills: const {Skill.stealth: 6},
      legendaryActionsPerRound: 3,
    ).resolve(const CreatureVars({}));

    expect(resolved.savingThrows, {Ability.dexterity: 4});
    expect(resolved.skills, {Skill.stealth: 6});
    expect(resolved.legendaryActionsPerRound, 3);
  });
}
