import 'dart:math';

import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/creature.dart';
import '../domain/effects.dart';
import '../domain/language.dart';
import '../domain/proficiency_labels.dart';
import '../domain/skill.dart';
import '../domain/spell_slots.dart';
import 'inventory_ops.dart';
import 'sheet_builder.dart';

/// Toma un [Character] con elecciones resueltas + el [ContentRepository] y
/// produce la ficha derivada. Es el corazón del motor dirigido por datos: toda
/// la lógica de cálculo vive aquí; el contenido solo aporta datos y efectos.
class CharacterCompiler {
  final ContentRepository repo;
  const CharacterCompiler(this.repo);

  ItemChoiceSlot _itemChoiceSlot(ItemChoiceEffect effect, Character character) {
    final eligible = <String>{
      for (final option in effect.options)
        if (option.minLevel <= character.level &&
            repo.item(option.itemId) != null)
          option.itemId,
    };

    // EFA permite además planes abiertos por categoría. Se resuelven contra el
    // catálogo real para que agregar contenido no obligue a duplicar cientos de
    // IDs dentro de la clase. Los bloques de rareza variable no califican como
    // una rareza concreta, aunque su registro de catálogo conserve una rareza
    // de presentación.
    if (effect.groupId == 'artificer-magic-item-plans') {
      for (final item in repo.itemsSorted) {
        final description = item.description.trimLeft().toLowerCase();
        final cursed =
            description.contains('maldici') || description.contains('maldito');
        final variable = description.contains('rareza variable');
        final potionOrScroll = description.startsWith('poción') ||
            description.startsWith('pergamino');
        final wondrous = description.startsWith('objeto maravilloso');
        if (!cursed &&
            !variable &&
            (character.level >= 2 &&
                    item.rarity == 'common' &&
                    !potionOrScroll ||
                character.level >= 10 &&
                    item.rarity == 'uncommon' &&
                    wondrous ||
                character.level >= 14 && item.rarity == 'rare' && wondrous)) {
          eligible.add(item.id);
        }
      }
    }

    return ItemChoiceSlot(
      groupId: effect.groupId,
      name: effect.name,
      count: effect.countAt(character.level),
      maxActive: artificerReplicasAtLevel(character.level),
      replaceable: effect.replaceable,
      optionItemIds: eligible.toList(),
      chosenItemIds: character.magicItemChoices
          .where(eligible.contains)
          .take(effect.countAt(character.level))
          .toList(),
    );
  }

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
    final proficiencySources =
        <({String id, String name, List<Effect> effects})>[];

    // Desenvuelve los [LeveledEffect] que no llegan al nivel del personaje y
    // deja el resto plano. Se hace **antes** de repartir, no dentro del
    // builder: `proficiencySources` alimenta las pasadas de competencias,
    // Pericia y elección de conjuros, que hacen `whereType<...>()`. Con el
    // envoltorio puesto, una de esas elecciones escalonada por nivel sería
    // invisible para ellas y el defecto entraría en verde.
    List<Effect> flatten(List<Effect> effects) => [
          for (final e in effects)
            if (e is LeveledEffect)
              ...(c.level >= e.minLevel ? flatten(e.effects) : const <Effect>[])
            else
              e,
        ];

    void applySource(
      String id,
      String name,
      List<Effect> effects, {
      Ability? spellAbilityOverride,
    }) {
      final flat = flatten(effects);
      builder.applyAll(
        flat,
        spellAbilityOverride: spellAbilityOverride,
        sourceName: name,
      );
      proficiencySources.add((id: id, name: name, effects: flat));
    }

    if (race != null) builder.speed = race.speed;

    // Bonos de característica explícitos (trasfondo 2024 + ASI). No vienen de
    // un efecto, así que el nombre de la fuente se arma acá: es el único lugar
    // que sabe de qué trasfondo o de qué nivel salieron.
    final backgroundLabel =
        background == null ? 'Trasfondo' : 'Trasfondo: ${background.name}';
    c.backgroundAbilityBonuses.forEach(
      (a, amount) =>
          builder.addAbilityBonus(a, amount, source: backgroundLabel),
    );
    for (final asi in c.asiChoices) {
      asi.abilityIncreases.forEach(
        (a, amount) => builder.addAbilityBonus(a, amount,
            source: 'Mejora de nivel ${asi.level}'),
      );
    }

    // Efectos de raza, clase (por nivel), trasfondo y dotes.
    if (race != null) {
      applySource(
        'race:' + race.id,
        race.name,
        race.effects,
        spellAbilityOverride: c.speciesSpellcastingAbility,
      );
    }

    // Rasgos del linaje de especie (si se eligió y pertenece a esta especie),
    // por nivel: igual que las subclases, pueden crecer con el personaje.
    final lineage = c.lineageId == null ? null : repo.lineage(c.lineageId!);
    if (lineage != null && lineage.raceId == c.raceId) {
      for (final f in lineage.featuresUpTo(c.level)) {
        applySource(
          'lineage:' +
              lineage.id +
              ':' +
              lineage.features.indexOf(f).toString(),
          f.name,
          f.effects,
          spellAbilityOverride: c.speciesSpellcastingAbility,
        );
      }
    }

    if (klass != null) {
      for (final f in klass.featuresUpTo(c.level)) {
        applySource(
          'class:' + klass.id + ':' + klass.features.indexOf(f).toString(),
          f.name,
          f.effects,
        );
      }
      builder.saveProficiencies.addAll(klass.savingThrows);
      builder.armorProficiencies.addAll(klass.armorProficiencies);
      builder.weaponProficiencies.addAll(klass.weaponProficiencies);
    }

