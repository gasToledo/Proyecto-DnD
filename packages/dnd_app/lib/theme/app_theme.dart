import 'package:flutter/material.dart';

/// Tokens de color de la dirección visual híbrida (base oscura moderna + oro
/// heráldico y carmesí). Se exponen como [ThemeExtension] para adaptarse a
/// claro/oscuro; el **oscuro es el tema prioritario y por defecto**.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color gold; // acento heráldico: números clave, reglas, activos
  final Color crimson; // PG / daño
  final Color plaque; // fondo de placas/plaquetas (más hundido que surface)
  final Color hairline; // bordes finos
  final Color goldSoft; // fondo suave para pills doradas
  final Color textMuted; // rótulos, hints

  const AppPalette({
    required this.gold,
    required this.crimson,
    required this.plaque,
    required this.hairline,
    required this.goldSoft,
    required this.textMuted,
  });

  static const dark = AppPalette(
    gold: Color(0xFFC9A24B),
    crimson: Color(0xFFC24A3E),
    plaque: Color(0xFF12100C),
    hairline: Color(0xFF3A2F25),
    goldSoft: Color(0xFF2E2617),
    textMuted: Color(0xFF7F7059),
  );

  static const light = AppPalette(
    gold: Color(0xFF8A6A1E),
    crimson: Color(0xFFA6392E),
    plaque: Color(0xFFEBE0C9),
    hairline: Color(0xFFD9C9A8),
    goldSoft: Color(0xFFEEE1BF),
    textMuted: Color(0xFF9E8E70),
  );

  @override
  AppPalette copyWith({
    Color? gold,
    Color? crimson,
    Color? plaque,
    Color? hairline,
    Color? goldSoft,
    Color? textMuted,
  }) => AppPalette(
    gold: gold ?? this.gold,
    crimson: crimson ?? this.crimson,
    plaque: plaque ?? this.plaque,
    hairline: hairline ?? this.hairline,
    goldSoft: goldSoft ?? this.goldSoft,
    textMuted: textMuted ?? this.textMuted,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      gold: Color.lerp(gold, other.gold, t)!,
      crimson: Color.lerp(crimson, other.crimson, t)!,
      plaque: Color.lerp(plaque, other.plaque, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Acceso corto a la paleta desde cualquier widget.
extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Fuente serif para títulos (el nombre del personaje, rótulos display).
/// Georgia está presente en Windows; en otras plataformas cae al serif genérico.
const _displayFont = 'Georgia';

class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scaffold: const Color(0xFF151210),
    surface: const Color(0xFF1E1915),
    onSurface: const Color(0xFFEFE7DA),
    onSurfaceVariant: const Color(0xFFA2937E),
    palette: AppPalette.dark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scaffold: const Color(0xFFF3ECDD),
    surface: const Color(0xFFFBF7EC),
    onSurface: const Color(0xFF2A2118),
    onSurfaceVariant: const Color(0xFF6E5F49),
    palette: AppPalette.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required AppPalette palette,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.gold,
      onPrimary: const Color(0xFF201A10),
      secondary: palette.crimson,
      onSecondary: Colors.white,
      error: palette.crimson,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: palette.hairline,
      surfaceContainerHighest: palette.plaque,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [palette],
      textTheme: base.textTheme
          .copyWith(
            displaySmall: base.textTheme.displaySmall?.copyWith(
              fontFamily: _displayFont,
              color: onSurface,
            ),
            headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontFamily: _displayFont,
              color: onSurface,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: _displayFont,
              color: onSurface,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(color: onSurface),
          )
          .apply(bodyColor: onSurface, displayColor: onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          fontSize: 20,
          color: onSurface,
        ),
        shape: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: palette.hairline, thickness: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.gold,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: palette.gold,
        dividerColor: palette.hairline,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.plaque,
        side: BorderSide(color: palette.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.hairline),
        ),
      ),
    );
  }
}
