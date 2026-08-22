@TestOn('vm')
library;

import 'dart:mirrors';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// `copyWith` de la ficha compilada y de sus dos tipos satélite.
///
/// Existe por un bug real: `applyWildShape` reconstruía la `ComputedSheet`
/// campo por campo y se olvidaba de `skillBonuses` y `carriedWeight`, así que
/// un druida transformado perdía su bono de Orden Primordial y quedaba con la
/// mochila en cero. El compilador no avisa, porque son parámetros opcionales
/// con valor por defecto.
///
/// `dart:mirrors` se usa acá y nunca en `lib/`: el motor es Dart puro y estos
/// tests corren en la VM, así que la compilación a JS del cliente web no se
/// entera. Es lo único que puede atrapar el campo que **todavía no existe**.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Nombres de los campos de instancia de [tipo].
  Set<String> camposDe(Type tipo) => reflectClass(tipo)
      .declarations
      .values
      .whereType<VariableMirror>()
      .where((v) => !v.isStatic)
      .map((v) => MirrorSystem.getName(v.simpleName))
      .toSet();

  /// Nombres de los parámetros del `copyWith` de [tipo].
  Set<String> parametrosDeCopyWith(Type tipo) =>
      (reflectClass(tipo).declarations[#copyWith] as MethodMirror)
          .parameters
          .map((p) => MirrorSystem.getName(p.simpleName))
          .toSet();

  group('copyWith declara un parámetro por cada campo', () {
    /// Un campo sin su parámetro se pierde en silencio en cada capa que se
    /// aplica sobre la ficha ya calculada. Esta es la red que sobrevive a
    /// quien agregue un campo dentro de un año.
    void fijarCobertura(Type tipo) {
      final campos = camposDe(tipo);
      final params = parametrosDeCopyWith(tipo);
      expect(
        campos.difference(params),
        isEmpty,
        reason: 'A $tipo.copyWith le faltan parámetros. Un campo sin '
            'parámetro se pierde en silencio en applyWildShape y en '
            'applyExhaustion, y el compilador no avisa porque son opcionales.',
      );
      expect(
        params.difference(campos),
        isEmpty,
        reason: '$tipo.copyWith declara un parámetro que ya no es campo.',
      );
    }

    test('ComputedSheet', () => fijarCobertura(ComputedSheet));
    test('Attack', () => fijarCobertura(Attack));
    test('Spellcasting', () => fijarCobertura(Spellcasting));
  });

  group('copyWith sin argumentos conserva todo', () {
    /// Un clérigo Taumaturgo con monedas encima: trae `skillBonuses` (el
    /// "+SAB a Arcanos y Religión" de Orden Divina), `carriedWeight` (las
    /// monedas pesan) y `spellcasting`. Los tres campos que un sheet pelado
    /// dejaría vacíos, y entre ellos los dos que se perdían de verdad.
    ComputedSheet fichaRica() => CharacterCompiler(repo).compile(Character(
          id: 'copywith',
          name: 'Prueba',
          raceId: 'human',
          classId: 'cleric',
          backgroundId: 'hermit',
          level: 3,
          assignedScores: const {
            Ability.strength: 10,
            Ability.dexterity: 14,
            Ability.constitution: 14,
            Ability.intelligence: 12,
            Ability.wisdom: 16,
            Ability.charisma: 10,
          },
          hpPerLevel: const [8, 5, 5],
          featureChoices: const {
            'divine-order': ['divine-order-thaumaturge'],
          },
          inventory: const [
            InventoryEntry(entryId: 'maza', itemId: 'mace', equipped: true),
          ],
          coins: const {'gp': 250},
        ));

    test('la ficha de prueba no está vacía donde importa', () {
      // Sin esto el test de abajo pasaría por vacuidad: comparar dos campos
      // vacíos no prueba nada, y son justo los dos que se perdían.
      final s = fichaRica();
      expect(s.skillBonuses, isNotEmpty);
      expect(s.carriedWeight, greaterThan(0));
      expect(s.spellcasting, isNotNull);
      expect(s.attacks, isNotEmpty);
    });

    test('cada campo sale idéntico', () {
      final original = fichaRica();
      final copia = original.copyWith();

      final espejoOriginal = reflect(original);
      final espejoCopia = reflect(copia);

      for (final campo in camposDe(ComputedSheet)) {
        final simbolo = Symbol(campo);
        expect(
          espejoCopia.getField(simbolo).reflectee,
          same(espejoOriginal.getField(simbolo).reflectee),
          reason: 'copyWith() sin argumentos cambió "$campo". Lo más probable '
              'es que el parámetro esté mal cableado.',
        );
      }
    });
  });

  group('el centinela distingue "no pasé nada" de "pasé null"', () {
    ComputedSheet conVision() => CharacterCompiler(repo).compile(Character(
          id: 'centinela',
          name: 'Prueba',
          // El enano ve en la oscuridad; el humano no.
          raceId: 'dwarf',
          classId: 'fighter',
          backgroundId: 'soldier',
          level: 1,
          assignedScores: const {
            Ability.strength: 15,
            Ability.dexterity: 12,
            Ability.constitution: 14,
            Ability.intelligence: 10,
            Ability.wisdom: 12,
            Ability.charisma: 8,
          },
          hpPerLevel: const [10],
        ));

    test('sin argumento conserva la visión en la oscuridad', () {
      final s = conVision();
      expect(s.darkvision, isNotNull);
      expect(s.copyWith().darkvision, s.darkvision);
    });

    test('con null explícito la borra', () {
      // Es el caso de la Forma Salvaje: una bestia sin visión en la oscuridad
      // tiene que borrar la del druida, no heredarla.
      expect(conVision().copyWith(darkvision: null).darkvision, isNull);
    });
  });
}