    // Rasgos de subclase (si se eligió y pertenece a esta clase), por nivel.
    final subclass = c.subclassId == null ? null : repo.subclass(c.subclassId!);
    if (subclass != null && subclass.classId == c.classId) {
      for (final f in subclass.featuresUpTo(c.level)) {
        applySource(
          'subclass:' +
              subclass.id +
              ':' +
              subclass.features.indexOf(f).toString(),
          f.name,
          f.effects,
        );
      }
    }
    if (background != null) {
      applySource(
          'background:' + background.id, background.name, background.effects);
      builder.skillProficiencies.addAll(background.skillProficiencies);
      for (final tool in background.toolProficiencies) {
        if (const {
          'artisans-tools',
          'gaming-set',
          'musical-instrument',
        }.contains(tool)) {
          proficiencySources.add((
            id: 'background:' + background.id + ':' + tool,
            name: background.name,
            effects: <Effect>[
              ProficiencyChoiceEffect(
                count: 1,
                includeSkills: false,
                tools: [tool],
              ),
            ],
          ));
        } else {
          builder.toolProficiencies.add(tool);
        }
      }
    }

    // Elecciones abiertas que el rasgo declara en línea (Orden Primordial,
    // Orden Divina): no son dotes, así que se resuelven contra las opciones del
    // slot. Los slots de clase ya están cargados: `klass.featuresUpTo` corrió
    // arriba.
    for (final slot in builder.featureChoiceSlots.values) {
      if (slot.options.isEmpty) continue;
      final chosen = c.featureChoices[slot.groupId] ?? const <String>[];
      for (final option in slot.options
          .where((o) => chosen.contains(o.id))
          .take(slot.count)) {
        applySource(
          'featureOption:' + slot.groupId + ':' + option.id,
          // "Orden Divina: Taumaturgo": sola, la opción no dice de qué elección
          // salió, y así es como se lee en el desglose de la ficha.
          slot.name + ': ' + option.name,
          option.effects,
        );
      }
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
      // Las elecciones abiertas (Estilo de Combate, Invocaciones) son dotes:
      // sus efectos se aplican por el mismo camino que el resto.
      for (final chosen in c.featureChoices.values) ...chosen,
    ];
    final appliedOnce = <String>{};
    final featSourceCounts = <String, int>{};
    for (final id in featIds) {
      if (id == null) continue;
      final feat = repo.feat(id);
      if (feat == null) continue;
      if (!feat.repeatable && !appliedOnce.add(id)) continue;
      final occurrence = featSourceCounts.update(
        feat.id,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      applySource(
        'feat:' +
            feat.id +
            (feat.repeatable ? ':' + occurrence.toString() : ''),
        feat.name,
        feat.effects,
        // Iniciado en la Magia deja elegir INT, SAB o CAR al tomar la dote.
        // Sin elección, manda la que declare el contenido.
        spellAbilityOverride: c.featSpellcastingAbilities[feat.id],
      );
    }

    // Bonos a la característica que el personaje eligió para una dote (Marca
    // Dracónica Potente sube la de su marca). Va acá, después del loop de
    // dotes y antes de calcular las puntuaciones finales.
    for (final (:effect, :source) in builder.abilityBonusesFromFeatChoice) {
      final elegida = featIds
          .whereType<String>()
          .where((id) => repo.feat(id)?.category == effect.featCategory)
          .map((id) => c.featSpellcastingAbilities[id])
          .whereType<Ability>()
          .firstOrNull;
      if (elegida != null) {
        builder.addAbilityBonus(elegida, effect.amount, source: source);
      }
    }

    // Objetos como fuente de efectos: la capa de protección, el anillo de
    // resistencia. Va acá, después de las dotes y antes de que se cierren las
    // puntuaciones y se calcule la CA.
    //
    // Un objeto solo aporta si lo llevás puesto y, cuando lo exige, si está
    // sintonizado. Pasar del límite de tres no recorta nada: el patrón del
    // motor es avisar sin bloquear, y la validación emite
    // `attunement_over_limit`.
    for (final entry in c.inventory) {
      final item = repo.item(entry.itemId);
      if (item == null || item.effects.isEmpty) continue;
      if (!InventoryOps.isEquipped(c, entry, repo)) continue;
      if (item.requiresAttunement && !entry.attuned) continue;
      applySource('item:${item.id}', item.name, item.effects);
    }

    // Habilidades elegidas en el wizard (raza/clase/trasfondo).
    builder.skillProficiencies.addAll(c.chosenSkills);

    // Cupos de competencia que declaran las dotes (Habilidoso, Mente Aguda),
    // con la dote de la que sale cada uno. Se recorre `featIds` de nuevo en vez
    // de leerlo del builder porque ahí la procedencia ya se perdió, y Habilidoso
    // es repetible: dos copias son dos cupos distintos.
    final proficiencySlots = <ProficiencyChoiceSlot>[];
    final slotNames = <String, String>{};
    final slotCounts = <String, int>{};
    final slotSkills = <String, List<String>>{};
    final slotTools = <String, List<String>>{};
    final slotReplaceable = <String, bool>{};
    final slotFallback = <String, String?>{};
    final slotUpgradesToExpertise = <String, bool>{};

    for (final source in proficiencySources) {
      // La Pericia pura se resuelve en una segunda pasada, más abajo: sus
      // opciones son las competencias que quedan cuando este loop terminó.
      //
      // La variante "competencia, o Pericia si ya eras competente" (Mente
      // Aguda) se queda acá a propósito: sus opciones son una lista fija, no
      // dependen de lo que ya tengas, así que sigue siendo una elección de
      // competencia. Sacarla de esta pasada le haría perder la migración del
      // campo viejo `chosenProficiencies`, y con ella la elección guardada de
      // cualquier personaje que venga de antes.
      for (final effect in source.effects
          .whereType<ProficiencyChoiceEffect>()
          .where((e) => !e.expertise || e.allowNewProficiency)) {
        final groupId = effect.groupId ?? source.id + ':proficiency';
        slotNames[groupId] = effect.name ?? source.name;
        slotUpgradesToExpertise[groupId] =
            (slotUpgradesToExpertise[groupId] ?? false) || effect.expertise;
        slotCounts[groupId] = (slotCounts[groupId] ?? 0) + effect.count;
        slotReplaceable[groupId] =
            (slotReplaceable[groupId] ?? false) || effect.replaceable;
        slotFallback[groupId] ??= effect.fallbackFor;

        final skills = slotSkills.putIfAbsent(groupId, () => <String>[]);
        if (effect.includeSkills) {
          final options = effect.skills.isEmpty ? Skill.allIds : effect.skills;
          for (final id in options) {
            if (!skills.contains(id)) skills.add(id);
          }
        }

        final tools = slotTools.putIfAbsent(groupId, () => <String>[]);
        final options = effect.includeTools
            ? toolProficiencyIds
            : expandToolProficiencyChoices(effect.tools);
        for (final id in options) {
          if (!tools.contains(id)) tools.add(id);
        }
      }
    }

    // Lo elegido se aplica donde corresponda: Habilidoso mezcla habilidades y
    // herramientas en una sola lista, así que se separan por el catálogo.
    final legacy = List<String>.of(c.chosenProficiencies);
    for (final groupId in slotCounts.keys) {
      var tools = slotTools[groupId] ?? const <String>[];
      final fallbackFor = slotFallback[groupId];
      if (fallbackFor != null) {
        final chosenElsewhere = c.proficiencyChoices.entries
            .where((entry) => entry.key != groupId)
            .expand((entry) => entry.value);
        final alreadyHadIt = builder.toolProficiencies.contains(fallbackFor) ||
            chosenElsewhere.contains(fallbackFor) ||
            legacy.contains(fallbackFor);
        if (!alreadyHadIt) {
          builder.toolProficiencies.add(fallbackFor);
          continue;
        }
        tools = tools.where((id) => id != fallbackFor).toList();
      }

      final options = <String>[
        ...slotSkills[groupId] ?? const <String>[],
        ...tools,
      ];
      final stored = c.proficiencyChoices[groupId];
      final chosen = stored == null ? <String>[] : List<String>.of(stored);
      if (stored == null) {
        for (final id in List<String>.of(legacy)) {
          if (chosen.length >= slotCounts[groupId]!) break;
          if (!options.contains(id)) continue;
          chosen.add(id);
          legacy.remove(id);
        }
        if (slotCounts.length == 1) {
          while (chosen.length < slotCounts[groupId]! && legacy.isNotEmpty) {
            chosen.add(legacy.removeAt(0));
          }
        }
      }

      proficiencySlots.add(
        ProficiencyChoiceSlot(
          groupId: groupId,
          name: slotNames[groupId] ?? groupId,
          count: slotCounts[groupId]!,
          skills: slotSkills[groupId] ?? const [],
          tools: tools,
          chosen: chosen,
          replaceable: slotReplaceable[groupId] ?? false,
        ),
      );

      for (final id in chosen.where(options.contains)) {
        if (Skill.allIds.contains(id)) {
          // Mente Aguda: si ya eras competente en la habilidad elegida, lo que
          // concede es Pericia en vez de una competencia que ya tenías.
          if ((slotUpgradesToExpertise[groupId] ?? false) &&
              builder.skillProficiencies.contains(id)) {
            builder.expertiseSkills.add(id);
          } else {
            builder.skillProficiencies.add(id);
          }
        } else {
          builder.toolProficiencies.add(id);
        }
      }
    }

    // --- Pericia ---
    // Segunda pasada, después de las competencias: las opciones son "las
    // habilidades en las que ya sos competente", y eso incluye lo que acaba de
    // conceder el loop de arriba (Habilidoso, la elección de trasfondo).
    final expertiseSlots = <ProficiencyChoiceSlot>[];
    final expertiseTaken = <String>{};

    for (final source in proficiencySources) {
      for (final effect in source.effects
          .whereType<ProficiencyChoiceEffect>()
          .where((e) => e.expertise && !e.allowNewProficiency)) {
        final groupId = effect.groupId ?? source.id + ':expertise';
        final pool = effect.skills.isEmpty ? Skill.allIds : effect.skills;
        // Se revalida contra el estado actual y nunca se confía en lo guardado:
        // si el personaje perdió la competencia (cambió de trasfondo), su
        // Pericia deja de ser elegible y el cupo vuelve a quedar pendiente.
        final options = [
          for (final id in pool)
            if (builder.skillProficiencies.contains(id))
              if (!expertiseTaken.contains(id)) id,
        ];

        final chosen = <String>[];
        for (final id in c.proficiencyChoices[groupId] ?? const <String>[]) {
          if (chosen.length >= effect.count) break;
          if (options.contains(id) && !chosen.contains(id)) chosen.add(id);
        }
        // Sacarlas de las opciones de los cupos siguientes es lo que impide que
        // el Pícaro repita a nivel 6 lo que eligió a nivel 1.
        expertiseTaken.addAll(chosen);

        expertiseSlots.add(
          ProficiencyChoiceSlot(
            groupId: groupId,
            name: effect.name ?? source.name,
            count: effect.count,
            skills: options,
            tools: const [],
            chosen: chosen,
            replaceable: effect.replaceable,
            expertise: true,
          ),
        );

        // Las opciones ya se filtraron a competencias que tiene, así que acá
        // no hay rama: todo lo elegido es Pericia.
        builder.expertiseSkills.addAll(chosen);
      }
    }

    // --- Finalización a valores derivados ---
    final scores = {for (final a in Ability.values) a: builder.finalScore(a)};
    final mods = {
      for (final a in Ability.values) a: abilityModifier(scores[a]!)
    };
    final profBonus = proficiencyBonusForLevel(c.level);
    final conMod = mods[Ability.constitution]!;
    final dexMod = mods[Ability.dexterity]!;

    final baseHp = c.hpPerLevel.fold<int>(0, (s, v) => s + v);
    final maxHp = baseHp +
        conMod * c.level +
        builder.bonusMaxHpFlat +
        builder.bonusMaxHpPerLevel * c.level;

    final ac = _armorClass(c, builder, mods);
    final speed = _speed(c, builder);
    final size = _size(c, race);

    final attacksPerAction = 1 + builder.maxExtraAttack;
    final targetChoices = _resolveTargetChoices(c, builder);

    final attacks = <Attack>[];
    for (final entry in c.inventory.where((e) => e.equipped)) {
      final resolved = InventoryOps.resolve(entry, repo);
      final w = resolved.weapon;
      if (w == null) continue;
      for (var unit = 0; unit < entry.quantity; unit++) {
        attacks.add(_attack(
          c,
          w,
          mods,
          profBonus,
          builder,
          magicBonus: resolved.magicBonus,
          weaponId: resolved.item == null ? w.id : entry.entryId,
          sourceEntryId: entry.entryId,
          name: resolved.name,
          isMagic: resolved.item?.isMagic == true || w.magicBonus != 0,
          activeTargetGroups: {
            for (final target in targetChoices.entryIdsByGroup.entries)
              if (target.value.contains(entry.entryId)) target.key,
          },
        ));
      }
    }

    final spellcasting = _spellcasting(builder, c.level, mods, profBonus);

    // Elección de conjuros. Va acá y no antes ni después por dos razones que
    // apuntan en direcciones opuestas: necesita `spellcasting` para el techo de
    // `maxLevelFromSlots`, y tiene que correr **antes** de `_resolveInnate`
    // porque el lanzamiento gratis se resuelve empujando un GrantSpellEffect al
    // builder y dejando que aquél acuñe el recurso.
    final spellChoiceSlots =
        _resolveSpellChoices(c, builder, proficiencySources, spellcasting);

    final innate = _resolveInnate(c, builder, mods, profBonus);

    // Idiomas. Común lo sabe todo personaje y no gasta una de las dos
    // elecciones del origen; lo elegido y lo que conceden los rasgos se unen
    // sin repetir. Se recorta a `originChoiceCount` para que una ficha con más
    // de la cuenta no las aplique todas; la validación además avisa.
    final knownLanguages = <String>{
      Language.universal.id,
      ...c.languages.take(Language.originChoiceCount),
      ...builder.languages,
    };
    // Las elecciones que declara un rasgo se resuelven después, para que su
    // pozo pueda excluir todo lo anterior.
    final languageChoiceSlots =
        _resolveLanguageChoices(c, proficiencySources, knownLanguages);

    // Un id que el catálogo no conoce se descarta acá, igual que en los
    // innatos: contenido incompleto no debe romper la ficha.
    // Marca Dracónica Potente deja siempre preparada la lista que sumó la
    // marca base. Se hace acá y no en el builder porque el orden importa: la
    // marca puede aplicarse después que la dote que promete prepararla.
    if (builder.prepareSpellListAdditions) {
      builder.alwaysPreparedSpellIds.addAll(builder.spellListAdditionIds);
    }

    final alwaysPrepared = {
      for (final id in builder.alwaysPreparedSpellIds)
        if (repo.spell(id) != null) id,
    };

    return ComputedSheet(
      level: c.level,
      proficiencyBonus: profBonus,
      abilityScores: scores,
      abilityModifiers: mods,
      abilityBonuses: List.unmodifiable(builder.abilityBonusSources),
      savingThrowProficiencies: builder.saveProficiencies,
      savingThrowBonus: builder.savingThrowBonus,
      heroicInspirationOnLongRest: builder.heroicInspirationOnLongRest,
      skillProficiencies: builder.skillProficiencies,
      expertiseSkills: builder.expertiseSkills,
      skillBonuses: builder.resolveSkillBonuses(mods),
      armorProficiencies: builder.armorProficiencies,
      weaponProficiencies: builder.weaponProficiencies,
      toolProficiencies: builder.toolProficiencies,
      maxHp: maxHp,
      hitDie: klass?.hitDie ?? 8,
      armorClass: ac,
      carriedWeight: InventoryOps.carriedWeight(c, repo),
      size: size,
      speed: speed,
      initiative: dexMod,
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
      companions: _resolveCompanions(c, builder, proficiencySources, {
        ...c.cantripIds,
        ...c.spellIds,
        ...alwaysPrepared,
        // Un conjuro concedido por un rasgo también se sabe. Sin esto, el
        // Pacto de la Cadena —que regala Encontrar Familiar en vez de ponerlo
        // en la lista— dejaría al brujo sin el familiar que el pacto le da.
        ...innate.spells.map((s) => s.spellId),
      }),
      innateSpells: innate.spells,
      alwaysPreparedSpellIds: alwaysPrepared,
      spellListAdditionIds: {
        for (final id in builder.spellListAdditionIds)
          if (repo.spell(id) != null) id,
      },
      featureChoiceSlots: [
        for (final e in builder.featureChoiceSlots.values)
          FeatureChoiceSlot(
            groupId: e.groupId,
            name: e.name,
            featCategory: e.featCategory,
            count: e.count,
            replaceable: e.replaceable,
            options: e.options,
          ),
      ],
      itemChoiceSlots: [
        for (final e in builder.itemChoiceSlots.values) _itemChoiceSlot(e, c),
      ],
      targetChoiceSlots: targetChoices.slots,
      proficiencyChoiceSlots: proficiencySlots,
      expertiseChoiceSlots: expertiseSlots,
      spellChoiceSlots: spellChoiceSlots,
      wildShape: _resolveWildShape(c, builder),
      languages: knownLanguages,
      languageChoiceSlots: languageChoiceSlots,
      spellcasting: spellcasting,
    );
  }

