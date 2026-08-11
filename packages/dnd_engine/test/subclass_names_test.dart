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

  group('Clérigo', () {
    test('rasgos legibles del manual (faltan las páginas 87 y 89)', () {
      expect(featuresOf('war-domain'), contains('Sacerdote Guerrero'));
      expect(featuresOf('life-domain'), contains('Sanación Suprema'));
      expect(featuresOf('light-domain'), contains('Fulgor Protector'));
    });
  });

  group('Druida', () {
    test('Tierra, Estrellas y Mar con los nombres del manual', () {
      expect(featuresOf('circle-land'), contains('Ayuda de la Tierra'));
      expect(
          featuresOf('circle-land'), contains('Protección de la Naturaleza'));
      expect(
          featuresOf('circle-stars'), contains('Constelaciones Centelleantes'));
      expect(featuresOf('circle-stars'), contains('Colmado de Luz Estelar'));
      expect(featuresOf('circle-sea'), contains('Ira de los Mares'));
      expect(featuresOf('circle-sea'), contains('Nacido de la Tempestad'));
      expect(featuresOf('circle-sea'), contains('Obsequio Oceánico'));
    });
  });

  group('Paladín', () {
    test('los cuatro juramentos, verificados completos', () {
      expect(nameOf('oath-devotion'), 'Juramento de Entrega');
      expect(nameOf('oath-ancients'), 'Juramento de los Antiguos');
      expect(nameOf('oath-glory'), 'Juramento de Gloria');
      expect(nameOf('oath-vengeance'), 'Juramento de Venganza');
    });

    test('rasgos con el nombre del manual', () {
      expect(featuresOf('oath-devotion'), contains('Aura de Entrega'));
      expect(featuresOf('oath-devotion'), contains('Castigo Protector'));
      expect(featuresOf('oath-devotion'), contains('Halo Sagrado'));
      expect(featuresOf('oath-ancients'), contains('Aura de Salvaguarda'));
      expect(featuresOf('oath-ancients'), contains('Campeón Ancestral'));
      expect(featuresOf('oath-glory'), contains('Aura de Celeridad'));
      expect(featuresOf('oath-vengeance'), contains('Espíritu Vengativo'));
    });
  });

  group('Monje', () {
    test('las cuatro subclases, verificadas completas', () {
      expect(featuresOf('open-hand'), contains('Plenitud de Cuerpo'));
      expect(featuresOf('open-hand'), contains('Palma Estremecedora'));
      expect(featuresOf('warrior-mercy'), contains('Toque de Galeno'));
      expect(featuresOf('warrior-mercy'),
          contains('Ráfaga de Curación y Aflicción'));
      expect(featuresOf('warrior-shadow'), contains('Artes Sombrías'));
      expect(featuresOf('warrior-shadow'), contains('Paso entre Sombras'));
      expect(featuresOf('warrior-shadow'), contains('Capa de Sombras'));
      expect(featuresOf('warrior-elements'),
          contains('Armonía con los Elementos'));
      expect(featuresOf('warrior-elements'), contains('Explosión Elemental'));
      expect(featuresOf('warrior-elements'), contains('Paradigma Elemental'));
    });
  });

  group('Brujo', () {
    test('rasgos legibles del manual (faltan las páginas 76 y 79)', () {
      expect(featuresOf('celestial-patron'), contains('Venganza Ardiente'));
      expect(featuresOf('archfey-patron'), contains('Defensas Seductoras'));
      expect(featuresOf('fiend-patron'), contains('La Suerte del Oscuro'));
      expect(featuresOf('fiend-patron'), contains('Resistencia Infernal'));
      expect(featuresOf('fiend-patron'), contains('Arrastrar por el Infierno'));
    });
  });

  group('Hechicero', () {
    test('rasgos con el nombre del manual', () {
      expect(featuresOf('aberrant-sorcery'), contains('Revelación en Carne'));
      expect(featuresOf('aberrant-sorcery'), contains('Implosión Deformadora'));
      expect(featuresOf('wild-magic-sorcery'), contains('Doblegar la Suerte'));
      expect(featuresOf('wild-magic-sorcery'), contains('Sobrecarga Domada'));
      expect(featuresOf('clockwork-sorcery'), contains('Bastión de la Ley'));
      expect(featuresOf('clockwork-sorcery'), contains('Trance de Orden'));
      expect(featuresOf('clockwork-sorcery'), contains('Cabalgata Mecánica'));
    });

    test('Hechicería Dracónica cambió el rasgo de 2014 del nivel 18', () {
      // En 2024 el nivel 18 es Compañero Dragón, no la Presencia Dracónica de
      // 2014. Era un cambio de rasgo, no de nombre, y quedó pendiente hasta
      // tener el texto del manual; ya está reescrito.
      expect(featuresOf('draconic-sorcery'), contains('Compañero Dragón'));
      expect(
        featuresOf('draconic-sorcery'),
        isNot(contains('Presencia Dracónica')),
      );
      // Afinidad Dracónica tampoco pertenece a la versión XPHB del nivel 3.
      expect(
        featuresOf('draconic-sorcery'),
        isNot(contains('Afinidad Dracónica')),
      );
    });
  });

  group('Nombres tomados del índice del manual', () {
    test('Pícaro: se nombran por el arquetipo, no por la clase', () {
      expect(nameOf('arcane-trickster'), 'Embaucador Arcano');
      expect(nameOf('soulknife'), 'Rebanaalmas');
      expect(nameOf('thief'), 'Ladrón');
      expect(nameOf('assassin'), 'Asesino');
    });

    test('Explorador, Guerrero, Hechicero y Mago', () {
      expect(nameOf('beast-master'), 'Señor de las Bestias');
      expect(nameOf('gloom-stalker'), 'Acechador en la Penumbra');
      expect(nameOf('battle-master'), 'Maestro del Combate');
      expect(nameOf('aberrant-sorcery'), 'Hechicería Aberrante');
      expect(nameOf('clockwork-sorcery'), 'Hechicería Mecánica');
      // Las escuelas de Mago se nombran por el practicante, no por la escuela.
      expect(nameOf('evoker'), 'Evocador');
      expect(nameOf('abjurer'), 'Abjurador');
      expect(nameOf('diviner'), 'Adivino');
      expect(nameOf('illusionist'), 'Ilusionista');
    });
  });
}
