import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

Character _base() => Character(
      id: 'x',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: const [10],
    );

void main() {
  group('CharacterAlignment', () {
    test('round-trip por nombre y etiqueta en español', () {
      for (final a in CharacterAlignment.values) {
        expect(CharacterAlignment.fromJson(a.toJson()), a);
        expect(a.label, isNotEmpty);
      }
      expect(CharacterAlignment.trueNeutral.label, 'Neutral');
    });

    test('valor ausente o desconocido devuelve null', () {
      expect(CharacterAlignment.fromJson(null), isNull);
      expect(CharacterAlignment.fromJson('inexistente'), isNull);
    });
  });

  group('Character: alineamiento y rasgo', () {
    test('sobreviven al round-trip JSON', () {
      final c = _base().copyWith(
        alignment: CharacterAlignment.chaoticGood,
        personalityTrait: 'Nunca deja una deuda sin pagar.',
      );
      final back = Character.fromJson(c.toJson());
      expect(back.alignment, CharacterAlignment.chaoticGood);
      expect(back.personalityTrait, 'Nunca deja una deuda sin pagar.');
    });

    test('una ficha anterior al campo se lee sin romperse', () {
      final json = _base().toJson()
        ..remove('alignment')
        ..remove('personalityTrait');
      final back = Character.fromJson(json);
      expect(back.alignment, isNull);
      expect(back.personalityTrait, '');
    });

    test('copyWith conserva por defecto y limpia con null explícito', () {
      final c = _base().copyWith(alignment: CharacterAlignment.lawfulEvil);
      expect(c.copyWith(name: 'Otro').alignment, CharacterAlignment.lawfulEvil,
          reason: 'sin pasar alignment se conserva');
      expect(c.copyWith(alignment: null).alignment, isNull,
          reason: 'el centinela permite limpiarlo');
    });
  });
}
