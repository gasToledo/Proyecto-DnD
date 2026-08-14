import 'package:flutter/material.dart';

/// Tokens de color de la dirección visual híbrida (base oscura moderna + oro
/// heráldico y carmesí). Se exponen como [ThemeExtension] para adaptarse a
/// claro/oscuro; el **oscuro es el tema prioritario y por defecto**.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color gold; // acento heráldico: números clave, reglas, activos
  final Color crimson; // PG / daño
  final Color verdant; // verde heráldico: la acción principal del turno
  final Color plaque; // fondo de placas/plaquetas (más hundido que surface)
  final Color hairline; // bordes finos
  final Color goldSoft; // fondo suave para pills doradas
  final Color textMuted; // rótulos, hints

  const AppPalette({
    required this.gold,
    required this.crimson,
    required this.verdant,
    required this.plaque,
    required this.hairline,
    required this.goldSoft,
    required this.textMuted,
  });

  /// Los colores que llevan texto están elegidos para llegar a 4.5:1 (WCAG AA)
  /// contra los **dos** fondos sobre los que se dibujan: `surface` y `plaque`,
  /// que es el más exigente porque es el más cercano al color del texto. El
  /// carmesí además lleva los PG de la tarjeta, que son texto chico: por eso es
  /// más claro que el rojo de marca original (`0xFFC24A3E`, 3.6:1) y el par
  /// `onError`/`onSecondary` pasa a ser oscuro en el tema oscuro.
  static const dark = AppPalette(
    gold: Color(0xFFC9A24B), // 7.3:1 sobre surface
    crimson: Color(0xFFD4665A), // 4.9:1 sobre surface, 5.3:1 sobre plaque
    verdant: Color(0xFF6FA85C), // 6.2:1 sobre surface
    plaque: Color(0xFF12100C),
    hairline: Color(0xFF3A2F25),
    goldSoft: Color(0xFF2E2617),
    textMuted: Color(0xFF9C8B6E), // 5.3:1 sobre surface, 5.8:1 sobre plaque
  );

  static const light = AppPalette(
    gold: Color(0xFF8A6A1E), // 4.7:1 sobre surface
    crimson: Color(0xFFA6392E), // 6.0:1 sobre surface
    verdant: Color(0xFF3E7A33), // 4.9:1 sobre surface
    plaque: Color(0xFFEBE0C9),
    hairline: Color(0xFFD9C9A8),
    goldSoft: Color(0xFFEEE1BF),
    textMuted: Color(0xFF6E6047), // 5.7:1 sobre surface, 4.7:1 sobre plaque
  );

  @override
  AppPalette copyWith({
    Color? gold,
    Color? crimson,
    Color? verdant,
    Color? plaque,
    Color? hairline,
    Color? goldSoft,
    Color? textMuted,
  }) => AppPalette(
    gold: gold ?? this.gold,
    crimson: crimson ?? this.crimson,
    verdant: verdant ?? this.verdant,
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
      verdant: Color.lerp(verdant, other.verdant, t)!,
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

  /// Duración de una animación, o cero si el sistema pide menos movimiento
  /// («Reducir movimiento» del sistema operativo, `prefers-reduced-motion` en
  /// el navegador).
  ///
  /// Cero y no "más corta": las animaciones de la aplicación marcan cambios de
  /// estado, y el cambio de estado se ve igual sin transición. Quien pide menos
  /// movimiento suele hacerlo por mareo o vértigo, y a esa persona una
  /// animación rápida no le sirve de menos que una lenta.
  Duration motion(Duration duration) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : duration;
}

/// Tema activo y su guardado.
///
/// Vive en la raíz de la aplicación y no en cada pantalla porque el control
/// aparece en dos paneles (dashboard y ficha) y las dos vistas tienen que
/// mostrar el mismo estado: una copia por pantalla se desincroniza al volver
/// atrás desde una ficha.
///
/// Arranca en oscuro —el tema prioritario— y adopta lo guardado en cuanto los
/// ajustes de la cuenta terminan de cargar ([attach]).
class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController() : super(ThemeMode.dark);

  Future<void> Function(ThemeMode)? _persist;

  /// Conecta el guardado y adopta la preferencia guardada. Antes de esto,
  /// elegir un tema lo cambia en pantalla pero no lo persiste: no hay todavía
  /// un documento de ajustes al que escribirle sin pisar el resto.
  void attach(ThemeMode saved, Future<void> Function(ThemeMode) persist) {
    _persist = persist;
    value = saved;
  }

  void choose(ThemeMode mode) {
    if (mode == value) return;
    value = mode;
    _persist?.call(mode);
  }

  /// [ThemeMode] por el nombre con que se guarda. Un valor desconocido (ajuste
  /// viejo, documento tocado a mano) cae a oscuro, que es el tema por defecto.
  static ThemeMode parse(String value) => ThemeMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => ThemeMode.dark,
  );
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
    // El carmesí del tema oscuro es claro (hace falta para que los PG lleguen a
    // AA sobre la tarjeta): encima de él el blanco ya no contrasta, así que lo
    // que va sobre carmesí es el mismo casi-negro que va sobre el oro.
    final onCrimson = brightness == Brightness.dark
        ? const Color(0xFF201A10)
        : Colors.white;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.gold,
      onPrimary: const Color(0xFF201A10),
      secondary: palette.crimson,
      onSecondary: onCrimson,
      // Sin estos dos, `secondaryContainer` cae en `secondary` —el carmesí— y
      // todo lo seleccionable de Material 3 (chips, sobre todo) se pinta del
      // único color que en esta aplicación significa peligro. Lo elegido va en
      // oro, como el resto de lo activo.
      secondaryContainer: palette.goldSoft,
      onSecondaryContainer: palette.gold,
      error: palette.crimson,
      onError: onCrimson,
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
        // El borde también marca la selección: sobre el fondo dorado suave, un
        // filete gris deja la píldora elegida casi igual que las demás.
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? palette.gold
                : palette.hairline,
          ),
        ),
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
