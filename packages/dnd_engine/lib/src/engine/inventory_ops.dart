import '../data/content_repository.dart';
import 'dice.dart';
import '../domain/character.dart';
import '../domain/content.dart';

/// Operaciones sobre la mochila. Puras: no mutan, devuelven una ficha nueva.
///
/// Existen porque "¿este objeto está equipado?" tiene dos respuestas posibles
/// según de qué catálogo salga el id, y esa decisión no puede estar repetida en
/// la ficha, el compilador y la validación: en cuanto una de las tres se
/// desincronice, el jugador ve una casilla tildada que no le está sumando la CA.
const shieldItemId = 'shield';

/// Valor de `Item.rechargeAmount` para los objetos que recuperan todas sus
/// cargas de una vez en vez de tirar una fórmula (los Anteojos de
/// encantamiento). Es palabra y no un booleano aparte porque el campo ya es
/// texto y así el JSON del catálogo se lee como el manual.
const todasLasCargas = 'todas';

int artificerReplicasAtLevel(int level) => switch (level) {
      < 2 => 0,
      < 6 => 2,
      < 10 => 3,
      < 14 => 4,
      < 18 => 5,
      _ => 6,
    };

class ResolvedInventoryEntry {
  final InventoryEntry entry;
  final Item? item;
  final Weapon? weapon;
  final Armor? armor;

  const ResolvedInventoryEntry({
    required this.entry,
    this.item,
    this.weapon,
    this.armor,
  });

  int get magicBonus => item?.magicBonus ?? 0;
  double get weight => weapon?.weight ?? armor?.weight ?? item?.weight ?? 0;
  int get costCp =>
      (item?.costCp ?? 0) + (weapon?.costCp ?? armor?.costCp ?? 0);
  String get name {
    if (item == null) return weapon?.name ?? armor?.name ?? entry.itemId;
    final base = weapon?.name ?? armor?.name;
    return base == null ? item!.name : '${item!.name} ($base)';
  }
}

class InventoryOps {
  static String _effectTargetOrigin(String groupId) => 'effect-target:$groupId';

  static String _uniqueEntryId(Character c, String itemId) {
    var suffix = c.inventory.length;
    var candidate = 'entry-$suffix-$itemId';
    final used = c.inventory.map((e) => e.entryId).toSet();
    while (used.contains(candidate)) {
      suffix++;
      candidate = 'entry-$suffix-$itemId';
    }
    return candidate;
  }

  /// Si la entrada cuenta como equipada.
  ///
  static bool isEquipped(
    Character c,
    InventoryEntry entry,
    ContentRepository repo,
  ) {
    return entry.equipped;
  }

  static ResolvedInventoryEntry resolve(
    InventoryEntry entry,
    ContentRepository repo,
  ) {
    final item = repo.item(entry.itemId);
    final baseId = entry.baseItemId;
    return ResolvedInventoryEntry(
      entry: entry,
      item: item,
      weapon: repo.weapon(baseId ?? (item == null ? entry.itemId : '')),
      armor: repo.armorPiece(baseId ?? (item == null ? entry.itemId : '')),
    );
  }

  /// Equipa o desequipa [itemId], escribiendo en el campo que corresponda.
  ///
  /// Una armadura desplaza a la anterior porque solo se puede llevar una
  /// puesta; las armas se acumulan porque la ficha lista todas las que tenés a
  /// mano, no solo la que estás blandiendo.
  static Character setEquipped(
    Character c,
    String itemId,
    bool value,
    ContentRepository repo,
  ) {
    final targetIndex = c.inventory.indexWhere(
      (e) => e.entryId == itemId || e.itemId == itemId,
    );
    if (targetIndex < 0) return c;
    final target = resolve(c.inventory[targetIndex], repo);
    final inventory = [
      for (final (index, e) in c.inventory.indexed)
        if (index == targetIndex)
          e.copyWith(equipped: value)
        else if (value &&
            target.armor != null &&
            resolve(e, repo).armor != null &&
            resolve(e, repo).armor!.isShield == target.armor!.isShield)
          e.copyWith(equipped: false)
        else
          e,
    ];
    if (target.armor?.isShield == true) {
      return c.copyWith(inventory: inventory, shieldEquipped: value);
    }
    if (target.armor != null) {
      return c.copyWith(
        inventory: inventory,
        equippedArmorId:
            value && target.item == null ? target.entry.itemId : null,
      );
    }
    if (target.weapon != null) {
      final legacy = [...c.equippedWeaponIds]..remove(target.entry.itemId);
      if (value && target.item == null) legacy.add(target.entry.itemId);
      return c.copyWith(inventory: inventory, equippedWeaponIds: legacy);
    }
    return c.copyWith(inventory: inventory);
  }

