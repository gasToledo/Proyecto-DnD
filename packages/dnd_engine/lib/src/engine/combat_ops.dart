import 'dart:math';

import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/effects.dart';
import 'dice.dart';

/// Operaciones de partida sobre el [CombatState]. Lógica pura y testeable;
/// mutan el estado in situ. La recuperación por descanso sigue reglas 2024
/// simplificadas para el MVP.
class CombatOps {
  /// Aplica daño: primero consume PG temporales, luego PG. No baja de 0
  /// (a 0 PG el personaje queda inconsciente y entran las salvaciones de muerte).
  static void applyDamage(CombatState c, int amount) {
    if (amount <= 0) return;
    var dmg = amount;
    if (c.tempHp > 0) {
      final absorbed = min(c.tempHp, dmg);
      c.tempHp -= absorbed;
      dmg -= absorbed;
    }
    c.currentHp = max(0, c.currentHp - dmg);
  }

  /// Cura PG hasta el máximo. Curar desde 0 o menos estabiliza y limpia las
  /// salvaciones de muerte.
  static void applyHealing(CombatState c, int maxHp, int amount) {
    if (amount <= 0) return;
    if (c.currentHp <= 0) {
      c.deathSuccesses = 0;
      c.deathFailures = 0;
    }
    c.currentHp = min(maxHp, c.currentHp + amount);
  }

  /// Fija los PG temporales (no se acumulan: se toma el mayor entre el actual
  /// y el nuevo, según las reglas).
  static void setTempHp(CombatState c, int value) {
    c.tempHp = max(0, max(c.tempHp, value));
  }

  /// Descanso corto: recupera los recursos que recargan en descanso corto.
  static void shortRest(CombatState c, List<CharacterResource> resources) {
    for (final r in resources) {
      if (r.recharge == RechargeOn.shortRest) c.resourceUsage[r.id] = 0;
    }
  }

  /// Descanso largo: PG al máximo, se limpian PG temporales y salvaciones de
  /// muerte, baja 1 el agotamiento, se recupera la mitad de los dados de golpe
  /// y se recargan todos los recursos.
  static void longRest(
    CombatState c,
    int maxHp,
    List<CharacterResource> resources,
    int hitDiceMax,
  ) {
    c.currentHp = maxHp;
    c.tempHp = 0;
    c.deathSuccesses = 0;
    c.deathFailures = 0;
    if (c.exhaustion > 0) c.exhaustion -= 1;
    c.hitDiceUsed = max(0, c.hitDiceUsed - max(1, hitDiceMax ~/ 2));
    for (final r in resources) {
      c.resourceUsage[r.id] = 0;
    }
  }

  /// Gasta un dado de golpe para curarse (tirada + mod. de CON). Devuelve los
  /// PG recuperados, o 0 si no quedan dados. `hitDiceMax` = nivel de personaje.
  static int spendHitDie(
    CombatState c,
    ComputedSheet sheet,
    int hitDiceMax, {
    Dice? dice,
  }) {
    if (c.hitDiceUsed >= hitDiceMax) return 0;
    final roll = (dice ?? Dice()).rollHitDie(sheet.hitDie);
    final heal = max(0, roll + _conMod(sheet));
    c.hitDiceUsed += 1;
    applyHealing(c, sheet.maxHp, heal);
    return heal;
  }

  static int _conMod(ComputedSheet sheet) {
    // El mod. de CON está en abilityModifiers; se accede por la característica.
    // Import evitado: se recompone desde el mapa por abreviatura.
    for (final e in sheet.abilityModifiers.entries) {
      if (e.key.abbr == 'CON') return e.value;
    }
    return 0;
  }

  /// Marca una salvación de muerte (éxito o fallo). Devuelve un resultado:
  /// 'stable' a 3 éxitos, 'dead' a 3 fallos, o null si sigue en juego.
  static String? recordDeathSave(CombatState c, {required bool success}) {
    if (success) {
      c.deathSuccesses = min(3, c.deathSuccesses + 1);
      if (c.deathSuccesses >= 3) {
        c.deathSuccesses = 0;
        c.deathFailures = 0;
        return 'stable';
      }
    } else {
      c.deathFailures = min(3, c.deathFailures + 1);
      if (c.deathFailures >= 3) return 'dead';
    }
    return null;
  }
}
