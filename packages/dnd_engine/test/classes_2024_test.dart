import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Regresión de rasgos de clase contra el SRD 5.2.1 en español.
///
/// El catálogo tenía rasgos con la redacción de 2014 y varios en el nivel
/// equivocado. Estas aserciones fijan el nivel y el nombre normativos.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Nivel en el que la clase `classId` concede el rasgo `name`, o null.
  int? levelOf(String classId, String name) => repo
      .characterClass(classId)!
      .features
      .where((f) => f.name == name)
      .map((f) => f.level)
      .firstOrNull;

  Iterable<String> featureNames(String classId) =>
      repo.characterClass(classId)!.features.map((f) => f.name);

  test('Bardo: Pericia se obtiene a nivel 2, no a nivel 3', () {
    expect(levelOf('bard', 'Pericia'), 2);
  });

  test('Pícaro: Talentos Fiables se obtiene a nivel 7, no a nivel 8', () {
    expect(levelOf('rogue', 'Talentos Fiables'), 7);
    expect(featureNames('rogue'), isNot(contains('Talento Fiable')));
  });

  test('Mago: Adepto en Rituales es un rasgo de nivel 1', () {
    expect(levelOf('wizard', 'Adepto en Rituales'), 1);
    // La entrada de nivel 3 tenía nombre de Recuperación Arcana y texto de
    // rituales: dos rasgos distintos mezclados en uno.
    expect(featureNames('wizard'),
        isNot(contains('Recuperación Arcana (mejora)')));
  });

  test('Clérigo: Abrasar Muertos Vivientes reemplaza a Destruir', () {
    expect(levelOf('cleric', 'Abrasar Muertos Vivientes'), 5);
    expect(
        featureNames('cleric'), isNot(contains('Destruir Muertos Vivientes')));
    final d = repo
        .characterClass('cleric')!
        .features
        .firstWhere((f) => f.name == 'Abrasar Muertos Vivientes')
        .description;
    // 2024 tira daño radiante en vez de destruir según nivel de desafío.
    expect(d, contains('radiante'));
  });

  test('Brujo: Dádiva de Pacto ya no es un rasgo de clase', () {
    // En 2024 los pactos son Invocaciones Sobrenaturales.
    expect(featureNames('warlock'), isNot(contains('Dádiva de Pacto')));
    expect(levelOf('warlock', 'Invocaciones Sobrenaturales'), 1);
    final d = repo
        .characterClass('warlock')!
        .features
        .firstWhere((f) => f.name == 'Invocaciones Sobrenaturales')
        .effects
        .whereType<PassiveTraitEffect>()
        .single
        .description;
    expect(d, contains('Talismán'), reason: 'en 2024 son cuatro pactos');
  });

  test('Paladín: Castigo Divino se lanza como acción adicional', () {
    final d = repo
        .characterClass('paladin')!
        .features
        .firstWhere((f) => f.name == 'Castigo Divino')
        .effects
        .whereType<PassiveTraitEffect>()
        .single
        .description;
    expect(d, contains('acción adicional'));
  });

  test('Bárbaro: Conocimiento Primigenio da competencia y pruebas de Fuerza',
      () {
    expect(levelOf('barbarian', 'Conocimiento Primigenio'), 3);
    final d = repo
        .characterClass('barbarian')!
        .features
        .firstWhere((f) => f.name == 'Conocimiento Primigenio')
        .effects
        .whereType<PassiveTraitEffect>()
        .single
        .description;
    expect(d, contains('competencia'));
    expect(d, contains('Fuerza'));
  });
}
