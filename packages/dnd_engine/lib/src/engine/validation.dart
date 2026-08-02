import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/effects.dart';
import '../domain/skill.dart';
import '../domain/spell_slots.dart';
import 'character_compiler.dart';

enum WarningSeverity { info, warning }

/// Advertencia de reglas. **Nunca bloquea**: la app siempre informa pero deja
/// actuar (el DM puede autorizar excepciones). Ver brief §6.
class ValidationWarning {
  final String code;
  final String message;
  final WarningSeverity severity;
  const ValidationWarning(this.code, this.message,
      [this.severity = WarningSeverity.warning]);

  @override
  String toString() => '[$code] $message';
}

/// Valida un personaje contra las reglas y devuelve advertencias, sin impedir
/// nada. Recibe el repositorio para chequear competencias y referencias.
class CharacterValidator {
  final ContentRepository repo;
  const CharacterValidator(this.repo);

  List<ValidationWarning> validate(Character c) {
    final w = <ValidationWarning>[];

    final race = repo.race(c.raceId);
    if (race == null) {
      w.add(ValidationWarning(
          'missing_race', 'Raza "${c.raceId}" no encontrada.'));
    } else {
      // Linaje de especie: obligatorio si la especie ofrece alguno. Sin él, los
      // rasgos que dependen de la elección (resistencias, trucos) no se aplican.
      final options = repo.lineagesForRace(c.raceId);
      final lineageId = c.lineageId;
      if (lineageId == null) {
        if (options.isNotEmpty) {
          w.add(ValidationWarning(
            'lineage_pending',
            'Falta elegir el linaje de ${race.name} '
                '(${options.map((l) => l.name).join(", ")}).',
          ));
        }
      } else {
        final lineage = repo.lineage(lineageId);
        if (lineage == null) {
          w.add(ValidationWarning(
              'lineage_missing', 'Linaje "$lineageId" no encontrado.'));
        } else if (lineage.raceId != c.raceId) {
          w.add(ValidationWarning(
            'lineage_wrong_race',
            'El linaje "${lineage.name}" pertenece a ${lineage.raceId}, '
                'no a ${c.raceId}.',
          ));
        } else if (_lineageUsesSpellcasting(lineage) &&
            c.speciesSpellcastingAbility == null) {
          w.add(const ValidationWarning(
            'species_spellcasting_ability_pending',
            'Falta elegir la aptitud mágica del linaje (INT, SAB o CAR).',
          ));
        }
      }
    }
    final klass = repo.characterClass(c.classId);
    if (klass == null) {
      w.add(ValidationWarning(
          'missing_class', 'Clase "${c.classId}" no encontrada.'));
    }
    final background = repo.background(c.backgroundId);
    if (background == null) {
      w.add(ValidationWarning('missing_background',
          'Trasfondo "${c.backgroundId}" no encontrado.'));
    }

    if (c.hpPerLevel.length != c.level) {
      w.add(ValidationWarning(
        'hp_entries',
        'Faltan aportes de PG: ${c.hpPerLevel.length} registrados para ${c.level} niveles.',
      ));
    }

    // Se compila para chequear valores derivados (maestrías, competencia).
    final sheet = CharacterCompiler(repo).compile(c);

    for (final a in Ability.values) {
      if (sheet.abilityScores[a]! > 20) {
        w.add(ValidationWarning(
          'ability_over_20',
          '${a.abbr} supera 20 (${sheet.abilityScores[a]}).',
        ));
      }
    }

    if (c.weaponMasteryChoices.length > sheet.weaponMasterySlots) {
      w.add(ValidationWarning(
        'too_many_masteries',
        'Elegiste ${c.weaponMasteryChoices.length} maestrías pero tenés ${sheet.weaponMasterySlots} espacios.',
      ));
    }

    // La maestría requiere competencia con el arma. La elección se conserva por
    // si más adelante ganás la competencia, pero mientras tanto no se aplica.
    for (final weaponId in c.weaponMasteryChoices) {
      final weapon = repo.weapon(weaponId);
      if (weapon == null) continue;
      final proficient = sheet.weaponProficiencies.contains(weapon.category) ||
          sheet.weaponProficiencies.contains(weapon.id);
      if (!proficient) {
        w.add(ValidationWarning(
          'mastery_not_proficient',
          'No sos competente con ${weapon.name}: su maestría no se aplica.',
        ));
      }
    }

    final armorId = c.equippedArmorId;
    if (armorId != null) {
      final armor = repo.armorPiece(armorId);
      if (armor != null &&
          !armor.isShield &&
          !sheet.armorProficiencies.contains(armor.category)) {
        w.add(ValidationWarning(
          'armor_not_proficient',
          'No sos competente con armadura ${armor.category}: desventaja y no podés lanzar conjuros.',
        ));
      }
      final strReq = armor?.strengthRequirement;
      if (strReq != null && sheet.abilityScores[Ability.strength]! < strReq) {
        w.add(ValidationWarning(
          'armor_strength',
          '${armor!.name} requiere Fuerza $strReq: tu velocidad baja 10 pies.',
          WarningSeverity.info,
        ));
      }
    }

    if (c.equippedWeaponIds.isEmpty) {
      w.add(ValidationWarning(
          'no_weapon', 'No hay arma equipada.', WarningSeverity.info));
    }

    for (final wid in c.equippedWeaponIds) {
      final weapon = repo.weapon(wid);
      if (weapon == null) continue;
      final proficient = sheet.weaponProficiencies.contains(weapon.category) ||
          sheet.weaponProficiencies.contains(weapon.id);
      if (!proficient) {
        w.add(ValidationWarning(
          'weapon_not_proficient',
          'No sos competente con ${weapon.name}: no sumás el bono de competencia al ataque.',
        ));
      }
    }

    for (final a in c.assignedScores.values) {
      if (a < 3 || a > 18) {
        w.add(ValidationWarning(
          'ability_out_of_range',
          'Una puntuación asignada ($a) está fuera del rango típico de generación (3-18).',
          WarningSeverity.info,
        ));
      }
    }

    if (klass != null) {
      final raceSkillOptions = race == null
          ? const <String>[]
          : _skillChoiceOptions(
              race.skillChoiceCount,
              race.skillChoiceFrom,
            );
      final classSkillOptions = _skillChoiceOptions(
        klass.skillChoiceCount,
        klass.skillChoiceFrom,
      );
      final allowedSkills = {...raceSkillOptions, ...classSkillOptions};
      final expectedCount =
          (race?.skillChoiceCount ?? 0) + klass.skillChoiceCount;
      if (c.chosenSkills.length != expectedCount) {
        w.add(ValidationWarning(
          'skill_choice_count',
          'Elegiste ${c.chosenSkills.length} habilidades pero corresponden $expectedCount.',
        ));
      }
      if (c.chosenSkills.toSet().length != c.chosenSkills.length) {
        w.add(ValidationWarning(
          'skill_choice_duplicate',
          'Hay habilidades elegidas repetidas.',
        ));
      }
      for (final s in c.chosenSkills) {
        if (!allowedSkills.contains(s)) {
          w.add(ValidationWarning(
            'skill_choice_invalid',
            'Habilidad "$s" no está entre las opciones de raza/clase.',
          ));
        }
      }

      for (final level in klass.asiLevels) {
        if (level > c.level) continue;
        final hasChoice = c.asiChoices.any((a) => a.level == level);
        if (!hasChoice) {
          w.add(ValidationWarning(
            'asi_pending',
            'Nivel $level: falta elegir mejora de característica o dote.',
            WarningSeverity.info,
          ));
        }
      }
      for (final asi in c.asiChoices) {
        if (!klass.asiLevels.contains(asi.level)) {
          w.add(ValidationWarning(
            'asi_invalid_level',
            'Nivel ${asi.level} no es un nivel de Mejora de Característica de ${klass.name}.',
          ));
        }
      }

      // Subclase: obligatoria a partir del subclassLevel; debe existir y
      // pertenecer a la clase.
      final subId = c.subclassId;
      if (subId == null) {
        if (c.level >= klass.subclassLevel) {
          w.add(ValidationWarning(
            'subclass_pending',
            'Nivel ${klass.subclassLevel}: falta elegir subclase de ${klass.name}.',
            WarningSeverity.info,
          ));
        }
      } else {
        final sub = repo.subclass(subId);
        if (sub == null) {
          w.add(ValidationWarning(
              'subclass_missing', 'Subclase "$subId" no encontrada.'));
        } else if (sub.classId != c.classId) {
          w.add(ValidationWarning(
            'subclass_wrong_class',
            'La subclase ${sub.name} no pertenece a ${klass.name}.',
          ));
        }
      }
    }

    for (final r in sheet.resources) {
      if (r.max <= 0) {
        w.add(ValidationWarning(
          'resource_zero_max',
          'El recurso "${r.name}" tiene 0 usos: revisá su definición (falta "max"?).',
        ));
      }
    }

    _validateSpells(c, sheet, w);

    final heldList = <String?>[
      repo.background(c.backgroundId)?.originFeatId,
      ...c.featIds,
      c.fightingStyleId,
    ].whereType<String>().toList();
    final held = heldList.toSet();

    final counts = <String, int>{};
    for (final id in heldList) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final entry in counts.entries.where((e) => e.value > 1)) {
      final feat = repo.feat(entry.key);
      if (feat != null && !feat.repeatable) {
        w.add(ValidationWarning(
          'feat_duplicate',
          '${feat.name}: esta dote no se puede elegir más de una vez.',
        ));
      }
    }

