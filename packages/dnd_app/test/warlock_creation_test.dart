import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// La creación del Brujo gnomo de la observación del 24/09/2026: el equipo
/// que nacía sin poner, la aptitud de Iniciado en la Magia que nadie pedía y
/// el Pacto del Grimorio sin sus trucos ni rituales.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Brujo con todo lo que no se prueba ya resuelto.
  CreationDraft brujo({String backgroundId = 'acolyte'}) {
    final d = CreationDraft(repo)
      ..raceId = 'gnome'
      ..lineageId = 'gnome-forest'
      ..speciesSpellcastingAbility = Ability.charisma
      ..classId = 'warlock'
      ..backgroundId = backgroundId
      ..spreadMode = AbilitySpreadMode.twoOne
      ..spreadPlusTwo = Ability.charisma
      ..spreadPlusOne = Ability.wisdom;
    d.featureChoices['warlock-invocation'] = ['armor-of-shadows'];
    d.assignedScores.addAll({
      Ability.strength: 8,
      Ability.dexterity: 14,
      Ability.constitution: 13,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 15,
    });
    return d;
  }

  String firstOption(String id, List<StartingEquipmentOption> options) =>
      options.firstWhere((o) => o.id == id).id;

  group('Equipo recibido puesto por defecto', () {
    CreationDraft conPaquete() {
      final d = brujo();
      d.classEquipmentOptionId = firstOption(
        d.klass!.startingEquipment.first.id,
        d.klass!.startingEquipment,
      );
      d.pruneEquipment();
      return d;
    }

    test('la Opción A del Brujo nace con cuero, hoz y daga puestas', () {
      final d = conPaquete();
      expect(d.receivedItemIds, containsAll(['leather', 'sickle', 'dagger']));
      expect(d.equippedArmorId, 'leather');
      expect(d.weaponIds, containsAll(['sickle', 'dagger']));

      final sheet = CharacterCompiler(repo).compile(d.build());
      final leather = repo.armorPiece('leather')!;
      expect(
        sheet.armorClass,
        leather.baseAc + sheet.abilityModifiers[Ability.dexterity]!,
      );
      final codes = CharacterValidator(
        repo,
      ).validate(d.build()).map((w) => w.code);
      expect(codes, isNot(contains('no_weapon')));
    });

    test('una armadura sin competencia se recibe pero no se pone', () {
      // Ningún paquete oficial da una armadura que la clase no sabe usar, así
      // que el caso se arma: si pasara, nacería con desventaja y sin poder
      // lanzar conjuros sin haberlo pedido.
      final synthetic = ContentRepository.fromJsonPacks(
        races: [
          {'id': 'human', 'name': 'Humano', 'source': 'srd_2024'},
        ],
        classes: [
          {
            'id': 'scholar',
            'name': 'Erudito',
            'source': 'srd_2024',
            'hitDie': 6,
            'startingEquipment': [
              {
                'id': 'A',
                'label': 'Opción A',
                'grants': [
                  {'itemId': 'leather'},
                ],
              },
            ],
          },
        ],
        backgrounds: [
          {'id': 'sage', 'name': 'Sabio', 'source': 'srd_2024'},
        ],
        armor: [
          {
            'id': 'leather',
            'name': 'Armadura de cuero',
            'source': 'srd_2024',
            'category': 'light',
            'baseAc': 11,
            'addDexMod': true,
          },
        ],
      );
      final d = CreationDraft(synthetic)
        ..raceId = 'human'
        ..classId = 'scholar'
        ..backgroundId = 'sage'
        ..classEquipmentOptionId = 'A';
      d.pruneEquipment();
      expect(d.receivedItemIds, contains('leather'));
      expect(d.previewSheet.armorProficiencies, isNot(contains('light')));
      expect(d.equippedArmorId, isNull);
    });

    test('la elección manual sobrevive al cambio de paquete y a recargar', () {
      final d = conPaquete();
      d.equipmentTouched = true;
      d.equippedArmorId = null;

      d.backgroundEquipmentOptionId = d.background!.startingEquipment.last.id;
      d.pruneEquipment();
      expect(d.equippedArmorId, isNull);

      final reloaded = CreationDraft.fromJson(
        repo,
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      );
      reloaded.pruneEquipment();
      expect(reloaded.equipmentTouched, isTrue);
      expect(reloaded.equippedArmorId, isNull);
    });
  });

  group('Aptitud mágica de la dote de origen', () {
    test('el Acólito la exige en el paso Trasfondo', () {
      final d = brujo();
      final feat = d.originFeatWithAbilityChoice!;
      expect(
        d.pendingFor(CreationStep.trasfondo),
        contains('Elegí la aptitud mágica de ${feat.name}.'),
      );
      d.originFeatSpellcastingAbility = Ability.charisma;
      expect(d.pendingFor(CreationStep.trasfondo), isEmpty);
    });

    test('el personaje nace con la aptitud y sin la advertencia', () {
      final d = brujo()..originFeatSpellcastingAbility = Ability.charisma;
      final c = d.build();
      final feat = d.originFeatWithAbilityChoice!;
      expect(c.featSpellcastingAbilities[feat.id], Ability.charisma);
      final codes = CharacterValidator(repo).validate(c).map((w) => w.code);
      expect(codes, isNot(contains('feat_spellcasting_ability_pending')));
    });

    test('un trasfondo cuya dote no la ofrece no la pide ni la escribe', () {
      final d = brujo(backgroundId: 'soldier')
        ..originFeatSpellcastingAbility = Ability.charisma;
      expect(d.originFeatWithAbilityChoice, isNull);
      expect(d.pendingFor(CreationStep.trasfondo), isEmpty);
      expect(d.build().featSpellcastingAbilities, isEmpty);
    });

    test('se conserva al recargar el borrador', () {
      final d = brujo()..originFeatSpellcastingAbility = Ability.wisdom;
      final reloaded = CreationDraft.fromJson(
        repo,
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      );
      expect(reloaded.originFeatSpellcastingAbility, Ability.wisdom);
    });
  });

  group('Pacto del Grimorio en la creación', () {
    test('sus cupos bloquean el paso Equipo hasta completarlos', () {
      final d = brujo(backgroundId: 'soldier');
      d.featureChoices['warlock-invocation'] = ['pact-of-the-tome'];
      final slots = {for (final s in d.spellChoiceSlots) s.groupId: s};
      expect(
        slots.keys,
        containsAll(['pact-of-the-tome:cantrips', 'pact-of-the-tome:rituals']),
      );
      expect(
        d.pendingFor(CreationStep.equipo),
        contains(
          'Conjuros a elección: ${slots.values.fold<int>(0, (n, s) => n + s.count)}.',
        ),
      );

      for (final s in slots.values) {
        d.spellChoices[s.groupId] = s.options.take(s.count).toList();
      }
      expect(
        d
            .pendingFor(CreationStep.equipo)
            .where((m) => m.startsWith('Conjuros a elección')),
        isEmpty,
      );
    });
  });
}
