import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// `LeveledEffect` envuelve efectos que solo aplican a partir de un nivel.
///
/// Una dote se aplica entera y sin nivel, a diferencia de un rasgo de clase que
/// hereda el suyo de `featuresUpTo`. Cuando un catálogo de elecciones abiertas
/// tiene que crecer por tramos —la tabla del Círculo de la Tierra escalona
/// 3/5/7/9— la dote necesita declarar el nivel por su cuenta.
///
/// El mecanismo se prueba entero contra contenido inventado: si hiciera falta
/// contenido oficial para probarlo, no estaría dirigido por datos.
ContentRepository _repo({
  List<Map<String, dynamic>> classFeatures = const [],
  List<Map<String, dynamic>> feats = const [],
}) =>
    ContentRepository.fromJsonPacks(
      races: [
        {'id': 'r', 'name': 'Raza', 'source': 'homebrew'},
      ],
      classes: [
        {
          'id': 'c',
          'name': 'Clase',
          'source': 'homebrew',
          'hitDie': 8,
          'features': classFeatures,
        },
      ],
      backgrounds: [
        {
          'id': 'b',
          'name': 'Trasfondo',
          'source': 'homebrew',
          'skillProficiencies': ['stealth', 'perception'],
        },
      ],
      feats: feats,
    );

Character _char({
  int level = 1,
  List<String> featIds = const [],
  Map<String, List<String>> proficiencyChoices = const {},
}) =>
    Character(
      id: 'p',
      name: 'Prueba',
      raceId: 'r',
      classId: 'c',
      backgroundId: 'b',
      level: level,
      assignedScores: {for (final a in Ability.values) a: 14},
      hpPerLevel: List.filled(level, 5),
      featIds: featIds,
      proficiencyChoices: proficiencyChoices,
    );

/// Una dote cuyos efectos llegan por tramos, que es el caso que motivó el tipo.
Map<String, dynamic> _tieredFeat() => {
      'id': 'f',
      'name': 'Dote',
      'source': 'homebrew',
      'category': 'general',
      'effects': [
        {'type': 'resistance', 'damageType': 'fire'},
        {
          'type': 'leveled',
          'minLevel': 5,
          'effects': [
            {'type': 'resistance', 'damageType': 'cold'},
          ],
        },
        {
          'type': 'leveled',
          'minLevel': 10,
          'effects': [
            {'type': 'resistance', 'damageType': 'acid'},
          ],
        },
      ],
    };

