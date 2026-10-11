import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import 'design_tokens.dart';

/// Seed color used when Material You dynamic color (Monet) is unavailable or
/// disabled.
const Color superCalcSeedColor = Color(0xFF536DDE);

/// Builds the Material 3 Expressive theme for a given [brightness].
///
/// When [colorScheme] is supplied (for example from Material You dynamic
/// color), it is used verbatim. Otherwise the scheme is generated from
/// [superCalcSeedColor] using the variant that matches [intensity]. The
/// [intensity] also selects the shape and motion tokens.
ThemeData buildAppTheme(
  Brightness brightness, {
  ColorScheme? colorScheme,
  ExpressiveIntensity intensity = ExpressiveIntensity.excellent,
}) {
  final scheme =
      colorScheme ??
      ColorScheme.fromSeed(
        seedColor: superCalcSeedColor,
        brightness: brightness,
        dynamicSchemeVariant: _schemeVariant(intensity),
      );
  final tokens = SuperCalcDesignTokens.forIntensity(intensity);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[tokens],
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(tokens.cornerMedium)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(tokens.cornerMedium)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(tokens.cornerMedium)),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.controlGap,
        vertical: tokens.controlGap,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(tokens.cornerLarge)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, tokens.controlMinHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(tokens.cornerMedium)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, tokens.controlMinHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(tokens.cornerMedium)),
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
    ),
  );
}

DynamicSchemeVariant _schemeVariant(ExpressiveIntensity intensity) {
  return switch (intensity) {
    ExpressiveIntensity.foundational => DynamicSchemeVariant.tonalSpot,
    ExpressiveIntensity.excellent => DynamicSchemeVariant.expressive,
    ExpressiveIntensity.transformative => DynamicSchemeVariant.vibrant,
  };
}
