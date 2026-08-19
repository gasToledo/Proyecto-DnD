import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    final base = repo.weapon('longsword')!;
    repo.items['test-magic-longsword'] = Item(
      id: 'test-magic-longsword',
      name: 'Espada de prueba +1',
      source: ContentSource.homebrew,
      category: 'magic',
      rarity: 'uncommon',
      magicBonus: 1,
      baseItemKind: 'weapon',
      eligibleBaseItemIds: [base.id],
    );
    repo.feats['test-magic-weapon-intelligence'] = const Feat(
      id: 'test-magic-weapon-intelligence',
      name: 'Arma arcana de prueba',
      source: ContentSource.homebrew,
      category: 'general',
      effects: [
        WeaponRuleEffect(
          filter: WeaponFilter(magic: true),
          grantsProficiency: true,
          abilityOptions: [Ability.intelligence],
          damageTypeOptions: ['force'],
          spellcastingFocus: true,
        ),
      ],
    );
    repo.feats['test-targeted-weapon'] = const Feat(
      id: 'test-targeted-weapon',
      name: 'Vínculo de arma de prueba',
      source: ContentSource.homebrew,
      category: 'general',
      effects: [
        TargetChoiceEffect(
          groupId: 'test-weapon-bond',
          name: 'Arma vinculada',
          replaceable: true,
          existingFilter: WeaponFilter(),
          createFilter: WeaponFilter(melee: true),
        ),
        WeaponRuleEffect(
          targetGroupId: 'test-weapon-bond',
          grantsProficiency: true,
          abilityOptions: [Ability.charisma],
          spellcastingFocus: true,
        ),
      ],
    );
    compiler = CharacterCompiler(repo);
  });

  tearDownAll(() {
    repo.items.remove('test-magic-longsword');
    repo.feats.remove('test-magic-weapon-intelligence');
    repo.feats.remove('test-targeted-weapon');
  });

  Character wizard({bool withRule = false, bool magic = true}) => Character(
        id: 'weapon-rule-probe',
        name: 'Prueba',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        assignedScores: const {
          Ability.strength: 8,
          Ability.dexterity: 12,
          Ability.constitution: 14,
          Ability.intelligence: 18,
          Ability.wisdom: 10,
          Ability.charisma: 10,
        },
        featIds: withRule ? const ['test-magic-weapon-intelligence'] : const [],
        hpPerLevel: const [6],
        inventory: [
          InventoryEntry(
            entryId: magic ? 'magic-sword' : 'mundane-sword',
            itemId: magic ? 'test-magic-longsword' : 'longsword',
            baseItemId: magic ? 'longsword' : null,
            equipped: true,
          ),
        ],
      );

  Character targetedWizard({List<String> targets = const []}) => Character(
        id: 'target-rule-probe',
        name: 'Prueba dirigida',
        raceId: 'human',
        classId: 'wizard',
        backgroundId: 'sage',
        assignedScores: const {
          Ability.strength: 8,
          Ability.dexterity: 12,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 10,
          Ability.charisma: 18,
        },
        featIds: const ['test-targeted-weapon'],
        effectTargets: {'test-weapon-bond': targets},
        hpPerLevel: const [6],
        inventory: const [
          InventoryEntry(
            entryId: 'sword-a',
            itemId: 'longsword',
            equipped: true,
          ),
          InventoryEntry(
            entryId: 'sword-b',
            itemId: 'longsword',
            equipped: true,
          ),
        ],
      );

  Character pactWarlock({
    int level = 1,
    List<String> invocations = const ['pact-of-the-blade'],
    List<InventoryEntry> inventory = const [],
    Map<String, List<String>> effectTargets = const {},
  }) =>
      Character(
        id: 'pact-warlock',
        name: 'Brujo del Filo',
        raceId: 'human',
        classId: 'warlock',
        backgroundId: 'sage',
        level: level,
        assignedScores: const {
          Ability.strength: 8,
          Ability.dexterity: 14,
          Ability.constitution: 14,
          Ability.intelligence: 10,
          Ability.wisdom: 10,
          Ability.charisma: 18,
        },
        featureChoices: {'warlock-invocation': invocations},
        effectTargets: effectTargets,
        hpPerLevel: List.filled(level, 8),
        inventory: inventory,
      );

  test('sin reglas nuevas conserva el cálculo normal del arma', () {
    final attack = compiler.compile(wizard()).attacks.single;
    expect(attack.abilityUsed, Ability.strength);
    expect(attack.proficient, isFalse);
    expect(attack.attackBonus, 0, reason: 'FUE -1 + arma mágica +1');
    expect(attack.damage, '1d8');
    expect(attack.damageTypeOptions, ['slashing']);
    expect(attack.spellcastingFocus, isFalse);
    expect(attack.attacksPerAction, 1);
  });

  test('una regla estática se aplica por filtro, no por clase', () {
    final attack = compiler.compile(wizard(withRule: true)).attacks.single;
    expect(attack.abilityUsed, Ability.intelligence);
    expect(attack.proficient, isTrue);
    expect(attack.attackBonus, 7, reason: 'INT +4 + competencia +2 + magia +1');
    expect(attack.damage, '1d8 + 5');
    expect(attack.damageTypeOptions, ['slashing', 'force']);
    expect(attack.spellcastingFocus, isTrue);
  });

  test('el filtro mágico no se derrama sobre un arma mundana', () {
    final attack =
        compiler.compile(wizard(withRule: true, magic: false)).attacks.single;
    expect(attack.abilityUsed, Ability.strength);
    expect(attack.proficient, isFalse);
    expect(attack.attackBonus, -1);
    expect(attack.damageTypeOptions, ['slashing']);
  });

  test('WeaponRuleEffect conserva su contrato al serializar', () {
    final effect = Effect.fromJson(const {
      'type': 'weaponRule',
      'filter': {
        'magic': true,
        'melee': true,
        'categories': ['martial'],
      },
      'grantsProficiency': true,
      'abilityOptions': ['charisma'],
      'damageTypeOptions': ['necrotic'],
      'spellcastingFocus': true,
      'extraAttacks': 1,
    }) as WeaponRuleEffect;

    expect(effect.filter.magic, isTrue);
    expect(effect.filter.melee, isTrue);
    expect(effect.filter.categories, ['martial']);
    expect(effect.abilityOptions, [Ability.charisma]);
    expect(effect.toJson(), {
      'type': 'weaponRule',
      'filter': {
        'magic': true,
        'melee': true,
        'categories': ['martial'],
      },
      'grantsProficiency': true,
      'abilityOptions': ['charisma'],
      'damageTypeOptions': ['necrotic'],
      'spellcastingFocus': true,
      'extraAttacks': 1,
    });
  });

  test('una regla dirigida solo modifica el ejemplar elegido', () {
    final sheet = compiler.compile(targetedWizard(targets: ['sword-b']));
    final first =
        sheet.attacks.singleWhere((a) => a.sourceEntryId == 'sword-a');
    final selected =
        sheet.attacks.singleWhere((a) => a.sourceEntryId == 'sword-b');

    expect(first.abilityUsed, Ability.strength);
    expect(first.proficient, isFalse);
    expect(first.attackBonus, -1);
    expect(selected.abilityUsed, Ability.charisma);
    expect(selected.proficient, isTrue);
    expect(selected.attackBonus, 6);
    expect(selected.spellcastingFocus, isTrue);

    final slot = sheet.targetChoiceSlots.single;
    expect(slot.eligibleEntryIds, ['sword-a', 'sword-b']);
    expect(slot.chosenEntryIds, ['sword-b']);
    expect(slot.pending, 0);
    expect(slot.creatableWeaponIds, contains('longsword'));
  });

  test('un objetivo huérfano se ignora sin derramar la regla', () {
    final sheet = compiler.compile(targetedWizard(targets: ['no-existe']));

    expect(sheet.attacks.every((a) => !a.proficient), isTrue);
    expect(
        sheet.attacks.every((a) => a.abilityUsed == Ability.strength), isTrue);
    expect(sheet.targetChoiceSlots.single.chosenEntryIds, isEmpty);
    expect(sheet.targetChoiceSlots.single.pending, 1);
  });

  test('crear y limpiar un objetivo solo elimina el ejemplar generado', () {
    final original = targetedWizard().copyWith(
      inventory: const [
        InventoryEntry(entryId: 'owned-rapier', itemId: 'rapier'),
      ],
    );

    final linked = InventoryOps.createEffectTarget(
      original,
      'test-weapon-bond',
      'rapier',
      repo,
    );
    final generated = linked.inventory.singleWhere(
      (e) => e.origin == 'effect-target:test-weapon-bond',
    );
    expect(linked.effectTargets['test-weapon-bond'], [generated.entryId]);
    expect(generated.equipped, isTrue);
    expect(linked.inventory.where((e) => e.itemId == 'rapier'), hasLength(2));

    final cleared = InventoryOps.clearEffectTargets(linked, 'test-weapon-bond');
    expect(cleared.effectTargets, isEmpty);
    expect(cleared.inventory.map((e) => e.entryId), ['owned-rapier']);
  });

  test('quitar un ejemplar limpia sus vínculos contextuales', () {
    final original = targetedWizard(targets: ['sword-a']);
    final removed = InventoryOps.remove(original, 'sword-a', repo);

    expect(removed.effectTargets, isEmpty);
    expect(removed.inventory.map((e) => e.entryId), ['sword-b']);
  });

  test('TargetChoiceEffect distingue una vía ausente de un filtro vacío', () {
    final effect = Effect.fromJson(const {
      'type': 'targetChoice',
      'groupId': 'bond',
      'name': 'Vínculo',
      'count': 2,
      'replaceable': true,
      'existingFilter': {},
    }) as TargetChoiceEffect;

    expect(effect.existingFilter, isNotNull);
    expect(effect.existingFilter!.isEmpty, isTrue);
    expect(effect.createFilter, isNull);
    expect(effect.toJson(), {
      'type': 'targetChoice',
      'groupId': 'bond',
      'name': 'Vínculo',
      'count': 2,
      'replaceable': true,
      'existingFilter': {},
    });
  });

  group('Pacto del Filo usa el mecanismo genérico', () {
    test('ofrece conjurar un estoque pero no vincula uno mundano', () {
      final character = pactWarlock(
        inventory: const [
          InventoryEntry(entryId: 'owned-rapier', itemId: 'rapier'),
        ],
      );
      final slot = compiler.compile(character).targetChoiceSlots.single;

      expect(slot.groupId, 'pact-weapon');
      expect(slot.eligibleEntryIds, isNot(contains('owned-rapier')));
      expect(slot.creatableWeaponIds, contains('rapier'));
    });

    test('el estoque conjurado usa competencia y Carisma solo en ese PJ', () {
      final linked = InventoryOps.createEffectTarget(
        pactWarlock(),
        'pact-weapon',
        'rapier',
        repo,
      );
      final attack = compiler.compile(linked).attacks.single;

      expect(attack.baseWeaponId, 'rapier');
      expect(attack.proficient, isTrue);
      expect(attack.abilityUsed, Ability.charisma);
      expect(attack.attackBonus, 6);
      expect(attack.damageTypeOptions, [
        'piercing',
        'necrotic',
        'psychic',
        'radiant',
      ]);
      expect(attack.spellcastingFocus, isTrue);

      final withoutPact = linked.copyWith(
        featureChoices: const {},
      );
      final ordinaryAttack = compiler.compile(withoutPact).attacks.single;
      expect(ordinaryAttack.proficient, isFalse);
      expect(ordinaryAttack.abilityUsed, Ability.dexterity);
      expect(ordinaryAttack.attackBonus, 2);
    });

    test('Filo Sediento y Hoja Devoradora escalan solo el arma vinculada', () {
      Character linkedAt(int level, List<String> invocations) {
        final base = pactWarlock(level: level, invocations: invocations);
        return InventoryOps.createEffectTarget(
          base,
          'pact-weapon',
          'rapier',
          repo,
        );
      }

      final thirsty = compiler.compile(linkedAt(5, const [
        'pact-of-the-blade',
        'thirsting-blade',
      ]));
      expect(thirsty.attacks.single.attacksPerAction, 2);
      expect(thirsty.attacksPerAction, 1);

      final devouring = compiler.compile(linkedAt(12, const [
        'pact-of-the-blade',
        'thirsting-blade',
        'devouring-blade',
      ]));
      expect(devouring.attacks.single.attacksPerAction, 3);
      expect(devouring.attacksPerAction, 1);
    });
  });
}
