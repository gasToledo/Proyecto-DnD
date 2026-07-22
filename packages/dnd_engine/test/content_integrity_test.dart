import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Chequeos de integridad sobre el contenido real del SRD 2024. Atrapa datos
/// mal referenciados (una dote inexistente, una maestría inválida) apenas se
/// cargan, sin necesidad de recorrer la app.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  // Las 8 propiedades de Maestría de Armas del PHB 2024.
  const validMasteries = {
    'cleave', 'graze', 'nick', 'push', 'sap', 'slow', 'topple', 'vex',
  };
  const validWeaponCategories = {'simple', 'martial'};
  const validArmorCategories = {'light', 'medium', 'heavy', 'shield'};

  const casterClasses = {
    'wizard', 'sorcerer', 'bard', 'warlock', 'cleric', 'druid', 'paladin', 'ranger',
  };

  test('el catálogo se cargó con volumen razonable', () {
    expect(repo.weapons.length, greaterThanOrEqualTo(30));
    expect(repo.armor.length, greaterThanOrEqualTo(12));
    expect(repo.races.length, greaterThanOrEqualTo(10));
    expect(repo.backgrounds.length, greaterThanOrEqualTo(12));
    expect(repo.spells.length, greaterThanOrEqualTo(150));
    expect(repo.feats.length, greaterThanOrEqualTo(50));
  });

  test('los conjuros cubren los niveles 0 a 9', () {
    final levels = repo.spells.values.map((s) => s.level).toSet();
    for (var l = 0; l <= 9; l++) {
      expect(levels, contains(l), reason: 'falta al menos un conjuro de nivel $l');
    }
  });

  test('cada conjuro tiene nivel válido y clases lanzadoras conocidas', () {
    for (final s in repo.spells.values) {
      expect(s.level, inInclusiveRange(0, 9), reason: '${s.id}: nivel inválido');
      expect(s.classes, isNotEmpty, reason: '${s.id}: sin clases');
      for (final c in s.classes) {
        expect(casterClasses, contains(c),
            reason: '${s.id}: clase lanzadora desconocida "$c"');
      }
    }
  });

  test('cada dote general con prerrequisito de competencia lo referencia bien', () {
    const knownProfs = {
      'light', 'medium', 'heavy', 'shield', 'simple', 'martial', 'spellcasting',
    };
    for (final f in repo.feats.values) {
      final prof = f.prerequisite?.requiredProficiency;
      if (prof == null) continue;
      expect(knownProfs, contains(prof),
          reason: '${f.id}: prerrequisito de competencia desconocido "$prof"');
    }
  });

  test('todas las dotes hacen round-trip por JSON (efectos y prerrequisitos)', () {
    for (final f in repo.feats.values) {
      final r = Feat.fromJson(f.toJson());
      expect(r.id, f.id);
      expect(r.effects.length, f.effects.length,
          reason: '${f.id}: se perdieron efectos en el round-trip');
    }
  });

  test('cada arma tiene categoría y maestría válidas', () {
    for (final w in repo.weapons.values) {
      expect(validWeaponCategories, contains(w.category),
          reason: '${w.id}: categoría inválida "${w.category}"');
      if (w.mastery != null) {
        expect(validMasteries, contains(w.mastery),
            reason: '${w.id}: maestría inválida "${w.mastery}"');
      }
    }
  });

  test('cada arma versátil declara su dado a dos manos', () {
    for (final w in repo.weapons.values) {
      if (w.properties.contains('versatile')) {
        expect(w.versatileDice, isNotNull,
            reason: '${w.id}: versátil sin versatileDice');
      }
    }
  });

  test('cada armadura tiene categoría válida', () {
    for (final a in repo.armor.values) {
      expect(validArmorCategories, contains(a.category),
          reason: '${a.id}: categoría inválida "${a.category}"');
    }
  });

  test('cada trasfondo referencia una dote de origen existente', () {
    for (final b in repo.backgrounds.values) {
      final id = b.originFeatId;
      if (id == null) continue;
      expect(repo.feat(id), isNotNull,
          reason: '${b.id}: dote de origen "$id" no existe');
      expect(repo.feat(id)!.category, 'origin',
          reason: '${b.id}: la dote "$id" no es de categoría origin');
    }
  });

  test('cada trasfondo ofrece exactamente 3 opciones de característica (2024)', () {
    for (final b in repo.backgrounds.values) {
      expect(b.abilityOptions, hasLength(3),
          reason: '${b.id}: debería ofrecer 3 características');
    }
  });

  test('todas las especies compilan sobre un Guerrero sin lanzar', () {
    for (final race in repo.races.values) {
      final c = Character(
        id: 'probe-${race.id}',
        name: 'Prueba',
        raceId: race.id,
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: const [10],
      );
      expect(() => CharacterCompiler(repo).compile(c), returnsNormally,
          reason: 'La especie ${race.id} no compila');
    }
  });

  test('FeatPrerequisite hace round-trip por JSON', () {
    const feat = Feat(
      id: 'hb-grappler',
      name: 'Forcejeador',
      source: ContentSource.homebrew,
      category: 'general',
      prerequisite: FeatPrerequisite(
        minAbilityScores: {Ability.strength: 13},
        minLevel: 4,
      ),
    );
    final r = Feat.fromJson(feat.toJson());
    expect(r.prerequisite, isNotNull);
    expect(r.prerequisite!.minAbilityScores[Ability.strength], 13);
    expect(r.prerequisite!.minLevel, 4);
  });
}
