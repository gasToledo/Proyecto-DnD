import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El mecanismo de elección de competencia, contra contenido inventado.
///
/// Igual que `feature_choice_test`, acá no aparece ningún id oficial: sumar
/// una dote que conceda competencias tiene que ser puro dato. Al final del
/// archivo sí se comprueban Habilidoso y Mente Aguda, que son las dos del
/// catálogo que lo usan.
ContentRepository _repo(List<Map<String, dynamic>> feats) =>
    ContentRepository.fromJsonPacks(
      races: [
        {'id': 'r', 'name': 'Raza', 'source': 'homebrew'},
      ],
      classes: [
        {
          'id': 'c',
          'name': 'Clase',
          'source': 'homebrew',
          'hitDie': 8,
          'features': const [],
        },
      ],
      backgrounds: [
        {'id': 'b', 'name': 'Trasfondo', 'source': 'homebrew'},
      ],
      feats: feats,
    );

Character _char({
  List<String> feats = const [],
  List<String> chosen = const [],
}) =>
    Character(
      id: 'p',
      name: 'Prueba',
      raceId: 'r',
      classId: 'c',
      backgroundId: 'b',
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: const [8],
      featIds: feats,
      chosenProficiencies: chosen,
    );

void main() {
  group('Mecanismo', () {
    test('la ficha expone el cupo con sus opciones ya resueltas', () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'effects': [
            {
              'type': 'proficiencyChoice',
              'count': 2,
              'skills': ['arcana', 'history'],
            },
          ],
        },
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(feats: ['f']));
      final slot = sheet.proficiencyChoiceSlots.single;
      expect(slot.featId, 'f');
      expect(slot.featName, 'Dote');
      expect(slot.count, 2);
      expect(slot.skills, ['arcana', 'history']);
      // Sin `includeTools` no se ofrecen herramientas.
      expect(slot.tools, isEmpty);
      expect(slot.options, ['arcana', 'history']);
    });

    test('lista de habilidades vacía significa todas', () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'effects': [
            {'type': 'proficiencyChoice', 'count': 1},
          ],
        },
      ]);
      final slot = CharacterCompiler(repo)
          .compile(_char(feats: ['f']))
          .proficiencyChoiceSlots
          .single;
      expect(slot.skills, Skill.allIds);
    });

    test('con includeTools ofrece herramientas, sin las genéricas', () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'effects': [
            {'type': 'proficiencyChoice', 'count': 1, 'includeTools': true},
          ],
        },
      ]);
      final slot = CharacterCompiler(repo)
          .compile(_char(feats: ['f']))
          .proficiencyChoiceSlots
          .single;
      expect(slot.tools, contains('thieves-tools'));
      // "una de esta familia a tu elección" no es una competencia elegible.
      expect(slot.tools, isNot(contains('artisans-tools')));
      expect(slot.tools, isNot(contains('gaming-set')));
    });

    test('lo elegido aterriza en habilidad o herramienta según corresponda',
        () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'effects': [
            {'type': 'proficiencyChoice', 'count': 2, 'includeTools': true},
          ],
        },
      ]);
      final sheet = CharacterCompiler(repo).compile(
        _char(feats: ['f'], chosen: ['stealth', 'thieves-tools']),
      );
      expect(sheet.skillProficiencies, contains('stealth'));
      expect(sheet.toolProficiencies, contains('thieves-tools'));
    });

    test('una dote repetible da un cupo por copia', () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'repeatable': true,
          'effects': [
            {'type': 'proficiencyChoice', 'count': 3},
          ],
        },
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(feats: ['f', 'f']));
      expect(sheet.proficiencyChoiceSlots, hasLength(2));
      expect(
        sheet.proficiencyChoiceSlots.fold<int>(0, (n, s) => n + s.count),
        6,
      );
    });

    test('una dote no repetible tomada dos veces da un solo cupo', () {
      final repo = _repo([
        {
          'id': 'f',
          'name': 'Dote',
          'source': 'homebrew',
          'effects': [
            {'type': 'proficiencyChoice', 'count': 1},
          ],
        },
      ]);
      final sheet = CharacterCompiler(repo).compile(_char(feats: ['f', 'f']));
      expect(sheet.proficiencyChoiceSlots, hasLength(1));
    });
  });

  group('Validación', () {
    ContentRepository repoConDote() => _repo([
          {
            'id': 'f',
            'name': 'Dote',
            'source': 'homebrew',
            'effects': [
              {
                'type': 'proficiencyChoice',
                'count': 2,
                'skills': ['arcana', 'history', 'nature'],
              },
            ],
          },
        ]);

    Set<String> avisos(ContentRepository repo, Character c) =>
        CharacterValidator(repo).validate(c).map((w) => w.code).toSet();

    test('elegir de menos avisa', () {
      final repo = repoConDote();
      expect(avisos(repo, _char(feats: ['f'], chosen: ['arcana'])),
          contains('proficiency_choice_count'));
    });

    test('elegir la cantidad justa no avisa', () {
      final repo = repoConDote();
      final c = _char(feats: ['f'], chosen: ['arcana', 'history']);
      expect(avisos(repo, c), isNot(contains('proficiency_choice_count')));
    });

    test('repetir una competencia avisa', () {
      final repo = repoConDote();
      final c = _char(feats: ['f'], chosen: ['arcana', 'arcana']);
      expect(avisos(repo, c), contains('proficiency_choice_duplicate'));
    });

    test('elegir algo fuera de la lista avisa', () {
      final repo = repoConDote();
      final c = _char(feats: ['f'], chosen: ['arcana', 'stealth']);
      expect(avisos(repo, c), contains('proficiency_choice_invalid'));
    });

    test('elegir sin tener ninguna dote que lo conceda avisa', () {
      final repo = repoConDote();
      expect(avisos(repo, _char(chosen: ['arcana'])),
          contains('proficiency_choice_count'));
    });
  });

  group('Catálogo oficial', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    test('Habilidoso: tres, entre habilidades y herramientas', () {
      final e = repo
          .feat('skilled')!
          .effects
          .whereType<ProficiencyChoiceEffect>()
          .single;
      expect(e.count, 3);
      expect(e.includeTools, isTrue);
      // Vacío = todas, así que no hay una lista que se desactualice.
      expect(e.skills, isEmpty);
    });

    test('Mente Aguda: una, de las cinco del manual', () {
      final e = repo
          .feat('keen-mind')!
          .effects
          .whereType<ProficiencyChoiceEffect>()
          .single;
      expect(e.count, 1);
      expect(e.includeTools, isFalse);
      expect(e.skills,
          ['arcana', 'history', 'investigation', 'nature', 'religion']);
      // Las cinco existen: un id mal escrito dejaría el cupo sin opciones.
      for (final id in e.skills) {
        expect(Skill.allIds, contains(id), reason: id);
      }
    });

    test('la competencia elegida llega a la ficha', () {
      final c = Character(
        id: 'x',
        name: 'Sabio',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 4,
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [6, 4, 4, 4],
        featIds: const ['keen-mind'],
        chosenProficiencies: const ['nature'],
      );
      final sheet = CharacterCompiler(repo).compile(c);
      expect(sheet.skillProficiencies, contains('nature'));
      expect(sheet.proficiencyChoiceSlots.single.featName, 'Mente Aguda');
    });
  });
}
