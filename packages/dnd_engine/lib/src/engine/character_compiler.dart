import 'dart:math';

import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/spell_slots.dart';
import 'sheet_builder.dart';

/// Toma un [Character] con elecciones resueltas + el [ContentRepository] y
/// produce la ficha derivada. Es el corazón del motor dirigido por datos: toda
/// la lógica de cálculo vive aquí; el contenido solo aporta datos y efectos.
class CharacterCompiler {
  final ContentRepository repo;
  const CharacterCompiler(this.repo);

  ComputedSheet compile(Character c) {
    final race = repo.race(c.raceId);
    final klass = repo.characterClass(c.classId);
    final background = repo.background(c.backgroundId);

    final builder = SheetBuilder(
      baseScores: {
        for (final a in Ability.values) a: c.assignedScores[a] ?? 10,
      },
      level: c.level,
    );

    if (race != null) builder.speed = race.speed;

    // Bonos de característica explícitos (trasfondo 2024 + ASI).
    c.backgroundAbilityBonuses.forEach(builder.addAbilityBonus);
    for (final asi in c.asiChoices) {
      asi.abilityIncreases.forEach(builder.addAbilityBonus);
    }

    // Efectos de raza, clase (por nivel), trasfondo y dotes.
    if (race != null) builder.applyAll(race.effects);
    if (klass != null) {
      for (final f in klass.featuresUpTo(c.level)) {
        builder.applyAll(f.effects);
      }
      builder.saveProficiencies.addAll(klass.savingThrows);
      builder.armorProficiencies.addAll(klass.armorProficiencies);
      builder.weaponProficiencies.addAll(klass.weaponProficiencies);
    }
    if (background != null) {
      builder.applyAll(background.effects);
      builder.skillProficiencies.addAll(background.skillProficiencies);
      builder.toolProficiencies.addAll(background.toolProficiencies);
    }

    // Dotes: la de origen del trasfondo + las elegidas + estilo de combate.
    final featIds = <String?>[
      background?.originFeatId,
      ...c.featIds,
      c.fightingStyleId,
    ];
    for (final id in featIds) {
      if (id == null) continue;
      final feat = repo.feat(id);
      if (feat != null) builder.applyAll(feat.effects);
    }

    // Habilidades elegidas en el wizard (raza/clase/trasfondo).
    builder.skillProficiencies.addAll(c.chosenSkills);

    // --- Finalización a valores derivados ---
    final scores = {for (final a in Ability.values) a: builder.finalScore(a)};
    final mods = {for (final a in Ability.values) a: abilityModifier(scores[a]!)};
    final profBonus = proficiencyBonusForLevel(c.level);
    final conMod = mods[Ability.constitution]!;
    final dexMod = mods[Ability.dexterity]!;
    final wisMod = mods[Ability.wisdom]!;

    final baseHp = c.hpPerLevel.fold<int>(0, (s, v) => s + v);
    final maxHp = baseHp +
        conMod * c.level +
        builder.bonusMaxHpFlat +
        builder.bonusMaxHpPerLevel * c.level;

    final ac = _armorClass(c, builder, mods);

    final passivePerception = 10 +
        wisMod +
        (builder.skillProficiencies.contains('perception') ? profBonus : 0);

    final attacksPerAction = 1 + builder.maxExtraAttack;

    final attacks = <Attack>[];
    for (final wid in c.equippedWeaponIds) {
      final w = repo.weapon(wid);
      if (w == null) continue;
      attacks.add(_attack(c, w, mods, profBonus, builder));
    }

    final spellcasting = _spellcasting(builder, c.level, mods, profBonus);

    return ComputedSheet(
      level: c.level,
      proficiencyBonus: profBonus,
      abilityScores: scores,
      abilityModifiers: mods,
      savingThrowProficiencies: builder.saveProficiencies,
      skillProficiencies: builder.skillProficiencies,
      armorProficiencies: builder.armorProficiencies,
      weaponProficiencies: builder.weaponProficiencies,
      toolProficiencies: builder.toolProficiencies,
      maxHp: maxHp,
      hitDie: klass?.hitDie ?? 8,
      armorClass: ac,
      speed: builder.speed,
      initiative: dexMod,
      passivePerception: passivePerception,
      darkvision: builder.darkvision,
      resistances: builder.resistances,
      immunities: builder.immunities,
      weaponMasterySlots: builder.weaponMasterySlots,
      attacksPerAction: attacksPerAction,
      attacks: attacks,
      passives: builder.passives,
      resources: builder.resources,
      spellcasting: spellcasting,
    );
  }

