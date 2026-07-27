import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_widgets.dart';

/// Personalización visual del contenido: color de acento (clases) e íconos
/// (clases, especies y trasfondos). Los datos viven en los JSON del pack
/// (`accentColor` / `iconId`); acá se traducen a tipos de Flutter, así el
/// homebrew los aprovecha igual que el contenido oficial.
///
/// Los íconos se mapean desde un id de texto a un [IconData] **const** de
/// Material: nunca se construye un IconData desde un codepoint variable (eso
/// rompería el tree-shaking de íconos en `flutter build`).
const Map<String, IconData> _icons = {
  // Clases.
  'shield': Icons.shield,
  'rage': Icons.local_fire_department,
  'dagger': Icons.theater_comedy,
  'fist': Icons.sports_martial_arts,
  'spellbook': Icons.auto_stories,
  'holy': Icons.healing,
  'leaf': Icons.eco,
  'music': Icons.music_note,
  'sparkle': Icons.auto_awesome,
  'eye': Icons.remove_red_eye,
  'oath': Icons.verified_user,
  'bow': Icons.gps_fixed,
  // Especies.
  'person': Icons.person,
  'terrain': Icons.terrain,
  'child_care': Icons.child_care,
  'fitness_center': Icons.fitness_center,
  'park': Icons.park,
  'local_fire_department': Icons.local_fire_department,
  'science': Icons.science,
  'whatshot': Icons.whatshot,
  'landscape': Icons.landscape,
  'auto_awesome': Icons.auto_awesome,
  // Trasfondos.
  'military_tech': Icons.military_tech,
  'security': Icons.security,
  'explore': Icons.explore,
  'handyman': Icons.handyman,
  'theater_comedy': Icons.theater_comedy,
  'lock_open': Icons.lock_open,
  'music_note': Icons.music_note,
  'agriculture': Icons.agriculture,
  'self_improvement': Icons.self_improvement,
  'storefront': Icons.storefront,
  'diamond': Icons.diamond,
  'history_edu': Icons.history_edu,
  'church': Icons.church,
  'menu_book': Icons.menu_book,
  'hiking': Icons.hiking,
  'sailing': Icons.sailing,
};

/// Ícono declarado por un contenido, o [fallback] si no lo declara o el id no
/// está en el registro.
IconData iconFor(String? iconId, {IconData fallback = Icons.circle_outlined}) =>
    _icons[iconId] ?? fallback;

/// Ícono de la clase (o uno genérico si no declara/reconoce el id).
IconData classIcon(CharacterClass? klass) =>
    iconFor(klass?.iconId, fallback: Icons.person_outline);

/// Ícono de la especie.
IconData raceIcon(Race? race) => iconFor(race?.iconId, fallback: Icons.groups);

/// Ícono del trasfondo. El fallback es a propósito uno que no está en el
/// registro, para que "sin ícono" se distinga de cualquier ícono real.
IconData backgroundIcon(Background? bg) =>
    iconFor(bg?.iconId, fallback: Icons.badge_outlined);

/// Medallón de un personaje: el retrato si lo hay y, si no, el **emblema de su
/// clase** (su ícono sobre su color de acento). Sin clase conocida cae a la
/// inicial del nombre, como antes.
class ClassMedallion extends StatelessWidget {
  final CharacterClass? klass;
  final ImageProvider? image;
  final String fallback;
  final double size;
  const ClassMedallion({
    super.key,
    required this.klass,
    required this.fallback,
    this.image,
    this.size = 74,
  });

  @override
  Widget build(BuildContext context) {
    final gold = context.palette.gold;
    return Medallion(
      image: image,
      fallback: fallback,
      size: size,
      emblemIcon: klass == null ? null : classIcon(klass),
      emblemColor: klass == null ? null : classAccent(klass, gold),
    );
  }
}

/// Color de acento de la clase, parseado de su hex `#RRGGBB`. Devuelve
/// [fallback] si la clase no declara color o el hex es inválido.
Color classAccent(CharacterClass? klass, Color fallback) {
  final hex = klass?.accentColor;
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '').trim();
  final value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return value == null ? fallback : Color(value);
}
