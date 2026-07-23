import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

/// Personalización visual por clase: color de acento + ícono. Los datos viven en
/// `classes.json` (`accentColor` / `iconId`); acá se traducen a tipos de Flutter.
///
/// Los íconos se mapean desde un id de texto a un [IconData] **const** de
/// Material: nunca se construye un IconData desde un codepoint variable (eso
/// rompería el tree-shaking de íconos en `flutter build`).
const Map<String, IconData> _classIcons = {
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
};

/// Ícono de la clase (o uno genérico si no declara/reconoce el id).
IconData classIcon(CharacterClass? klass) =>
    _classIcons[klass?.iconId] ?? Icons.person_outline;

/// Color de acento de la clase, parseado de su hex `#RRGGBB`. Devuelve
/// [fallback] si la clase no declara color o el hex es inválido.
Color classAccent(CharacterClass? klass, Color fallback) {
  final hex = klass?.accentColor;
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '').trim();
  final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16);
  return value == null ? fallback : Color(value);
}
