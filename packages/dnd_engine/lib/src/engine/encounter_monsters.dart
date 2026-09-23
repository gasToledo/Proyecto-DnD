import 'dart:math';

import '../domain/creature.dart';
import '../domain/encounter.dart';
import 'dice.dart';
import 'initiative.dart';

/// Sumar monstruos del bestiario a un encuentro.
///
/// Es una extensión en `engine/` y no un método de [Encounter] porque tira
/// dados, y `domain/` no depende de `engine/`. Vive acá y no en la pantalla
/// porque la suman dos lugares —Combate y el perfil del Bestiario— y la
/// numeración o los PG no pueden salir distintos según desde dónde se sumó.
extension EncounterMonsters on Encounter {
  /// Suma [count] copias de [creature] y devuelve el encuentro resultante.
  ///
  /// Numera los repetidos sobre lo que **ya está** en la mesa: si hay
  /// «Goblin» y «Goblin 2», las nuevas entran como «Goblin 3», «Goblin 4».
  ///
  /// Con [rollHp], cada copia tira sus dados de golpe y ese resultado es
  /// también su máximo: si no, un goblin que sacó 5 se vería «5 / 7» y la
  /// barra arrancaría a media asta. Sin él, todas arrancan con el promedio
  /// del libro, que es lo que corresponde para un jefe. Un perfil sin dados
  /// (invocaciones, compañeros) no tiene nada que tirar y usa el promedio.
  ///
  /// Si el combate ya arrancó, cada copia tira su iniciativa por separado —
  /// nunca la misma para el grupo—. Si todavía se está armando, entra sin
  /// iniciativa: la tirada es de todos juntos al empezar.
  ///
  /// [random] existe para que los tests fijen la semilla.
  Encounter withMonsters(
    Creature creature,
    int count, {
    required String Function() newId,
    CombatantSide side = CombatantSide.enemy,
    bool rollHp = false,
    Random? random,
  }) {
    final rng = random ?? Random();
    final formula =
        rollHp ? DiceFormula.tryParse(creature.hitDice ?? '') : null;
    final dice = Dice(rng);
    final averageHp = creature.resolve(const CreatureVars({})).maxHp;
    final already = combatants.where((c) => c.creatureId == creature.id).length;

    var encounter = this;
    for (var i = 0; i < count; i++) {
      final n = already + i + 1;
      final hp = formula?.roll(dice) ?? averageHp;
      encounter = encounter.withCombatant(
        Combatant(
          id: newId(),
          kind: CombatantKind.monster,
          name: n == 1 ? creature.name : '${creature.name} $n',
          initiative:
              encounter.isPreparing ? 0 : rollInitiative(creature, random: rng),
          creatureId: creature.id,
          currentHp: hp,
          maxHp: hp,
          side: side,
        ),
      );
    }
    return encounter;
  }
}
