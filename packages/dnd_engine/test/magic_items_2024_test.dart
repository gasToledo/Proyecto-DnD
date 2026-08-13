import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

Character _character({
  String classId = 'fighter',
  int level = 1,
  List<String> plans = const [],
  List<InventoryEntry> inventory = const [],
}) =>
    Character(
      id: 'magic-test',
      name: 'Prueba',
      raceId: 'human',
      classId: classId,
      backgroundId: 'soldier',
      level: level,
      assignedScores: {for (final a in Ability.values) a: 10},
      hpPerLevel: List.filled(level, 8),
      magicItemChoices: plans,
      inventory: inventory,
    );

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('catálogo SRD coincide con la lista esperada y EFA tiene nueve', () {
    final expected = (jsonDecode(
      File('lib/assets/srd_2024/expected_magic_item_ids.json')
          .readAsStringSync(),
    ) as List)
        .cast<String>();
    expect(expected, hasLength(261));
    expect(expected.toSet(), hasLength(expected.length));
    expect(expected.where(repo.items.containsKey), hasLength(expected.length));
    expect(
      repo.items.values.where((e) => e.source == ContentSource.foa2025),
      hasLength(9),
    );
  });

  test('todas las plantillas con base resuelven un tipo existente', () {
    for (final item in repo.items.values.where((e) => e.baseItemKind != null)) {
      expect(item.baseItemKind, anyOf('weapon', 'armor', 'shield'));
      for (final id in item.eligibleBaseItemIds) {
        expect(repo.catalogEntry(id), isNotNull, reason: '${item.id} -> $id');
      }
    }
  });

  test('espada +1 modifica solo su propio ataque y conserva identidad', () {
    final c = _character(inventory: const [
      InventoryEntry(
        entryId: 'magic-sword',
        itemId: 'arma-1',
        baseItemId: 'longsword',
        equipped: true,
      ),
      InventoryEntry(
        entryId: 'plain-sword',
        itemId: 'shortsword',
        equipped: true,
      ),
    ]);
    final attacks = CharacterCompiler(repo).compile(c).attacks;
    expect(
        attacks.singleWhere((e) => e.weaponId == 'magic-sword').attackBonus, 3);
    expect(
        attacks.singleWhere((e) => e.weaponId == 'shortsword').attackBonus, 2);
  });

  test('escudo mágico suma su base y bono sin degradarse a mundano', () {
    final c = _character(inventory: const [
      InventoryEntry(
        entryId: 'repulsion',
        itemId: 'repulsion-shield',
        baseItemId: 'shield',
        equipped: true,
      ),
    ]);
    expect(CharacterCompiler(repo).compile(c).armorClass, 13);
    expect(c.inventory.single.itemId, 'repulsion-shield');
  });

  test('efectos pasivos estables respetan equipado y sintonizado', () {
    final off = _character(inventory: const [
      InventoryEntry(itemId: 'amuleto-de-salud', equipped: true),
      InventoryEntry(itemId: 'anillo-de-proteccion', equipped: true),
    ]);
    final active = _character(inventory: const [
      InventoryEntry(
        itemId: 'amuleto-de-salud',
        equipped: true,
        attuned: true,
      ),
      InventoryEntry(
        itemId: 'anillo-de-proteccion',
        equipped: true,
        attuned: true,
      ),
    ]);
    final compiler = CharacterCompiler(repo);
    expect(compiler.compile(off).abilityScores[Ability.constitution], 10);
    final sheet = compiler.compile(active);
    expect(sheet.abilityScores[Ability.constitution], 19);
    expect(sheet.armorClass, 11);
    expect(sheet.savingThrow(Ability.wisdom), 1);
  });

  test('dos ejemplares iguales tienen identidad y procedencia separadas', () {
    var c = _character();
    c = InventoryOps.add(c, 'anillo-de-proteccion', origin: 'tesoro:uno');
    c = InventoryOps.add(c, 'anillo-de-proteccion', origin: 'tesoro:dos');
    expect(c.inventory, hasLength(2));
    expect(c.inventory.map((e) => e.entryId).toSet(), hasLength(2));
    expect(c.inventory.map((e) => e.origin).toSet(), hasLength(2));
  });

  test('conocer un plano no concede el objeto y respeta cupo de réplicas', () {
    var c = _character(
      classId: 'artificer',
      level: 2,
      plans: const ['returning-weapon', 'repeating-shot'],
    );
    expect(CharacterCompiler(repo).compile(c).attacks, isEmpty);
    c = InventoryOps.replicateMagicItem(
      c,
      'returning-weapon',
      repo,
      baseItemId: 'dagger',
    );
    c = InventoryOps.replicateMagicItem(
      c,
      'repeating-shot',
      repo,
      baseItemId: 'shortbow',
    );
    final full = c;
    c = InventoryOps.replicateMagicItem(
      c.copyWith(magicItemChoices: [...c.magicItemChoices, 'manifold-tool']),
      'manifold-tool',
      repo,
    );
    expect(c.inventory, hasLength(2));
    expect(
        c.inventory.map((e) => e.itemId), full.inventory.map((e) => e.itemId));
  });

  test('las réplicas de arma solo aceptan bases elegibles', () {
    final c = _character(
      classId: 'artificer',
      level: 2,
      plans: const ['returning-weapon', 'repeating-shot'],
    );
    expect(
      InventoryOps.replicateMagicItem(
        c,
        'returning-weapon',
        repo,
        baseItemId: 'longsword',
      ).inventory,
      isEmpty,
    );
    expect(
      InventoryOps.replicateMagicItem(
        c,
        'repeating-shot',
        repo,
        baseItemId: 'dagger',
      ).inventory,
      isEmpty,
    );
    expect(
      InventoryOps.replicateMagicItem(
        c,
        'returning-weapon',
        repo,
        baseItemId: 'dagger',
      ).inventory.single.baseItemId,
      'dagger',
    );
  });

  test('los planes abiertos de EFA respetan rareza, tipo y nivel', () {
    ItemChoiceSlot slotAt(int level) => CharacterCompiler(repo)
        .compile(_character(classId: 'artificer', level: level))
        .itemChoiceSlots
        .single;

    final level2 = slotAt(2);
    expect(level2.count, 4);
    expect(level2.maxActive, 2);
    expect(level2.optionItemIds, contains('abalorio-de-nutricion'));
    expect(level2.optionItemIds, isNot(contains('pocion-de-trepar')));
    expect(level2.optionItemIds, isNot(contains('pergamino-de-conjuro')));

    final level10 = slotAt(10);
    expect(level10.count, 6);
    expect(level10.maxActive, 4);
    expect(level10.optionItemIds, contains('aljaba-eficiente'));

    final level14 = slotAt(14);
    expect(level14.count, 7);
    expect(level14.maxActive, 5);
    expect(level14.optionItemIds, contains('anillo-de-proteccion'));
    expect(
        level14.optionItemIds, isNot(contains('armadura-de-vulnerabilidad')));
  });

  test('cambiar un plano elimina solo su réplica', () {
    final c = _character(
      classId: 'artificer',
      level: 2,
      plans: const ['returning-weapon', 'manifold-tool'],
      inventory: const [
        InventoryEntry(
          itemId: 'returning-weapon',
          baseItemId: 'dagger',
          origin: 'artificer:replicate-magic-item:returning-weapon',
        ),
        InventoryEntry(
          itemId: 'manifold-tool',
          origin: 'artificer:replicate-magic-item:manifold-tool',
        ),
      ],
    );
    final changed = InventoryOps.replaceMagicItemChoice(
      c,
      'returning-weapon',
      'repeating-shot',
    );
    expect(changed.inventory.map((e) => e.itemId), ['manifold-tool']);
  });
}
