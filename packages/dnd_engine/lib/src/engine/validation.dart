import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
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
      w.add(ValidationWarning('missing_race', 'Raza "${c.raceId}" no encontrada.'));
    }
    final klass = repo.characterClass(c.classId);
    if (klass == null) {
      w.add(ValidationWarning('missing_class', 'Clase "${c.classId}" no encontrada.'));
    }
    final background = repo.background(c.backgroundId);
    if (background == null) {
      w.add(ValidationWarning(
          'missing_background', 'Trasfondo "${c.backgroundId}" no encontrado.'));
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
      w.add(ValidationWarning('no_weapon', 'No hay arma equipada.',
          WarningSeverity.info));
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
      final allowedSkills = {...race?.skillChoiceFrom ?? const [], ...klass.skillChoiceFrom};
      final expectedCount = (race?.skillChoiceCount ?? 0) + klass.skillChoiceCount;
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
      // Si la raza otorga elección libre (cupo > 0 sin lista), no se puede
      // validar membresía por habilidad sin trackear de qué origen viene cada
      // elección: se omite ese chequeo puntual para no generar falsos positivos.
      final raceGrantsFreeChoice =
          (race?.skillChoiceCount ?? 0) > 0 && (race?.skillChoiceFrom.isEmpty ?? true);
      if (allowedSkills.isNotEmpty && !raceGrantsFreeChoice) {
        for (final s in c.chosenSkills) {
          if (!allowedSkills.contains(s)) {
            w.add(ValidationWarning(
              'skill_choice_invalid',
              'Habilidad "$s" no está entre las opciones de raza/clase.',
            ));
          }
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
    }

    final chosenFeatIds = <String?>[
      background?.originFeatId,
      ...c.featIds,
      c.fightingStyleId,
    ];
    for (final id in chosenFeatIds) {
      if (id == null) continue;
      final feat = repo.feat(id);
      final prereq = feat?.prerequisite;
      if (feat == null || prereq == null || prereq.isEmpty) continue;
      final missing = _unmetPrerequisite(prereq, c, sheet);
      if (missing != null) {
        w.add(ValidationWarning(
          'feat_prerequisite',
          '${feat.name}: no cumplís el prerrequisito ($missing).',
        ));
      }
    }

    return w;
  }

  /// Devuelve una descripción del primer prerrequisito incumplido, o null si
  /// se cumplen todos.
  String? _unmetPrerequisite(
      FeatPrerequisite prereq, Character c, ComputedSheet sheet) {
    for (final entry in prereq.minAbilityScores.entries) {
      if (sheet.abilityScores[entry.key]! < entry.value) {
        return '${entry.key.abbr} ${entry.value}';
      }
    }
    final reqProf = prereq.requiredProficiency;
    if (reqProf != null) {
      final has = reqProf == 'spellcasting'
          ? false // El motor todavía no modela lanzamiento; se deja pendiente.
          : (sheet.weaponProficiencies.contains(reqProf) ||
              sheet.armorProficiencies.contains(reqProf) ||
              sheet.toolProficiencies.contains(reqProf) ||
              sheet.skillProficiencies.contains(reqProf));
      if (!has) return 'competencia "$reqProf"';
    }
    if (prereq.minLevel != null && c.level < prereq.minLevel!) {
      return 'nivel ${prereq.minLevel}';
    }
    return null;
  }
}
