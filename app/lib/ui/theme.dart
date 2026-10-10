import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Manabi visual language: deep emerald, warm paper and soft gold, with
/// generous radii and very soft elevation.
class Palette {
  static const emerald = Color(0xFF0F5C52);
  static const emeraldDeep = Color(0xFF0E3B36);
  static const gold = Color(0xFFC9A45C);
  static const paper = Color(0xFFF6F3EC);
  static const ink = Color(0xFF1B2724);
  static const night = Color(0xFF0B1513);
  static const nightSurface = Color(0xFF12201D);
}

const uiFont = 'Vazirmatn';
const arabicFont = 'NotoNaskhArabic';

class ManabiColors extends ThemeExtension<ManabiColors> {
  const ManabiColors({required this.gold, required this.quoteBg, required this.userBubble, required this.onUserBubble, required this.glow, required this.success, required this.warning});
  final Color gold;
  final Color quoteBg;
  final Color userBubble;
  final Color onUserBubble;
  final Color glow;
  final Color success;
  final Color warning;

  @override
  ManabiColors copyWith({Color? gold, Color? quoteBg, Color? userBubble, Color? onUserBubble, Color? glow, Color? success, Color? warning}) =>
      ManabiColors(
        gold: gold ?? this.gold,
        quoteBg: quoteBg ?? this.quoteBg,
        userBubble: userBubble ?? this.userBubble,
        onUserBubble: onUserBubble ?? this.onUserBubble,
        glow: glow ?? this.glow,
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  @override
  ManabiColors lerp(ManabiColors? other, double t) {
    if (other == null) return this;
    return ManabiColors(
      gold: Color.lerp(gold, other.gold, t)!,
      quoteBg: Color.lerp(quoteBg, other.quoteBg, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      onUserBubble: Color.lerp(onUserBubble, other.onUserBubble, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ManabiColors get mc => Theme.of(this).extension<ManabiColors>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.emerald,
    brightness: brightness,
    surface: dark ? Palette.night : Palette.paper,
  ).copyWith(
    primary: dark ? const Color(0xFF7FD3BF) : Palette.emerald,
    onPrimary: dark ? const Color(0xFF00382F) : Colors.white,
    secondary: Palette.gold,
    surfaceContainerLowest: dark ? const Color(0xFF0E1916) : Colors.white,
    surfaceContainerLow: dark ? Palette.nightSurface : const Color(0xFFFBF9F4),
    surfaceContainer: dark ? const Color(0xFF172723) : const Color(0xFFF1EDE3),
    surfaceContainerHigh: dark ? const Color(0xFF1D2F2B) : const Color(0xFFEAE5D9),
    outlineVariant: dark ? const Color(0xFF2A3D38) : const Color(0xFFE2DCCD),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: uiFont, brightness: brightness);
  final radius = BorderRadius.circular(20);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.apply(bodyColor: dark ? const Color(0xFFE3ECE9) : Palette.ink, displayColor: dark ? Colors.white : Palette.ink).copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.75, fontSize: 16),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.7),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 18, fontWeight: FontWeight.w700, color: dark ? Colors.white : Palette.ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.4)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLowest,
      labelStyle: TextStyle(fontFamily: uiFont, fontSize: 13, color: scheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: BorderSide(color: scheme.outlineVariant), textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w500)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: const StadiumBorder(), textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w500))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: uiFont, fontSize: 12, color: scheme.onSurface)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.7), thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerLow, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
    extensions: [
      ManabiColors(
        gold: dark ? const Color(0xFFD9B979) : const Color(0xFFB08A3E),
        quoteBg: dark ? const Color(0xFF1A2A26) : const Color(0xFFFAF5E8),
        userBubble: dark ? const Color(0xFF1F4A42) : Palette.emerald,
        onUserBubble: Colors.white,
        glow: (dark ? const Color(0xFF7FD3BF) : Palette.emerald).withValues(alpha: 0.10),
        success: dark ? const Color(0xFF7FD3A0) : const Color(0xFF1E7D4F),
        warning: dark ? const Color(0xFFE7B76A) : const Color(0xFFA2650F),
      ),
    ],
  );
}

/// Text style for classical Arabic source text.
TextStyle arabicStyle(BuildContext context, {double size = 19, double scale = 1, FontWeight weight = FontWeight.w400}) => TextStyle(
      fontFamily: arabicFont,
      fontSize: size * scale,
      height: 2.0,
      fontWeight: weight,
      color: context.cs.onSurface,
    );

bool isRtlLanguage(String? code) => code == 'ar' || code == 'fa' || code == 'ps';
