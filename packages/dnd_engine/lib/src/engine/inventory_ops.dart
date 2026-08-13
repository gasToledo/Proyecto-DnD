import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/content.dart';

/// Operaciones sobre la mochila. Puras: no mutan, devuelven una ficha nueva.
///
/// Existen porque "¿este objeto está equipado?" tiene dos respuestas posibles
/// según de qué catálogo salga el id, y esa decisión no puede estar repetida en
/// la ficha, el compilador y la validación: en cuanto una de las tres se
/// desincronice, el jugador ve una casilla tildada que no le está sumando la CA.
/// Id del escudo del catálogo oficial. Existe como constante porque
/// `Character.shieldEquipped` es un bool: es el único escudo que se puede
/// reconstruir a partir de la ficha.
const shieldItemId = 'shield';

class InventoryOps {
  /// Si la entrada cuenta como equipada.
  ///
  /// Para armas y armaduras manda el equipo de la ficha, que es lo que lee el
  /// compilador; `InventoryEntry.equipped` solo decide para los objetos.
  static bool isEquipped(
    Character c,
    InventoryEntry entry,
    ContentRepository repo,
  ) {
    final armor = repo.armorPiece(entry.itemId);
    if (armor != null) {
      return armor.isShield
          ? c.shieldEquipped
          : c.equippedArmorId == entry.itemId;
    }
    if (repo.weapon(entry.itemId) != null) {
      return c.equippedWeaponIds.contains(entry.itemId);
    }
    return entry.equipped;
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
    final armor = repo.armorPiece(itemId);
    if (armor != null) {
      // ponytail: `shieldEquipped` es un bool, así que solo hay lugar para un
      // escudo aunque lleves tres en la mochila. Pasarlo a
      // `equippedShieldId` el día que alguien quiera escudos homebrew con
      // estadísticas distintas.
      if (armor.isShield) return c.copyWith(shieldEquipped: value);
      return c.copyWith(equippedArmorId: value ? itemId : null);
    }
    if (repo.weapon(itemId) != null) {
      final ids = [...c.equippedWeaponIds]..remove(itemId);
      if (value) ids.add(itemId);
      return c.copyWith(equippedWeaponIds: ids);
    }
    return c.copyWith(
      inventory: [
        for (final e in c.inventory)
          e.itemId == itemId ? e.copyWith(equipped: value) : e,
      ],
    );
  }

  /// Suma [quantity] unidades de [itemId], juntándolas con la línea que ya
  /// exista. Una segunda línea del mismo objeto haría que la ficha mostrara
  /// "Antorcha 3" y "Antorcha 5" sin que ninguna de las dos sea el total.
  static Character add(Character c, String itemId, {int quantity = 1}) {
    final index = c.inventory.indexWhere((e) => e.itemId == itemId);
    if (index < 0) {
      return c.copyWith(
        inventory: [
          ...c.inventory,
          InventoryEntry(itemId: itemId, quantity: quantity),
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

  /// Saca [quantity] unidades, y la línea entera si no queda ninguna. Al llegar
  /// a cero también desequipa: un objeto que ya no llevás no puede seguir
  /// sumando a la CA.
  static Character remove(
    Character c,
    String itemId,
    ContentRepository repo, {
    int quantity = 1,
  }) {
    final index = c.inventory.indexWhere((e) => e.itemId == itemId);
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
    final removingShield =
        repo.armorPiece(itemId)?.isShield ?? itemId == shieldItemId;
    return c.copyWith(
      inventory: without,
      equippedArmorId: c.equippedArmorId == itemId ? null : c.equippedArmorId,
      shieldEquipped: c.shieldEquipped && !removingShield,
      equippedWeaponIds: [
        for (final id in c.equippedWeaponIds)
          if (id != itemId) id,
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
    final present = {for (final e in c.inventory) e.itemId};
    return [
      ...c.inventory,
      for (final id in [
        if (c.equippedArmorId != null) c.equippedArmorId!,
        // `shieldEquipped` es un bool y no guarda de qué escudo se trata, así
        // que solo se puede recuperar el del catálogo. Ver el techo declarado
        // en [setEquipped].
        if (c.shieldEquipped) shieldItemId,
        ...c.equippedWeaponIds,
      ])
        if (repo.catalogEntry(id) != null && present.add(id))
          InventoryEntry(itemId: id),
    ];
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
      final entry = repo.catalogEntry(e.itemId);
      if (entry != null) total += entry.weight * e.quantity;
    }
    final coins = c.coins.values.fold(0, (a, b) => a + b);
    return total + coins / coinsPerPound;
  }
}
