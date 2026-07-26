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
}
