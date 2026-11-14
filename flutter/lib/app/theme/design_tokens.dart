import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_settings.dart';
import 'squircle_border.dart';

/// App-owned tokens for the Material 3 Expressive layer.
///
/// The official `material_ui` package provides the expressive component
/// variants (buttons, icon buttons, shape morphing), while these tokens keep
/// the application-level geometry, spacing and motion in one place. Motion is
/// expressed as spring simulations rather than fixed curves so presses,
/// selections and page changes feel physical on every platform.
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
    required this.cornerExtraLarge,
    required this.controlMinHeight,
    required this.keyMinHeight,
    required this.fastMotion,
    required this.standardMotion,
    required this.slowMotion,
    required this.cornerStyle,
    required this.motionScale,
    required this.fastSpring,
    required this.settleSpring,
    required this.emphasizedSpring,
  });

  const SuperCalcDesignTokens.defaults()
    : compactBreakpoint = 600,
      mediumBreakpoint = 840,
      expandedBreakpoint = 1200,
      pagePadding = 20,
      cardGap = 14,
      controlGap = 12,
      plotMinHeight = 360,
      cornerSmall = 14,
      cornerMedium = 22,
      cornerLarge = 30,
      cornerExtraLarge = 38,
      controlMinHeight = 52,
      keyMinHeight = 54,
      fastMotion = const Duration(milliseconds: 150),
      standardMotion = const Duration(milliseconds: 280),
      slowMotion = const Duration(milliseconds: 460),
      cornerStyle = CornerStyle.squircle,
      motionScale = 1,
      fastSpring = kFastSpring,
      settleSpring = kSettleSpring,
      emphasizedSpring = kEmphasizedSpring;

  /// Foundational intensity: clarity and familiarity first, with restrained
  /// corners and slightly quicker motion.
  const SuperCalcDesignTokens.foundational({
    this.cornerStyle = CornerStyle.squircle,
    this.motionScale = 1,
    double controlMinHeight = 52,
  }) : compactBreakpoint = 600,
       mediumBreakpoint = 840,
       expandedBreakpoint = 1200,
       pagePadding = 20,
       cardGap = 14,
       controlGap = 12,
       plotMinHeight = 340,
       cornerSmall = 10,
       cornerMedium = 16,
       cornerLarge = 22,
       cornerExtraLarge = 28,
       controlMinHeight = controlMinHeight,
       keyMinHeight = controlMinHeight,
       fastMotion = const Duration(milliseconds: 130),
       standardMotion = const Duration(milliseconds: 220),
       slowMotion = const Duration(milliseconds: 360),
       fastSpring = kFastSpring,
       settleSpring = kSettleSpring,
       emphasizedSpring = kEmphasizedSpring;

  /// Excellent intensity: the expressive baseline, strengthening color, type
  /// and shape while preserving established patterns.
  const SuperCalcDesignTokens.excellent({
    this.cornerStyle = CornerStyle.squircle,
    this.motionScale = 1,
    double controlMinHeight = 54,
  }) : compactBreakpoint = 600,
       mediumBreakpoint = 840,
       expandedBreakpoint = 1200,
       pagePadding = 20,
       cardGap = 14,
       controlGap = 12,
       plotMinHeight = 360,
       cornerSmall = 14,
       cornerMedium = 22,
       cornerLarge = 30,
       cornerExtraLarge = 38,
       controlMinHeight = controlMinHeight,
       keyMinHeight = controlMinHeight + 2,
       fastMotion = const Duration(milliseconds: 150),
       standardMotion = const Duration(milliseconds: 280),
       slowMotion = const Duration(milliseconds: 460),
       fastSpring = kFastSpring,
       settleSpring = kSettleSpring,
       emphasizedSpring = kEmphasizedSpring;

  /// Transformative intensity: bolder shapes and motion for hero moments while
  /// keeping the same usability and accessibility contract.
  const SuperCalcDesignTokens.transformative({
    this.cornerStyle = CornerStyle.squircle,
    this.motionScale = 1,
    double controlMinHeight = 56,
  }) : compactBreakpoint = 600,
       mediumBreakpoint = 840,
       expandedBreakpoint = 1200,
       pagePadding = 24,
       cardGap = 18,
       controlGap = 14,
       plotMinHeight = 380,
       cornerSmall = 18,
       cornerMedium = 28,
       cornerLarge = 38,
       cornerExtraLarge = 48,
       controlMinHeight = controlMinHeight,
       keyMinHeight = controlMinHeight + 4,
       fastMotion = const Duration(milliseconds: 170),
       standardMotion = const Duration(milliseconds: 320),
       slowMotion = const Duration(milliseconds: 540),
       fastSpring = kFastSpring,
       settleSpring = kSettleSpring,
       emphasizedSpring = kEmphasizedSpring;

  /// Standard, comfortably damped spring used for selection and expansion.
  static const SpringDescription kSettleSpring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 33.53,
  );

  /// Snappier spring used for presses and small state changes.
  static const SpringDescription kFastSpring = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 42,
  );

  /// Softer, slightly bouncy spring reserved for hero transitions.
  static const SpringDescription kEmphasizedSpring = SpringDescription(
    mass: 1,
    stiffness: 210,
    damping: 17.97,
  );

  /// Resolves the token set for an [ExpressiveIntensity] level.
  static SuperCalcDesignTokens forIntensity(
    ExpressiveIntensity intensity, {
    CornerStyle cornerStyle = CornerStyle.squircle,
    double motionScale = 1,
    bool largeTouchTargets = false,
  }) {
    final controlHeight = largeTouchTargets ? 60.0 : 0.0;
    return switch (intensity) {
      ExpressiveIntensity.foundational => SuperCalcDesignTokens.foundational(
        cornerStyle: cornerStyle,
        motionScale: motionScale,
        controlMinHeight: controlHeight == 0 ? 52 : controlHeight,
      ),
      ExpressiveIntensity.excellent => SuperCalcDesignTokens.excellent(
        cornerStyle: cornerStyle,
        motionScale: motionScale,
        controlMinHeight: controlHeight == 0 ? 54 : controlHeight,
      ),
      ExpressiveIntensity.transformative =>
        SuperCalcDesignTokens.transformative(
          cornerStyle: cornerStyle,
          motionScale: motionScale,
          controlMinHeight: controlHeight == 0 ? 56 : controlHeight,
        ),
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
  final double cornerExtraLarge;
  final double controlMinHeight;
  final double keyMinHeight;
  final Duration fastMotion;
  final Duration standardMotion;
  final Duration slowMotion;
  final CornerStyle cornerStyle;
  final double motionScale;
  final SpringDescription fastSpring;
  final SpringDescription settleSpring;
  final SpringDescription emphasizedSpring;

  static SuperCalcDesignTokens of(BuildContext context) =>
      Theme.of(context).extension<SuperCalcDesignTokens>() ??
      const SuperCalcDesignTokens.defaults();

  /// Scales a base duration by the user's motion speed and intensity.
  Duration scaled(Duration base) => Duration(
    microseconds: (base.inMicroseconds * motionScale).round().clamp(1, 1 << 31),
  );

  /// The shape family used for cards, sheets and large containers.
  ShapeBorder surfaceShape({double? radius}) {
    final value = radius ?? cornerLarge;
    if (cornerStyle == CornerStyle.rounded) {
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(value));
    }
    return SquircleBorder(radius: value);
  }

  /// A circular/squircle container shape for icon buttons and avatars.
  ShapeBorder circleShape() => const CircleBorder();

  /// A pill used for chips, segmented controls and compact buttons.
  ShapeBorder pillShape() => const StadiumBorder();

  /// A shape that reads as "expressive but calm" for small keys.
  ShapeBorder keyShape() => cornerStyle == CornerStyle.rounded
      ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(cornerSmall))
      : SquircleBorder(radius: cornerSmall);

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
    double? cornerExtraLarge,
    double? controlMinHeight,
    double? keyMinHeight,
    Duration? fastMotion,
    Duration? standardMotion,
    Duration? slowMotion,
    CornerStyle? cornerStyle,
    double? motionScale,
    SpringDescription? fastSpring,
    SpringDescription? settleSpring,
    SpringDescription? emphasizedSpring,
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
      cornerExtraLarge: cornerExtraLarge ?? this.cornerExtraLarge,
      controlMinHeight: controlMinHeight ?? this.controlMinHeight,
      keyMinHeight: keyMinHeight ?? this.keyMinHeight,
      fastMotion: fastMotion ?? this.fastMotion,
      standardMotion: standardMotion ?? this.standardMotion,
      slowMotion: slowMotion ?? this.slowMotion,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      motionScale: motionScale ?? this.motionScale,
      fastSpring: fastSpring ?? this.fastSpring,
      settleSpring: settleSpring ?? this.settleSpring,
      emphasizedSpring: emphasizedSpring ?? this.emphasizedSpring,
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
      cornerExtraLarge: d(cornerExtraLarge, other.cornerExtraLarge),
      controlMinHeight: d(controlMinHeight, other.controlMinHeight),
      keyMinHeight: d(keyMinHeight, other.keyMinHeight),
      fastMotion: t < 0.5 ? fastMotion : other.fastMotion,
      standardMotion: t < 0.5 ? standardMotion : other.standardMotion,
      slowMotion: t < 0.5 ? slowMotion : other.slowMotion,
      cornerStyle: t < 0.5 ? cornerStyle : other.cornerStyle,
      motionScale: d(motionScale, other.motionScale),
      fastSpring: t < 0.5 ? fastSpring : other.fastSpring,
      settleSpring: t < 0.5 ? settleSpring : other.settleSpring,
      emphasizedSpring: t < 0.5 ? emphasizedSpring : other.emphasizedSpring,
    );
  }
}