  /// Suma [quantity] unidades de [itemId], juntándolas con la línea que ya
  /// exista. Una segunda línea del mismo objeto haría que la ficha mostrara
  /// "Antorcha 3" y "Antorcha 5" sin que ninguna de las dos sea el total.
  static Character add(
    Character c,
    String itemId, {
    int quantity = 1,
    String? baseItemId,
    String? origin,
  }) {
    final canStack = baseItemId == null && origin == null;
    final index = canStack
        ? c.inventory.indexWhere((e) =>
            e.itemId == itemId &&
            e.baseItemId == null &&
            e.origin == null &&
            !e.equipped &&
            !e.attuned &&
            e.note.isEmpty)
        : -1;
    if (index < 0) {
      final next = c.inventory.length;
      return c.copyWith(
        inventory: [
          ...c.inventory,
          InventoryEntry(
            entryId: 'entry-$next-$itemId',
            itemId: itemId,
            baseItemId: baseItemId,
            origin: origin,
            quantity: quantity,
          ),
        ],
      );
    }
    final existing = c.inventory[index];
    return c.copyWith(
      inventory: [
        for (var i = 0; i < c.inventory.length; i++)
          i == index
              ? existing.copyWith(quantity: existing.quantity + quantity)
              : c.inventory[i],
      ],
    );
  }

  /// Vincula un ejemplar existente a un grupo contextual. Si el cupo está
  /// lleno reemplaza la última elección; solo borra inventario cuando el
  /// ejemplar desplazado había sido creado por este mismo grupo.
  static Character setEffectTarget(
    Character c,
    String groupId,
    String entryId, {
    int count = 1,
  }) {
    if (count < 1) return clearEffectTargets(c, groupId);
    if (!c.inventory.any((e) => e.entryId == entryId)) return c;

    final inventoryIds = c.inventory.map((e) => e.entryId).toSet();
    final current = <String>[];
    for (final id in c.effectTargets[groupId] ?? const <String>[]) {
      if (inventoryIds.contains(id) && !current.contains(id)) current.add(id);
    }
    final alreadyWithinLimit = current.take(count).contains(entryId);
    final next = alreadyWithinLimit
        ? current.take(count).toList()
        : count == 1
            ? <String>[entryId]
            : <String>[...current.take(count - 1), entryId];
    final displaced = current.where((id) => !next.contains(id)).toSet();
    final origin = _effectTargetOrigin(groupId);

    return c.copyWith(
      inventory: [
        for (final entry in c.inventory)
          if (!(displaced.contains(entry.entryId) && entry.origin == origin))
            entry,
      ],
      effectTargets: {...c.effectTargets, groupId: next},
    );
  }

  /// Crea un arma contextual desde el catálogo y la vincula al grupo. La
  /// procedencia permite reemplazarla o limpiarla sin tocar objetos del PJ.
  static Character createEffectTarget(
    Character c,
    String groupId,
    String weaponId,
    ContentRepository repo, {
    int count = 1,
    bool equipped = true,
  }) {
    if (repo.weapon(weaponId) == null || count < 1) return c;
    final entryId = _uniqueEntryId(c, weaponId);
    final withEntry = c.copyWith(inventory: [
      ...c.inventory,
      InventoryEntry(
        entryId: entryId,
        itemId: weaponId,
        origin: _effectTargetOrigin(groupId),
        equipped: equipped,
      ),
    ]);
    return setEffectTarget(withEntry, groupId, entryId, count: count);
  }

  /// Limpia el vínculo y únicamente los ejemplares generados por ese grupo.
  /// Las armas que ya pertenecían al personaje se conservan intactas.
  static Character clearEffectTargets(Character c, String groupId) {
    final origin = _effectTargetOrigin(groupId);
    return c.copyWith(
      inventory: [
        for (final e in c.inventory)
          if (e.origin != origin) e
      ],
      effectTargets: {
        for (final entry in c.effectTargets.entries)
          if (entry.key != groupId) entry.key: entry.value,
      },
    );
  }