  /// Deriva el bloque de lanzamiento a partir del rasgo de lanzamiento activo.
  /// Sin multiclase, el nivel de lanzador == nivel de personaje.
  Spellcasting? _spellcasting(
    SheetBuilder b,
    int level,
    Map<Ability, int> mods,
    int profBonus,
  ) {
    final sc = b.spellcasting;
    if (sc == null || sc.progression == CasterProgression.none) return null;
    final abilityMod = mods[sc.ability]!;

    // Nivel de lanzador efectivo: los semi-lanzadores preparan según la mitad
    // de su nivel (2024). Sigue siendo una aproximación de la tabla por clase.
    final casterLevel = sc.progression == CasterProgression.half
        ? (level / 2).ceil()
        : level;
    final prepared = sc.preparation == SpellPreparation.prepared
        ? max(1, casterLevel + abilityMod)
        : 0;

    // Trucos conocidos: base de la clase + 1 a niveles 4 y 10 (2024). Las clases
    // sin trucos (Paladín/Explorador) no ganan ninguno.
    final cantrips = sc.cantripsKnown == 0
        ? 0
        : sc.cantripsKnown + (level >= 4 ? 1 : 0) + (level >= 10 ? 1 : 0);

    return Spellcasting(
      ability: sc.ability,
      progression: sc.progression,
      preparation: sc.preparation,
      spellList: sc.spellList,
      saveDc: 8 + profBonus + abilityMod,
      attackBonus: profBonus + abilityMod,
      cantripsKnown: cantrips,
      preparedCount: prepared,
      slotsByLevel: spellSlotsFor(sc.progression, level),
    );
  }

  int _armorClass(Character c, SheetBuilder b, Map<Ability, int> mods) {
    final dexMod = mods[Ability.dexterity]!;
    var ac = 10 + dexMod; // Sin armadura.
    final armor = c.equippedArmorId == null ? null : repo.armorPiece(c.equippedArmorId!);
    if (armor != null && !armor.isShield) {
      ac = armor.baseAc;
      if (armor.addDexMod) {
        ac += armor.maxDexBonus == null ? dexMod : min(dexMod, armor.maxDexBonus!);
      }
    } else if (b.unarmoredDefenseAbility != null) {
      // Defensa sin Armadura (Bárbaro: +CON, Monje: +SAB), solo sin armadura.
      // El Monje la pierde si empuña un escudo; el Bárbaro la conserva.
      final voidedByShield =
          c.shieldEquipped && !b.unarmoredDefenseAllowShield;
      if (!voidedByShield) {
        ac = 10 + dexMod + mods[b.unarmoredDefenseAbility!]!;
      }
    }
    if (c.shieldEquipped) ac += 2;
    ac += b.acBonus;
    return ac;
  }

  Attack _attack(
    Character c,
    Weapon w,
    Map<Ability, int> mods,
    int profBonus,
    SheetBuilder b,
  ) {
    final int abilityMod;
    if (w.isRanged) {
      abilityMod = mods[Ability.dexterity]!;
    } else if (w.isFinesse) {
      abilityMod = max(mods[Ability.strength]!, mods[Ability.dexterity]!);
    } else {
      abilityMod = mods[Ability.strength]!;
    }

    final proficient = b.weaponProficiencies.contains(w.category) ||
        b.weaponProficiencies.contains(w.id);
    final attackBonus = abilityMod + (proficient ? profBonus : 0);

    final twoHanded = c.weaponTwoHanded[w.id] ?? false;
    final dice = (twoHanded && w.versatileDice != null)
        ? w.versatileDice!
        : w.damageDice;

    final hasMastery = w.mastery != null &&
        b.weaponMasterySlots > 0 &&
        c.weaponMasteryChoices.contains(w.id);

    return Attack(
      weaponId: w.id,
      name: w.name,
      attackBonus: attackBonus,
      damage: _damageString(dice, abilityMod),
      damageType: w.damageType,
      mastery: hasMastery ? w.mastery : null,
    );
  }

  String _damageString(String dice, int mod) {
    if (mod == 0) return dice;
    return mod > 0 ? '$dice + $mod' : '$dice - ${mod.abs()}';
  }
}
