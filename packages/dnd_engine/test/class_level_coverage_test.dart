import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Cobertura de niveles de los rasgos de clase.
///
/// El objetivo del catálogo es que el jugador vea el panorama completo al
/// elegir clase. Mago, Bardo, Hechicero y Brujo no tenían **ningún** rasgo por
/// encima del nivel 2, así que quien elegía una de ellas decidía a ciegas.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Iterable<ClassFeature> featuresOf(String id) =>
      repo.characterClass(id)!.features;

  int lastLevel(String id) =>
      featuresOf(id).map((f) => f.level).reduce((a, b) => a > b ? a : b);

  /// Clases ya completadas contra el SRD. Se van sumando por tanda; el resto
  /// queda en la lista de abajo para que el hueco siga siendo visible.
  const completas = [
    'wizard',
    'bard',
    'sorcerer',
    'warlock',
    'rogue',
    'ranger',
    'fighter'
  ];

  for (final id in completas) {
    test('$id llega al nivel 20', () {
      expect(lastLevel(id), 20);
    });
  }

  test('Paladín cierra en 19 porque su nivel 20 es rasgo de subclase', () {
    // No es un hueco: el SRD reserva el nivel 20 del Paladín al juramento.
    expect(lastLevel('paladin'), 19);
    expect(
      repo.subclass('oath-devotion')!.features.map((f) => f.level),
      contains(20),
    );
  });

  test('las clases completas cubren sus niveles de rasgo del SRD', () {
    Set<int> levels(String id) => featuresOf(id).map((f) => f.level).toSet();
    // Niveles con rasgo de clase (sin contar subclase ni mejora de
    // característica) según las tablas del SRD 5.2.1.
    expect(levels('wizard'), containsAll([1, 2, 5, 18, 19, 20]));
    expect(levels('bard'), containsAll([1, 2, 5, 7, 9, 10, 18, 19, 20]));
    expect(levels('sorcerer'), containsAll([1, 2, 5, 7, 10, 17, 19, 20]));
    expect(levels('warlock'), containsAll([1, 2, 9, 11, 13, 15, 17, 19, 20]));
    expect(levels('rogue'),
        containsAll([1, 2, 3, 5, 6, 7, 11, 14, 15, 18, 19, 20]));
    expect(levels('ranger'),
        containsAll([1, 2, 5, 6, 9, 10, 13, 14, 17, 18, 19, 20]));
    expect(
        levels('fighter'), containsAll([1, 2, 5, 9, 11, 13, 16, 17, 19, 20]));
  });

  test('el Guerrero acumula ataques hasta cuatro', () {
    // El motor toma el máximo de ExtraAttackEffect, así que cada nivel declara
    // el total y no el incremento.
    int extraAt(int level) => repo
        .characterClass('fighter')!
        .features
        .where((f) => f.level <= level)
        .expand((f) => f.effects)
        .whereType<ExtraAttackEffect>()
        .map((e) => e.extra)
        .fold(0, (a, b) => a > b ? a : b);
    expect(extraAt(4), 0);
    expect(extraAt(5), 1);
    expect(extraAt(11), 2);
    expect(extraAt(20), 3);
  });

  test('los nombres de nivel 2 son los del SRD, no traducciones propias', () {
    expect(featuresOf('wizard').map((f) => f.name), contains('Académico'));
    expect(
      featuresOf('bard').map((f) => f.name),
      contains('Aprendiz de Mucho'),
    );
    expect(
      featuresOf('sorcerer').map((f) => f.name),
      contains('Fuente de Magia'),
    );
  });

  test('las clases que todavía no se completaron siguen anotadas', () {
    // Este caso no protege un comportamiento: mide la deuda y falla cuando se
    // salda, para que haya que venir a actualizarlo en vez de olvidarlo.
    const pendientes = {
      'druid': 17,
      'cleric': 18,
      'monk': 18,
      'barbarian': 17,
    };
    for (final e in pendientes.entries) {
      expect(lastLevel(e.key), e.value,
          reason: '${e.key}: si ya se completó, moverlo a la lista de arriba');
    }
  });
}
