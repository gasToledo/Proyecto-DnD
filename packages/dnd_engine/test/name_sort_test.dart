import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('compareContentNames', () {
    List<String> ordered(List<String> names) =>
        names.toList()..sort(compareContentNames);

    test('la tilde no manda: la vocal acentuada vale por su vocal base', () {
      // Con `String.compareTo` "Bárbaro" cae detrás de "Brujo", porque á está
      // fuera del rango ASCII. Es el caso que rompía la lista de clases.
      expect(
        ordered(['Bardo', 'Brujo', 'Bárbaro', 'Clérigo']),
        ['Bárbaro', 'Bardo', 'Brujo', 'Clérigo'],
      );
    });

    test('una tilde interior no expulsa la palabra al final de la lista', () {
      // "Látigo" quedaba después de "Lucero del alba" por el mismo motivo.
      expect(
        ordered(['Lanza', 'Lucero del alba', 'Látigo', 'Mandoble']),
        ['Lanza', 'Látigo', 'Lucero del alba', 'Mandoble'],
      );
    });

    test('no distingue mayúsculas de minúsculas', () {
      expect(ordered(['banshee', ' Archivo', 'Cíclope']).first, ' Archivo');
      expect(ordered(['zorro', 'Alfa']), ['Alfa', 'zorro']);
    });

    test('la Ñ es letra propia y va detrás de la N, no en su lugar', () {
      expect(
        ordered(['anzuelo', 'añejo', 'ao', 'ancla']),
        ['ancla', 'anzuelo', 'añejo', 'ao'],
      );
    });

    test('dos nombres que solo difieren en la tilde no comparan iguales', () {
      // Si empataran, el orden dependería del orden de entrada y la lista
      // podría bailar entre recargas.
      expect(compareContentNames('Publico', 'Público'), isNot(0));
      expect(ordered(['Público', 'Publico']), ordered(['Publico', 'Público']));
    });

    test('ordena igual sin importar el orden de entrada', () {
      const nombres = ['Látigo', 'Lanza', 'Bárbaro', 'añejo', 'Bardo', 'Ancla'];
      final unaVuelta = ordered(nombres);
      final otraVuelta = ordered(nombres.reversed.toList());
      expect(unaVuelta, otraVuelta);
    });
  });

  group('Catálogos ordenados del repositorio', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    void expectAlfabetico(String etiqueta, List<String> nombres) {
      final esperado = nombres.toList()..sort(compareContentNames);
      expect(nombres, esperado, reason: etiqueta);
    }

    test('especies, clases, trasfondos, dotes, armas y armaduras', () {
      expectAlfabetico(
          'especies', repo.racesSorted.map((e) => e.name).toList());
      expectAlfabetico(
          'clases', repo.classesSorted.map((e) => e.name).toList());
      expectAlfabetico(
          'trasfondos', repo.backgroundsSorted.map((e) => e.name).toList());
      expectAlfabetico('dotes', repo.featsSorted.map((e) => e.name).toList());
      expectAlfabetico('armas', repo.weaponsSorted.map((e) => e.name).toList());
      expectAlfabetico(
          'armaduras', repo.armorSorted.map((e) => e.name).toList());
    });

    test('los catálogos ordenados no pierden ni agregan entradas', () {
      expect(repo.racesSorted, hasLength(repo.races.length));
      expect(repo.classesSorted, hasLength(repo.classes.length));
      expect(repo.backgroundsSorted, hasLength(repo.backgrounds.length));
      expect(repo.featsSorted, hasLength(repo.feats.length));
      expect(repo.weaponsSorted, hasLength(repo.weapons.length));
      expect(repo.armorSorted, hasLength(repo.armor.length));
      expect(repo.spellsSorted, hasLength(repo.spells.length));
    });

    test('el Bárbaro encabeza las clases con B', () {
      // Regresión concreta del reporte: en la lista real, no solo en un fixture.
      final conB =
          repo.classesSorted.map((e) => e.name).where((n) => n.startsWith('B'));
      expect(conB.first, 'Bárbaro');
    });

    test('los conjuros ordenan por nivel y después por nombre', () {
      final wizard = repo.spellsForList('wizard');
      for (var i = 1; i < wizard.length; i++) {
        final prev = wizard[i - 1];
        final cur = wizard[i];
        expect(prev.level <= cur.level, isTrue,
            reason: '${prev.name} antes que ${cur.name}');
        if (prev.level == cur.level) {
          expect(compareContentNames(prev.name, cur.name), lessThan(0),
              reason: '${prev.name} antes que ${cur.name}');
        }
      }
    });

    test('subclases y linajes también salen alfabéticos', () {
      expectAlfabetico('subclases de mago',
          repo.subclassesForClass('wizard').map((e) => e.name).toList());
      expectAlfabetico('linajes de elfo',
          repo.lineagesForRace('elf').map((e) => e.name).toList());
    });
  });
}