  /// Cruza los compañeros declarados por los rasgos con el catálogo de
  /// criaturas.
  ///
  /// Los que dependen de un conjuro (Encontrar Familiar, Hallar Corcel) se
  /// descartan si el personaje no lo tiene: el rasgo del Mago concede el
  /// familiar, pero un mago que nunca aprendió el conjuro no tiene ninguno.
  /// Se mira lo aprendido **y** lo siempre preparado, porque el Corcel Fiel del
  /// Paladín llega por la segunda vía.
  List<CompanionOption> _resolveCompanions(
    Character c,
    SheetBuilder builder,
    List<({String id, String name, List<Effect> effects})> sources,
    Set<String> knownSpells,
  ) {
    if (builder.companions.isEmpty) return const [];

    // De qué rasgo salió cada compañero. El builder no lo sabe (guarda el
    // efecto suelto), pero las fuentes ya vienen con su nombre legible.
    final sourceNames = <String, String>{};
    for (final s in sources) {
      for (final e in s.effects.whereType<CompanionEffect>()) {
        sourceNames.putIfAbsent(e.id, () => s.name);
      }
    }

    final options = <CompanionOption>[];
    for (final e in builder.companions.values) {
      if (e.requiresSpell != null && !knownSpells.contains(e.requiresSpell)) {
        continue;
      }
      final forms = [
        for (final id in e.creatureIds)
          if (repo.creature(id) case final Creature form) form,
      ];
      // Sin ninguna forma en el catálogo no hay nada que invocar. Se descarta
      // en silencio por la misma razón que los conjuros innatos: contenido
      // incompleto no debe romper la ficha.
      if (forms.isEmpty) continue;
      options.add(
        CompanionOption(
          id: e.id,
          name: e.name,
          source: sourceNames[e.id] ?? '',
          forms: forms,
          maxActive: e.maxActive,
          spellId: e.requiresSpell,
          // El piso sale del conjuro, no del contenido de la criatura: es el
          // mismo dato y tenerlo dos veces es tenerlo mal una vez.
          minSpellLevel: e.requiresSpell == null
              ? 0
              : repo.spell(e.requiresSpell!)?.level ?? 0,
        ),
      );
    }
    return options;
  }