  /// Saca [quantity] unidades, y la línea entera si no queda ninguna. Al llegar
  /// a cero también desequipa: un objeto que ya no llevás no puede seguir
  /// sumando a la CA.
  static Character remove(
    Character c,
    String itemId,
    ContentRepository repo, {
    int quantity = 1,
  }) {
    final index = c.inventory.indexWhere(
      (e) => e.entryId == itemId || e.itemId == itemId,
    );
    if (index < 0) return c;
    final left = c.inventory[index].quantity - quantity;
    if (left > 0) {
      return c.copyWith(
        inventory: [
          for (var i = 0; i < c.inventory.length; i++)
            i == index
                ? c.inventory[i].copyWith(quantity: left)
                : c.inventory[i],
        ],
      );
    }
    final without = [...c.inventory]..removeAt(index);
    final removed = resolve(c.inventory[index], repo);
    return c.copyWith(
      inventory: without,
      effectTargets: {
        for (final target in c.effectTargets.entries)
          if (target.value.any((id) => id != removed.entry.entryId))
            target.key: [
              for (final id in target.value)
                if (id != removed.entry.entryId) id,
            ],
      },
      equippedArmorId:
          c.equippedArmorId == removed.entry.itemId ? null : c.equippedArmorId,
      shieldEquipped:
          removed.armor?.isShield == true ? false : c.shieldEquipped,
      equippedWeaponIds: [
        for (final id in c.equippedWeaponIds)
          if (id != removed.entry.itemId) id,
      ],
    );
  }

  /// Lo que el personaje lleva encima, incluyendo lo que está equipado aunque
  /// nadie le haya agregado su línea.
  ///
  /// Los cinco campos de equipado se pueden escribir sin tocar el inventario
  /// —lo hacen el asistente de creación, las fichas de demostración y cualquier
  /// importación vieja—, y una mochila que no muestra la armadura que tenés
  /// puesta es una mochila que miente. Derivarlo acá lo arregla de una vez, en
  /// lugar de exigirle a cada lugar que construye un personaje que se acuerde.
  static List<InventoryEntry> entries(Character c, ContentRepository repo) {
    return c.inventory;
  }

  /// Cuántos objetos que realmente exigen sintonización tiene sintonizados la
  /// ficha. Un flag viejo sobre un objeto mundano u huérfano no ocupa espacio.
  static int attunedCount(Character c, ContentRepository repo) => c.inventory
      .where(
          (e) => e.attuned && repo.item(e.itemId)?.requiresAttunement == true)
      .length;

  /// Peso total en libras de la mochila, monedas incluidas.
  ///
  /// Un id que no está en ningún catálogo pesa cero en vez de hacer fallar el
  /// cálculo: puede ser un objeto homebrew que todavía no se cargó, y una ficha
  /// que no abre es peor que una carga incompleta.
  static double carriedWeight(Character c, ContentRepository repo) {
    var total = 0.0;
    for (final e in entries(c, repo)) {
      total += resolve(e, repo).weight * e.quantity;
    }
    final coins = c.coins.values.fold(0, (a, b) => a + b);
    return total + coins / coinsPerPound;
  }

  /// Cargas que le quedan a [e]: las anotadas, o el máximo del catálogo si
  /// nunca se tocaron. null cuando el objeto no funciona con cargas.
  ///
  /// La lee la ficha y la recarga, y las dos tienen que resolver "sin anotar"
  /// igual o el primer gasto haría saltar el contador de 0 a 9.
  static int? chargesLeft(InventoryEntry e, ContentRepository repo) {
    final max = repo.item(e.itemId)?.maxCharges;
    if (max == null) return null;
    return e.charges ?? max;
  }