    final exclusiveGroups = <String, Set<String>>{};
    for (final id in held) {
      final feat = repo.feat(id);
      final group = feat?.effectiveExclusiveGroup;
      if (group != null) {
        exclusiveGroups.putIfAbsent(group, () => <String>{}).add(id);
      }
    }
    for (final entry
        in exclusiveGroups.entries.where((e) => e.value.length > 1)) {
      final names =
          entry.value.map((id) => repo.feat(id)?.name ?? id).join(', ');
      w.add(ValidationWarning(
        'feat_exclusive_group',
        'Estas dotes son mutuamente excluyentes: $names.',
      ));
    }

    // El set completo se necesita para las dotes que exigen otra dote: una
    // marca mayor mira si la marca base también está elegida.
    for (final id in held) {
      final feat = repo.feat(id);
      if (feat == null) continue;
      final missing = unmetFeatPrerequisite(feat, c, sheet, held: held);
      if (missing != null) {
        w.add(ValidationWarning(
          'feat_prerequisite',
          '${feat.name}: no cumplís el prerrequisito ($missing).',
        ));
      }
    }

    return w;
  }

  bool _lineageUsesSpellcasting(Lineage lineage) => lineage.features.any(
        (feature) =>
            feature.effects.any((effect) => effect is GrantSpellEffect),
      );

  /// Chequeos no bloqueantes sobre trucos y conjuros elegidos.
  void _validateSpells(
      Character c, ComputedSheet sheet, List<ValidationWarning> w) {
    final sc = sheet.spellcasting;
    if (sc == null) {
      if (c.cantripIds.isNotEmpty || c.spellIds.isNotEmpty) {
        w.add(ValidationWarning(
          'spells_without_caster',
          'Hay conjuros elegidos pero esta clase no lanza conjuros.',
        ));
      }
      return;
    }

    final list = repo.spellsForList(sc.spellList).map((s) => s.id).toSet();
    final maxSlotLevel =
        sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    // Un rasgo que concede un conjuro ya lo da "siempre preparado" y con un uso
    // gratis: volver a elegirlo desde la clase no suma nada y gasta un cupo.
    final grantedSpellIds = {for (final s in sheet.innateSpells) s.spellId};

    if (c.cantripIds.length > sc.cantripsKnown) {
      w.add(ValidationWarning(
        'too_many_cantrips',
        'Elegiste ${c.cantripIds.length} trucos pero conocés ${sc.cantripsKnown}.',
      ));
    }
    for (final id in c.cantripIds) {
      final sp = repo.spell(id);
      if (sp == null) {
        w.add(ValidationWarning('spell_missing', 'Truco "$id" no encontrado.'));
      } else if (!sp.isCantrip) {
        w.add(ValidationWarning(
            'cantrip_not_level_0', '${sp.name} no es un truco.'));
      } else if (!list.contains(id)) {
        w.add(ValidationWarning('cantrip_wrong_list',
            '${sp.name} no está en la lista de ${sc.spellList}.'));
      } else if (grantedSpellIds.contains(id)) {
        w.add(ValidationWarning('cantrip_already_granted',
            '${sp.name} ya lo tenés por un rasgo de tu especie: elegilo de clase ocupa un cupo de más.'));
      }
    }

    if (sc.preparation == SpellPreparation.prepared &&
        c.spellIds.length > sc.preparedCount) {
      w.add(ValidationWarning(
        'too_many_prepared',
        'Preparaste ${c.spellIds.length} conjuros pero podés preparar ${sc.preparedCount}.',
      ));
    }
    for (final id in c.spellIds) {
      final sp = repo.spell(id);
      if (sp == null) {
        w.add(
            ValidationWarning('spell_missing', 'Conjuro "$id" no encontrado.'));
        continue;
      }
      if (sp.isCantrip) {
        w.add(ValidationWarning('spell_is_cantrip',
            '${sp.name} es un truco; va en la lista de trucos.'));
        continue;
      }
      if (!list.contains(id)) {
        w.add(ValidationWarning('spell_wrong_list',
            '${sp.name} no está en la lista de ${sc.spellList}.'));
      }
      if (grantedSpellIds.contains(id)) {
        w.add(ValidationWarning('spell_already_granted',
            '${sp.name} ya lo tenés siempre preparado por un rasgo de tu especie: prepararlo ocupa un cupo de más.'));
      }
      if (maxSlotLevel > 0 && sp.level > maxSlotLevel) {
        w.add(ValidationWarning(
          'spell_level_too_high',
          '${sp.name} (nivel ${sp.level}) supera tu mayor espacio (nivel $maxSlotLevel).',
          WarningSeverity.info,
        ));
      }
    }
  }

  /// Ids de todas las dotes que el personaje ya tiene: la de origen del
  /// trasfondo, las elegidas (incluida la que concede la especie) y el estilo
  /// de combate. Es lo que hay que mirar para las dotes que exigen otra dote.
  Set<String> heldFeatIds(Character c) => <String?>[
        repo.background(c.backgroundId)?.originFeatId,
        ...c.featIds,
        c.fightingStyleId,
      ].whereType<String>().toSet();

  /// Descripción del primer prerrequisito de [feat] que [c] no cumple, o null
  /// si los cumple todos (o si la dote no exige nada).
  ///
  /// La UI la usa para no ofrecer dotes inelegibles; `validate` la usa para
  /// avisar sobre las que ya están elegidas. Ambas comparten esta única
  /// implementación: las reglas no se duplican en la app.
  ///
  /// [held] permite pasar el set ya calculado cuando se evalúan muchas dotes
  /// seguidas, y también evaluar una dote todavía **no** elegida sin que se
  /// cuente a sí misma.
  String? unmetFeatPrerequisite(Feat feat, Character c, ComputedSheet sheet,
      {Set<String>? held}) {
    final heldIds = held ?? heldFeatIds(c);
    final exclusiveGroup = feat.effectiveExclusiveGroup;
    if (exclusiveGroup != null &&
        heldIds.any((id) =>
            id != feat.id &&
            repo.feat(id)?.effectiveExclusiveGroup == exclusiveGroup)) {
      return 'no tener otra dote del grupo "$exclusiveGroup"';
    }
    final prereq = feat.prerequisite;
    if (prereq == null || prereq.isEmpty) return null;
    return _unmetPrerequisite(prereq, c, sheet, heldIds);
  }

  /// Devuelve una descripción del primer prerrequisito incumplido, o null si
  /// se cumplen todos.
  String? _unmetPrerequisite(FeatPrerequisite prereq, Character c,
      ComputedSheet sheet, Set<String> heldFeatIds) {
    for (final entry in prereq.minAbilityScores.entries) {
      if (sheet.abilityScores[entry.key]! < entry.value) {
        return '${entry.key.abbr} ${entry.value}';
      }
    }
    // Basta una: el PHB 2024 escribe "Fuerza o Destreza 13 o más".
    final any = prereq.anyAbilityScores;
    if (any.isNotEmpty &&
        !any.entries.any((e) => sheet.abilityScores[e.key]! >= e.value)) {
      return any.entries.map((e) => '${e.key.abbr} ${e.value}').join(' o ');
    }
    final reqProf = prereq.requiredProficiency;
    if (reqProf != null) {
      final has = reqProf == 'spellcasting'
          ? sheet.spellcasting != null
          : (sheet.weaponProficiencies.contains(reqProf) ||
              sheet.armorProficiencies.contains(reqProf) ||
              sheet.toolProficiencies.contains(reqProf) ||
              sheet.skillProficiencies.contains(reqProf));
      if (!has) return 'competencia "$reqProf"';
    }
    final reqFeats = prereq.requiredFeatIds;
    if (reqFeats.isNotEmpty && !reqFeats.any(heldFeatIds.contains)) {
      final names = reqFeats.map((id) => repo.feat(id)?.name ?? id);
      return 'la dote ${names.join(' o ')}';
    }
    final reqCategory = prereq.requiredFeatCategory;
    if (reqCategory != null &&
        !heldFeatIds.any((id) => repo.feat(id)?.category == reqCategory)) {
      return 'alguna dote de categoría "$reqCategory"';
    }
    final reqFeature = prereq.requiredClassFeature;
    if (reqFeature != null) {
      final has = repo.characterClass(c.classId)?.features.any((feature) =>
              feature.level <= c.level && feature.name == reqFeature) ??
          false;
      if (!has) return 'el rasgo de clase "$reqFeature"';
    }
    if (prereq.minLevel != null && c.level < prereq.minLevel!) {
      return 'nivel ${prereq.minLevel}';
    }
    return null;
  }
}

/// Una lista vacía con cupo positivo significa "cualquier habilidad" en el
/// contenido 2024 (por ejemplo, el Bardo), no "ninguna habilidad".
Iterable<String> _skillChoiceOptions(int count, List<String> from) =>
    count > 0 && from.isEmpty ? Skill.allIds : from;
