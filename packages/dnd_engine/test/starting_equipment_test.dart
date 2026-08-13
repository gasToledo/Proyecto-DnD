import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('las listas esperadas cubren 13 clases y 33 trasfondos', () {
    List<String> ids(String file) =>
        (jsonDecode(File(file).readAsStringSync()) as List).cast<String>();
    final classes = ids('lib/assets/srd_2024/expected_class_ids.json');
    final backgrounds = ids('lib/assets/srd_2024/expected_background_ids.json');
    expect(classes, hasLength(13));
    expect(backgrounds, hasLength(33));
    expect(classes.toSet(), repo.classes.keys.toSet());
    expect(backgrounds.toSet(), repo.backgrounds.keys.toSet());
  });

  test('toda clase y trasfondo tiene opciones y referencias resolubles', () {
    final sources = <StartingEquipmentOption>[
      for (final value in repo.classes.values) ...value.startingEquipment,
      for (final value in repo.backgrounds.values) ...value.startingEquipment,
    ];
    expect(repo.classes.values.every((e) => e.startingEquipment.isNotEmpty),
        isTrue);
    expect(
      repo.backgrounds.values.every((e) => e.startingEquipment.isNotEmpty),
      isTrue,
    );
    for (final option in sources) {
      expect(option.grants, isNotEmpty, reason: option.label);
      for (final grant in option.grants) {
        if (grant.itemId != null) {
          expect(repo.catalogEntry(grant.itemId!), isNotNull,
              reason: '${option.label}: ${grant.itemId}');
        }
        for (final id in grant.chooseFromItemIds) {
          expect(repo.catalogEntry(id), isNotNull,
              reason: '${option.label}: $id');
        }
      }
    }
  });

  test('Guerrero conserva sus tres alternativas', () {
    final fighter = repo.characterClass('fighter')!;
    expect(fighter.startingEquipment.map((e) => e.id), ['A', 'B', 'C']);
    expect(fighter.startingEquipment.last.grants.single.coins, {'gp': 155});
  });

  test('las alternativas monetarias no agregan objetos', () {
    final sources = [
      for (final value in repo.classes.values)
        (name: value.name, options: value.startingEquipment),
      for (final value in repo.backgrounds.values)
        (name: value.name, options: value.startingEquipment),
    ];
    for (final source in sources) {
      final option = source.options.last;
      if (option.grants.any((e) => e.coins.isNotEmpty)) {
        expect(
            option.grants.every((e) => e.itemId == null && !e.isChoice), isTrue,
            reason: source.name);
      }
    }
  });
}
