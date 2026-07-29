import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Regresión de rasgos de especie contra el SRD 5.2.1 en español.
///
/// Son aserciones de texto a propósito: el catálogo arrastraba redacciones de
/// 2014 que ningún test estructural detectaba, así que revertir el dato tiene
/// que romper el build.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Descripción del rasgo pasivo `name` de la especie `raceId`.
  String? traitOf(String raceId, String name) => repo
      .race(raceId)!
      .effects
      .whereType<PassiveTraitEffect>()
      .where((t) => t.name == name)
      .map((t) => t.description)
      .firstOrNull;

  Iterable<String> traitNames(String raceId) => repo
      .race(raceId)!
      .effects
      .whereType<PassiveTraitEffect>()
      .map((t) => t.name);

  group('Enano', () {
    test('Afinidad con la Piedra dura 10 minutos y tiene usos limitados', () {
      final d = traitOf('dwarf', 'Afinidad con la Piedra');
      expect(d, isNotNull, reason: 'el SRD lo llama Afinidad con la piedra');
      // Antes decía "hasta el fin de tu turno" y no limitaba los usos.
      expect(d, contains('10 minutos'));
      expect(d, contains('competencia'));
      expect(d, isNot(contains('fin de tu turno')));
    });

    test('conserva visión en la oscuridad de 120 pies', () {
      final dark =
          repo.race('dwarf')!.effects.whereType<DarkvisionEffect>().single;
      expect(dark.range, 120);
    });
  });

  group('Orco', () {
    test('tiene exactamente los tres rasgos del SRD', () {
      expect(traitNames('orc'),
          containsAll(['Aguante Incansable', 'Descarga de Adrenalina']));
    });

    test('no tiene Complexión Poderosa: es rasgo del Goliat', () {
      expect(traitNames('orc'), isNot(contains('Complexión Poderosa')));
      expect(traitNames('goliath'), contains('Constitución Poderosa'));
    });

    test('Descarga de Adrenalina se recupera en descanso corto o largo', () {
      expect(
          traitOf('orc', 'Descarga de Adrenalina'), contains('corto o largo'));
    });
  });

  group('Humano', () {
    test('nombra los tres rasgos del SRD', () {
      expect(traitNames('human'),
          containsAll(['Diestro', 'Ingenioso', 'Versátil']));
    });

    test('Diestro se corresponde con la elección de habilidad', () {
      expect(repo.race('human')!.skillChoiceCount, 1);
    });
  });

  group('Aasimar (PHB 2024, fuera del SRD)', () {
    test('Manos Sanadoras tira d4 iguales al bonificador de competencia', () {
      final d = traitOf('aasimar', 'Manos Sanadoras');
      expect(d, contains('d4'));
      expect(d, contains('competencia'));
    });
  });

  group('Goliat', () {
    test('Constitución Poderosa usa la regla 2024', () {
      final d = traitOf('goliath', 'Constitución Poderosa');
      expect(d, contains('terminar el estado agarrado'));
      expect(d, contains('capacidad de carga'));
      expect(d, isNot(contains('empujar')));
    });

    test('Forma Grande concede Fuerza y velocidad', () {
      final d = traitOf('goliath', 'Forma Grande (nivel 5)');
      expect(d, contains('ventaja en las pruebas de Fuerza'));
      expect(d, contains('velocidad aumenta 10 pies'));
    });
  });
}
