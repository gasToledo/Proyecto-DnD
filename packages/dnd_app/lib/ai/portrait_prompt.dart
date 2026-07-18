import 'package:dnd_engine/dnd_engine.dart';

/// Estilos predeterminados para la generación de retratos (brief §3.B.3 / §9).
const portraitStyles = <String>[
  'Arte digital de fantasía',
  'Óleo clásico',
  'Ilustración de cómic',
  'Realista cinematográfico',
  'Acuarela',
  'Pixel art',
  'Boceto a lápiz',
];

/// Construye el prompt de retrato auto-completando datos ya conocidos de la
/// ficha (raza, clase, armadura, arma) y sumando texto libre y estilo. Puro y
/// testeable (brief §3.B.2).
String buildPortraitPrompt({
  required Character character,
  required ContentRepository repo,
  required String style,
  required String extraText,
}) {
  final race = repo.race(character.raceId)?.name ?? '';
  final klass = repo.characterClass(character.classId)?.name ?? '';
  final armor = character.equippedArmorId == null
      ? null
      : repo.armorPiece(character.equippedArmorId!)?.name;
  final weapon = character.equippedWeaponIds.isEmpty
      ? null
      : repo.weapon(character.equippedWeaponIds.first)?.name;

  final parts = <String>[
    'Retrato de personaje de fantasía (D&D)',
    [race, klass].where((s) => s.isNotEmpty).join(' '),
  ];
  if (armor != null) parts.add('viste $armor');
  if (weapon != null) parts.add('porta $weapon');
  final extra = extraText.trim();
  if (extra.isNotEmpty) parts.add(extra);

  final base = parts.where((s) => s.isNotEmpty).join(', ');
  final styleClause = style.trim().isEmpty ? '' : ' Estilo: ${style.trim()}.';
  return '$base. Encuadre tipo busto/retrato, fondo simple.$styleClause';
}