  /// Arma el cupo de formas de Forma Salvaje: filtra el pozo de bestias por el
  /// valor de desafío y el vuelo que permite el nivel, y revalida lo anotado.
  ///
  /// El pozo se rearma en cada compilación y nunca se confía en lo guardado,
  /// igual que en [_resolveSpellChoices]: un druida que baja de nivel pierde el
  /// oso de VD 1 de la lista sin que haya que tocar la ficha guardada, y lo
  /// recupera si vuelve a subir.
  WildShapeSlot? _resolveWildShape(Character c, SheetBuilder builder) {
    final e = builder.wildShapeForms;
    if (e == null) return null;

    // Una bestia sin valor de desafío declarado no entra: los espíritus
    // invocables también son de tipo Bestia, y el libro les pone «Desafío:
    // ninguno», con lo que no pueden cumplir un máximo.
    final options = [
      for (final beast in repo.creatures.values)
        if (beast.availableToCharacters &&
            beast.isBeast &&
            beast.cr != null &&
            beast.cr! <= e.maxCr &&
            (e.allowFly || !beast.canFly))
          beast,
    ]..sort((a, b) => a.name.compareTo(b.name));

    final eligible = {for (final o in options) o.id: o};
    final chosen = <Creature>[];
    for (final id in c.wildShapeForms) {
      if (chosen.length >= e.count) break;
      final beast = eligible[id];
      if (beast != null && !chosen.contains(beast)) chosen.add(beast);
    }

    return WildShapeSlot(
      count: e.count,
      options: options,
      chosen: chosen,
      canCast: builder.castWhileWildShaped,
    );
  }

