import 'package:flutter/material.dart';

/// Colours from Greek pottery and marble: parchment and black-figure ink,
/// terracotta, olive, Aegean blue and a little gold.
class Palette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color line;
  final Color terracotta;
  final Color olive;
  final Color aegean;
  final Color gold;

  const Palette._({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.terracotta,
    required this.olive,
    required this.aegean,
    required this.gold,
  });

  static const light = Palette._(
    brightness: Brightness.light,
    background: Color(0xFFF3EEE4),
    surface: Color(0xFFFBF8F2),
    raised: Color(0xFFFFFFFF),
    ink: Color(0xFF26252C),
    muted: Color(0xFF77736B),
    line: Color(0xFFDCD4C5),
    terracotta: Color(0xFFB0502F),
    olive: Color(0xFF66784A),
    aegean: Color(0xFF2E5B7A),
    gold: Color(0xFFB8913A),
  );

  static const dark = Palette._(
    brightness: Brightness.dark,
    background: Color(0xFF121318),
    surface: Color(0xFF1B1D24),
    raised: Color(0xFF242731),
    ink: Color(0xFFEDE6D6),
    muted: Color(0xFF9C978C),
    line: Color(0xFF33363F),
    terracotta: Color(0xFFD9774F),
    olive: Color(0xFF9DB07A),
    aegean: Color(0xFF7FA9C6),
    gold: Color(0xFFD9BA6A),
  );

  static Palette of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Display type is Cinzel (inscriptional capitals); body text is Jost.
class Type {
  static const display = 'Cinzel';
  static const body = 'Jost';

  static TextStyle title(Color c, {double size = 28, FontWeight weight = FontWeight.w600}) => TextStyle(
    fontFamily: display,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: size * 0.16,
    color: c,
    height: 1.1,
  );

  static TextStyle label(Color c, {double size = 12, FontWeight weight = FontWeight.w600}) => TextStyle(
    fontFamily: display,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: size * 0.22,
    color: c,
  );

  static TextStyle text(Color c, {double size = 15, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: weight, color: c, height: 1.35);

  static TextStyle number(Color c, {double size = 28, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: body,
    fontSize: size,
    fontWeight: weight,
    color: c,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme(Palette p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.terracotta,
    brightness: p.brightness,
  ).copyWith(primary: p.terracotta, surface: p.surface, onSurface: p.ink, secondary: p.olive);
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    fontFamily: Type.body,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: p.line,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: Type.label(p.ink, size: 15),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.surface : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.terracotta : p.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: Type.label(p.ink, size: 16),
      contentTextStyle: Type.text(p.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: Type.text(p.background),
      behavior: SnackBarBehavior.floating,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.terracotta,
        textStyle: Type.label(p.terracotta, size: 13),
      ),
    ),
  );
}
