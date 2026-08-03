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
      ..featureChoices['fighting-style'] = ['fs-defense']
      ..weaponMasteries.addAll(['longsword', 'greatsword', 'dagger'])
      ..raceId = 'human'
      ..raceFeatId = 'skilled'
      ..backgroundId = 'soldier'
      ..spreadMode = AbilitySpreadMode.twoOne
      ..spreadPlusTwo = Ability.strength
      ..spreadPlusOne = Ability.constitution
      ..equippedArmorId = 'leather'
      ..weaponIds.add('longsword')
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

    test('holdersExcept y freeCopiesOf distinguen valores repetidos', () {
      final d = CreationDraft(repo)
        ..applyScoreMethod(ScoreMethod.manual)
        ..scoreMethod = ScoreMethod.roll4d6
        ..pool = [15, 14, 14, 10, 9, 8];
      expect(d.freeCopiesOf(14, Ability.strength), 2);

      d.assignScore(Ability.dexterity, 14);
      // Desde FUE: el 14 sigue teniendo una copia libre, pero hay que poder
      // ver que la otra está en DES.
      expect(d.holdersExcept(Ability.strength)[14], [Ability.dexterity]);
      expect(d.freeCopiesOf(14, Ability.strength), 1);

      d.assignScore(Ability.constitution, 14);
      expect(d.freeCopiesOf(14, Ability.strength), 0);
      // La propia característica no se cuenta como ocupante de su valor.
      expect(d.holdersExcept(Ability.dexterity)[14], [Ability.constitution]);
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

  // --- Armas equipadas -----------------------------------------------------
  group('armas equipadas', () {
    test('varias armas producen un ataque por cada una', () {
      final d = CreationDraft(repo)
        ..classId = 'rogue'
        ..raceId = 'human'
        ..backgroundId = 'soldier'
        ..weaponIds.addAll(['dagger', 'dagger'])
        ..applyScoreMethod(ScoreMethod.standardArray);
      for (final a in Ability.values) {
        d.assignScore(a, d.availableFor(a).first);
      }
      // Dos dagas: el pícaro las lleva en ambas manos.
      final sheet = CharacterCompiler(repo).compile(d.build());
      expect(sheet.attacks, hasLength(2));
      expect(
        sheet.attacks.every((a) => a.name.toLowerCase().contains('daga')),
        isTrue,
      );
    });

    test('un borrador con el formato viejo de un arma se sigue leyendo', () {
      final d = CreationDraft(repo)..weaponIds.addAll(['dagger', 'shortsword']);
      final json = d.toJson()
        ..remove('weaponIds')
        ..['weaponId'] = 'longsword';
      expect(CreationDraft.fromJson(repo, json).weaponIds, ['longsword']);
    });

    test('el round-trip conserva el orden y descarta ids inexistentes', () {
      final d = CreationDraft(repo)..weaponIds.addAll(['shortsword', 'dagger']);
      final json = d.toJson()..['weaponIds'] = ['shortsword', 'nope', 'dagger'];
      expect(CreationDraft.fromJson(repo, json).weaponIds, [
        'shortsword',
        'dagger',
      ]);
    });
  });

  // --- Puntuaciones escritas a mano ----------------------------------------
  group('ScoreMethod.manual', () {
    test('acepta valores fuera del pool y respeta el rango', () {
      final d = CreationDraft(repo)..applyScoreMethod(ScoreMethod.manual);
      d.setManualScore(Ability.strength, 17);
      d.setManualScore(Ability.dexterity, 17); // repetir es legítimo
      expect(d.assignedScores[Ability.strength], 17);
      expect(d.assignedScores[Ability.dexterity], 17);

      d.setManualScore(Ability.constitution, 0);
      d.setManualScore(Ability.intelligence, 31);
      expect(d.assignedScores.containsKey(Ability.constitution), isFalse);
      expect(d.assignedScores.containsKey(Ability.intelligence), isFalse);

      d.setManualScore(Ability.strength, null);
      expect(d.assignedScores.containsKey(Ability.strength), isFalse);
    });

    test('un borrador manual sobrevive al guardado', () {
      final d = CreationDraft(repo)..applyScoreMethod(ScoreMethod.manual);
      // Valores que ningún pool podría producir: el round-trip los filtraría
      // si siguiera validando contra el array estándar.
      const written = [20, 3, 19, 11, 7, 16];
      for (var i = 0; i < Ability.values.length; i++) {
        d.setManualScore(Ability.values[i], written[i]);
      }
      expect(d.allScoresAssigned, isTrue);

      final restored = CreationDraft.fromJson(repo, d.toJson());
      expect(restored.scoreMethod, ScoreMethod.manual);
      expect(restored.allScoresAssigned, isTrue);
      for (var i = 0; i < Ability.values.length; i++) {
        expect(restored.assignedScores[Ability.values[i]], written[i]);
      }
    });

    test('cambiar de método limpia lo escrito a mano', () {
      final d = CreationDraft(repo)..applyScoreMethod(ScoreMethod.manual);
      d.setManualScore(Ability.strength, 20);
      d.applyScoreMethod(ScoreMethod.standardArray);
      expect(d.assignedScores, isEmpty);
      expect(d.pool, standardArray);
    });
  });

  // --- Compra de puntos ------------------------------------------------------

  group('compra de puntos', () {
    CreationDraft pointBuyDraft() =>
        CreationDraft(repo)..applyScoreMethod(ScoreMethod.pointBuy);

    test('arranca con las seis en el mínimo y el presupuesto entero', () {
      final d = pointBuyDraft();
      expect(d.assignedScores.values, everyElement(pointBuyMin));
      expect(d.allScoresAssigned, isTrue);
      expect(d.pointsSpent, 0);
      expect(d.pointsRemaining, pointBuyBudget);
    });

    test('subir descuenta según la tabla, no de a uno', () {
      final d = pointBuyDraft();
      for (var i = 0; i < 5; i++) {
        d.stepPointBuy(Ability.strength, 1);
      }
      expect(d.assignedScores[Ability.strength], 13);
      expect(d.pointsSpent, 5);

      // El sexto escalón (13 → 14) cuesta 2, no 1.
      d.stepPointBuy(Ability.strength, 1);
      expect(d.assignedScores[Ability.strength], 14);
      expect(d.pointsSpent, 7);
    });

    test('no se puede pasar de 15 ni bajar de 8', () {
      final d = pointBuyDraft();
      for (var i = 0; i < 10; i++) {
        d.stepPointBuy(Ability.strength, 1);
      }
      expect(d.assignedScores[Ability.strength], pointBuyMax);
      expect(d.canRaisePointBuy(Ability.strength), isFalse);

      for (var i = 0; i < 10; i++) {
        d.stepPointBuy(Ability.dexterity, -1);
      }
      expect(d.assignedScores[Ability.dexterity], pointBuyMin);
      expect(d.canLowerPointBuy(Ability.dexterity), isFalse);
    });

    test('el presupuesto frena la subida antes de pasarse', () {
      final d = pointBuyDraft();
      // 15/15/15 gasta los 27 justos: nada más puede subir.
      for (final a in [
        Ability.strength,
        Ability.dexterity,
        Ability.constitution,
      ]) {
        for (var i = 0; i < 7; i++) {
          d.stepPointBuy(a, 1);
        }
      }
      expect(d.pointsSpent, pointBuyBudget);
      expect(d.pointsRemaining, 0);
      expect(d.canRaisePointBuy(Ability.wisdom), isFalse);

      d.stepPointBuy(Ability.wisdom, 1);
      expect(d.assignedScores[Ability.wisdom], pointBuyMin);
      expect(d.pointsSpent, pointBuyBudget);
    });

    test('quedan 2 puntos y un escalón de 2 todavía entra', () {
      final d = pointBuyDraft();
      // 25 gastados exactos: 15 (9) + 14 (7) + 13 (5) + 12 (4).
      for (var i = 0; i < 7; i++) {
        d.stepPointBuy(Ability.strength, 1);
      }
      for (var i = 0; i < 6; i++) {
        d.stepPointBuy(Ability.dexterity, 1);
      }
      for (var i = 0; i < 5; i++) {
        d.stepPointBuy(Ability.constitution, 1);
      }
      for (var i = 0; i < 4; i++) {
        d.stepPointBuy(Ability.intelligence, 1);
      }
      expect(d.pointsSpent, 25);

      // Sabiduría está en 8: subir cuesta 1 y entra dos veces.
      expect(d.canRaisePointBuy(Ability.wisdom), isTrue);
      d.stepPointBuy(Ability.wisdom, 1);
      d.stepPointBuy(Ability.wisdom, 1);
      expect(d.assignedScores[Ability.wisdom], 10);
      expect(d.pointsRemaining, 0);
    });

    test('un reparto válido sobrevive al guardado', () {
      final d = pointBuyDraft();
      for (var i = 0; i < 7; i++) {
        d.stepPointBuy(Ability.strength, 1);
      }
      for (var i = 0; i < 4; i++) {
        d.stepPointBuy(Ability.constitution, 1);
      }
      final spent = d.pointsSpent;

      final restored = CreationDraft.fromJson(repo, d.toJson());
      expect(restored.scoreMethod, ScoreMethod.pointBuy);
      expect(restored.assignedScores[Ability.strength], pointBuyMax);
      expect(restored.assignedScores[Ability.constitution], 12);
      expect(restored.pointsSpent, spent);
    });

    test('un borrador que se pasa del presupuesto vuelve al mínimo', () {
      // No es alcanzable desde la UI: simula un archivo editado a mano.
      final d = pointBuyDraft();
      final json = d.toJson();
      json['assignedScores'] = {
        for (final a in Ability.values) a.name: pointBuyMax,
      };

      final restored = CreationDraft.fromJson(repo, json);
      expect(restored.assignedScores.values, everyElement(pointBuyMin));
      expect(restored.pointsSpent, 0);
    });

    test('un borrador con una puntuación fuera de rango vuelve al mínimo', () {
      final d = pointBuyDraft();
      final json = d.toJson();
      json['assignedScores'] = {
        for (final a in Ability.values) a.name: pointBuyMin,
        Ability.strength.name: 18,
      };

      final restored = CreationDraft.fromJson(repo, json);
      expect(restored.assignedScores.values, everyElement(pointBuyMin));
    });

    test('limpiar devuelve el presupuesto entero, no deja las seis vacías', () {
      final d = pointBuyDraft();
      for (var i = 0; i < 7; i++) {
        d.stepPointBuy(Ability.strength, 1);
      }
      d.clearScores();
      expect(d.assignedScores.values, everyElement(pointBuyMin));
      expect(d.allScoresAssigned, isTrue);
      expect(d.pointsRemaining, pointBuyBudget);
    });

    test('cambiar a compra de puntos descarta lo asignado por pool', () {
      final d = CreationDraft(repo)
        ..applyScoreMethod(ScoreMethod.standardArray);
      d.assignScore(Ability.strength, 15);
      d.applyScoreMethod(ScoreMethod.pointBuy);
      expect(d.assignedScores[Ability.strength], pointBuyMin);
      expect(d.pointsSpent, 0);
    });
  });

  // --- Gating por paso -----------------------------------------------------

  /// Completa el paso de Clase (Guerrero: estilo de combate + 3 maestrías).
  void completeClase(CreationDraft d) {
    d.featureChoices['fighting-style'] = ['fs-defense'];
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

    test('Goliat y Dracónido exigen linaje, pero sin aptitud mágica', () {
      // Sus linajes no conceden conjuros, así que elegirlo alcanza: pedir una
      // aptitud mágica ahí sería inventar una elección que el PHB no tiene.
      const cases = {
        'goliath': ('goliath-stone', 6),
        'dragonborn': ('dragonborn-red', 10),
      };

      for (final entry in cases.entries) {
        final d = newDraft()..raceId = entry.key;
        expect(d.lineageOptions, hasLength(entry.value.$2));
        expect(
          d.pendingFor(CreationStep.raza),
          contains('Elegí un linaje de especie.'),
        );

        d.lineageId = entry.value.$1;
        expect(d.lineageUsesSpellcastingAbility, isFalse);
        expect(d.pendingFor(CreationStep.raza), isEmpty);
      }
    });

    test('Clase (Guerrero) exige estilo de combate y maestrías', () {
      final d = newDraft(); // classId = fighter por defecto
      expect(d.pendingFor(CreationStep.clase), isNotEmpty);
      completeClase(d);
      expect(d.pendingFor(CreationStep.clase), isEmpty);
    });

    test('Clase (Brujo) exige la invocación de nivel 1', () {
      // El mismo gating genérico, sin nombrar el grupo: el Brujo elige una
      // invocación a nivel 1 igual que el Guerrero elige estilo.
      final d = newDraft()..classId = 'warlock';

      final slot = d.featureChoiceSlots.single;
      expect(slot.groupId, 'warlock-invocation');
      expect(slot.count, 1);
      expect(d.pendingFor(CreationStep.clase), isNotEmpty);

      d.featureChoices['warlock-invocation'] = ['pact-of-the-tome'];
      expect(d.pendingFor(CreationStep.clase), isEmpty);

      // Y la elección llega al personaje construido.
      expect(d.build().featureChoices['warlock-invocation'], [
        'pact-of-the-tome',
      ]);
    });

    test('cambiar de clase suelta las elecciones de la anterior', () {
      final d = newDraft();
      completeClase(d);
      expect(d.featureChoices, isNotEmpty);

      // Lo hace la UI al tocar otra clase; acá se comprueba el efecto sobre el
      // gating: un Brujo no arrastra el estilo de combate del Guerrero.
      d
        ..classId = 'warlock'
        ..featureChoices.clear();
      expect(d.featureChoiceSlots.single.groupId, 'warlock-invocation');
      expect(d.pendingFor(CreationStep.clase), isNotEmpty);
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
