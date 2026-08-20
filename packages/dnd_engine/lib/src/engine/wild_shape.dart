import '../domain/ability.dart';
import '../domain/computed_sheet.dart';
import '../domain/creature.dart';

/// Características que la bestia reemplaza. Las otras tres —INT, SAB y CAR—
/// son las tuyas, y por eso una salvación de Sabiduría en forma de lobo sigue
/// siendo la del druida.
const _beastAbilities = {
  Ability.strength,
  Ability.dexterity,
  Ability.constitution,
};

// El tamaño sale de `Creature.creatureSize`, que ya concuerda el femenino del
// perfil ("Bestia Mediana") con el masculino que muestra la ficha ("Mediano").

/// Devuelve la ficha del druida transformado en [beast].
///
/// Reemplaza lo que el rasgo dice que se reemplaza —CA, velocidad, sentidos,
/// tamaño, FUE/DES/CON y ataques— y deja intacto todo lo demás: PG, dados de
/// golpe, INT/SAB/CAR, rasgos de clase, competencias, idiomas y recursos.
///
/// Es una función pura y vive en el motor y no en la pantalla a propósito. Si
/// cada tarjeta se acordara por su cuenta de que estás en forma de oso, la que
/// se olvide muestra un número de la ficha humana en medio del combate; así la
/// pantalla solo elige **qué ficha** pinta y ninguna tarjeta se entera.
///
/// Las habilidades salen solas: [ComputedSheet.skillModifier] las calcula desde
/// los modificadores, así que el Sigilo de la pantera aparece sin tocar nada.
///
/// ponytail: falta la regla de «si el modificador de habilidad de la bestia es
/// superior, usá el de la bestia». Casi toda la diferencia viene del cambio de
/// características, que sí está; aplicarla exacta pide capturar las habilidades
/// de las 64 bestias y una tabla de sobrescrituras por habilidad. Se suma si en
/// la mesa se extraña.
ComputedSheet applyWildShape(ComputedSheet base, Creature beast) {
  final resolved = beast.resolve(CreatureVars.from(
    level: base.level,
    proficiencyBonus: base.proficiencyBonus,
    abilityModifiers: base.abilityModifiers,
  ));

  final scores = {
    for (final a in Ability.values)
      a: _beastAbilities.contains(a)
          ? (beast.abilityScores[a] ?? 10)
          : base.abilityScores[a]!,
  };
  // Los modificadores mentales se copian en vez de recalcularse desde el
  // puntaje: el compilador es el único que sabe armarlos y no hay por qué
  // repetir esa cuenta acá.
  final mods = {
    for (final a in Ability.values)
      a: _beastAbilities.contains(a)
          ? beast.abilityModifierFor(a)
          : base.abilityModifiers[a]!,
  };

  return ComputedSheet(
    level: base.level,
    proficiencyBonus: base.proficiencyBonus,
    abilityScores: scores,
    abilityModifiers: mods,
    abilityBonuses: base.abilityBonuses,
    savingThrowProficiencies: base.savingThrowProficiencies,
    savingThrowBonus: base.savingThrowBonus,
    skillProficiencies: base.skillProficiencies,
    expertiseSkills: base.expertiseSkills,
    armorProficiencies: base.armorProficiencies,
    weaponProficiencies: base.weaponProficiencies,
    toolProficiencies: base.toolProficiencies,
    maxHp: base.maxHp,
    hitDie: base.hitDie,
    armorClass: resolved.armorClass,
    size: beast.creatureSize?.label ?? base.size,
    speed: beast.walkSpeed,
    initiative: mods[Ability.dexterity]!,
    darkvision: beast.darkvision,
    resistances: base.resistances,
    immunities: base.immunities,
    weaponMasterySlots: base.weaponMasterySlots,
    attacksPerAction: base.attacksPerAction,
    attacks: [
      for (final a in resolved.actions)
        if (a.isAttack)
          Attack(
            // No hay arma detrás: el id apunta a la criatura, que es de donde
            // salió el ataque.
            weaponId: beast.id,
            name: a.name,
            attackBonus: a.attackBonus!,
            damage: a.damage ?? '',
            damageType: a.damageType ?? '',
          ),
    ],
    passives: base.passives,
    resources: base.resources,
    companions: base.companions,
    innateSpells: base.innateSpells,
    alwaysPreparedSpellIds: base.alwaysPreparedSpellIds,
    spellListAdditionIds: base.spellListAdditionIds,
    featureChoiceSlots: base.featureChoiceSlots,
    itemChoiceSlots: base.itemChoiceSlots,
    targetChoiceSlots: base.targetChoiceSlots,
    proficiencyChoiceSlots: base.proficiencyChoiceSlots,
    expertiseChoiceSlots: base.expertiseChoiceSlots,
    spellChoiceSlots: base.spellChoiceSlots,
    wildShape: base.wildShape,
    languages: base.languages,
    languageChoiceSlots: base.languageChoiceSlots,
    spellcasting: base.spellcasting,
  );
}
