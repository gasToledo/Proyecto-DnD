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
  const completas = ['wizard', 'bard', 'sorcerer', 'warlock'];

  for (final id in completas) {
    test('$id llega al nivel 20', () {
      expect(lastLevel(id), 20);
    });
  }

  test('las clases completas cubren sus niveles de rasgo del SRD', () {
    Set<int> levels(String id) => featuresOf(id).map((f) => f.level).toSet();
    // Niveles con rasgo de clase (sin contar subclase ni mejora de
    // característica) según las tablas del SRD 5.2.1.
    expect(levels('wizard'), containsAll([1, 2, 5, 18, 19, 20]));
    expect(levels('bard'), containsAll([1, 2, 5, 7, 9, 10, 18, 19, 20]));
    expect(levels('sorcerer'), containsAll([1, 2, 5, 7, 10, 17, 19, 20]));
    expect(levels('warlock'), containsAll([1, 2, 9, 11, 13, 15, 17, 19, 20]));
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
      'rogue': 7,
      'ranger': 5,
      'paladin': 11,
      'druid': 17,
      'fighter': 16,
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
