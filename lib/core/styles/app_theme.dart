import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// Friendly, playful type pairing. Fredoka (rounded, bubbly) carries display
/// and headline roles — the big hero numbers and screen titles — where its
/// personality reads clearly at size. Nunito (warm, humanist) carries body
/// and label roles, where dense text needs to stay calm and legible rather
/// than bubbly. Both ship as a single regular-weight file (no bold cut), so
/// heavier weights below render via Flutter's synthetic bold rather than a
/// true cut — a fast-follow would bundle the full Google Fonts weight
/// families for crisper bold rendering, but the single-weight files already
/// read fine at these sizes.
TextTheme appTextTheme(AppPalette p) {
  const display = 'Fredoka';
  const body = 'Nunito';
  TextStyle s(
    String family,
    double size,
    FontWeight w, {
    double spacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: w,
    letterSpacing: spacing,
    color: color ?? p.textStrong,
  );
  return TextTheme(
    displayLarge: s(display, 57, FontWeight.w600, spacing: -1),
    displayMedium: s(display, 45, FontWeight.w600, spacing: -0.5),
    displaySmall: s(display, 36, FontWeight.w600),
    headlineLarge: s(display, 32, FontWeight.w600),
    headlineMedium: s(display, 28, FontWeight.w600),
    headlineSmall: s(display, 23, FontWeight.w600),
    titleLarge: s(display, 21, FontWeight.w600),
    titleMedium: s(body, 16, FontWeight.w700),
    titleSmall: s(body, 14, FontWeight.w700),
    bodyLarge: s(body, 16, FontWeight.w500),
    bodyMedium: s(body, 14, FontWeight.w500),
    bodySmall: s(body, 12.5, FontWeight.w500, color: p.textMuted),
    labelLarge: s(body, 15, FontWeight.w700),
    labelMedium: s(body, 13, FontWeight.w700),
    labelSmall: s(body, 11.5, FontWeight.w700, color: p.textMuted),
  );
}

/// Builds the friendly-flat [ThemeData] for a palette. Component themes carry
/// the rounded shapes and flat surfaces so the look propagates app-wide; depth
/// lives in the [AppCard] widget rather than in heavy elevation here.
ThemeData buildAppTheme(AppPalette p) {
  final scheme = p.colorScheme;
  final text = appTextTheme(p);
  const pill = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.canvas,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Dimens.borderRadiusL,
        side: BorderSide(color: p.border, width: Dimens.hairline),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.textStrong,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accent.withValues(alpha: 0.16),
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: pill,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size(64, Dimens.minTouchTarget),
        shape: pill,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: text.labelLarge,
        shape: pill,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: p.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing16,
        vertical: Dimens.spacing12,
      ),
      border: const OutlineInputBorder(
        borderRadius: Dimens.borderRadiusM,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: Dimens.borderRadiusM,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Dimens.borderRadiusM,
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      backgroundColor: p.surfaceMuted,
      side: BorderSide.none,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Dimens.borderRadiusL),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: Dimens.borderRadiusM),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimens.radiusXL),
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
