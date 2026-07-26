import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El glosario de maestrías del PHB 2024, y su acuerdo con el catálogo.
///
/// Antes `mastery` era un identificador suelto sin descripción en ningún lado,
/// así que la ficha mostraba "Nick" o "Vex" en inglés.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('están las ocho propiedades del capítulo 6', () {
    expect(weaponMasteries.keys.toSet(), {
      'cleave',
      'graze',
      'nick',
      'push',
      'sap',
      'slow',
      'topple',
      'vex',
    });
  });

  test('cada entrada tiene nombre en español y regla', () {
    for (final m in weaponMasteries.values) {
      expect(m.name, isNotEmpty, reason: m.id);
      expect(m.name, isNot(equalsIgnoringCase(m.id)),
          reason: '${m.id}: el nombre no puede ser el identificador en inglés');
      expect(m.description.length, greaterThan(40), reason: m.id);
    }
  });

  test('los nombres son los oficiales del PHB, no una traducción propia', () {
    // El manual usa Debilitar, Hender, Molestar, Ralentizar y Rozar, que no son
    // las traducciones literales que uno supondría de sap/cleave/vex/slow/graze.
    expect(weaponMasteryName('sap'), 'Debilitar');
    expect(weaponMasteryName('cleave'), 'Hender');
    expect(weaponMasteryName('vex'), 'Molestar');
    expect(weaponMasteryName('slow'), 'Ralentizar');
    expect(weaponMasteryName('graze'), 'Rozar');
    expect(weaponMasteryName('nick'), 'Mellar');
    expect(weaponMasteryName('push'), 'Empujar');
    expect(weaponMasteryName('topple'), 'Derribar');
  });

  test('ningún arma del catálogo usa una maestría fuera del glosario', () {
    for (final w in repo.weapons.values) {
      final m = w.mastery;
      if (m == null) continue;
      expect(weaponMasteries, contains(m),
          reason: '${w.id}: maestría desconocida "$m"');
    }
  });

  test('una maestría desconocida cae en su identificador sin romper', () {
    // Puede venir de homebrew o de una importación, que son datos no confiables.
    expect(weaponMasteryName('inventada'), 'inventada');
  });
}
