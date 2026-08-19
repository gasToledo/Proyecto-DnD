import 'dart:math';

import '../domain/ability.dart';
import '../domain/creature.dart';

/// Tira la iniciativa de un monstruo: 1d20 + su modificador de Destreza.
///
/// Es la única tirada de dado de todo el combat tracker — nunca ataque ni
/// daño, de nadie — y el bonificador sale siempre de DES, la misma fórmula
/// que ya usan [character_compiler.dart] y `wild_shape.dart` para PJ y formas
/// salvajes. [random] es inyectable para poder probar el resultado con una
/// semilla fija.
///
/// ponytail: no modela la competencia en iniciativa de la regla 2024 (la
/// trae, por ejemplo, el Guerrero hobgoblin ya cargado): `creatures.json` no
/// tiene campo para eso. El DM puede cargar la iniciativa a mano si hace
/// falta. Subir cuando moleste: agregar un campo opcional al catálogo.
int rollInitiative(Creature creature, {Random? random}) {
  final rng = random ?? Random();
  return rng.nextInt(20) + 1 + creature.abilityModifierFor(Ability.dexterity);
}
