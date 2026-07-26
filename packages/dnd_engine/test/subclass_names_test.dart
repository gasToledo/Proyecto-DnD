import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Nomenclatura de subclases y rasgos verificada contra el capítulo 3.
///
/// El catálogo usaba traducciones propias donde el manual tiene nombre oficial.
/// Se adopta la palabra del PHB manteniendo la capitalización Title Case, que
/// es uniforme en las 48 subclases.
///
/// Solo se fijan las subclases cuya página pudo leerse en el PDF: faltan las
/// 64 y 65 (Colegio de la Danza y Colegio del Conocimiento), así que de esas
/// dos únicamente el nombre de la subclase está comprobado, no sus rasgos.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  String nameOf(String id) => repo.subclasses[id]!.name;

  Iterable<String> featuresOf(String id) =>
      repo.subclasses[id]!.features.map((f) => f.name);

  group('Bárbaro', () {
    test('las cuatro son "Senda de…", no "Camino de…"', () {
      expect(nameOf('berserker'), 'Senda del Berserker');
      expect(nameOf('wild-heart'), 'Senda del Corazón Salvaje');
      expect(nameOf('world-tree'), 'Senda del Árbol del Mundo');
      expect(nameOf('zealot'), 'Senda del Fanático');
    });

    test('rasgos con el nombre del manual', () {
      expect(featuresOf('world-tree'), contains('Raíces Apaleadoras'));
      expect(featuresOf('world-tree'), contains('Viajar por el Árbol'));
      expect(featuresOf('wild-heart'), contains('Hablante de la Naturaleza'));
      expect(featuresOf('zealot'), contains('Presencia Ferviente'));
      // El rasgo de nivel 3 del Corazón Salvaje es una elección doble.
      expect(featuresOf('wild-heart').first, startsWith('Portavoz de los '));
    });
  });

  group('Bardo', () {
    test('los cuatro colegios llevan el nombre del manual', () {
      expect(nameOf('college-lore'), 'Colegio del Conocimiento');
      expect(nameOf('college-dance'), 'Colegio de la Danza');
      expect(nameOf('college-glamour'), 'Colegio del Glamour');
      expect(nameOf('college-valor'), 'Colegio del Valor');
    });

    test('Valor y Glamour: rasgos verificados página por página', () {
      expect(featuresOf('college-valor'), contains('Inspiración en Combate'));
      expect(featuresOf('college-valor'), contains('Entrenamiento Marcial'));
      expect(featuresOf('college-valor'), contains('Magia de Batalla'));
      expect(featuresOf('college-glamour'), contains('Manto de Inspiración'));
      expect(featuresOf('college-glamour'), contains('Magia Cautivadora'));
      expect(
          featuresOf('college-glamour'), contains('Majestad Inquebrantable'));
    });
  });

  group('Brujo', () {
    test('los cuatro patrones llevan el nombre del manual', () {
      expect(nameOf('fiend-patron'), 'Patrón Infernal');
      expect(nameOf('great-old-one-patron'), 'Patrón Primigenio');
      expect(nameOf('archfey-patron'), 'Patrón Feérico');
      expect(nameOf('celestial-patron'), 'Patrón Celestial');
    });
  });
}
