import 'package:flutter/material.dart';

/// The palette behind the "Neutral canvas, one quiet accent" redesign.
///
/// A near-white (near-black in dark mode) neutral canvas carries the app —
/// no warm tint, no colour except where it means something. Depth comes
/// from a hairline border alone; cards are flat by default. A single vivid
/// [accent] (a deep coral by default) is used sparingly — the progress
/// ring, the primary action, key numbers — not on every icon or badge, and
/// is user-overridable via the accent picker / Material You. The macro trio
/// (carbs mango, fat berry-pink, protein sky-blue) stays fixed as genuine
/// data colour, distinct from decoration.
class AppPalette {
  final Brightness brightness;
  final Color canvas; // scaffold background
  final Color surface; // cards / sheets
  final Color surfaceMuted; // secondary fills, track backgrounds
  final Color border; // hairline outline
  final Color shadow; // soft shadow colour
  final Color accent; // the one vivid colour (overridable)
  final Color onAccent;
  final Color carbsColor;
  final Color fatColor;
  final Color proteinColor;
  final Color textStrong;
  final Color textMuted;

  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.shadow,
    required this.accent,
    required this.onAccent,
    required this.carbsColor,
    required this.fatColor,
    required this.proteinColor,
    required this.textStrong,
    required this.textMuted,
  });

  Color get carbs => carbsColor;
  Color get fat => fatColor;
  Color get protein => proteinColor;

  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFFAFAF8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0EFEC),
    border: Color(0xFFE5E3DE),
    // Barely-there — flat cards lean on the hairline border for definition,
    // not a shadow. Kept non-zero only so a card lifted for emphasis (a
    // dialog, a bottom sheet) still separates from what's behind it.
    shadow: Color(0x0A1A1A1A),
    // Deep coral, computed to clear WCAG AA (~5.0:1) for white-on-accent —
    // the ring, the primary button, the mark's bolt. Used sparingly
    // elsewhere by design, not painted on every icon.
    accent: Color(0xFFC7401F),
    onAccent: Color(0xFFFFFFFF),
    carbsColor: Color(0xFFD98A15),
    fatColor: Color(0xFFD14E85),
    proteinColor: Color(0xFF3B72D6),
    textStrong: Color(0xFF1A1A18),
    // ~5.4:1 against the white surface — comfortably clears AA.
    textMuted: Color(0xFF6B6B66),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF121110),
    surface: Color(0xFF1A1918),
    surfaceMuted: Color(0xFF242322),
    border: Color(0xFF333130),
    shadow: Color(0x40000000),
    accent: Color(0xFFFF8A65),
    onAccent: Color(0xFF3A1408),
    carbsColor: Color(0xFFFFC966),
    fatColor: Color(0xFFFF9EC4),
    proteinColor: Color(0xFF8AB4FF),
    textStrong: Color(0xFFF2F1EF),
    textMuted: Color(0xFFA8A6A2),
  );

  /// Returns a copy with the accent swapped for [newAccent] (accent picker or a
  /// harmonized Material You primary). The neutral canvas, surfaces and macro
  /// colours are untouched, so only the one vivid role follows the user.
  AppPalette withAccent(Color newAccent) {
    final onNew =
        ThemeData.estimateBrightnessForColor(newAccent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF20201C);
    return AppPalette(
      brightness: brightness,
      canvas: canvas,
      surface: surface,
      surfaceMuted: surfaceMuted,
      border: border,
      shadow: shadow,
      accent: newAccent,
      onAccent: onNew,
      carbsColor: carbsColor,
      fatColor: fatColor,
      proteinColor: proteinColor,
      textStrong: textStrong,
      textMuted: textMuted,
    );
  }

  ColorScheme get colorScheme => ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: accent,
    onPrimaryContainer: onAccent,
    secondary: proteinColor,
    onSecondary: onAccent,
    secondaryContainer: surfaceMuted,
    onSecondaryContainer: textStrong,
    tertiary: carbsColor,
    onTertiary: onAccent,
    tertiaryContainer: surfaceMuted,
    onTertiaryContainer: textStrong,
    error: brightness == Brightness.light
        ? const Color(0xFFC4453A)
        : const Color(0xFFFFB4AB),
    onError: brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF690005),
    surface: surface,
    onSurface: textStrong,
    surfaceContainerLowest: canvas,
    surfaceContainerLow: canvas,
    surfaceContainer: surfaceMuted,
    surfaceContainerHigh: surfaceMuted,
    surfaceContainerHighest: surfaceMuted,
    onSurfaceVariant: textMuted,
    outline: border,
    outlineVariant: border,
    surfaceTint: Colors.transparent,
    shadow: shadow,
  );
}
