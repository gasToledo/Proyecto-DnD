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

  group('Bárbaro: Conocimiento Primigenio', () {
    /// Un Bárbaro de `level`, con las dos habilidades de nivel 1 ya elegidas
    /// para que el cupo del rasgo sea el único pendiente.
    Character barbaro(int level, {List<String> primal = const []}) => Character(
          id: 'furioso',
          name: 'Prueba',
          raceId: 'human',
          classId: 'barbarian',
          backgroundId: 'soldier',
          level: level,
          assignedScores: {for (final a in Ability.values) a: 14},
          hpPerLevel: List.filled(level, 7),
          chosenSkills: const ['athletics', 'survival'],
          proficiencyChoices: {
            if (primal.isNotEmpty) 'class:barbarian:primal-knowledge': primal,
          },
        );

    test('el rasgo declara la elección y no solo la promete', () {
      expect(levelOf('barbarian', 'Conocimiento Primigenio'), 3);
      final e = repo
          .characterClass('barbarian')!
          .features
          .firstWhere((f) => f.name == 'Conocimiento Primigenio')
          .effects
          .whereType<ProficiencyChoiceEffect>()
          .single;
      expect(e.count, 1);
      expect(e.expertise, isFalse);
      // Derivado del catálogo: la regla dice "de la lista del Bárbaro", así que
      // el pozo tiene que ser el mismo que el de nivel 1 y no una copia que se
      // desincronice cuando se corrija la lista.
      expect(e.skills, repo.characterClass('barbarian')!.skillChoiceFrom);
    });

    test('el cupo aparece a nivel 3 y no antes', () {
      final compiler = CharacterCompiler(repo);
      groupIds(int level) => compiler
          .compile(barbaro(level))
          .proficiencyChoiceSlots
          .map((s) => s.groupId);

      expect(groupIds(2), isNot(contains('class:barbarian:primal-knowledge')));
      expect(groupIds(3), contains('class:barbarian:primal-knowledge'));
    });

    test('lo elegido llega a las competencias de la ficha', () {
      final compiler = CharacterCompiler(repo);
      final sinElegir = compiler.compile(barbaro(3));
      expect(sinElegir.skillProficiencies, isNot(contains('nature')));
      final slot = sinElegir.proficiencyChoiceSlots
          .firstWhere((s) => s.groupId == 'class:barbarian:primal-knowledge');
      expect(slot.pending, 1);
      // El pozo son las seis de la clase, no las dieciocho.
      expect(slot.options, repo.characterClass('barbarian')!.skillChoiceFrom);

      final elegido = compiler.compile(barbaro(3, primal: ['nature']));
      expect(elegido.skillProficiencies, contains('nature'));
      expect(
        elegido.proficiencyChoiceSlots
            .firstWhere((s) => s.groupId == 'class:barbarian:primal-knowledge')
            .pending,
        0,
      );
    });

    test('la sustitución por Fuerza durante la Furia sigue siendo texto', () {
      // Es una sustitución de característica en tiempo de tirada: el motor no
      // la modela y no vale la pena un mecanismo para un solo rasgo. Lo que sí
      // importa es que el texto ya no prometa la competencia, que ahora la
      // concede el efecto de al lado.
      final d = repo
          .characterClass('barbarian')!
          .features
          .firstWhere((f) => f.name == 'Conocimiento Primigenio')
          .effects
          .whereType<PassiveTraitEffect>()
          .single
          .description;
      expect(d, contains('Fuerza'));
      expect(d, isNot(contains('competencia')));
    });
  });

  /// Descripción del rasgo pasivo `trait` dentro del rasgo de clase `feature`.
  String passiveIn(String classId, String feature, String trait) => repo
      .characterClass(classId)!
      .features
      .firstWhere((f) => f.name == feature)
      .effects
      .whereType<PassiveTraitEffect>()
      .firstWhere((t) => t.name == trait)
      .description;

  /// Las opciones en línea del rasgo `feature` de la clase `classId`.
  List<FeatureOption> optionsIn(String classId, String feature) => repo
      .characterClass(classId)!
      .features
      .firstWhere((f) => f.name == feature)
      .effects
      .whereType<FeatureChoiceEffect>()
      .single
      .options;

  test('Guerrero: Mente Táctica no gasta el uso si la prueba sigue fallando',
      () {
    final d = passiveIn('fighter', 'Mente Táctica', 'Mente Táctica');
    expect(d, contains('1d10'));
    expect(d, contains('Tomar Aliento'));
    // La mitad que faltaba: el reembolso.
    expect(d, contains('no se gasta'));
  });

  test('Bárbaro: el daño de Furia no exige que el ataque sea cuerpo a cuerpo',
      () {
    final d = passiveIn('barbarian', 'Furia', 'Daño por Furia');
    expect(d, contains('use la Fuerza'));
    expect(d, contains('sin armas'));
    // La regla 2024 no dice "cuerpo a cuerpo" y el catálogo sí lo decía.
    expect(
      repo
          .characterClass('barbarian')!
          .features
          .firstWhere((f) => f.name == 'Furia')
          .description,
      isNot(contains('daño cuerpo a cuerpo')),
    );
  });

  test('Druida: Compañero Salvaje admite espacio de conjuro o Forma Salvaje',
      () {
    final d = passiveIn('druid', 'Compañero Salvaje', 'Compañero Salvaje');
    expect(d, contains('acción de Magia'));
    expect(d, contains('espacio de conjuro'));
    expect(d, contains('Forma Salvaje'));
    expect(d, contains('sin componentes materiales'));
    expect(d, contains('Feérico'));
    expect(d, contains('descanso largo'));
  });

  test('Paladín: Castigo de Paladín trae el lanzamiento gratuito como recurso',
      () {
    final effects = repo
        .characterClass('paladin')!
        .features
        .firstWhere((f) => f.name == 'Castigo de Paladín')
        .effects;
    // Sigue siempre preparado…
    expect(
      effects.whereType<AlwaysPreparedSpellEffect>().map((e) => e.spellId),
      contains('divine-smite'),
    );
    // …y además hay un uso gratis por descanso largo, no solo texto.
    final gratis = effects
        .whereType<GrantSpellEffect>()
        .where((e) => e.spellId == 'divine-smite');
    expect(gratis, hasLength(1));
    expect(gratis.single.use, InnateSpellUse.oncePerLongRest);
  });

  test('Explorador: Explorador Hábil también concede dos idiomas', () {
    final effects = repo
        .characterClass('ranger')!
        .features
        .firstWhere((f) => f.name == 'Explorador Hábil')
        .effects;
    // La Pericia que ya estaba sigue estando.
    expect(
      effects.whereType<ProficiencyChoiceEffect>().where((e) => e.expertise),
      hasLength(1),
    );
    final idiomas = effects.whereType<LanguageChoiceEffect>();
    expect(idiomas, hasLength(1));
    expect(idiomas.single.count, 2);
  });

  group('Orden Primordial del Druida (nivel 1)', () {
    test('es una elección obligatoria entre Naturalista y Guardián', () {
      expect(levelOf('druid', 'Orden Primordial'), 1);
      final options = optionsIn('druid', 'Orden Primordial');
      expect(options.map((o) => o.id),
          ['primal-order-magician', 'primal-order-warden']);
      for (final o in options) {
        expect(o.source, ContentSource.srd2024, reason: o.id);
      }
    });

    test('Naturalista da un truco de Druida y el bono a Arcanos y Naturaleza',
        () {
      final magician = optionsIn('druid', 'Orden Primordial').first;
      final truco = magician.effects.whereType<SpellChoiceEffect>().single;
      expect(truco.count, 1);
      expect(truco.minLevel, 0);
      expect(truco.maxLevel, 0);
      expect(truco.fromClasses, ['druid']);

      final bonos = magician.effects.whereType<SkillBonusEffect>();
      expect(bonos.map((b) => b.skill).toSet(), {'arcana', 'nature'});
      for (final b in bonos) {
        expect(b.fromAbility, Ability.wisdom);
        expect(b.minimum, 1);
      }
    });

    test('Guardián da armas marciales y armadura media', () {
      final warden = optionsIn('druid', 'Orden Primordial').last;
      expect(
        warden.effects.whereType<WeaponProficiencyEffect>().single.category,
        'martial',
      );
      expect(
        warden.effects.whereType<ArmorProficiencyEffect>().single.category,
        'medium',
      );
    });
  });

  group('Orden Divina del Clérigo (nivel 1)', () {
    test('es una elección obligatoria entre Protector y Taumaturgo', () {
      expect(levelOf('cleric', 'Orden Divina'), 1);
      expect(optionsIn('cleric', 'Orden Divina').map((o) => o.id),
          ['divine-order-protector', 'divine-order-thaumaturge']);
    });

    test('Protector da armas marciales y armadura pesada', () {
      final protector = optionsIn('cleric', 'Orden Divina').first;
      expect(
        protector.effects.whereType<WeaponProficiencyEffect>().single.category,
        'martial',
      );
      expect(
        protector.effects.whereType<ArmorProficiencyEffect>().single.category,
        'heavy',
      );
    });

    test('Taumaturgo da un truco de Clérigo y el bono a Arcanos y Religión',
        () {
      final thaumaturge = optionsIn('cleric', 'Orden Divina').last;
      final truco = thaumaturge.effects.whereType<SpellChoiceEffect>().single;
      expect(truco.maxLevel, 0);
      expect(truco.fromClasses, ['cleric']);
      final bonos = thaumaturge.effects.whereType<SkillBonusEffect>();
      expect(bonos.map((b) => b.skill).toSet(), {'arcana', 'religion'});
      // Y no concede ninguna competencia de armas ni armadura.
      expect(thaumaturge.effects.whereType<WeaponProficiencyEffect>(), isEmpty);
      expect(thaumaturge.effects.whereType<ArmorProficiencyEffect>(), isEmpty);
    });
  });
}
