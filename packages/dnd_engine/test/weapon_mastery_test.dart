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

  test('las distancias están en pies, como el resto del catálogo', () {
    // El texto viene del SRD en español, que mide en metros: la ficha mostraba
    // «a 1,5 m» al lado de alcances en pies.
    for (final m in weaponMasteries.values) {
      // Sin `\b`, que en Dart solo conoce letras ASCII.
      final metros = RegExp(r'\d+(,\d+)? m(?![\p{L}\p{N}_])', unicode: true);
      expect(m.description, isNot(matches(metros)), reason: m.id);
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

  test('toda propiedad y categoría del catálogo tiene su regla', () {
    // El formulario homebrew explica cada una al elegirla: una que faltara en
    // el glosario se ofrecería sin decir qué hace.
    for (final w in repo.weapons.values) {
      for (final p in w.properties) {
        expect(weaponProperties, contains(p),
            reason: '${w.id}: propiedad "$p"');
      }
      expect(weaponCategoryRules, contains(w.category), reason: w.id);
    }
  });

  test('una maestría desconocida cae en su identificador sin romper', () {
    // Puede venir de homebrew o de una importación, que son datos no confiables.
    expect(weaponMasteryName('inventada'), 'inventada');
  });

  group('Mellar (Nick) es la primera maestría con efecto mecánico', () {
    /// Pícaro con dos dagas: es competente con la daga y tiene espacios de
    /// maestría, así que puede aplicar Mellar. La daga es Ligera y su maestría
    /// es `nick`, que es justo el caso que cambia la economía de acciones.
    Character dualDaggers({List<String> masteries = const []}) => Character(
          id: 'probe-nick',
          name: 'Prueba',
          raceId: 'human',
          classId: 'rogue',
          backgroundId: 'soldier',
          level: 1,
          assignedScores: {
            Ability.strength: 10,
            Ability.dexterity: 16,
            Ability.constitution: 14,
            Ability.intelligence: 12,
            Ability.wisdom: 10,
            Ability.charisma: 10,
          },
          weaponMasteryChoices: masteries,
          hpPerLevel: const [8],
          equippedWeaponIds: const ['dagger', 'shortsword'],
          weaponOffHand: const {'dagger': true},
        );

    Attack daggerOf(Character c, ContentRepository repo) => CharacterCompiler(
          repo,
        ).compile(c).attacks.firstWhere((a) => a.weaponId == 'dagger');

    test('con Mellar elegida, el ataque entra en la acción de Atacar', () {
      final a = daggerOf(dualDaggers(masteries: const ['dagger']), repo);
      expect(a.mastery, 'nick');
      expect(a.action, AttackAction.action);
    });

    test('sin elegir Mellar, la misma daga sigue siendo acción adicional', () {
      // Prueba que Mellar no se aplica gratis por ser la maestría del arma:
      // hay que haberla elegido en un espacio de maestría.
      final a = daggerOf(dualDaggers(), repo);
      expect(a.mastery, isNull);
      expect(a.action, AttackAction.bonusAction);
    });

    test('Mellar no cambia el daño, solo la acción', () {
      final a = daggerOf(dualDaggers(masteries: const ['dagger']), repo);
      expect(a.damage, '1d4', reason: 'sigue sin sumar el modificador');
    });
  });
}
