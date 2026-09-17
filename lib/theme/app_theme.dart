import 'package:flutter/material.dart';

/// News Insight's own visual identity — matched to the app icon's
/// green (assets/icon/generate_icon.py's BLUE, also the web splash and
/// theme_color), so the in-app chrome doesn't clash with the icon and
/// loading screen the user actually sees first.
///
/// 2026-09-17: green, having been blue. The icon was drawn from
/// 雅伟之言's palette so the two would look related and they came out
/// looking identical; see the note at the top of `generate_icon.py`.
/// This constant is downstream of that file — change one, change both,
/// or the chrome fights the splash screen. Material 3's tonal
/// system derives the full light/dark neutral palette (including the
/// charcoal-toned dark-mode surfaces) from this one seed.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF2E8C5A); // icon green

  // Bundled CJK fallback (assets/fonts/) — see the pubspec.yaml `fonts:`
  // comment for why this is bundled rather than left to the browser's
  // system font fallback.
  static const List<String> _fontFallback = ['NotoSansSC'];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          fontFamilyFallback: _fontFallback,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12.5,
          fontFamilyFallback: _fontFallback,
        ),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      // No `platform:` override here — this app is bilingual (EN/中文)
      // and Typography's iOS/"englishLike" geometry (tight letter-
      // spacing tuned for Latin scripts) mis-measured some CJK glyph
      // combinations tightly enough to clip chip labels (e.g. "世界"
      // rendered as just "世"). The platform-default geometry picks
      // the CJK-safe "dense" set on Android/other non-Apple targets.
      textTheme: Typography.material2021().black.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
            fontFamilyFallback: _fontFallback,
          ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontFamilyFallback: _fontFallback,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