  /// Recupera las cargas de todo lo que se recarga al amanecer, tirando la
  /// fórmula de cada objeto. Devuelve la ficha nueva y cuántos objetos tocó.
  ///
  /// Nunca pasa del máximo y nunca baja: una tirada de 1d6 + 4 sobre un bastón
  /// al que solo le falta una carga le devuelve esa y nada más.
  ///
  /// ponytail: se dispara con el descanso largo y no con el amanecer, que es lo
  /// que dice la regla. Coinciden casi siempre —el descanso dura 8 horas— pero
  /// no cuando la mesa descansa de día. Modelar la hora del día es lo que hace
  /// falta para separarlos, y hoy el proyecto no tiene reloj.
  static (Character, int) rechargeAtDawn(
    Character c,
    ContentRepository repo, {
    Dice? dice,
  }) {
    final roller = dice ?? Dice();
    var tocados = 0;
    final inventory = <InventoryEntry>[];
    for (final e in c.inventory) {
      final item = repo.item(e.itemId);
      final max = item?.maxCharges;
      final amount = item?.rechargeAmount;
      final actual = e.charges ?? max;
      // Sin máximo no hay cargas; sin fórmula el objeto no se recarga solo; con
      // máximo 0 la mesa lleva la cuenta y el motor no tiene qué techo aplicar.
      if (max == null ||
          max == 0 ||
          amount == null ||
          actual == null ||
          actual >= max) {
        inventory.add(e);
        continue;
      }
      final recuperadas = amount == todasLasCargas
          ? max
          : DiceFormula.tryParse(amount)?.roll(roller);
      // Una fórmula que no se entiende no inventa un resultado: el objeto queda
      // como estaba y el jugador lo sube a mano.
      if (recuperadas == null) {
        inventory.add(e);
        continue;
      }
      inventory.add(e.copyWith(charges: (actual + recuperadas).clamp(0, max)));
      tocados++;
    }
    return (c.copyWith(inventory: inventory), tocados);
  }

  /// Crea una réplica solo para un Artífice que conoce el plano y respeta el
  /// cupo simultáneo. La base se valida contra la plantilla.
  static Character replicateMagicItem(
    Character c,
    String itemId,
    ContentRepository repo, {
    String? baseItemId,
  }) {
    if (c.classId != 'artificer' ||
        c.level < 2 ||
        !c.magicItemChoices.contains(itemId)) return c;
    final item = repo.item(itemId);
    if (item == null) return c;
    final replicas = c.inventory.where(
      (e) => e.origin?.startsWith('artificer:replicate-magic-item:') == true,
    );
    if (replicas.length >= artificerReplicasAtLevel(c.level) ||
        replicas.any((e) => e.itemId == itemId)) return c;
    if (!_validBase(item, baseItemId, repo)) return c;
    return add(
      c,
      itemId,
      baseItemId: baseItemId,
      origin: 'artificer:replicate-magic-item:$itemId',
    );
  }

  /// Cambia un plano y elimina únicamente su réplica asociada.
  static Character replaceMagicItemChoice(
    Character c,
    String oldItemId,
    String newItemId,
  ) {
    final choices = [...c.magicItemChoices];
    final index = choices.indexOf(oldItemId);
    if (index < 0) return c;
    choices[index] = newItemId;
    return c.copyWith(
      magicItemChoices: choices.toSet().toList(),
      inventory: [
        for (final e in c.inventory)
          if (e.origin != 'artificer:replicate-magic-item:$oldItemId') e,
      ],
    );
  }

  /// Transmutar conserva identidad y estado del ejemplar, cambiando plantilla
  /// y base. El control de uso por descanso sigue descrito en el rasgo.
  static Character transmuteReplica(
    Character c,
    String entryId,
    String newItemId,
    ContentRepository repo, {
    String? baseItemId,
  }) {
    if (c.classId != 'artificer' || !c.magicItemChoices.contains(newItemId))
      return c;
    final item = repo.item(newItemId);
    if (item == null || !_validBase(item, baseItemId, repo)) return c;
    return c.copyWith(inventory: [
      for (final e in c.inventory)
        e.entryId == entryId &&
                e.origin?.startsWith('artificer:replicate-magic-item:') == true
            ? InventoryEntry(
                entryId: e.entryId,
                itemId: newItemId,
                baseItemId: baseItemId,
                origin: 'artificer:replicate-magic-item:$newItemId',
                quantity: 1,
                equipped: e.equipped,
                attuned: e.attuned,
                note: e.note,
              )
            : e,
    ]);
  }

  static bool _validBase(
    Item item,
    String? baseItemId,
    ContentRepository repo,
  ) {
    if (item.baseItemKind == null) return baseItemId == null;
    if (baseItemId == null ||
        item.eligibleBaseItemIds.isNotEmpty &&
            !item.eligibleBaseItemIds.contains(baseItemId)) return false;
    return switch (item.baseItemKind) {
      'weapon' => repo.weapon(baseItemId) != null,
      'armor' => repo.armorPiece(baseItemId)?.isShield == false,
      'shield' => repo.armorPiece(baseItemId)?.isShield == true,
      _ => false,
    };
  }
}