  /// Resuelve los conjuros concedidos por rasgos contra el repositorio y, para
  /// los de uso gratuito, crea el recurso que registra ese uso por descanso
  /// largo (así la ficha lo muestra y lo gasta como cualquier otro).
  /// Truco que realmente se lanza: el reemplazo elegido si el rasgo lo permite
  /// y la elección sigue siendo válida, y si no el que declara el contenido.
  ///
  /// Se revalida en cada compilación, igual que el tamaño: el reemplazo tiene
  /// que existir, tener el mismo nivel que el original —un truco se cambia por
  /// otro truco— y pertenecer a la lista declarada. Una elección que dejó de
  /// cumplir eso se ignora en silencio en vez de conceder algo que la regla no
  /// respalda.
  Spell _replacementFor(Character c, GrantSpellEffect g, Spell granted) {
    if (g.replaceableFrom.isEmpty) return granted;
    final chosenId = c.innateCantripChoices[g.spellId];
    if (chosenId == null || chosenId == granted.id) return granted;
    final chosen = repo.spell(chosenId);
    if (chosen == null) return granted;
    if (chosen.level != granted.level) return granted;
    if (!g.replaceableFrom.any(chosen.classes.contains)) return granted;
    return chosen;
  }

  /// Resuelve los cupos de elección de idiomas y **suma lo elegido a
  /// [known]**, que por eso se recibe mutable: un idioma tomado en un cupo no
  /// se vuelve a ofrecer en el siguiente ni cuenta dos veces en la ficha.
  List<LanguageChoiceSlot> _resolveLanguageChoices(
    Character c,
    List<({String id, String name, List<Effect> effects})> sources,
    Set<String> known,
  ) {
    final slots = <LanguageChoiceSlot>[];

    for (final source in sources) {
      for (final effect in source.effects.whereType<LanguageChoiceEffect>()) {
        // El pozo se rearma en cada compilación: lo guardado que el personaje
        // ya sabe por otra vía se descarta en silencio y devuelve el cupo.
        final options = [
          for (final l in Language.values)
            if (!known.contains(l.id))
              if (!effect.standardOnly || l.standard) l.id,
        ];

        final chosen = <String>[];
        for (final id
            in c.languageChoices[effect.groupId] ?? const <String>[]) {
          if (chosen.length >= effect.count) break;
          if (options.contains(id) && !chosen.contains(id)) chosen.add(id);
        }

        slots.add(LanguageChoiceSlot(
          groupId: effect.groupId,
          name: effect.name.isEmpty ? source.name : effect.name,
          count: effect.count,
          options: options,
          chosen: chosen,
        ));

        known.addAll(chosen);
      }
    }
    return slots;
  }

