import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';

/// App-owned tokens for the SuperCalculator expressive layer.
///
/// Flutter stable provides Material 3 and expressive color scheme generation,
/// but it does not expose a single global Material 3 Expressive switch. These
/// tokens keep the application-level additions centralized and replaceable.
@immutable
class SuperCalcDesignTokens extends ThemeExtension<SuperCalcDesignTokens> {
  const SuperCalcDesignTokens({
    required this.compactBreakpoint,
    required this.mediumBreakpoint,
    required this.expandedBreakpoint,
    required this.pagePadding,
    required this.cardGap,
    required this.controlGap,
    required this.plotMinHeight,
    required this.cornerSmall,
    required this.cornerMedium,
    required this.cornerLarge,
    required this.controlMinHeight,
    required this.fastMotion,
    required this.standardMotion,
  });

  const SuperCalcDesignTokens.defaults()
    : compactBreakpoint = 600,
      mediumBreakpoint = 840,
      expandedBreakpoint = 1200,
      pagePadding = 24,
      cardGap = 16,
      controlGap = 12,
      plotMinHeight = 360,
      cornerSmall = 12,
      cornerMedium = 20,
      cornerLarge = 28,
      controlMinHeight = 48,
      fastMotion = const Duration(milliseconds: 120),
      standardMotion = const Duration(milliseconds: 260);

  /// Foundational intensity: clarity and familiarity first, with restrained
  /// corners and slightly quicker motion.
  const SuperCalcDesignTokens.foundational()
    : compactBreakpoint = 600,
      mediumBreakpoint = 840,
      expandedBreakpoint = 1200,
      pagePadding = 24,
      cardGap = 16,
      controlGap = 12,
      plotMinHeight = 360,
      cornerSmall = 8,
      cornerMedium = 14,
      cornerLarge = 20,
      controlMinHeight = 48,
      fastMotion = const Duration(milliseconds: 110),
      standardMotion = const Duration(milliseconds: 220);

  /// Excellent intensity: the expressive baseline, strengthening color, type
  /// and shape while preserving established patterns.
  const SuperCalcDesignTokens.excellent()
    : compactBreakpoint = 600,
      mediumBreakpoint = 840,
      expandedBreakpoint = 1200,
      pagePadding = 24,
      cardGap = 16,
      controlGap = 12,
      plotMinHeight = 360,
      cornerSmall = 12,
      cornerMedium = 20,
      cornerLarge = 28,
      controlMinHeight = 48,
      fastMotion = const Duration(milliseconds: 120),
      standardMotion = const Duration(milliseconds: 260);

  /// Transformative intensity: bolder shapes and motion for hero moments while
  /// keeping the same usability and accessibility contract.
  const SuperCalcDesignTokens.transformative()
    : compactBreakpoint = 600,
      mediumBreakpoint = 840,
      expandedBreakpoint = 1200,
      pagePadding = 24,
      cardGap = 16,
      controlGap = 12,
      plotMinHeight = 360,
      cornerSmall = 16,
      cornerMedium = 26,
      cornerLarge = 36,
      controlMinHeight = 48,
      fastMotion = const Duration(milliseconds: 140),
      standardMotion = const Duration(milliseconds: 300);

  /// Resolves the token set for an [ExpressiveIntensity] level.
  static SuperCalcDesignTokens forIntensity(ExpressiveIntensity intensity) {
    return switch (intensity) {
      ExpressiveIntensity.foundational =>
        const SuperCalcDesignTokens.foundational(),
      ExpressiveIntensity.excellent => const SuperCalcDesignTokens.excellent(),
      ExpressiveIntensity.transformative =>
        const SuperCalcDesignTokens.transformative(),
    };
  }

  final double compactBreakpoint;
  final double mediumBreakpoint;
  final double expandedBreakpoint;
  final double pagePadding;
  final double cardGap;
  final double controlGap;
  final double plotMinHeight;
  final double cornerSmall;
  final double cornerMedium;
  final double cornerLarge;
  final double controlMinHeight;
  final Duration fastMotion;
  final Duration standardMotion;

  static SuperCalcDesignTokens of(BuildContext context) =>
      Theme.of(context).extension<SuperCalcDesignTokens>() ??
      const SuperCalcDesignTokens.defaults();

  @override
  SuperCalcDesignTokens copyWith({
    double? compactBreakpoint,
    double? mediumBreakpoint,
    double? expandedBreakpoint,
    double? pagePadding,
    double? cardGap,
    double? controlGap,
    double? plotMinHeight,
    double? cornerSmall,
    double? cornerMedium,
    double? cornerLarge,
    double? controlMinHeight,
    Duration? fastMotion,
    Duration? standardMotion,
  }) {
    return SuperCalcDesignTokens(
      compactBreakpoint: compactBreakpoint ?? this.compactBreakpoint,
      mediumBreakpoint: mediumBreakpoint ?? this.mediumBreakpoint,
      expandedBreakpoint: expandedBreakpoint ?? this.expandedBreakpoint,
      pagePadding: pagePadding ?? this.pagePadding,
      cardGap: cardGap ?? this.cardGap,
      controlGap: controlGap ?? this.controlGap,
      plotMinHeight: plotMinHeight ?? this.plotMinHeight,
      cornerSmall: cornerSmall ?? this.cornerSmall,
      cornerMedium: cornerMedium ?? this.cornerMedium,
      cornerLarge: cornerLarge ?? this.cornerLarge,
      controlMinHeight: controlMinHeight ?? this.controlMinHeight,
      fastMotion: fastMotion ?? this.fastMotion,
      standardMotion: standardMotion ?? this.standardMotion,
    );
  }

  @override
  SuperCalcDesignTokens lerp(
    covariant ThemeExtension<SuperCalcDesignTokens>? other,
    double t,
  ) {
    if (other is! SuperCalcDesignTokens) {
      return this;
    }
    double d(double a, double b) => a + (b - a) * t;
    return SuperCalcDesignTokens(
      compactBreakpoint: d(compactBreakpoint, other.compactBreakpoint),
      mediumBreakpoint: d(mediumBreakpoint, other.mediumBreakpoint),
      expandedBreakpoint: d(expandedBreakpoint, other.expandedBreakpoint),
      pagePadding: d(pagePadding, other.pagePadding),
      cardGap: d(cardGap, other.cardGap),
      controlGap: d(controlGap, other.controlGap),
      plotMinHeight: d(plotMinHeight, other.plotMinHeight),
      cornerSmall: d(cornerSmall, other.cornerSmall),
      cornerMedium: d(cornerMedium, other.cornerMedium),
      cornerLarge: d(cornerLarge, other.cornerLarge),
      controlMinHeight: d(controlMinHeight, other.controlMinHeight),
      fastMotion: t < 0.5 ? fastMotion : other.fastMotion,
      standardMotion: t < 0.5 ? standardMotion : other.standardMotion,
    );
  }
}
