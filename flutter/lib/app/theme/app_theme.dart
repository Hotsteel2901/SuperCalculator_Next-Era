import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_settings.dart';
import 'design_tokens.dart';
import 'monet.dart';
import 'squircle_border.dart';

/// Seed color used when Material You dynamic color (Monet) is unavailable or
/// disabled.
const Color superCalcSeedColor = Color(0xFF536DDE);

/// Builds the Material 3 Expressive theme for [brightness].
///
/// The theme intentionally opts Material components into
/// [StyleVariant.material3Expressive] (buttons and icon buttons), uses the
/// expressive shape family for surfaces, and installs spring-based motion
/// tokens. Dynamic color is supplied by [dynamicSeed]; when it is null the
/// built-in seed palette from [settings] is used.
///
/// Calls that only pass a [colorScheme] (tests and previews) receive that
/// scheme verbatim and the default expressive tokens.
ThemeData buildAppTheme(
  Brightness brightness, {
  ColorScheme? colorScheme,
  ExpressiveIntensity intensity = ExpressiveIntensity.excellent,
  AppSettings settings = AppSettings.defaults,
  Color? dynamicSeed,
  bool platformReduceMotion = false,
}) {
  final useDynamic = dynamicSeed != null && settings.monetEnabled;
  final seed = useDynamic
      ? dynamicSeed
      : (settings.seedPalette.seedColor);
  final scheme =
      colorScheme ??
      buildColorScheme(
        brightness: brightness,
        seedColor: seed,
        style: settings.monetStyle,
        contrastLevel: settings.contrastLevel,
      );

  final reduceMotion = settings.shouldReduceMotion(platformReduceMotion);
  final motionScale = reduceMotion ? 0.0 : settings.motionSpeed.scale;
  final tokens = SuperCalcDesignTokens.forIntensity(
    intensity,
    cornerStyle: settings.cornerStyle,
    motionScale: motionScale,
    largeTouchTargets: settings.largeTouchTargets,
  );

  final textTheme = _buildTextTheme(
    brightness,
    scheme,
    bold: settings.boldText,
    expressive: intensity,
  );

  final buttonTextStyle = textTheme.labelLarge?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
  );
  final buttonHeight = tokens.controlMinHeight;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[tokens],
    textTheme: textTheme,
    visualDensity: settings.largeTouchTargets
        ? VisualDensity.comfortable
        : VisualDensity.standard,
    materialTapTargetSize: settings.largeTouchTargets
        ? MaterialTapTargetSize.padded
        : MaterialTapTargetSize.shrinkWrap,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: _pageTransitions(reduceMotion),
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      scrolledUnderElevation: 2,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: tokens.surfaceShape(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerExtraLarge),
            )
          : SquircleBorder(radius: tokens.cornerExtraLarge),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: scheme.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainerLow,
      elevation: 1,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      dragHandleSize: const Size(40, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.cornerExtraLarge),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(0, buttonHeight)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(buttonTextStyle),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          StadiumBorder(),
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        animationDuration: tokens.scaled(const Duration(milliseconds: 160)),
        iconAlignment: IconAlignment.end,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      variant: StyleVariant.material3Expressive,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(0, buttonHeight)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(buttonTextStyle),
        elevation: const WidgetStatePropertyAll<double>(1),
        animationDuration: tokens.scaled(const Duration(milliseconds: 160)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(0, buttonHeight)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(buttonTextStyle),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: scheme.outlineVariant),
        ),
        animationDuration: tokens.scaled(const Duration(milliseconds: 160)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(0, buttonHeight - 8)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          buttonTextStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
        animationDuration: tokens.scaled(const Duration(milliseconds: 160)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      variant: StyleVariant.material3Expressive,
      style: ButtonStyle(
        animationDuration: tokens.scaled(const Duration(milliseconds: 160)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 4,
      sizeConstraints: const BoxConstraints.tightFor(width: 64, height: 64),
      shape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerMedium),
            )
          : SquircleBorder(radius: tokens.cornerMedium),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.cornerSmall + 4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.cornerSmall + 4),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.cornerSmall + 4),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.cornerSmall + 4),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: scheme.primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      secondarySelectedColor: scheme.secondaryContainer,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      shape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerSmall),
            )
          : SquircleBorder(radius: tokens.cornerSmall),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerSmall),
            )
          : SquircleBorder(radius: tokens.cornerSmall),
      elevation: 3,
      insetPadding: const EdgeInsets.all(16),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 550),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(tokens.cornerSmall - 2),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(0, buttonHeight - 6)),
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          buttonTextStyle?.copyWith(fontSize: 13.5),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: scheme.outlineVariant),
        ),
        animationDuration: tokens.scaled(const Duration(milliseconds: 220)),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerSmall),
            )
          : SquircleBorder(radius: tokens.cornerSmall),
      collapsedShape: tokens.cornerStyle == CornerStyle.rounded
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cornerSmall),
            )
          : SquircleBorder(radius: tokens.cornerSmall),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      collapsedTextColor: scheme.onSurface,
      childrenPadding: const EdgeInsets.only(bottom: 8),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll<Color>(
        scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      crossAxisMargin: 2,
    ),
  );
}

TextTheme _buildTextTheme(
  Brightness brightness,
  ColorScheme scheme, {
  required bool bold,
  required ExpressiveIntensity expressive,
}) {
  final base = (brightness == Brightness.dark
          ? Typography.material2021().white
          : Typography.material2021().black)
      .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  // Material 3 Expressive tightens large display type and gives labels a
  // confident, slightly heavier voice.
  final tracking = switch (expressive) {
    ExpressiveIntensity.foundational => 0.0,
    ExpressiveIntensity.excellent => -0.4,
    ExpressiveIntensity.transformative => -0.8,
  };
  final heroWeight = bold ? FontWeight.w800 : FontWeight.w700;
  final strongWeight = bold ? FontWeight.w700 : FontWeight.w600;
  final bodyWeight = bold ? FontWeight.w500 : FontWeight.w400;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: heroWeight,
      letterSpacing: -1.2 + tracking,
      height: 1.05,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: heroWeight,
      letterSpacing: -0.8 + tracking,
      height: 1.08,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: heroWeight,
      letterSpacing: -0.5 + tracking,
      height: 1.1,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: strongWeight,
      letterSpacing: -0.4 + tracking,
      height: 1.12,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: strongWeight,
      letterSpacing: -0.3 + tracking,
      height: 1.15,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: strongWeight,
      letterSpacing: -0.2 + tracking,
      height: 1.2,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: strongWeight,
      letterSpacing: -0.15,
    ),
    titleMedium: base.titleMedium?.copyWith(fontWeight: strongWeight),
    titleSmall: base.titleSmall?.copyWith(fontWeight: strongWeight),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: bodyWeight, height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(fontWeight: bodyWeight, height: 1.4),
    bodySmall: base.bodySmall?.copyWith(height: 1.35),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: strongWeight,
      letterSpacing: 0.1,
    ),
    labelMedium: base.labelMedium?.copyWith(fontWeight: strongWeight),
    labelSmall: base.labelSmall?.copyWith(letterSpacing: 0.3),
  );
}

PageTransitionsTheme _pageTransitions(bool reduceMotion) {
  final builder = reduceMotion
      ? const FadeForwardsPageTransitionsBuilder(allowSnapshotting: false)
      : const FadeForwardsPageTransitionsBuilder();
  return PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: builder,
      TargetPlatform.fuchsia: builder,
      TargetPlatform.linux: builder,
      TargetPlatform.windows: builder,
      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
    },
  );
}
