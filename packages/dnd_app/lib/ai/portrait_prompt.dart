import 'package:dnd_engine/dnd_engine.dart';

/// Estilos predeterminados para la generación de retratos.
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
/// testeable.
String buildPortraitPrompt({
  required Character character,
  required ContentRepository repo,
  required String style,
  required String extraText,
  bool includeWeapon = true,
}) {
  final race = repo.race(character.raceId)?.name ?? '';
  final classIds = <String>[];
  for (final id in character.classHistory) {
    if (!classIds.contains(id)) classIds.add(id);
  }
  final klass = classIds
      .map(
        (id) =>
            '${repo.characterClass(id)?.name ?? id} ${character.classLevel(id)}',
      )
      .join(' · ');
  final armor = character.equippedArmorId == null
      ? null
      : repo.armorPiece(character.equippedArmorId!)?.name;
  final weapon = !includeWeapon || character.equippedWeaponIds.isEmpty
      ? null
      : repo.weapon(character.equippedWeaponIds.first)?.name;

  final parts = <String>[
    'Retrato de personaje de fantasía (D&D)',
    [race, klass].where((s) => s.isNotEmpty).join(' '),
  ];
  if (armor != null) parts.add('viste $armor');
  if (weapon != null) parts.add('porta $weapon');

  return _assemble(parts, extraText, style);
}

String _assemble(List<String> parts, String extraText, String style) {
  final extra = extraText.trim();
  final base = [
    ...parts,
    if (extra.isNotEmpty) extra,
  ].where((s) => s.isNotEmpty).join(', ');
  final styleClause = style.trim().isEmpty ? '' : ' Estilo: ${style.trim()}.';
  return '$base. Encuadre tipo busto/retrato, fondo simple.$styleClause';
}

/// El prompt de retrato de un PNJ, que se completa solo según su tipo de
/// ficha: igual que un personaje si tiene ficha ([sheet]), con la criatura de
/// la que partió si tiene bloque, y sin nada automático si no tiene
/// estadísticas — el tabernero no tiene datos visuales de los que partir, así
/// que todo va en [extraText] (la «apariencia»).
///
/// **Nunca lee el trasfondo, las notas ni «cómo habla».** El proveedor es un
/// servicio externo y esos textos son justamente donde el DM guarda los
/// secretos de la campaña. No es una opción: la función no los toca.
String buildNpcPortraitPrompt({
  required Npc npc,
  required ContentRepository repo,
  required String style,
  required String extraText,
  Character? sheet,
  bool includeWeapon = true,
}) {
  if (npc.sheetKind == NpcSheetKind.character && sheet != null) {
    return buildPortraitPrompt(
      character: sheet,
      repo: repo,
      style: style,
      extraText: extraText,
      includeWeapon: includeWeapon,
    );
  }
  final block = npc.block;
  final parts = <String>[
    'Retrato de personaje de fantasía (D&D)',
    if (npc.sheetKind == NpcSheetKind.block && block != null) ...[
      npc.baseCreatureName ?? block.name,
      // «Humanoide Mediano o Pequeño, neutral» → sin el alineamiento, que no
      // se dibuja.
      block.kind.split(',').first.trim(),
    ],
  ];
  return _assemble(parts, extraText, style);
}
