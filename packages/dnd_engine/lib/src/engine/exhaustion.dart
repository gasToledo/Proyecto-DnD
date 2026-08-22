import 'dart:math';

import '../domain/character.dart' show maxExhaustionLevel;
import '../domain/computed_sheet.dart';

/// Lo que resta cada nivel de Cansancio a las pruebas con d20.
const int _d20PorNivel = 2;

/// Lo que resta cada nivel a la velocidad, en pies. El SRD en español dice
/// 1,5 m; el catálogo entero está en pies.
const int _piesPorNivel = 5;

/// Devuelve la ficha con [level] niveles de Cansancio ya aplicados.
///
/// La regla 2024 son dos frases: la prueba con d20 se reduce en 2 × nivel, y
/// la velocidad en 5 pies × nivel. Nada más — el daño, la CD de conjuros, los
/// PG máximos y la CA no se tocan, porque ninguno es una tirada.
///
/// Es una función pura y vive en el motor y no en la pantalla, por el mismo
/// motivo que [applyWildShape]: si cada tarjeta se acordara por su cuenta de
/// que estás cansado, la que se olvide muestra el número descansado en medio
/// del combate.
///
/// **Se aplica después de la Forma Salvaje**, no antes: la bestia reemplaza
/// velocidad, iniciativa y ataques enteros, así que restar primero sería
/// restar sobre números que después se pisan.
///
/// Nivel 0 devuelve [base] **por identidad**. No es una optimización de
/// adorno: la pantalla llama a esto en cada `build`, y el personaje que no
/// está cansado —que son casi todos, casi siempre— no tiene que pagar una
/// copia de la ficha entera.
ComputedSheet applyExhaustion(ComputedSheet base, int level) {
  final n = level.clamp(0, maxExhaustionLevel);
  if (n == 0) return base;

  final d20 = _d20PorNivel * n;

  return base.copyWith(
    // Se resta al valor que ya había en vez de asignarlo: el campo es la suma
    // de lo situacional, y el Cansancio es hoy la única fuente pero no tiene
    // por qué ser la última.
    d20Modifier: base.d20Modifier - d20,
    // Con piso en 0: la regla resta velocidad, no empuja a caminar para atrás.
    speed: max(0, base.speed - _piesPorNivel * n),
    initiative: base.initiative - d20,
    attacks: [
      for (final a in base.attacks)
        a.copyWith(attackBonus: a.attackBonus - d20),
    ],
    // La CD de conjuros **no** se toca: el que tira el d20 ahí es quien se
    // salva, y su cansancio es asunto suyo.
    spellcasting: base.spellcasting
        ?.copyWith(attackBonus: base.spellcasting!.attackBonus - d20),
  );
}
