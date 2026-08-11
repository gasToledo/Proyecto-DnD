import 'dart:math';

import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/creature.dart';
import '../domain/effects.dart';
import '../domain/spell_slots.dart';
import 'dice.dart';

/// Operaciones de partida sobre el [CombatState]. Lógica pura y testeable;
/// mutan el estado in situ. La recuperación por descanso sigue reglas 2024
/// simplificadas para el MVP.
class CombatOps {
  /// La regla de daño en crudo: los PG temporales absorben primero y los PG no
  /// bajan de 0. Devuelve los valores nuevos.
  ///
  /// Vive suelta porque la aplican dos cosas distintas —el personaje y cada
  /// compañero invocado— y una copia por cada una es una copia que se puede
  /// desincronizar.
  static ({int hp, int tempHp}) _absorbDamage(int hp, int tempHp, int amount) {
    if (amount <= 0) return (hp: hp, tempHp: tempHp);
    var dmg = amount;
    var temp = tempHp;
    if (temp > 0) {
      final absorbed = min(temp, dmg);
      temp -= absorbed;
      dmg -= absorbed;
    }
    return (hp: max(0, hp - dmg), tempHp: temp);
  }

  /// Aplica daño: primero consume PG temporales, luego PG. No baja de 0
  /// (a 0 PG el personaje queda inconsciente y entran las salvaciones de muerte).
  static void applyDamage(CombatState c, int amount) {
    final next = _absorbDamage(c.currentHp, c.tempHp, amount);
    c.currentHp = next.hp;
    c.tempHp = next.tempHp;
    // A 0 PG quedás Incapacitado, y eso termina la Forma Salvaje. Va acá y no
    // en la pantalla porque el daño entra por varios lados y una revisión por
    // cada uno es una revisión que alguno se olvida.
    if (c.currentHp <= 0) c.wildShapeCreatureId = null;
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

  /// Descanso corto: recupera por completo los recursos de recarga corta y la
  /// cantidad declarada por los recursos de recuperación parcial. Si el
  /// personaje usa Magia de Pacto (Brujo), también recupera sus espacios.
  static void shortRest(
    CombatState c,
    List<CharacterResource> resources, {
    Spellcasting? spellcasting,
  }) {
    for (final r in resources) {
      if (r.recharge == RechargeOn.shortRest) {
        c.resourceUsage[r.id] = 0;
      } else if (r.shortRestRecovery > 0) {
        final used = c.resourceUsage[r.id] ?? 0;
        c.resourceUsage[r.id] = max(0, used - r.shortRestRecovery);
      }
    }
    if (spellcasting?.progression == CasterProgression.pact) {
      c.spellSlotsUsed.clear();
    }
  }

  /// Descanso largo: PG al máximo, se limpian PG temporales y salvaciones de
  /// muerte, baja 1 el agotamiento, se recupera la mitad de los dados de golpe,
  /// se recargan todos los recursos, se recuperan los espacios de conjuro y
  /// termina la concentración.
  ///
  /// [companionMaxHp] resuelve los PG máximos de cada compañero invocado, que
  /// dependen del catálogo y del nivel del espacio con que se lo convocó. Si no
  /// se pasa, los compañeros quedan como estaban.
  ///
  /// ponytail: el descanso largo deja a los compañeros activos a tope y no
  /// despide a ninguno. El Cañón Arcano dura una hora por regla y tendría que
  /// desaparecer solo; queda para el botón Despedir hasta que algún compañero
  /// necesite de verdad una duración modelada.
  static void longRest(
    CombatState c,
    int maxHp,
    List<CharacterResource> resources,
    int hitDiceMax, {
    int Function(CompanionInstance)? companionMaxHp,
  }) {
    c.currentHp = maxHp;
    c.tempHp = 0;
    c.deathSuccesses = 0;
    c.deathFailures = 0;
    if (c.exhaustion > 0) c.exhaustion -= 1;
    c.hitDiceUsed = max(0, c.hitDiceUsed - max(1, hitDiceMax ~/ 2));
    for (final r in resources) {
      c.resourceUsage[r.id] = 0;
    }
    c.spellSlotsUsed.clear();
    c.wildShapeCreatureId = null;
    // Por la misma vía que el botón de terminar: el descanso corta la
    // concentración, y con ella se van los espíritus invocados.
    endConcentration(c);
    if (companionMaxHp != null) {
      for (final companion in c.companions) {
        companion.currentHp = companionMaxHp(companion);
        companion.tempHp = 0;
        companion.conditions.clear();
      }
    }
  }

  /// Gasta un espacio de conjuro del [slotLevel] indicado. Devuelve false si no
  /// quedan espacios disponibles de ese nivel.
  static bool spendSpellSlot(CombatState c, Spellcasting sc, int slotLevel) {
    final available = sc.slotsByLevel[slotLevel] ?? 0;
    final used = c.spellSlotsUsed[slotLevel] ?? 0;
    if (used >= available) return false;
    c.spellSlotsUsed[slotLevel] = used + 1;
    return true;
  }

  /// Recupera manualmente un espacio de conjuro del [slotLevel] indicado.
  static void recoverSpellSlot(CombatState c, int slotLevel) {
    final used = c.spellSlotsUsed[slotLevel] ?? 0;
    if (used > 0) c.spellSlotsUsed[slotLevel] = used - 1;
  }

  /// Espacios de conjuro disponibles (no gastados) del [slotLevel] indicado.
  static int spellSlotsRemaining(
      CombatState c, Spellcasting sc, int slotLevel) {
    final available = sc.slotsByLevel[slotLevel] ?? 0;
    return max(0, available - (c.spellSlotsUsed[slotLevel] ?? 0));
  }

  /// Inicia (o reemplaza) la concentración en un conjuro. Reemplazarla rompe la
  /// anterior, así que se lleva puestos a los compañeros que la sostenían.
  static void startConcentration(CombatState c, String spell) {
    _dismissConcentrationCompanions(c);
    c.concentratingOn = spell;
  }

  /// Termina la concentración actual y despide a lo que dependía de ella.
  static void endConcentration(CombatState c) {
    _dismissConcentrationCompanions(c);
    c.concentratingOn = null;
  }

  /// Los compañeros que sostiene un conjuro de concentración desaparecen con
  /// ella. Los que no dependen de ninguna —el cañón, el defensor, el familiar—
  /// se quedan donde están.
  static void _dismissConcentrationCompanions(CombatState c) {
    c.companions.removeWhere((i) => i.concentration);
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
    final conMod = sheet.abilityModifiers[Ability.constitution] ?? 0;
    final heal = max(0, roll + conMod);
    c.hitDiceUsed += 1;
    applyHealing(c, sheet.maxHp, heal);
    return heal;
  }

  // ------------------------------------------------------------ Compañeros

  /// Invoca un compañero con los PG al máximo y lo devuelve.
  ///
  /// El nivel del espacio sale de [vars], no de un parámetro aparte: es el
  /// mismo número que resuelve los PG del Corcel Sobrenatural, y tenerlo dos
  /// veces es tenerlo mal una vez.
  ///
  /// Si ya se llegó a [CompanionOption.maxActive], el más viejo se reemplaza en
  /// lugar de rechazar la invocación. Es lo que dicen las reglas: volver a
  /// lanzar Encontrar Familiar le cambia la forma al que había, y solo puede
  /// haber un cañón a la vez.
  ///
  /// [concentration] marca que lo sostiene un conjuro de concentración, y hace
  /// dos cosas: el compañero se va cuando la concentración termina, y empezarla
  /// rompe la anterior (con lo que se lleva puesto al compañero que hubiera).
  static CompanionInstance summonCompanion(
    CombatState c,
    CompanionOption option,
    Creature form,
    CreatureVars vars, {
    bool concentration = false,
    String concentratingOn = '',
  }) {
    // Antes de nada: empezar una concentración nueva rompe la que hubiera, y
    // eso puede llevarse por delante a un compañero que ya estaba en juego.
    if (concentration) startConcentration(c, concentratingOn);

    final active = c.companions.where((i) => i.optionId == option.id).toList();
    // Se retiran los más viejos hasta dejar un lugar libre para el nuevo.
    for (var i = 0; i <= active.length - option.maxActive; i++) {
      c.companions.remove(active[i]);
    }
    final instance = CompanionInstance(
      optionId: option.id,
      creatureId: form.id,
      spellLevel: vars['spellLevel'] ?? 0,
      concentration: concentration,
      currentHp: resolveCreatureInt(form.hp, vars),
    );
    c.companions.add(instance);
    return instance;
  }

  /// Despide un compañero (o lo retira cuando fue destruido).
  static void dismissCompanion(CombatState c, CompanionInstance instance) {
    c.companions.removeWhere((i) => identical(i, instance));
  }

  /// Daña a un compañero con la misma regla que al personaje. Devuelve true si
  /// el daño lo destruyó.
  ///
  /// A 0 PG desaparece, que es lo que dicen las reglas: el Cañón Arcano, el
  /// familiar, el corcel y el homúnculo se desvanecen. Un compañero destruido
  /// no se cura ni se lleva más: se vuelve a invocar.
  ///
  /// ponytail: el Defensor de Acero se puede revivir gastando un espacio de
  /// conjuro dentro de la hora, y acá también se va. Volver a invocarlo deja el
  /// mismo resultado en la ficha; modelar el revivir pide llevar la cuenta de
  /// cuándo murió, que hoy no existe.
  static bool damageCompanion(
    CombatState c,
    CompanionInstance i,
    int amount,
  ) {
    final next = _absorbDamage(i.currentHp, i.tempHp, amount);
    i.currentHp = next.hp;
    i.tempHp = next.tempHp;
    if (i.currentHp > 0) return false;
    dismissCompanion(c, i);
    return true;
  }

  static void healCompanion(CompanionInstance i, int maxHp, int amount) {
    if (amount <= 0) return;
    i.currentHp = min(maxHp, i.currentHp + amount);
  }

  /// PG temporales de un compañero (el modo Protector del Cañón Arcano). No se
  /// acumulan, igual que los del personaje.
  static void setCompanionTempHp(CompanionInstance i, int value) {
    i.tempHp = max(0, max(i.tempHp, value));
  }

  // --------------------------------------------------------- Forma Salvaje

  /// Recurso que gasta la Forma Salvaje. El contenido lo declara con este id en
  /// los tres escalones del rasgo (niveles 2, 6 y 17).
  static const String wildShapeResourceId = 'wild_shape';

  /// Se transforma en [beast] gastando un uso de Forma Salvaje y sumando PG
  /// temporales iguales al nivel de druida. Devuelve false si no quedan usos.
  ///
  /// Solo cambia el estado: los números de la ficha los reemplaza
  /// `applyWildShape`, que es una función pura sobre la ficha ya compilada.
  static bool enterWildShape(
    CombatState c,
    ComputedSheet sheet,
    Creature beast,
  ) {
    final resource =
        sheet.resources.where((r) => r.id == wildShapeResourceId).firstOrNull;
    if (resource == null) return false;
    final used = c.resourceUsage[wildShapeResourceId] ?? 0;
    if (used >= resource.max) return false;
    c.resourceUsage[wildShapeResourceId] = used + 1;
    c.wildShapeCreatureId = beast.id;
    setTempHp(c, sheet.level);
    return true;
  }

  /// Vuelve a la forma propia. Los PG temporales no se quitan: son PG
  /// temporales normales y duran hasta que se gastan o hasta el descanso largo.
  static void leaveWildShape(CombatState c) => c.wildShapeCreatureId = null;

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
