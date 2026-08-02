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
    // Son **tres** pactos, no cuatro: el Pacto del Talismán es de 2014 y no
    // está en el capítulo 3 del PHB 2024. El catálogo lo afirmaba y este test
    // lo daba por bueno.
    expect(d, contains('Pacto de la Cadena'));
    expect(d, contains('Pacto del Filo'));
    expect(d, contains('Pacto del Grimorio'));
    expect(d, isNot(contains('Talismán')));

    // Y los tres existen como opciones elegibles, no solo como texto.
    expect(
      repo.featsByCategory('warlock-invocation').map((f) => f.id),
      containsAll(<String>[
        'pact-of-the-chain',
        'pact-of-the-blade',
        'pact-of-the-tome',
      ]),
    );
  });

  test('Brujo: las invocaciones conocidas crecen según la tabla del PHB', () {
    // Columna "Invocaciones sobrenaturales" de la tabla "Rasgos de brujo".
    // El contenido declara el acumulado, así que solo hay rasgo en los niveles
    // en que el número sube.
    const esperado = {
      1: 1,
      2: 3,
      5: 5,
      7: 6,
      9: 7,
      12: 8,
      15: 9,
      18: 10,
    };

    final declarados = <int, int>{};
    for (final f in repo.characterClass('warlock')!.features) {
      for (final e in f.effects) {
        if (e is FeatureChoiceEffect && e.groupId == 'warlock-invocation') {
          declarados[f.level] = e.count;
        }
      }
    }
    expect(declarados, esperado);

    // Y se puede cambiar una al subir de nivel, que es la regla 2024.
    final compiler = CharacterCompiler(repo);
    Character brujo(int level) => Character(
          id: 'brujo',
          name: 'Prueba',
          raceId: 'human',
          classId: 'warlock',
          backgroundId: 'sage',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 12},
          hpPerLevel: List.filled(level, 8),
        );

    final slot = compiler.compile(brujo(1)).featureChoiceSlots.single;
    expect(slot.groupId, 'warlock-invocation');
    expect(slot.count, 1);
    expect(slot.replaceable, isTrue);

    // El acumulado gana: a nivel 6 sigue valiendo el 5 del nivel 5.
    expect(compiler.compile(brujo(6)).featureChoiceSlots.single.count, 5);
    expect(compiler.compile(brujo(20)).featureChoiceSlots.single.count, 10);
  });

  test('Paladín: Castigo de Paladín se lanza como acción adicional', () {
    // El rasgo de clase se llama Castigo de Paladín; Castigo Divino es el
    // conjuro que concede. El catálogo los confundía en un solo nombre.
    expect(levelOf('paladin', 'Castigo de Paladín'), 2);
    final d = repo
        .characterClass('paladin')!
        .features
        .firstWhere((f) => f.name == 'Castigo de Paladín')
        .effects
        .whereType<PassiveTraitEffect>()
        .single
        .description;
    expect(d, contains('acción adicional'));
  });

  test('Paladín: Canalizar Divinidad pasa de 2 a 3 usos en el nivel 11', () {
    final paladin = repo.characterClass('paladin')!;
    int maxAt(int level) => paladin.features
        .where((f) => f.level <= level)
        .expand((f) => f.effects)
        .whereType<ResourceEffect>()
        .where((r) => r.id == 'channel_divinity')
        .map((r) => r.max)
        .reduce((a, b) => a > b ? a : b);
    expect(maxAt(3), 2);
    expect(maxAt(10), 2);
    expect(maxAt(11), 3);
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
