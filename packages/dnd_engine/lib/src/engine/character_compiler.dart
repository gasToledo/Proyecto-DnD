import 'dart:math';

import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/effects.dart';
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
    if (race != null) {
      builder.applyAll(
        race.effects,
        spellAbilityOverride: c.speciesSpellcastingAbility,
      );
    }

    // Rasgos del linaje de especie (si se eligió y pertenece a esta especie),
    // por nivel: igual que las subclases, pueden crecer con el personaje.
    final lineage = c.lineageId == null ? null : repo.lineage(c.lineageId!);
    if (lineage != null && lineage.raceId == c.raceId) {
      for (final f in lineage.featuresUpTo(c.level)) {
        builder.applyAll(
          f.effects,
          spellAbilityOverride: c.speciesSpellcastingAbility,
        );
      }
    }

    if (klass != null) {
      for (final f in klass.featuresUpTo(c.level)) {
        builder.applyAll(f.effects);
      }
      builder.saveProficiencies.addAll(klass.savingThrows);
      builder.armorProficiencies.addAll(klass.armorProficiencies);
      builder.weaponProficiencies.addAll(klass.weaponProficiencies);
    }

    // Rasgos de subclase (si se eligió y pertenece a esta clase), por nivel.
    final subclass = c.subclassId == null ? null : repo.subclass(c.subclassId!);
    if (subclass != null && subclass.classId == c.classId) {
      for (final f in subclass.featuresUpTo(c.level)) {
        builder.applyAll(f.effects);
      }
    }
    if (background != null) {
      builder.applyAll(background.effects);
      builder.skillProficiencies.addAll(background.skillProficiencies);
      builder.toolProficiencies.addAll(background.toolProficiencies);
    }

    // Dotes: la de origen del trasfondo + las elegidas + estilo de combate.
    //
    // Una dote se toma una sola vez salvo que sea repetible (PHB, cap. 5). Un
    // personaje puede tenerla por dos vías sin que nadie lo haya buscado —el
    // trasfondo concede una dote de origen y el Humano otra—, así que la
    // repetición se descarta en vez de aplicar los efectos dos veces. La
    // validación sigue avisando aparte con `feat_duplicate`.
    final featIds = <String?>[
      background?.originFeatId,
      ...c.featIds,
      c.fightingStyleId,
    ];
    final appliedOnce = <String>{};
    for (final id in featIds) {
      if (id == null) continue;
      final feat = repo.feat(id);
      if (feat == null) continue;
      if (!feat.repeatable && !appliedOnce.add(id)) continue;
      builder.applyAll(feat.effects);
    }

    // Habilidades elegidas en el wizard (raza/clase/trasfondo).
    builder.skillProficiencies.addAll(c.chosenSkills);

    // --- Finalización a valores derivados ---
    final scores = {for (final a in Ability.values) a: builder.finalScore(a)};
    final mods = {
      for (final a in Ability.values) a: abilityModifier(scores[a]!)
    };
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
    final speed = _speed(c, builder);

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
    final innate = _resolveInnate(builder, mods, profBonus);

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
      speed: speed,
      initiative: dexMod,
      passivePerception: passivePerception,
      darkvision: builder.darkvision,
      resistances: builder.resistances,
      immunities: builder.immunities,
      weaponMasterySlots: builder.weaponMasterySlots,
      attacksPerAction: attacksPerAction,
      attacks: attacks,
      passives: builder.passives,
      resources: [
        ...builder.resolveResources(mods, c.level),
        ...innate.resources
      ],
      innateSpells: innate.spells,
      spellcasting: spellcasting,
    );
  }

  /// Resuelve los conjuros concedidos por rasgos contra el repositorio y, para
  /// los de uso gratuito, crea el recurso que registra ese uso por descanso
  /// largo (así la ficha lo muestra y lo gasta como cualquier otro).
  _InnateResult _resolveInnate(
    SheetBuilder builder,
    Map<Ability, int> mods,
    int proficiencyBonus,
  ) {
    final spells = <InnateSpell>[];
    final resources = <CharacterResource>[];
    for (final g in builder.grantedSpells) {
      final spell = repo.spell(g.spellId);
      if (spell == null) continue; // contenido incompleto: se ignora
      final mod = mods[g.ability] ?? 0;
      spells.add(InnateSpell(
        spellId: spell.id,
        name: spell.name,
        level: spell.level,
        ability: g.ability,
        use: g.use,
        saveDc: 8 + proficiencyBonus + mod,
        attackBonus: proficiencyBonus + mod,
      ));
      if (g.use != InnateSpellUse.atWill) {
        resources.add(CharacterResource(
          id: 'innate-${spell.id}',
          name: spell.name,
          max: g.use == InnateSpellUse.proficiencyBonusPerLongRest
              ? proficiencyBonus
              : 1,
          recharge: RechargeOn.longRest,
          description: 'Lanzarlo sin gastar espacio de conjuro. '
              'También podés lanzarlo gastando un espacio.',
        ));
      }
    }
    return _InnateResult(spells, resources);
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

    // Conjuros preparados: columna fija por clase/progresión (2024), sin
    // depender del modificador de característica (a diferencia de 2014).
    final prepared = sc.preparation == SpellPreparation.prepared
        ? preparedSpellsFor(sc.progression, level, sc.spellList)
        : 0;

    // Trucos conocidos: base de la clase + escalado por nivel. Si el rasgo
    // declara sus propios niveles de aumento (Artífice: 10 y 14), se usan esos;
    // si no, se conserva el escalado por defecto de 2024: los lanzadores
    // completos ganan +1 a niveles 4 y 10, los de un tercio solo a nivel 10, y
    // las clases sin trucos (Paladín/Explorador) no ganan ninguno.
    final int cantripBonus;
    if (sc.cantripsKnown == 0) {
      cantripBonus = 0;
    } else if (sc.cantripIncreases != null) {
      cantripBonus = sc.cantripIncreases!.where((lv) => level >= lv).length;
    } else if (sc.progression == CasterProgression.third) {
      cantripBonus = level >= 10 ? 1 : 0;
    } else {
      cantripBonus = (level >= 4 ? 1 : 0) + (level >= 10 ? 1 : 0);
    }
    final cantrips = sc.cantripsKnown + cantripBonus;

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

  /// Velocidad final: base + bonos incondicionales (raza) + Movimiento sin
  /// Armadura, este último solo si no se lleva armadura (para el Monje, tampoco
  /// escudo; para el Bárbaro, solo lo anula la armadura pesada).
  int _speed(Character c, SheetBuilder b) {
    var speed = b.speed;
    if (b.unarmoredMovementBonus != 0) {
      final armor = c.equippedArmorId == null
          ? null
          : repo.armorPiece(c.equippedArmorId!);
      var voided = false;
      if (armor != null && !armor.isShield) {
        voided =
            b.unarmoredMovementHeavyOnly ? armor.category == 'heavy' : true;
      }
      if (c.shieldEquipped && !b.unarmoredMovementAllowShield) voided = true;
      if (!voided) speed += b.unarmoredMovementBonus;
    }
    return speed;
  }

  int _armorClass(Character c, SheetBuilder b, Map<Ability, int> mods) {
    final dexMod = mods[Ability.dexterity]!;
    var ac = 10 + dexMod; // Sin armadura.
    final armor =
        c.equippedArmorId == null ? null : repo.armorPiece(c.equippedArmorId!);
    if (armor != null && !armor.isShield) {
      ac = armor.baseAc;
      if (armor.addDexMod) {
        ac += armor.maxDexBonus == null
            ? dexMod
            : min(dexMod, armor.maxDexBonus!);
      }
    } else if (b.unarmoredDefenseAbility != null) {
      // Defensa sin Armadura (Bárbaro: +CON, Monje: +SAB), solo sin armadura.
      // El Monje la pierde si empuña un escudo; el Bárbaro la conserva.
      final voidedByShield = c.shieldEquipped && !b.unarmoredDefenseAllowShield;
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

    // 2024: la propiedad de Maestría solo se aplica con armas con las que sos
    // competente. `proficient` sale de la ficha compilada, así que una subclase
    // o dote que conceda la categoría también habilita la maestría.
    final hasMastery = w.mastery != null &&
        b.weaponMasterySlots > 0 &&
        c.weaponMasteryChoices.contains(w.id) &&
        proficient;

    final offHand = c.weaponOffHand[w.id] ?? false;

    // 2024: el ataque de mano secundaria no suma el modificador al daño, pero
    // solo cuando es **positivo**; un modificador negativo se sigue restando.
    // El estilo Combate con Dos Armas lo devuelve, y llega acá como efecto
    // ([OffHandAbilityDamageEffect]), no como el id de la dote.
    final damageMod =
        (offHand && !b.offHandAbilityDamage && abilityMod > 0) ? 0 : abilityMod;

    // Mellar (Nick) no cambia el daño: cambia la economía de acciones, porque
    // permite hacer el ataque extra dentro de la acción de Atacar.
    final nick = hasMastery && w.mastery == 'nick';
    final action =
        (offHand && !nick) ? AttackAction.bonusAction : AttackAction.action;

    return Attack(
      weaponId: w.id,
      name: w.name,
      attackBonus: attackBonus,
      damage: _damageString(dice, damageMod),
      damageType: w.damageType,
      mastery: hasMastery ? w.mastery : null,
      offHand: offHand,
      action: action,
    );
  }

  String _damageString(String dice, int mod) {
    if (mod == 0) return dice;
    return mod > 0 ? '$dice + $mod' : '$dice - ${mod.abs()}';
  }
}

/// Par de listas que sale de resolver los conjuros concedidos por rasgos.
class _InnateResult {
  final List<InnateSpell> spells;
  final List<CharacterResource> resources;
  const _InnateResult(this.spells, this.resources);
}