void main() {
  group('Nivel', () {
    test('por debajo del mínimo no aporta nada', () {
      final repo = _repo(feats: [_tieredFeat()]);
      final sheet = CharacterCompiler(repo).compile(
        _char(level: 4, featIds: ['f']),
      );
      expect(sheet.resistances, {'fire'});
    });

    test('al alcanzarlo aplica, y los tramos se acumulan', () {
      final repo = _repo(feats: [_tieredFeat()]);
      final compiler = CharacterCompiler(repo);

      expect(
        compiler.compile(_char(level: 5, featIds: ['f'])).resistances,
        {'fire', 'cold'},
      );
      expect(
        compiler.compile(_char(level: 10, featIds: ['f'])).resistances,
        {'fire', 'cold', 'acid'},
      );
    });

    test('el nivel exacto entra, el anterior no', () {
      final repo = _repo(feats: [_tieredFeat()]);
      final compiler = CharacterCompiler(repo);
      expect(
        compiler.compile(_char(level: 9, featIds: ['f'])).resistances,
        isNot(contains('acid')),
      );
      expect(
        compiler.compile(_char(level: 10, featIds: ['f'])).resistances,
        contains('acid'),
      );
    });

    test('anidado: el tramo interno también respeta su mínimo', () {
      final repo = _repo(feats: [
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'category': 'general',
          'effects': [
            {
              'type': 'leveled',
              'minLevel': 3,
              'effects': [
                {'type': 'resistance', 'damageType': 'fire'},
                {
                  'type': 'leveled',
                  'minLevel': 7,
                  'effects': [
                    {'type': 'resistance', 'damageType': 'cold'},
                  ],
                },
              ],
            },
          ],
        }
      ]);
      final compiler = CharacterCompiler(repo);

      expect(compiler.compile(_char(level: 2, featIds: ['f'])).resistances,
          isEmpty);
      expect(compiler.compile(_char(level: 3, featIds: ['f'])).resistances,
          {'fire'});
      expect(compiler.compile(_char(level: 7, featIds: ['f'])).resistances,
          {'fire', 'cold'});
    });

    test('sirve igual dentro de un rasgo de clase', () {
      final repo = _repo(classFeatures: [
        {
          'level': 1,
          'name': 'Rasgo',
          'effects': [
            {
              'type': 'leveled',
              'minLevel': 4,
              'effects': [
                {'type': 'speedBonus', 'feet': 10},
              ],
            },
          ],
        },
      ]);
      final compiler = CharacterCompiler(repo);
      expect(compiler.compile(_char(level: 3)).speed, 30);
      expect(compiler.compile(_char(level: 4)).speed, 40);
    });
  });

  group('Visibilidad para las pasadas del compilador', () {
    // Ésta es la regresión de la decisión de diseño: el compilador expande el
    // envoltorio en `applySource`, antes de guardar los efectos de la fuente.
    // Si el desenvuelto viviera en `SheetBuilder`, la lista guardada
    // conservaría el `LeveledEffect` y estos cupos no existirían, en verde.
    // Todavía ningún contenido oficial declara esto; el test va igual.
    Map<String, dynamic> gatedProficiencyFeat() => {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'category': 'general',
          'effects': [
            {
              'type': 'leveled',
              'minLevel': 6,
              'effects': [
                {
                  'type': 'proficiencyChoice',
                  'groupId': 'g',
                  'name': 'Cupo tardío',
                  'count': 1,
                  'skills': ['arcana', 'history'],
                },
              ],
            },
          ],
        };

    test('un proficiencyChoice envuelto no produce cupo antes de tiempo', () {
      final repo = _repo(feats: [gatedProficiencyFeat()]);
      final sheet = CharacterCompiler(repo).compile(
        _char(level: 5, featIds: ['f']),
      );
      expect(sheet.proficiencyChoiceSlots, isEmpty);
    });

    test('y sí lo produce al llegar al nivel', () {
      final repo = _repo(feats: [gatedProficiencyFeat()]);
      final sheet = CharacterCompiler(repo).compile(
        _char(level: 6, featIds: ['f']),
      );
      final slot = sheet.proficiencyChoiceSlots.single;
      expect(slot.groupId, 'g');
      expect(slot.name, 'Cupo tardío');
      expect(slot.skills, ['arcana', 'history']);
    });

    test('lo elegido en un cupo envuelto se aplica', () {
      final repo = _repo(feats: [gatedProficiencyFeat()]);
      final sheet = CharacterCompiler(repo).compile(
        _char(level: 6, featIds: [
          'f'
        ], proficiencyChoices: {
          'g': ['arcana'],
        }),
      );
      expect(sheet.skillProficiencies, contains('arcana'));
    });
  });

  group('Serialización', () {
    test('round-trip preserva los efectos internos', () {
      const original = LeveledEffect(
        minLevel: 5,
        effects: [
          ResistanceEffect('fire'),
          LeveledEffect(
            minLevel: 9,
            effects: [ResistanceEffect('cold')],
          ),
        ],
      );

      final back = Effect.fromJson(original.toJson()) as LeveledEffect;
      expect(back.minLevel, 5);
      expect(back.effects, hasLength(2));
      expect((back.effects.first as ResistanceEffect).damageType, 'fire');

      final nested = back.effects.last as LeveledEffect;
      expect(nested.minLevel, 9);
      expect((nested.effects.single as ResistanceEffect).damageType, 'cold');
    });

    test('un tramo vacío es válido y no rompe', () {
      final back =
          Effect.fromJson({'type': 'leveled', 'minLevel': 3}) as LeveledEffect;
      expect(back.effects, isEmpty);
    });
  });

  group('SheetBuilder directo', () {
    // SheetBuilder es público y no pasa por `applySource`, así que lleva su
    // propia comprobación de nivel como red.
    test('respeta el nivel sin la expansión del compilador', () {
      final low = SheetBuilder(
        baseScores: {for (final a in Ability.values) a: 10},
        level: 2,
      )..applyEffect(const LeveledEffect(
          minLevel: 5,
          effects: [ResistanceEffect('fire')],
        ));
      expect(low.resistances, isEmpty);

      final high = SheetBuilder(
        baseScores: {for (final a in Ability.values) a: 10},
        level: 5,
      )..applyEffect(const LeveledEffect(
          minLevel: 5,
          effects: [ResistanceEffect('fire')],
        ));
      expect(high.resistances, {'fire'});
    });
  });
}
