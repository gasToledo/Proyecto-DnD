import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Cambio de truco innato tras un descanso largo.
///
/// Lo declaran el Alto Elfo ("conocés Prestidigitación; al terminar un descanso
/// largo podés cambiarlo por otro truco de la lista de Mago") y el Don Feérico
/// del Khoravar, que además elige entre tres listas.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character highElf({Map<String, String> choices = const {}}) => Character(
        id: 'x',
        name: 'Prueba',
        raceId: 'elf',
        lineageId: 'elf-high',
        classId: 'fighter',
        backgroundId: 'soldier',
        innateCantripChoices: choices,
        assignedScores: {for (final a in Ability.values) a: 10},
      );

  InnateSpell? prestidigitation(Character c) => CharacterCompiler(repo)
      .compile(c)
      .innateSpells
      .where((s) => s.grantedSpellId == 'prestidigitation')
      .firstOrNull;

  group('catálogo', () {
    test('el Alto Elfo declara la lista de Mago', () {
      final grant = repo
          .lineage('elf-high')!
          .featuresUpTo(1)
          .expand((f) => f.effects)
          .whereType<GrantSpellEffect>()
          .single;
      expect(grant.spellId, 'prestidigitation');
      expect(grant.replaceableFrom, ['wizard']);
    });

    test('el Don Feérico del Khoravar declara las tres listas', () {
      // Es lo que obliga a que el campo sea una lista y no un solo id.
      final grant = repo
          .race('khoravar')!
          .effects
          .whereType<GrantSpellEffect>()
          .firstWhere((g) => g.spellId == 'friends');
      expect(grant.replaceableFrom, ['cleric', 'druid', 'wizard']);
    });

    test('los conjuros de nivel 3 y 5 del Alto Elfo no son reemplazables', () {
      // Solo el truco se cambia: Detectar Magia y Paso Brumoso son fijos.
      final grants = repo
          .lineage('elf-high')!
          .featuresUpTo(5)
          .expand((f) => f.effects)
          .whereType<GrantSpellEffect>()
          .where((g) => g.spellId != 'prestidigitation');
      expect(grants, isNotEmpty);
      for (final g in grants) {
        expect(g.replaceableFrom, isEmpty, reason: g.spellId);
      }
    });
  });

  group('compilación', () {
    test('sin elegir se lanza el truco del rasgo', () {
      final innate = prestidigitation(highElf())!;
      expect(innate.spellId, 'prestidigitation');
      expect(innate.isReplaced, isFalse);
      expect(innate.isReplaceable, isTrue);
      expect(innate.replaceableFrom, ['wizard']);
    });

    test('el reemplazo elegido se lanza en su lugar', () {
      final innate = prestidigitation(
        highElf(choices: {'prestidigitation': 'fire-bolt'}),
      )!;
      expect(innate.spellId, 'fire-bolt');
      expect(innate.grantedSpellId, 'prestidigitation');
      expect(innate.isReplaced, isTrue);
    });

    test('un conjuro fuera de la lista declarada se ignora', () {
      // Llama Sagrada es truco, pero de Clérigo: el Alto Elfo elige de Mago.
      final innate = prestidigitation(
        highElf(choices: {'prestidigitation': 'sacred-flame'}),
      )!;
      expect(innate.spellId, 'prestidigitation');
      expect(innate.isReplaced, isFalse);
    });

    test('un conjuro que no es truco se ignora', () {
      // Está en la lista de Mago, pero es de nivel 1: la regla es cambiar un
      // truco por otro truco.
      final innate = prestidigitation(
        highElf(choices: {'prestidigitation': 'magic-missile'}),
      )!;
      expect(innate.spellId, 'prestidigitation');
    });

    test('un id que el catálogo no conoce se ignora', () {
      final innate = prestidigitation(
        highElf(choices: {'prestidigitation': 'no-existe'}),
      )!;
      expect(innate.spellId, 'prestidigitation');
    });

    test('una elección sobre un rasgo que no la permite no hace nada', () {
      // Detectar Magia es fijo: escribir una entrada para él no lo cambia.
      final c = Character(
        id: 'x',
        name: 'Prueba',
        raceId: 'elf',
        lineageId: 'elf-high',
        classId: 'fighter',
        backgroundId: 'soldier',
        level: 3,
        innateCantripChoices: const {'detect-magic': 'fire-bolt'},
        assignedScores: {for (final a in Ability.values) a: 10},
      );
      final innate = CharacterCompiler(repo)
          .compile(c)
          .innateSpells
          .firstWhere((s) => s.grantedSpellId == 'detect-magic');
      expect(innate.spellId, 'detect-magic');
      expect(innate.isReplaceable, isFalse);
    });

    test('el Khoravar puede tomarlo de cualquiera de sus tres listas', () {
      Character khoravar(String cantripId) => Character(
            id: 'x',
            name: 'Prueba',
            raceId: 'khoravar',
            classId: 'fighter',
            backgroundId: 'soldier',
            innateCantripChoices: {'friends': cantripId},
            assignedScores: {for (final a in Ability.values) a: 10},
          );

      // Llama Sagrada es de Clérigo y Saeta de Fuego de Mago: las dos valen.
      for (final id in ['sacred-flame', 'fire-bolt']) {
        final innate = CharacterCompiler(repo)
            .compile(khoravar(id))
            .innateSpells
            .firstWhere((s) => s.grantedSpellId == 'friends');
        expect(innate.spellId, id, reason: id);
      }
    });
  });

  group('persistencia', () {
    test('la elección sobrevive al round-trip', () {
      final c = highElf(choices: {'prestidigitation': 'fire-bolt'});
      final restored = Character.fromJson(c.toJson());
      expect(restored.innateCantripChoices, {'prestidigitation': 'fire-bolt'});
    });

    test('una ficha vieja sin el campo se lee como sin cambios', () {
      final json = highElf(choices: {'prestidigitation': 'fire-bolt'}).toJson()
        ..remove('innateCantripChoices');
      expect(Character.fromJson(json).innateCantripChoices, isEmpty);
    });

    test('copyWith lo conserva y lo puede reemplazar', () {
      final c = highElf(choices: {'prestidigitation': 'fire-bolt'});
      expect(c.copyWith(level: 2).innateCantripChoices, {
        'prestidigitation': 'fire-bolt',
      });
      expect(c.copyWith(innateCantripChoices: const {}).innateCantripChoices,
          isEmpty);
    });

    test('el efecto conserva la lista al serializarse', () {
      const effect = GrantSpellEffect(
        spellId: 'prestidigitation',
        ability: Ability.intelligence,
        replaceableFrom: ['wizard'],
      );
      final restored = Effect.fromJson(effect.toJson()) as GrantSpellEffect;
      expect(restored.replaceableFrom, ['wizard']);
    });
  });
}
