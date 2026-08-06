import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Elección de tamaño de especie (PHB 2024).
///
/// Siete especies abarcan cuerpos de tamaños distintos y dejan elegir entre
/// Mediano y Pequeño. Las demás tienen un tamaño fijo y no preguntan nada.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character character(String raceId, {String? chosenSize}) => Character(
        id: 'x',
        name: 'Prueba',
        raceId: raceId,
        classId: 'fighter',
        backgroundId: 'soldier',
        chosenSize: chosenSize,
        assignedScores: {for (final a in Ability.values) a: 10},
      );

  group('catálogo', () {
    test('exactamente siete especies ofrecen la elección', () {
      final choosers = repo.races.values
          .where((r) => r.sizeOptions.isNotEmpty)
          .map((r) => r.id)
          .toList()
        ..sort();
      expect(choosers, [
        'aasimar',
        'changeling',
        'human',
        'khoravar',
        'shifter',
        'tiefling',
        'warforged',
      ]);
    });

    test('las siete ofrecen Mediano o Pequeño', () {
      for (final id in [
        'human',
        'tiefling',
        'aasimar',
        'changeling',
        'khoravar',
        'shifter',
        'warforged',
      ]) {
        expect(repo.race(id)!.sizeOptions, ['Mediano', 'Pequeño'], reason: id);
      }
    });

    test('el tamaño por defecto sigue siendo una de las opciones', () {
      // Si no lo fuera, no elegir dejaría al personaje con un tamaño que la
      // especie no ofrece.
      for (final race
          in repo.races.values.where((r) => r.sizeOptions.isNotEmpty)) {
        expect(race.sizeOptions, contains(race.size), reason: race.id);
      }
    });

    test('el resto del catálogo no pregunta nada', () {
      final fixed = repo.races.values.where((r) => r.sizeOptions.isEmpty);
      expect(fixed, isNotEmpty);
      for (final race in fixed) {
        expect(race.size, isNotEmpty, reason: race.id);
      }
    });
  });

  group('compilación', () {
    test('el tamaño elegido llega a la ficha', () {
      final sheet = CharacterCompiler(
        repo,
      ).compile(character('human', chosenSize: 'Pequeño'));
      expect(sheet.size, 'Pequeño');
    });

    test('sin elegir cae al tamaño por defecto de la especie', () {
      // Es lo que hace que una ficha guardada antes de esta elección siga
      // compilando igual, sin migración.
      final sheet = CharacterCompiler(repo).compile(character('human'));
      expect(sheet.size, 'Mediano');
    });

    test('una especie sin elección ignora el tamaño guardado', () {
      // El Goliat es Mediano y punto: un "Pequeño" que quedó de otra especie no
      // debe cambiarle el tamaño.
      final sheet = CharacterCompiler(
        repo,
      ).compile(character('goliath', chosenSize: 'Pequeño'));
      expect(sheet.size, repo.race('goliath')!.size);
    });

    test('un tamaño que la especie no ofrece cae al de la especie', () {
      final sheet = CharacterCompiler(
        repo,
      ).compile(character('human', chosenSize: 'Enorme'));
      expect(sheet.size, 'Mediano');
    });
  });

  group('validación', () {
    List<String> codes(Character c) =>
        CharacterValidator(repo).validate(c).map((w) => w.code).toList();

    test('avisa si la especie ofrece la elección y no se hizo', () {
      expect(codes(character('human')), contains('size_pending'));
    });

    test('no avisa cuando el tamaño está elegido', () {
      final warnings = codes(character('human', chosenSize: 'Pequeño'));
      expect(warnings, isNot(contains('size_pending')));
      expect(warnings, isNot(contains('size_invalid')));
    });

    test('avisa si el tamaño no es una de las opciones', () {
      expect(
        codes(character('human', chosenSize: 'Grande')),
        contains('size_invalid'),
      );
    });

    test('una especie de tamaño fijo no pide nada', () {
      expect(codes(character('goliath')), isNot(contains('size_pending')));
    });

    test('avisa si se guardó un tamaño en una especie que no elige', () {
      expect(
        codes(character('goliath', chosenSize: 'Pequeño')),
        contains('size_not_choosable'),
      );
    });
  });

  group('persistencia', () {
    test('el tamaño elegido sobrevive al round-trip', () {
      final c = character('tiefling', chosenSize: 'Pequeño');
      final restored = Character.fromJson(c.toJson());
      expect(restored.chosenSize, 'Pequeño');
    });

    test('una ficha vieja sin el campo se lee como sin elegir', () {
      final json = character('human', chosenSize: 'Pequeño').toJson()
        ..remove('chosenSize');
      expect(Character.fromJson(json).chosenSize, isNull);
    });

    test('copyWith lo conserva y lo puede limpiar', () {
      final c = character('human', chosenSize: 'Pequeño');
      expect(c.copyWith(level: 2).chosenSize, 'Pequeño');
      expect(c.copyWith(chosenSize: null).chosenSize, isNull);
      expect(c.copyWith(chosenSize: 'Mediano').chosenSize, 'Mediano');
    });
  });
}
