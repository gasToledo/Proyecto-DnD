import 'dart:math';

import '../domain/creature.dart';

/// Tira la iniciativa de un monstruo: 1d20 + su modificador de iniciativa.
///
/// Es la única tirada de dado de todo el combat tracker — nunca ataque ni
/// daño, de nadie. [random] es inyectable para poder probar el resultado con
/// una semilla fija.
///
/// El modificador sale de [Creature.initiativeModifier], que es DES salvo que
/// el perfil imprima otro: la regla 2024 permite competencia en iniciativa y
/// hay monstruos del catálogo que la tienen.
int rollInitiative(Creature creature, {Random? random}) {
  final rng = random ?? Random();
  return rng.nextInt(20) + 1 + creature.initiativeModifier;
}
