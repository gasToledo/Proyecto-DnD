import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
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

    if (repo.race(c.raceId) == null) {
      w.add(ValidationWarning('missing_race', 'Raza "${c.raceId}" no encontrada.'));
    }
    final klass = repo.characterClass(c.classId);
    if (klass == null) {
      w.add(ValidationWarning('missing_class', 'Clase "${c.classId}" no encontrada.'));
    }
    if (repo.background(c.backgroundId) == null) {
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

    return w;
  }
}