  /// Resuelve los cupos de elección de conjuros: filtra el pozo, revalida lo
  /// guardado y vuelca lo elegido en `alwaysPreparedSpellIds`.
  ///
  /// Ese volcado es el punto entero del mecanismo. A partir de ahí el editor de
  /// conjuros, la vista previa de creación y la validación tratan lo elegido
  /// igual que lo que concede un `AlwaysPreparedSpellEffect`: no gasta cupo de
  /// preparados, no se puede desmarcar y no se ofrece dos veces.
  List<SpellChoiceSlot> _resolveSpellChoices(
    Character c,
    SheetBuilder builder,
    List<({String id, String name, List<Effect> effects})> sources,
    Spellcasting? spellcasting,
  ) {
    final slots = <SpellChoiceSlot>[];
    final maxSlotLevel =
        spellcasting?.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m) ??
            0;

    for (final source in sources) {
      for (final effect in source.effects.whereType<SpellChoiceEffect>()) {
        final ceiling = effect.maxLevelFromSlots
            ? min(effect.maxLevel ?? maxSlotLevel, maxSlotLevel)
            : effect.maxLevel;

        // El pozo se rearma en cada compilación y nunca se confía en lo
        // guardado, igual que la pasada de Pericia y `_replacementFor`.
        final options = [
          for (final s in repo.spellsSorted)
            if (s.level >= effect.minLevel &&
                (ceiling == null || s.level <= ceiling) &&
                (effect.fromClasses.isEmpty ||
                    effect.fromClasses.any(s.classes.contains)) &&
                (effect.schools.isEmpty || effect.schools.contains(s.school)) &&
                (effect.castingTimes.isEmpty ||
                    effect.castingTimes.contains(s.castingTime)) &&
                (!effect.ritualOnly || s.ritual) &&
                // Lo que otro rasgo ya concede no se puede volver a elegir.
                // Como lo elegido se vuelca abajo, esto cubre también los cupos
                // anteriores de este mismo recorrido.
                !builder.alwaysPreparedSpellIds.contains(s.id))
              s.id,
        ];

        // Lanzador Ritual crece con el bonificador por competencia en vez de
        // declarar un grupo por tramo.
        final cupo = effect.countFromProficiency
            ? proficiencyBonusForLevel(c.level)
            : effect.count;

        final chosen = <String>[];
        for (final id in c.spellChoices[effect.groupId] ?? const <String>[]) {
          if (chosen.length >= cupo) break;
          if (options.contains(id) && !chosen.contains(id)) chosen.add(id);
        }

        slots.add(SpellChoiceSlot(
          groupId: effect.groupId,
          name: effect.name.isEmpty ? source.name : effect.name,
          count: cupo,
          options: options,
          chosen: chosen,
          replaceable: effect.replaceable,
        ));

        builder.alwaysPreparedSpellIds.addAll(chosen);

        // El lanzamiento gratis se declara como conjuro innato: así
        // `_resolveInnate` acuña el recurso que lleva la cuenta de los usos sin
        // que este mecanismo sepa nada de recursos ni de descansos.
        if (effect.freeCast != null) {
          // Una dote puede traer su propia característica elegida (Iniciado en
          // la Magia). El id de la fuente es "feat:<id>[:copia]".
          final featId =
              source.id.startsWith('feat:') ? source.id.split(':')[1] : null;
          for (final id in chosen) {
            builder.grantedSpells.add(GrantSpellEffect(
              spellId: id,
              ability: effect.ability ??
                  (featId == null
                      ? null
                      : c.featSpellcastingAbilities[featId]) ??
                  builder.spellcasting?.ability ??
                  Ability.intelligence,
              use: effect.freeCast!,
            ));
          }
        }
      }
    }
    return slots;
  }

  _InnateResult _resolveInnate(
    Character c,
    SheetBuilder builder,
    Map<Ability, int> mods,
    int proficiencyBonus,
  ) {
    final spells = <InnateSpell>[];
    final resources = <CharacterResource>[];
    for (final g in builder.grantedSpells) {
      final granted = repo.spell(g.spellId);
      if (granted == null) continue; // contenido incompleto: se ignora
      final spell = _replacementFor(c, g, granted);
      final mod = mods[g.ability] ?? 0;
      spells.add(InnateSpell(
        spellId: spell.id,
        name: spell.name,
        level: spell.level,
        ability: g.ability,
        use: g.use,
        saveDc: 8 + proficiencyBonus + mod,
        attackBonus: proficiencyBonus + mod,
        grantedSpellId: granted.id,
        replaceableFrom: g.replaceableFrom,
      ));
      if (g.use != InnateSpellUse.atWill) {
        resources.add(CharacterResource(
          // Se indexa por el conjuro del contenido, no por el reemplazo: si no,
          // cambiar el truco devolvería los usos ya gastados.
          id: innateSpellResourceId(granted.id),
          name: spell.name,
          max: g.use == InnateSpellUse.proficiencyBonusPerLongRest
              ? proficiencyBonus
              : 1,
          recharge: g.use == InnateSpellUse.oncePerShortRest
              ? RechargeOn.shortRest
              : RechargeOn.longRest,
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
      final equipped = c.inventory
          .where((e) => e.equipped)
          .map((e) => InventoryOps.resolve(e, repo));
      final armor = equipped
          .map((e) => e.armor)
          .whereType<Armor>()
          .where((e) => !e.isShield)
          .firstOrNull;
      var voided = false;
      if (armor != null && !armor.isShield) {
        voided =
            b.unarmoredMovementHeavyOnly ? armor.category == 'heavy' : true;
      }
      final hasShield = equipped.any((e) => e.armor?.isShield == true);
      if (hasShield && !b.unarmoredMovementAllowShield) voided = true;
      if (!voided) speed += b.unarmoredMovementBonus;
    }
    return speed;
  }

  /// Tamaño final: el elegido si la especie ofrece la elección y el valor sigue
  /// siendo una de sus opciones; si no, el de la especie.
  ///
  /// Se revalida contra el catálogo en cada compilación a propósito: un
  /// personaje guardado puede traer un tamaño que la especie ya no ofrece
  /// —porque cambió de especie, o porque el homebrew que lo declaraba
  /// desapareció— y en ese caso vale más caer al valor de la especie que
  /// mostrar un tamaño que nada respalda.
  String _size(Character c, Race? race) {
    if (race == null) return c.chosenSize ?? 'Mediano';
    final chosen = c.chosenSize;
    if (chosen != null && race.sizeOptions.contains(chosen)) return chosen;
    return race.size;
  }

  int _armorClass(Character c, SheetBuilder b, Map<Ability, int> mods) {
    final dexMod = mods[Ability.dexterity]!;
    var ac = 10 + dexMod; // Sin armadura.
    final equipped = c.inventory
        .where((e) => e.equipped)
        .map((e) => InventoryOps.resolve(e, repo))
        .toList();
    final armor = equipped
        .map((e) => e.armor)
        .whereType<Armor>()
        .where((e) => !e.isShield)
        .firstOrNull;
    final shield = equipped.where((e) => e.armor?.isShield == true).firstOrNull;
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
      final voidedByShield = shield != null && !b.unarmoredDefenseAllowShield;
      if (!voidedByShield) {
        ac = 10 + dexMod + mods[b.unarmoredDefenseAbility!]!;
      }
    }
    if (shield != null) ac += shield.armor!.baseAc + shield.magicBonus;
    if (armor != null) {
      final armorEntry = equipped.firstWhere((e) => e.armor == armor);
      ac += armorEntry.magicBonus;
    }
    ac += b.acBonus;
    return ac;
  }

  _TargetChoiceResolution _resolveTargetChoices(
      Character c, SheetBuilder builder) {
    final slots = <TargetChoiceSlot>[];
    final entryIdsByGroup = <String, Set<String>>{};

    for (final effect in builder.targetChoiceSlots.values) {
      final eligibleEntryIds = <String>[];
      for (final entry in c.inventory) {
        final resolved = InventoryOps.resolve(entry, repo);
        final weapon = resolved.weapon;
        if (weapon == null) continue;

        final generated = entry.origin == 'effect-target:${effect.groupId}';
        final filter = generated ? effect.createFilter : effect.existingFilter;
        if (filter == null) continue;
        final isMagic =
            resolved.item?.isMagic == true || weapon.magicBonus != 0;
        if (_weaponMatches(filter, weapon, isMagic: isMagic)) {
          eligibleEntryIds.add(entry.entryId);
        }
      }

      final eligible = eligibleEntryIds.toSet();
      final chosen = <String>[];
      for (final entryId in c.effectTargets[effect.groupId] ?? const []) {
        if (chosen.length >= effect.count) break;
        if (eligible.contains(entryId) && !chosen.contains(entryId)) {
          chosen.add(entryId);
        }
      }
      entryIdsByGroup[effect.groupId] = chosen.toSet();

      final creatableWeaponIds = effect.createFilter == null
          ? const <String>[]
          : [
              for (final weapon in repo.weaponsSorted)
                if (_weaponMatches(
                  effect.createFilter!,
                  weapon,
                  isMagic: weapon.magicBonus != 0,
                ))
                  weapon.id,
            ];

      slots.add(TargetChoiceSlot(
        groupId: effect.groupId,
        name: effect.name,
        count: effect.count,
        replaceable: effect.replaceable,
        eligibleEntryIds: List.unmodifiable(eligibleEntryIds),
        creatableWeaponIds: List.unmodifiable(creatableWeaponIds),
        chosenEntryIds: List.unmodifiable(chosen),
      ));
    }

    return _TargetChoiceResolution(
      slots: List.unmodifiable(slots),
      entryIdsByGroup: entryIdsByGroup,
    );
  }

  Attack _attack(Character c, Weapon w, Map<Ability, int> mods, int profBonus,
      SheetBuilder b,
      {int magicBonus = 0,
      String? weaponId,
      String? sourceEntryId,
      String? name,
      bool isMagic = false,
      Set<String> activeTargetGroups = const {}}) {
    final normalAbilities = <Ability>[];
    if (w.isRanged) {
      normalAbilities.add(Ability.dexterity);
    } else if (w.isFinesse) {
      normalAbilities.addAll([Ability.strength, Ability.dexterity]);
    } else {
      normalAbilities.add(Ability.strength);
    }

    final context = _WeaponAttackContext(
      proficient: w.isProficientWith(b.weaponProficiencies),
      abilityOptions: normalAbilities,
      damageTypeOptions: [w.damageType],
      extraAttacks: b.maxExtraAttack,
    );
    for (final rule in b.weaponRules) {
      final targetGroupId = rule.targetGroupId;
      if (targetGroupId != null &&
          !activeTargetGroups.contains(targetGroupId)) {
        continue;
      }
      if (!_weaponMatches(rule.filter, w, isMagic: isMagic)) continue;
      context.apply(rule);
    }

    var abilityUsed = context.abilityOptions.first;
    for (final candidate in context.abilityOptions.skip(1)) {
      if (mods[candidate]! > mods[abilityUsed]!) abilityUsed = candidate;
    }
    final abilityMod = mods[abilityUsed]!;
    final proficient = context.proficient;
    // El bono mágico suma al ataque y al daño. Vive en el arma y no como
    // efecto porque ningún efecto sabe decir "solo esta arma".
    final attackBonus =
        abilityMod + (proficient ? profBonus : 0) + w.magicBonus + magicBonus;

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
      weaponId: weaponId ?? w.id,
      baseWeaponId: w.id,
      sourceEntryId: sourceEntryId,
      name: name ?? w.name,
      attackBonus: attackBonus,
      proficient: proficient,
      abilityUsed: abilityUsed,
      damage: _damageString(dice, damageMod + w.magicBonus + magicBonus),
      damageType: w.damageType,
      damageTypeOptions: List.unmodifiable(context.damageTypeOptions),
      spellcastingFocus: context.spellcastingFocus,
      attacksPerAction: 1 + context.extraAttacks,
      mastery: hasMastery ? w.mastery : null,
      offHand: offHand,
      action: action,
    );
  }

  bool _weaponMatches(WeaponFilter filter, Weapon weapon,
      {required bool isMagic}) {
    if (filter.magic != null && filter.magic != isMagic) return false;
    if (filter.melee != null && filter.melee != !weapon.isRanged) return false;
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(weapon.category)) return false;
    if (filter.properties.isNotEmpty &&
        !filter.properties.every(weapon.properties.contains)) return false;
    return true;
  }

  String _damageString(String dice, int mod) {
    if (mod == 0) return dice;
    return mod > 0 ? '$dice + $mod' : '$dice - ${mod.abs()}';
  }
}

