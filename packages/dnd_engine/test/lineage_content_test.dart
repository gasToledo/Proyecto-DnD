import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// L3, Tier A: verifica el contenido real de los linajes de Elfo, Gnomo y
/// Tiefling contra el pack, para que un id mal escrito no pase silencioso.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character _pj(String raceId, String lineageId, {int level = 5}) => Character(
        id: 'x',
        name: 'P',
        raceId: raceId,
        classId: 'fighter',
        backgroundId: 'soldier',
        lineageId: lineageId,
        speciesSpellcastingAbility: Ability.wisdom,
        level: level,
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: List.filled(level, 10),
      );

  test('cada especie con linaje ofrece exactamente sus opciones', () {
    expect(repo.lineagesForRace('elf').map((l) => l.id).toSet(),
        {'elf-high', 'elf-drow', 'elf-wood'});
    expect(repo.lineagesForRace('gnome').map((l) => l.id).toSet(),
        {'gnome-forest', 'gnome-rock'});
    expect(repo.lineagesForRace('tiefling').length, 3);
    // Linaje gigante del Goliat y Linaje dracónico del Dracónido: el PHB los
    // llama linajes igual que a los del Elfo, y son 6 gigantes y 10 dragones.
    expect(repo.lineagesForRace('goliath').length, 6);
    expect(repo.lineagesForRace('dragonborn').length, 10);
    // Las especies sin linaje no ofrecen ninguno.
    expect(repo.lineagesForRace('human'), isEmpty);
    expect(repo.lineagesForRace('dwarf'), isEmpty);
  });

  test('el Linaje gigante da un recurso con usos = bonif. por competencia', () {
    for (final lineage in repo.lineagesForRace('goliath')) {
      final sheet = CharacterCompiler(repo).compile(_pj('goliath', lineage.id));
      final recurso = sheet.resources.singleWhere(
        (r) => r.id == 'giant_ancestry',
        orElse: () => throw StateError('${lineage.id} no da el recurso'),
      );
      // Nivel 5 → bonificador 3.
      expect(recurso.max, 3, reason: lineage.id);
      expect(recurso.recharge, RechargeOn.longRest, reason: lineage.id);
    }

    // Y escala con el bonificador, no con el nivel.
    final nivel1 = CharacterCompiler(repo)
        .compile(_pj('goliath', 'goliath-stone', level: 1));
    expect(
      nivel1.resources.firstWhere((r) => r.id == 'giant_ancestry').max,
      2,
    );
    final nivel17 = CharacterCompiler(repo)
        .compile(_pj('goliath', 'goliath-stone', level: 17));
    expect(
      nivel17.resources.firstWhere((r) => r.id == 'giant_ancestry').max,
      6,
    );
  });

  test('el Linaje dracónico fija la resistencia y el Ataque de Aliento', () {
    const porDragon = {
      'dragonborn-black': 'acid',
      'dragonborn-copper': 'acid',
      'dragonborn-blue': 'lightning',
      'dragonborn-bronze': 'lightning',
      'dragonborn-white': 'cold',
      'dragonborn-silver': 'cold',
      'dragonborn-green': 'poison',
      'dragonborn-red': 'fire',
      'dragonborn-gold': 'fire',
      'dragonborn-brass': 'fire',
    };
    expect(
      repo.lineagesForRace('dragonborn').map((l) => l.id).toSet(),
      porDragon.keys.toSet(),
    );

    for (final entry in porDragon.entries) {
      final sheet =
          CharacterCompiler(repo).compile(_pj('dragonborn', entry.key));
      // Antes la resistencia era solo texto: ahora se aplica de verdad.
      expect(sheet.resistances, contains(entry.value), reason: entry.key);
      expect(
        sheet.resources.firstWhere((r) => r.id == 'breath_weapon').max,
        3,
        reason: entry.key,
      );
    }
  });

  test('sin elegir linaje, el Goliat recibe un aviso y no se rompe', () {
    final sinLinaje = Character(
      id: 'x',
      name: 'P',
      raceId: 'goliath',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: 5,
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: List.filled(5, 10),
    );
    final sheet = CharacterCompiler(repo).compile(sinLinaje);
    expect(sheet.resources.where((r) => r.id == 'giant_ancestry'), isEmpty);

    // Es una advertencia, no un bloqueo: un personaje guardado antes de que
    // existieran estos linajes tiene que seguir abriéndose.
    final avisos = CharacterValidator(repo).validate(sinLinaje);
    expect(avisos.map((w) => w.code), contains('lineage_pending'));
  });

  test('todo conjuro que concede un linaje existe en el pack', () {
    final missing = <String>[];
    for (final l in repo.lineages.values) {
      for (final f in l.features) {
        for (final e in f.effects) {
          if (e is GrantSpellEffect && repo.spell(e.spellId) == null) {
            missing.add('${l.id} → ${e.spellId}');
          }
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'linajes que conceden conjuros inexistentes: $missing');
  });

  test('cada linaje pertenece a una especie que existe', () {
    for (final l in repo.lineages.values) {
      expect(repo.race(l.raceId), isNotNull,
          reason: '${l.id} apunta a la especie inexistente ${l.raceId}');
    }
  });

  test('los tres legados del Tiefling dan resistencia y truco a nivel 1', () {
    final cases = {
      'tiefling-infernal': ('fire', 'fire-bolt'),
      'tiefling-abyssal': ('poison', 'poison-spray'),
      'tiefling-chthonic': ('necrotic', 'chill-touch'),
    };
    cases.forEach((lineageId, expected) {
      final s =
          CharacterCompiler(repo).compile(_pj('tiefling', lineageId, level: 1));
      expect(s.resistances, contains(expected.$1), reason: lineageId);
      // El truco del legado + la Taumaturgia base del Tiefling.
      final ids = s.innateSpells.map((x) => x.spellId);
      expect(ids, contains(expected.$2), reason: lineageId);
      expect(ids, contains('thaumaturgy'),
          reason: 'la Taumaturgia del Tiefling base ahora es real');
    });
  });

  test('el Drow tiene visión superior; el Elfo del Bosque, magia y velocidad',
      () {
    final drow =
        CharacterCompiler(repo).compile(_pj('elf', 'elf-drow', level: 1));
    expect(drow.darkvision, 120);
    final wood =
        CharacterCompiler(repo).compile(_pj('elf', 'elf-wood', level: 1));
    expect(wood.speed, 35);
    expect(wood.innateSpells.map((spell) => spell.spellId),
        contains('druidcraft'));
  });

  test('Hablar con los Animales tiene usos iguales a competencia', () {
    final forest =
        CharacterCompiler(repo).compile(_pj('gnome', 'gnome-forest', level: 5));
    final resource = forest.resources
        .firstWhere((entry) => entry.id == 'innate-speak-with-animals');
    expect(resource.max, 3);
  });

  test('el dispositivo del Gnomo de las Rocas sigue la regla 2024', () {
    final trait = repo
        .lineage('gnome-rock')!
        .features
        .expand((f) => f.effects)
        .whereType<PassiveTraitEffect>()
        .singleWhere((e) => e.name == 'Dispositivo Mecánico')
        .description;
    expect(trait, contains('10 minutos'));
    expect(trait, contains('hasta tres'));
    expect(trait, contains('8 horas'));
    expect(trait, isNot(contains('10 po')));
  });

  test('los conjuros de nivel 3 y 5 aparecen al subir, con su recurso', () {
    final low = CharacterCompiler(repo)
        .compile(_pj('tiefling', 'tiefling-infernal', level: 1));
    expect(low.innateSpells.map((s) => s.spellId),
        isNot(contains('hellish-rebuke')));

    final high = CharacterCompiler(repo)
        .compile(_pj('tiefling', 'tiefling-infernal', level: 5));
    final ids = high.innateSpells.map((s) => s.spellId);
    expect(ids, containsAll(['fire-bolt', 'hellish-rebuke', 'darkness']));
    // Los dos conjuros con nivel traen su uso gratuito por descanso largo.
    expect(high.resources.where((r) => r.id.startsWith('innate-')).length, 2);
  });
}
