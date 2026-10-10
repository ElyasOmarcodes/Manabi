import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// "Aura" design language: clean surfaces, a violet → blue → cyan signature
/// gradient, warm pink/orange highlights and very soft depth.
const uiFont = 'Vazirmatn';
const arabicFont = 'NotoNaskhArabic';

class AuraHues {
  static const violet = Color(0xFF7357FF);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF14C3E0);
  static const pink = Color(0xFFF2569B);
  static const orange = Color(0xFFFF9655);
  static const mint = Color(0xFF19C394);
  static const amber = Color(0xFFF5B43C);
  static const rose = Color(0xFFFF6B6B);

  /// Palette for icon tiles and covers – cycled by index.
  static const all = [violet, blue, cyan, mint, amber, orange, pink, rose];
  static Color at(int i) => all[i.abs() % all.length];
}

class Aura extends ThemeExtension<Aura> {
  const Aura({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.glass,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color glass;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;

  LinearGradient get brand => const LinearGradient(colors: [AuraHues.violet, AuraHues.blue, AuraHues.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight);
  LinearGradient get warm => const LinearGradient(colors: [AuraHues.pink, AuraHues.orange], begin: Alignment.topLeft, end: Alignment.bottomRight);
  LinearGradient get soft => LinearGradient(
        colors: dark
            ? [AuraHues.violet.withValues(alpha: 0.16), AuraHues.cyan.withValues(alpha: 0.08)]
            : [AuraHues.violet.withValues(alpha: 0.08), AuraHues.cyan.withValues(alpha: 0.06)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const light = Aura(
    dark: false,
    bg: Color(0xFFF6F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F2FA),
    glass: Color(0xCCFFFFFF),
    border: Color(0xFFE5E8F3),
    text: Color(0xFF111327),
    muted: Color(0xFF666B8A),
    faint: Color(0xFFA3A8C3),
    accent: Color(0xFF6650F5),
    success: Color(0xFF12A673),
    warning: Color(0xFFE08A00),
    danger: Color(0xFFE5484D),
    shadow: Color(0x1A3B3F8F),
  );

  static const night = Aura(
    dark: true,
    bg: Color(0xFF070811),
    surface: Color(0xFF10121D),
    surfaceAlt: Color(0xFF171A29),
    glass: Color(0xB3131626),
    border: Color(0xFF242842),
    text: Color(0xFFF1F2FA),
    muted: Color(0xFF9095B4),
    faint: Color(0xFF5A5F80),
    accent: Color(0xFF9B8CFF),
    success: Color(0xFF3DD9A0),
    warning: Color(0xFFFFC266),
    danger: Color(0xFFFF6B70),
    shadow: Color(0x66000000),
  );

  @override
  Aura copyWith() => this;

  @override
  Aura lerp(Aura? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Aura(
      dark: t < 0.5 ? dark : other.dark,
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      glass: l(glass, other.glass),
      border: l(border, other.border),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension ThemeX on BuildContext {
  Aura get aura => Theme.of(this).extension<Aura>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final a = brightness == Brightness.dark ? Aura.night : Aura.light;
  final scheme = ColorScheme.fromSeed(seedColor: AuraHues.violet, brightness: brightness).copyWith(
    primary: a.accent,
    onPrimary: Colors.white,
    secondary: AuraHues.cyan,
    tertiary: AuraHues.pink,
    surface: a.bg,
    onSurface: a.text,
    onSurfaceVariant: a.muted,
    surfaceContainerLowest: a.surface,
    surfaceContainerLow: a.surface,
    surfaceContainer: a.surfaceAlt,
    surfaceContainerHigh: a.surfaceAlt,
    surfaceContainerHighest: a.surfaceAlt,
    outline: a.faint,
    outlineVariant: a.border,
    error: a.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: uiFont, brightness: brightness, splashFactory: InkSparkle.splashFactory);
  final r16 = BorderRadius.circular(16);
  return base.copyWith(
    scaffoldBackgroundColor: a.bg,
    textTheme: base.textTheme.apply(bodyColor: a.text, displayColor: a.text).copyWith(
          bodyLarge: TextStyle(fontFamily: uiFont, fontSize: 16, height: 1.8, color: a.text),
          bodyMedium: TextStyle(fontFamily: uiFont, fontSize: 14.5, height: 1.7, color: a.text),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: a.text,
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 18, fontWeight: FontWeight.w700, color: a.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: a.surfaceAlt,
      hintStyle: TextStyle(color: a.faint, fontFamily: uiFont),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide(color: a.accent.withValues(alpha: 0.6), width: 1.4)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: a.accent,
      inactiveTrackColor: a.border,
      thumbColor: Colors.white,
      overlayColor: a.accent.withValues(alpha: 0.12),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: a.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      showDragHandle: true,
      dragHandleColor: a.faint,
    ),
    dialogTheme: DialogThemeData(backgroundColor: a.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    popupMenuTheme: PopupMenuThemeData(
      color: a.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: a.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: a.border)),
      textStyle: TextStyle(fontFamily: uiFont, color: a.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: a.dark ? a.surfaceAlt : a.text,
      contentTextStyle: TextStyle(fontFamily: uiFont, color: a.dark ? a.text : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: a.dark ? a.surfaceAlt : a.text, borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(fontFamily: uiFont, color: a.dark ? a.text : Colors.white, fontSize: 12),
    ),
    dividerTheme: DividerThemeData(color: a.border, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: a.accent),
    textSelectionTheme: TextSelectionThemeData(cursorColor: a.accent, selectionColor: a.accent.withValues(alpha: 0.25), selectionHandleColor: a.accent),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: r16), iconColor: a.muted),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
    extensions: [a],
  );
}

/// Classical Arabic source text.
TextStyle arabicStyle(BuildContext context, {double size = 19, double scale = 1, FontWeight weight = FontWeight.w400, Color? color}) => TextStyle(
      fontFamily: arabicFont,
      fontSize: size * scale,
      height: 2.0,
      fontWeight: weight,
      color: color ?? context.aura.text,
    );

bool isRtlLanguage(String? code) => code == 'ar' || code == 'fa' || code == 'ps';
