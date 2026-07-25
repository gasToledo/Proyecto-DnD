import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifica que el wizard (capa de estado `CreationDraft`) reproduce el caso
/// Sagan y produce una ficha compilada con los valores esperados.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  test('un draft con las elecciones de Sagan compila correctamente', () {
    final d = CreationDraft(repo)
      ..classId = 'fighter'
      ..fightingStyleId = 'fs-defense'
      ..weaponMasteries.addAll(['longsword', 'greatsword', 'dagger'])
      ..raceId = 'human'
      ..raceFeatId = 'skilled'
      ..backgroundId = 'soldier'
      ..spreadMode = AbilitySpreadMode.twoOne
      ..spreadPlusTwo = Ability.strength
      ..spreadPlusOne = Ability.constitution
      ..equippedArmorId = 'leather'
      ..weaponId = 'longsword'
      ..name = 'Sagan "The Red"';

    d.classSkills.addAll(['perception', 'survival']);
    d.raceSkills.add('insight');

    // Asignación de array estándar.
    d.applyScoreMethod(ScoreMethod.standardArray);
    d.assignedScores.addAll({
      Ability.strength: 15,
      Ability.dexterity: 13,
      Ability.constitution: 14,
      Ability.intelligence: 10,
      Ability.wisdom: 12,
      Ability.charisma: 8,
    });

    final character = d.build();
    final sheet = CharacterCompiler(repo).compile(character);

    expect(sheet.abilityScores[Ability.strength], 17);
    expect(sheet.abilityScores[Ability.constitution], 15);
    expect(sheet.maxHp, 12);
    expect(sheet.armorClass, 13); // cuero 11 + DEX 1 + Defensa 1
    expect(sheet.weaponMasterySlots, 3);
    expect(sheet.passivePerception, 13);
    expect(sheet.attacks.single.attackBonus, 5);
    expect(sheet.attacks.single.mastery, 'sap');
    expect(character.name, 'Sagan "The Red"');
  });

  test('un linaje válido se conserva y aporta sus rasgos al personaje', () {
    final d = CreationDraft(repo)
      ..raceId = 'elf'
      ..lineageId = 'elf-high'
      ..speciesSpellcastingAbility = Ability.wisdom;

    final character = d.build();
    final sheet = CharacterCompiler(repo).compile(character);

    expect(character.lineageId, 'elf-high');
    expect(character.speciesSpellcastingAbility, Ability.wisdom);
    expect(
      sheet.innateSpells.map((spell) => spell.name),
      contains('Prestidigitación'),
    );
  });

  test('al restaurar descarta un linaje que pertenece a otra especie', () {
    final restored = CreationDraft.fromJson(repo, {
      'raceId': 'elf',
      'lineageId': 'tiefling-infernal',
    });

    expect(restored.raceId, 'elf');
    expect(restored.lineageId, isNull);
    expect(restored.pendingFor(CreationStep.raza), isNotEmpty);
  });

  test(
    'el reparto +1/+1/+1 aplica a las tres características del trasfondo',
    () {
      final d = CreationDraft(repo)
        ..backgroundId = 'soldier'
        ..spreadMode = AbilitySpreadMode.oneOneOne;
      expect(d.abilitySpread, {
        Ability.strength: 1,
        Ability.dexterity: 1,
        Ability.constitution: 1,
      });
    },
  );

  // --- Reasignación de dados con intercambio -------------------------------
  CreationDraft newDraft() =>
      CreationDraft(repo)..applyScoreMethod(ScoreMethod.standardArray);

  group('assignScore', () {
    test('asignar un valor libre no intercambia', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 14);
      expect(d.assignedScores[Ability.strength], 15);
      expect(d.assignedScores[Ability.dexterity], 14);
    });

    test('elegir un valor ya tomado por otra las intercambia', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 14);
      d.assignScore(Ability.strength, 14); // FUE roba el 14 → DES recibe el 15
      expect(d.assignedScores[Ability.strength], 14);
      expect(d.assignedScores[Ability.dexterity], 15);
    });

    test('elegir un valor tomado con el destino vacío se lo roba', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      d.assignScore(Ability.dexterity, 15); // 15 no libre → roba a FUE
      expect(d.assignedScores[Ability.dexterity], 15);
      expect(d.assignedScores.containsKey(Ability.strength), isFalse);
    });

    test('con las 6 asignadas se puede reordenar', () {
      final d = newDraft();
      const order = [15, 14, 13, 12, 10, 8];
      for (var i = 0; i < Ability.values.length; i++) {
        d.assignScore(Ability.values[i], order[i]);
      }
      expect(d.allScoresAssigned, isTrue);
      d.assignScore(Ability.strength, 8); // intercambia FUE(15) con CAR(8)
      expect(d.assignedScores[Ability.strength], 8);
      expect(d.assignedScores[Ability.charisma], 15);
      expect(d.allScoresAssigned, isTrue);
    });

    test('clearScores vacía las asignaciones y conserva el pool', () {
      final d = newDraft();
      d.assignScore(Ability.strength, 15);
      final pool = List.of(d.pool);
      d.clearScores();
      expect(d.assignedScores, isEmpty);
      expect(d.pool, pool);
    });
  });

  // --- Gating por paso -----------------------------------------------------

  /// Completa el paso de Clase (Guerrero: estilo de combate + 3 maestrías).
  void completeClase(CreationDraft d) {
    d.fightingStyleId = 'fs-defense';
    d.weaponMasteries.addAll(
      d.proficientWeapons.take(d.weaponMasterySlots).map((w) => w.id),
    );
  }

  group('pendingFor', () {
    test('Puntuaciones bloquea hasta asignar las 6', () {
      final d = newDraft();
      expect(d.pendingFor(CreationStep.puntuaciones), isNotEmpty);
      const order = [15, 14, 13, 12, 10, 8];
      for (var i = 0; i < Ability.values.length; i++) {
        d.assignScore(Ability.values[i], order[i]);
      }
      expect(d.pendingFor(CreationStep.puntuaciones), isEmpty);
    });

    test('Raza sin linajes solo exige elegir especie', () {
      final d = newDraft();
      expect(d.pendingFor(CreationStep.raza), isNotEmpty);
      d.raceId = 'human';
      expect(d.pendingFor(CreationStep.raza), isEmpty);
    });

    test('Elfo, Gnomo y Tiefling exigen elegir su linaje', () {
      const cases = {
        'elf': ('elf-high', 3),
        'gnome': ('gnome-forest', 2),
        'tiefling': ('tiefling-infernal', 3),
      };

      for (final entry in cases.entries) {
        final d = newDraft()..raceId = entry.key;
        expect(d.lineageOptions, hasLength(entry.value.$2));
        expect(
          d.pendingFor(CreationStep.raza),
          contains('Elegí un linaje de especie.'),
        );

        d.lineageId = entry.value.$1;
        expect(
          d.pendingFor(CreationStep.raza),
          contains('Elegí la aptitud mágica del linaje.'),
        );
        d.speciesSpellcastingAbility = Ability.charisma;
        expect(d.pendingFor(CreationStep.raza), isEmpty);
      }
    });

    test('Clase (Guerrero) exige estilo de combate y maestrías', () {
      final d = newDraft(); // classId = fighter por defecto
      expect(d.pendingFor(CreationStep.clase), isNotEmpty);
      completeClase(d);
      expect(d.pendingFor(CreationStep.clase), isEmpty);
    });

    test('Aptitudes exige las habilidades y la dote de origen', () {
      final d = newDraft();
      final race = repo.races.values.first;
      d.raceId = race.id;
      // Guerrero elige 2 habilidades de clase: el paso arranca pendiente.
      expect(d.pendingFor(CreationStep.aptitudes), isNotEmpty);
      d.classSkills.addAll(['perception', 'survival']);
      // Algunas especies eligen "de cualquier lista" (skillChoiceFrom vacío).
      final pickable = race.skillChoiceFrom.isEmpty
          ? const ['acrobatics', 'arcana', 'athletics']
          : race.skillChoiceFrom;
      for (final s in pickable.take(race.skillChoiceCount)) {
        d.raceSkills.add(s);
      }
      if (race.effects.any((e) => e is GrantFeatEffect)) {
        expect(d.pendingFor(CreationStep.aptitudes), isNotEmpty);
        d.raceFeatId = repo.feats.values
            .firstWhere((f) => f.category == 'origin')
            .id;
      }
      expect(d.pendingFor(CreationStep.aptitudes), isEmpty);
    });

    test('Equipo (clase no lanzadora), Detalles y Resumen nunca bloquean', () {
      final d = newDraft(); // Guerrero: no lanza conjuros
      expect(d.pendingFor(CreationStep.equipo), isEmpty);
      expect(d.pendingFor(CreationStep.detalles), isEmpty);
      expect(d.pendingFor(CreationStep.resumen), isEmpty);
    });

    test(
      'el cupo de habilidades no bloquea si quedan menos opciones elegibles',
      () {
        final d = newDraft(); // Guerrero: elige 2 de 9 opciones
        final fighter = repo.characterClass('fighter')!;
        final from = fighter.skillChoiceFrom;
        expect(fighter.skillChoiceCount, 2);
        // Otro origen ya tomó todas las opciones de clase menos una: queda 1 < 2.
        d.raceSkills.addAll(from.take(from.length - 1));
        // Con 0/2 elegidas pero solo 1 elegible, todavía debe pedir esa 1.
        expect(d.pendingFor(CreationStep.aptitudes), isNotEmpty);
        // Elegida la única disponible, el gate se satisface (no exige el 2.º).
        d.classSkills.add(from.last);
        expect(d.pendingFor(CreationStep.aptitudes), isEmpty);
      },
    );
  });

  // --- Navegación del stepper ----------------------------------------------
  group('canGoTo / firstIncompleteStep', () {
    test('no se puede saltar a un paso con pendientes atrás', () {
      final d = newDraft();
      expect(
        d.canGoTo(CreationStep.raza),
        isTrue,
        reason: 'el primero siempre',
      );
      expect(
        d.canGoTo(CreationStep.clase),
        isFalse,
        reason: 'falta elegir especie',
      );
      expect(d.firstIncompleteStep, CreationStep.raza);
    });

    test('completar habilita el siguiente, y volver atrás sigue permitido', () {
      final d = newDraft();
      d.raceId = repo.races.values.first.id;
      expect(d.canGoTo(CreationStep.clase), isTrue);
      expect(
        d.canGoTo(CreationStep.trasfondo),
        isFalse,
        reason: 'Clase aún pide estilo y maestrías',
      );
      completeClase(d);
      expect(d.canGoTo(CreationStep.trasfondo), isTrue);
      expect(d.canGoTo(CreationStep.raza), isTrue, reason: 'volver siempre');
      expect(d.firstIncompleteStep, CreationStep.trasfondo);
    });
  });
}