class _TargetChoiceResolution {
  final List<TargetChoiceSlot> slots;
  final Map<String, Set<String>> entryIdsByGroup;

  const _TargetChoiceResolution({
    required this.slots,
    required this.entryIdsByGroup,
  });
}

class _WeaponAttackContext {
  bool proficient;
  final List<Ability> abilityOptions;
  final List<String> damageTypeOptions;
  bool spellcastingFocus = false;
  int extraAttacks;

  _WeaponAttackContext({
    required this.proficient,
    required Iterable<Ability> abilityOptions,
    required Iterable<String> damageTypeOptions,
    this.extraAttacks = 0,
  })  : abilityOptions = abilityOptions.toSet().toList(),
        damageTypeOptions = damageTypeOptions.toSet().toList();

  void apply(WeaponRuleEffect rule) {
    proficient = proficient || rule.grantsProficiency;
    for (final ability in rule.abilityOptions) {
      if (!abilityOptions.contains(ability)) abilityOptions.add(ability);
    }
    for (final type in rule.damageTypeOptions) {
      if (!damageTypeOptions.contains(type)) damageTypeOptions.add(type);
    }
    spellcastingFocus = spellcastingFocus || rule.spellcastingFocus;
    extraAttacks = max(extraAttacks, rule.extraAttacks);
  }
}

/// Par de listas que sale de resolver los conjuros concedidos por rasgos.
class _InnateResult {
  final List<InnateSpell> spells;
  final List<CharacterResource> resources;
  const _InnateResult(this.spells, this.resources);
}
