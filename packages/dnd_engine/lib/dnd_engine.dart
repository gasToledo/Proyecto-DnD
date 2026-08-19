/// Motor de reglas dirigido por datos para fichas de personaje de D&D 5e.
/// Núcleo Dart puro, sin dependencias de Flutter. Baseline: SRD 5.2 (2024).
library dnd_engine;

export 'src/domain/ability.dart';
export 'src/domain/alignment.dart';
export 'src/domain/data_version.dart';
export 'src/domain/damage_type.dart';
export 'src/domain/language.dart';
export 'src/domain/name_sort.dart';
export 'src/domain/proficiency_labels.dart';
export 'src/domain/skill.dart';
export 'src/domain/weapon_mastery.dart';
export 'src/domain/content_source.dart';
export 'src/domain/effects.dart';
export 'src/domain/spell_slots.dart';
export 'src/domain/content.dart';
export 'src/domain/creature.dart';
export 'src/domain/character.dart';
export 'src/domain/campaign.dart';
export 'src/domain/chapter.dart';
export 'src/domain/encounter.dart';
export 'src/domain/computed_sheet.dart';
export 'src/data/content_repository.dart';
export 'src/engine/sheet_builder.dart';
export 'src/engine/character_compiler.dart';
export 'src/engine/validation.dart';
export 'src/engine/dice.dart';
export 'src/engine/initiative.dart';
export 'src/engine/combat_ops.dart';
export 'src/engine/inventory_ops.dart';
export 'src/engine/wild_shape.dart';
export 'src/engine/sheet_diff.dart';
