import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Personaje mínimo sobre el catálogo real: lo que se prueba acá es la mochila,
/// así que la clase y la especie solo tienen que existir.
Character _guerrera({
  List<InventoryEntry> inventory = const [],
  Map<String, int> coins = const {},
  int strength = 10,
  String? armorId,
  bool shield = false,
  List<String> weapons = const [],
}) =>
    Character(
      id: 'mochila',
      name: 'Guerrera',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {
        Ability.strength: strength,
        Ability.dexterity: 10,
        Ability.constitution: 10,
        Ability.intelligence: 10,
        Ability.wisdom: 10,
        Ability.charisma: 10,
      },
      hpPerLevel: const [10],
      inventory: inventory,
      coins: coins,
      equippedArmorId: armorId,
      shieldEquipped: shield,
      equippedWeaponIds: weapons,
    );

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('carga', () {
    test('suma el peso de cada línea por su cantidad', () {
      // 20 flechas = 1 lb la unidad de compra, y la unidad es el paquete de 20.
      // 5 antorchas = 5 lb. 1 cuerda = 5 lb.
      final c = _guerrera(
        inventory: const [
          InventoryEntry(itemId: 'arrows', quantity: 2),
          InventoryEntry(itemId: 'torch', quantity: 5),
          InventoryEntry(itemId: 'rope'),
        ],
      );

      expect(InventoryOps.carriedWeight(c, repo), 2 + 5 + 5);
    });

    test('las monedas pesan: 50 hacen una libra', () {
      final c = _guerrera(coins: const {'gp': 100, 'sp': 50});

      expect(InventoryOps.carriedWeight(c, repo), 3);
    });

    test('un id que no está en ningún catálogo pesa cero y no rompe', () {
      // Puede ser homebrew que todavía no se cargó. Una ficha que no abre es
      // peor que un peso incompleto.
      final c = _guerrera(
        inventory: const [
          InventoryEntry(itemId: 'espada-del-abuelo'),
          InventoryEntry(itemId: 'rope'),
        ],
      );

      expect(InventoryOps.carriedWeight(c, repo), 5);
    });

    test('la capacidad es Fuerza por 15 y el aviso llega al pasarse', () {
      final sheet = CharacterCompiler(repo).compile(
        _guerrera(
          strength: 10,
          inventory: const [InventoryEntry(itemId: 'barrel', quantity: 3)],
        ),
      );

      expect(sheet.carryingCapacity, 150);
      expect(sheet.carriedWeight, 210);
      expect(sheet.isEncumbered, isTrue);

      final avisos = CharacterValidator(repo).validate(
        _guerrera(
          strength: 10,
          inventory: const [InventoryEntry(itemId: 'barrel', quantity: 3)],
        ),
      );
      expect(
        avisos.where((a) => a.code == 'encumbered').single.message,
        'Llevás 210 lb y tu capacidad es 150 lb.',
      );
    });

    test('sin pasarse no hay aviso', () {
      final avisos = CharacterValidator(repo).validate(
        _guerrera(inventory: const [InventoryEntry(itemId: 'rope')]),
      );

      expect(avisos.where((a) => a.code == 'encumbered'), isEmpty);
    });
  });

  group('bono mágico del arma', () {
    test('suma al ataque y al daño', () {
      final base = repo.weapon('longsword')!;
      final magica = Weapon(
        id: 'espada-larga-1',
        name: 'Espada larga +1',
        source: ContentSource.homebrew,
        category: base.category,
        damageDice: base.damageDice,
        damageType: base.damageType,
        properties: base.properties,
        versatileDice: base.versatileDice,
        mastery: base.mastery,
        magicBonus: 1,
      );
      repo.weapons[magica.id] = magica;
      addTearDown(() => repo.weapons.remove(magica.id));

      final normal = CharacterCompiler(repo)
          .compile(_guerrera(strength: 16, weapons: const ['longsword']))
          .attacks
          .single;
      final conBono = CharacterCompiler(repo)
          .compile(_guerrera(strength: 16, weapons: const ['espada-larga-1']))
          .attacks
          .single;

      expect(conBono.attackBonus, normal.attackBonus + 1);
      expect(normal.damage, '1d8 + 3');
      expect(conBono.damage, '1d8 + 4');
    });
  });

  group('efectos de objeto', () {
    Item capa({bool requiresAttunement = true}) => Item(
          id: 'capa-de-proteccion',
          name: 'Capa de protección',
          source: ContentSource.homebrew,
          category: 'magic',
          rarity: 'uncommon',
          requiresAttunement: requiresAttunement,
          effects: const [ArmorClassBonusEffect(1)],
        );

    int caCon(InventoryEntry entry, {bool requiresAttunement = true}) {
      final item = capa(requiresAttunement: requiresAttunement);
      repo.items[item.id] = item;
      addTearDown(() => repo.items.remove(item.id));
      return CharacterCompiler(repo)
          .compile(_guerrera(inventory: [entry]))
          .armorClass;
    }

    test('no aplica si el objeto está en la mochila pero no puesto', () {
      expect(caCon(const InventoryEntry(itemId: 'capa-de-proteccion')), 10);
    });

    test('no aplica si lo exige y no está sintonizado', () {
      expect(
        caCon(
          const InventoryEntry(itemId: 'capa-de-proteccion', equipped: true),
        ),
        10,
      );
    });

    test('aplica puesto y sintonizado', () {
      expect(
        caCon(
          const InventoryEntry(
            itemId: 'capa-de-proteccion',
            equipped: true,
            attuned: true,
          ),
        ),
        11,
      );
    });

    test('un objeto que no exige sintonización alcanza con llevarlo puesto',
        () {
      expect(
        caCon(
          const InventoryEntry(itemId: 'capa-de-proteccion', equipped: true),
          requiresAttunement: false,
        ),
        11,
      );
    });
  });

  group('sintonización', () {
    const ids = ['anillo-1', 'anillo-2', 'anillo-3', 'anillo-4'];

    setUp(() {
      for (final id in ids) {
        repo.items[id] = Item(
          id: id,
          name: id,
          source: ContentSource.homebrew,
          category: 'magic',
          rarity: 'uncommon',
          requiresAttunement: true,
        );
      }
    });

    tearDown(() {
      for (final id in ids) {
        repo.items.remove(id);
      }
    });

    test('cuatro objetos sintonizados avisan del límite de tres', () {
      final avisos = CharacterValidator(repo).validate(
        _guerrera(
          inventory: const [
            InventoryEntry(itemId: 'anillo-1', attuned: true),
            InventoryEntry(itemId: 'anillo-2', attuned: true),
            InventoryEntry(itemId: 'anillo-3', attuned: true),
            InventoryEntry(itemId: 'anillo-4', attuned: true),
          ],
        ),
      );

      expect(
        avisos.where((a) => a.code == 'attunement_over_limit').single.message,
        'Tenés 4 objetos sintonizados y solo podés mantener 3.',
      );
    });

    test('tres no avisan', () {
      final avisos = CharacterValidator(repo).validate(
        _guerrera(
          inventory: const [
            InventoryEntry(itemId: 'anillo-1', attuned: true),
            InventoryEntry(itemId: 'anillo-2', attuned: true),
            InventoryEntry(itemId: 'anillo-3', attuned: true),
          ],
        ),
      );

      expect(avisos.where((a) => a.code == 'attunement_over_limit'), isEmpty);
    });

    test('un flag viejo sobre un objeto mundano no ocupa espacio', () {
      final c = _guerrera(
        inventory: const [InventoryEntry(itemId: 'orb', attuned: true)],
      );

      expect(InventoryOps.attunedCount(c, repo), 0);
    });
  });

  group('equipar desde la mochila', () {
    test('para un arma manda la lista de equipadas, no la entrada', () {
      final c = _guerrera(
        inventory: const [InventoryEntry(itemId: 'club', equipped: true)],
      );

      expect(
        InventoryOps.isEquipped(c, c.inventory.single, repo),
        isFalse,
        reason: 'la entrada dice que sí pero el arma no está empuñada',
      );

      final equipada = InventoryOps.setEquipped(c, 'club', true, repo);
      expect(equipada.equippedWeaponIds, ['club']);
      expect(
        InventoryOps.isEquipped(
          equipada,
          equipada.inventory.single,
          repo,
        ),
        isTrue,
      );
    });

    test('el escudo escribe en su propio campo', () {
      final c = InventoryOps.setEquipped(
        _guerrera(inventory: const [InventoryEntry(itemId: 'shield')]),
        'shield',
        true,
        repo,
      );

      expect(c.shieldEquipped, isTrue);
      expect(c.equippedArmorId, isNull);
    });

    test('una armadura nueva desplaza a la puesta', () {
      final c = InventoryOps.setEquipped(
        _guerrera(armorId: 'leather'),
        'plate',
        true,
        repo,
      );

      expect(c.equippedArmorId, 'plate');
    });

    test('para un objeto manda la entrada', () {
      final c = InventoryOps.setEquipped(
        _guerrera(inventory: const [InventoryEntry(itemId: 'backpack')]),
        'backpack',
        true,
        repo,
      );

      expect(InventoryOps.isEquipped(c, c.inventory.single, repo), isTrue);
    });
  });

  group('alta y baja', () {
    test('agregar dos veces junta la cantidad en una sola línea', () {
      var c = _guerrera();
      c = InventoryOps.add(c, 'torch', quantity: 3);
      c = InventoryOps.add(c, 'torch', quantity: 2);

      expect(c.inventory, hasLength(1));
      expect(c.inventory.single.quantity, 5);
    });

    test('sacar de más borra la línea y desequipa', () {
      var c = _guerrera(
        armorId: 'plate',
        weapons: const ['club'],
        inventory: const [
          InventoryEntry(itemId: 'plate'),
          InventoryEntry(itemId: 'club'),
        ],
      );
      c = InventoryOps.remove(c, 'plate', repo);
      c = InventoryOps.remove(c, 'club', repo);

      expect(c.inventory, isEmpty);
      expect(c.equippedArmorId, isNull);
      expect(c.equippedWeaponIds, isEmpty);
    });

    test('quitar un escudo homebrew también lo desequipa', () {
      const id = 'hb-escudo-torre';
      repo.armor[id] = const Armor(
        id: id,
        name: 'Escudo torre',
        source: ContentSource.homebrew,
        category: 'shield',
        baseAc: 2,
      );
      addTearDown(() => repo.armor.remove(id));

      var c = _guerrera(inventory: const [InventoryEntry(itemId: id)]);
      c = InventoryOps.setEquipped(c, id, true, repo);
      c = InventoryOps.remove(c, id, repo);

      expect(c.shieldEquipped, isFalse);
      expect(InventoryOps.entries(c, repo), isEmpty);
    });

    test('sacar de a poco deja el resto', () {
      var c = InventoryOps.add(_guerrera(), 'arrows', quantity: 4);
      c = InventoryOps.remove(c, 'arrows', repo);

      expect(c.inventory.single.quantity, 3);
    });
  });

  group('formato de precio', () {
    test('elige la denominación más grande que no deje fracción', () {
      expect(formatCost(1500), '15 po');
      expect(formatCost(150), '15 pp');
      expect(formatCost(50), '5 pp', reason: 'el electro no se ofrece nunca');
      expect(formatCost(5), '5 pc');
      expect(formatCost(155), '155 pc', reason: 'no entra redondo en plata');
      expect(formatCost(100000), '1000 po');
      expect(formatCost(0), '—');
    });

    test('el peso conserva cuartos y centésimas sin ceros finales', () {
      expect(formatPounds(1), '1');
      expect(formatPounds(1.5), '1.5');
      expect(formatPounds(0.25), '0.25');
      expect(formatPounds(0.02), '0.02');
    });
  });
}
