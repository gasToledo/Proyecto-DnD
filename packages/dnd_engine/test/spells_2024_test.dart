import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Conjuros que 2024 reescribió y el catálogo seguía teniendo en su forma 2014.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Spell spell(String id) => repo.spells[id]!;

  test('Toque Helado pasa a ser un ataque cuerpo a cuerpo', () {
    final s = spell('chill-touch');
    expect(s.name, 'Toque Helado', reason: 'en 2024 deja de ser "Gélido"');
    expect(s.range, 'Toque', reason: 'ya no son 120 pies a distancia');
    expect(s.description, contains('cuerpo a cuerpo'));
    expect(s.description, contains('necrótico'));
    // El truco escala con el nivel de personaje, no con espacios.
    expect(s.level, 0);
    expect(s.description, contains('4d10'));
  });

  test('Marca del Cazador inflige daño de fuerza y conserva el rastreo', () {
    final s = spell('hunters-mark');
    expect(s.description, contains('fuerza'),
        reason: '2024 fija el tipo de daño del 1d6 extra');
    // La ventaja para buscar a la presa sigue en el conjuro: no se quitó.
    expect(s.description, contains('Supervivencia'));
    expect(s.school, 'Adivinación');
    expect(s.castingTime, 'Acción Adicional');
    expect(s.concentration, isTrue);
  });

  test('Conjurar Animales deja de invocar criaturas y pasa a daño de área', () {
    final s = spell('conjure-animals');
    expect(s.name, 'Conjurar Animales');
    expect(s.duration, '10 minutos', reason: 'en 2014 duraba 1 hora');
    expect(s.concentration, isTrue);
    expect(s.description, contains('3d10'));
    expect(s.description, contains('salvación de Destreza'));
    // Ya no hay criaturas aliadas con bloque de estadísticas.
    expect(s.description, isNot(contains('combaten a tu lado')));
  });

  group('nomenclatura del PHB 2024', () {
    // 31 conjuros llevaban un nombre en español que no es el del manual. Se
    // verificaron por dos vías independientes: la firma de metadatos (nivel,
    // componentes, duración, alcance y clases) contra el capítulo 7, y el id,
    // que es el nombre en inglés. Los ids no cambian: son la referencia que
    // usan los linajes y los personajes guardados.
    const oficiales = {
      'druidcraft': 'Saber Druídico',
      'vicious-mockery': 'Burla Dañina',
      'shocking-grasp': 'Agarre Electrizante',
      'spare-the-dying': 'Piedad con los Moribundos',
      'produce-flame': 'Crear Llama',
      'fire-bolt': 'Descarga de Fuego',
      'charm-person': 'Hechizar Persona',
      'thunderwave': 'Ola Atronadora',
      'guiding-bolt': 'Saeta Guía',
      'see-invisibility': 'Ver Invisibilidad',
      'animate-dead': 'Animar a los Muertos',
      'tongues': 'Don de Lenguas',
      'raise-dead': 'Alzar a los Muertos',
      'heal': 'Curar',
      'plane-shift': 'Desplazamiento entre Planos',
      'mass-heal': 'Curar en Masa',
    };

    oficiales.forEach((id, nombre) {
      test('$id se llama $nombre', () => expect(spell(id).name, nombre));
    });

    test('Geas dejó de llamarse Mandato', () {
      // Es el caso que más confundía: "Mandato" es el nombre de otro conjuro
      // (Command, de nivel 1), no de este.
      expect(spell('geas').name, 'Geas');
      expect(spell('geas').level, 5);
    });

    test('la escuela de ilusión se llama Ilusionismo', () {
      final escuelas = repo.spells.values.map((s) => s.school).toSet();
      expect(escuelas, contains('Ilusionismo'));
      expect(escuelas, isNot(contains('Ilusión')));
    });
  });
}
