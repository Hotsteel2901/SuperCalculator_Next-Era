import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show Color, Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

const _settingsStorageKey = 'supercalculator.next_era.settings.v1';

/// Material 3 Expressive intensity levels.
///
/// The levels follow the expressive guidance: `foundational` keeps clarity and
/// familiarity first, `excellent` strengthens color, type and shape while
/// preserving established patterns, and `transformative` uses bolder shapes and
/// motion while keeping the same usability and accessibility contract.
enum ExpressiveIntensity { foundational, excellent, transformative }

/// The user-selectable theme mode.
enum AppThemeMode { system, light, dark }

extension AppThemeModeMapping on AppThemeMode {
  /// Maps the persisted value onto Flutter's [ThemeMode].
  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// Application language preference. `system` follows the platform locale.
enum AppLocale { system, english, simplifiedChinese }

extension AppLocaleMapping on AppLocale {
  /// The explicit locale, or null when the platform locale should be used.
  Locale? get locale => switch (this) {
    AppLocale.system => null,
    AppLocale.english => const Locale('en'),
    AppLocale.simplifiedChinese => const Locale('zh'),
  };
}

/// Built-in seed palettes used when Material You dynamic color is unavailable
/// or disabled. Each entry keeps a hand-tuned, accessible seed color.
enum SeedPalette { indigo, teal, green, amber, rose, violet, cyan, slate }

extension SeedPaletteColor on SeedPalette {
  Color get seedColor => switch (this) {
    SeedPalette.indigo => const Color(0xFF536DDE),
    SeedPalette.teal => const Color(0xFF00796B),
    SeedPalette.green => const Color(0xFF2E7D32),
    SeedPalette.amber => const Color(0xFFB26A00),
    SeedPalette.rose => const Color(0xFFB3245B),
    SeedPalette.violet => const Color(0xFF6A4BC4),
    SeedPalette.cyan => const Color(0xFF00738B),
    SeedPalette.slate => const Color(0xFF4F5B6B),
  };
}

/// Color scheme generation style applied to Monet and to the seed palette.
enum MonetStyle { tonalSpot, vibrant, expressive, neutral, monochrome }

/// Tonal contrast level. Mirrors the Material color utilities contrast levels.
enum MonetContrast { standard, medium, high }

extension MonetContrastLevel on MonetContrast {
  double get contrastLevel => switch (this) {
    MonetContrast.standard => 0,
    MonetContrast.medium => 0.5,
    MonetContrast.high => 1,
  };
}

/// Shape family for cards, sheets, buttons and the quick-input keys.
enum CornerStyle { rounded, squircle }

/// Plot sampling budget. `adaptive` distributes samples where the curve bends.
enum PlotResolution { adaptive, balanced, high, ultra }

extension PlotResolutionBudget on PlotResolution {
  int get maximumSamples => switch (this) {
    PlotResolution.adaptive => 1600,
    PlotResolution.balanced => 2400,
    PlotResolution.high => 4800,
    PlotResolution.ultra => 8000,
  };
}

/// Background treatment for the plot canvas.
enum PlotBackgroundStyle { surface, container, contrast }

/// Mesh density for 3D surfaces, contours and vector fields.
enum MeshDensity { low, medium, high }

extension MeshDensityGrid on MeshDensity {
  int get divisions => switch (this) {
    MeshDensity.low => 32,
    MeshDensity.medium => 48,
    MeshDensity.high => 72,
  };
}

/// How the quick input panel is presented.
enum QuickPanelLayout { automatic, bottomSheet, sidePanel, dialog }

/// Global motion multiplier. `calm` gently shortens travel, `lively` makes
/// springs more visible without exceeding the reduced-motion contract.
enum MotionSpeed { calm, standard, brisk, lively }

extension MotionSpeedScale on MotionSpeed {
  double get scale => switch (this) {
    MotionSpeed.calm => 0.75,
    MotionSpeed.standard => 1,
    MotionSpeed.brisk => 1.25,
    MotionSpeed.lively => 1.55,
  };
}

/// Reduced-motion preference, with an explicit override for users who want the
/// platform setting ignored in either direction.
enum ReduceMotionPreference { system, reduce, allow }

/// Landing route after a cold start.
enum StartPage { home, plotting, history }

/// Significant-digit policy for computed values.
enum NumberPrecision { auto, six, eight, ten, twelve }

extension NumberPrecisionDigits on NumberPrecision {
  /// Digits passed to `toStringAsPrecision`, or null for adaptive formatting.
  int? get digits => switch (this) {
    NumberPrecision.auto => null,
    NumberPrecision.six => 6,
    NumberPrecision.eight => 8,
    NumberPrecision.ten => 10,
    NumberPrecision.twelve => 12,
  };
}

/// Persisted preferences for the whole application.
///
/// Every field is applied by a concrete consumer (theme, plot, navigation,
/// quick input or accessibility), so the settings surface never exposes a
/// switch that does nothing. The record is serialized as a compact JSON map and
/// unknown keys are ignored, which keeps older builds forward compatible.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.monetEnabled = false,
    this.intensity = ExpressiveIntensity.excellent,
    this.seedPalette = SeedPalette.indigo,
    this.monetStyle = MonetStyle.tonalSpot,
    this.monetContrast = MonetContrast.standard,
    this.cornerStyle = CornerStyle.squircle,
    this.textScale = 1,
    this.boldText = false,
    this.highContrast = false,
    this.largeTouchTargets = false,
    this.showTooltips = true,
    this.motionSpeed = MotionSpeed.standard,
    this.reduceMotion = ReduceMotionPreference.system,
    this.plotResolution = PlotResolution.adaptive,
    this.adaptiveSampling = true,
    this.autoResample = true,
    this.curveThickness = 2.4,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.animatePlotDraw = true,
    this.plotBackground = PlotBackgroundStyle.surface,
    this.meshDensity = MeshDensity.medium,
    this.tapToMark = true,
    this.doubleTapZoom = true,
    this.haptics = true,
    this.autoEvaluate = false,
    this.keyboardShortcuts = true,
    this.confirmReset = true,
    this.historyLimit = 100,
    this.autoSaveHistory = true,
    this.quickPanelLayout = QuickPanelLayout.automatic,
    this.startPage = StartPage.home,
    this.numberPrecision = NumberPrecision.auto,
    this.locale = AppLocale.system,
  });

  /// Whether the theme follows the system, is always light, or always dark.
  final AppThemeMode themeMode;

  /// Whether Material You dynamic color (Monet) should be used when the
  /// platform provides it.
  final bool monetEnabled;

  /// The Material 3 Expressive intensity applied to the design tokens.
  final ExpressiveIntensity intensity;

  /// Seed palette used when dynamic color is off or unavailable.
  final SeedPalette seedPalette;

  /// Color scheme variant used for generated palettes.
  final MonetStyle monetStyle;

  /// Tonal contrast applied to the generated palette.
  final MonetContrast monetContrast;

  /// Shape family used for surfaces.
  final CornerStyle cornerStyle;

  /// Additional text scaling on top of the platform value (0.85 – 1.45).
  final double textScale;

  /// Uses heavier weights for emphasis.
  final bool boldText;

  /// Requests the highest contrast palette available.
  final bool highContrast;

  /// Increases minimum control heights and tap targets.
  final bool largeTouchTargets;

  /// Shows long-press tooltips for icon-only controls.
  final bool showTooltips;

  /// Motion duration multiplier.
  final MotionSpeed motionSpeed;

  /// Reduced-motion preference.
  final ReduceMotionPreference reduceMotion;

  /// Plot sampling budget.
  final PlotResolution plotResolution;

  /// Enables adaptive (curvature-driven) sampling.
  final bool adaptiveSampling;

  /// Re-samples function plots after the visible x-range changes.
  final bool autoResample;

  /// Curve stroke width in logical pixels (1.0 – 5.0).
  final double curveThickness;

  /// Draws the grid behind curves.
  final bool showGrid;

  /// Draws numeric tick labels.
  final bool showAxisLabels;

  /// Animates curves as they are drawn.
  final bool animatePlotDraw;

  /// Plot background treatment.
  final PlotBackgroundStyle plotBackground;

  /// Mesh density for multi-dimensional plots.
  final MeshDensity meshDensity;

  /// Tap adds a coordinate marker on the plot.
  final bool tapToMark;

  /// Double tap zooms the plot.
  final bool doubleTapZoom;

  /// Haptic feedback for keys, evaluation and navigation.
  final bool haptics;

  /// Evaluates automatically while typing (debounced) instead of only on submit.
  final bool autoEvaluate;

  /// Enables desktop keyboard shortcuts.
  final bool keyboardShortcuts;

  /// Asks before discarding a plot configuration.
  final bool confirmReset;

  /// Number of history entries that are retained.
  final int historyLimit;

  /// Records evaluations and plots in the history.
  final bool autoSaveHistory;

  /// Presentation style for the quick input panel.
  final QuickPanelLayout quickPanelLayout;

  /// Landing route after a cold start.
  final StartPage startPage;

  /// Significant-digit policy for results.
  final NumberPrecision numberPrecision;

  /// Application language preference.
  final AppLocale locale;

  /// Effective text scale multiplier, clamped to a usable range.
  double get effectiveTextScale => textScale.clamp(0.85, 1.45).toDouble();

  /// Whether motion should be reduced given the platform accessibility state.
  bool shouldReduceMotion(bool platformDisablesAnimations) {
    return switch (reduceMotion) {
      ReduceMotionPreference.reduce => true,
      ReduceMotionPreference.allow => false,
      ReduceMotionPreference.system => platformDisablesAnimations,
    };
  }

  /// Contrast value passed to the palette generator.
  double get contrastLevel => highContrast ? 1 : monetContrast.contrastLevel;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? monetEnabled,
    ExpressiveIntensity? intensity,
    SeedPalette? seedPalette,
    MonetStyle? monetStyle,
    MonetContrast? monetContrast,
    CornerStyle? cornerStyle,
    double? textScale,
    bool? boldText,
    bool? highContrast,
    bool? largeTouchTargets,
    bool? showTooltips,
    MotionSpeed? motionSpeed,
    ReduceMotionPreference? reduceMotion,
    PlotResolution? plotResolution,
    bool? adaptiveSampling,
    bool? autoResample,
    double? curveThickness,
    bool? showGrid,
    bool? showAxisLabels,
    bool? animatePlotDraw,
    PlotBackgroundStyle? plotBackground,
    MeshDensity? meshDensity,
    bool? tapToMark,
    bool? doubleTapZoom,
    bool? haptics,
    bool? autoEvaluate,
    bool? keyboardShortcuts,
    bool? confirmReset,
    int? historyLimit,
    bool? autoSaveHistory,
    QuickPanelLayout? quickPanelLayout,
    StartPage? startPage,
    NumberPrecision? numberPrecision,
    AppLocale? locale,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      monetEnabled: monetEnabled ?? this.monetEnabled,
      intensity: intensity ?? this.intensity,
      seedPalette: seedPalette ?? this.seedPalette,
      monetStyle: monetStyle ?? this.monetStyle,
      monetContrast: monetContrast ?? this.monetContrast,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      textScale: textScale ?? this.textScale,
      boldText: boldText ?? this.boldText,
      highContrast: highContrast ?? this.highContrast,
      largeTouchTargets: largeTouchTargets ?? this.largeTouchTargets,
      showTooltips: showTooltips ?? this.showTooltips,
      motionSpeed: motionSpeed ?? this.motionSpeed,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      plotResolution: plotResolution ?? this.plotResolution,
      adaptiveSampling: adaptiveSampling ?? this.adaptiveSampling,
      autoResample: autoResample ?? this.autoResample,
      curveThickness: curveThickness ?? this.curveThickness,
      showGrid: showGrid ?? this.showGrid,
      showAxisLabels: showAxisLabels ?? this.showAxisLabels,
      animatePlotDraw: animatePlotDraw ?? this.animatePlotDraw,
      plotBackground: plotBackground ?? this.plotBackground,
      meshDensity: meshDensity ?? this.meshDensity,
      tapToMark: tapToMark ?? this.tapToMark,
      doubleTapZoom: doubleTapZoom ?? this.doubleTapZoom,
      haptics: haptics ?? this.haptics,
      autoEvaluate: autoEvaluate ?? this.autoEvaluate,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
      confirmReset: confirmReset ?? this.confirmReset,
      historyLimit: historyLimit ?? this.historyLimit,
      autoSaveHistory: autoSaveHistory ?? this.autoSaveHistory,
      quickPanelLayout: quickPanelLayout ?? this.quickPanelLayout,
      startPage: startPage ?? this.startPage,
      numberPrecision: numberPrecision ?? this.numberPrecision,
      locale: locale ?? this.locale,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'version': 2,
    'themeMode': themeMode.name,
    'monetEnabled': monetEnabled,
    'intensity': intensity.name,
    'seedPalette': seedPalette.name,
    'monetStyle': monetStyle.name,
    'monetContrast': monetContrast.name,
    'cornerStyle': cornerStyle.name,
    'textScale': textScale,
    'boldText': boldText,
    'highContrast': highContrast,
    'largeTouchTargets': largeTouchTargets,
    'showTooltips': showTooltips,
    'motionSpeed': motionSpeed.name,
    'reduceMotion': reduceMotion.name,
    'plotResolution': plotResolution.name,
    'adaptiveSampling': adaptiveSampling,
    'autoResample': autoResample,
    'curveThickness': curveThickness,
    'showGrid': showGrid,
    'showAxisLabels': showAxisLabels,
    'animatePlotDraw': animatePlotDraw,
    'plotBackground': plotBackground.name,
    'meshDensity': meshDensity.name,
    'tapToMark': tapToMark,
    'doubleTapZoom': doubleTapZoom,
    'haptics': haptics,
    'autoEvaluate': autoEvaluate,
    'keyboardShortcuts': keyboardShortcuts,
    'confirmReset': confirmReset,
    'historyLimit': historyLimit,
    'autoSaveHistory': autoSaveHistory,
    'quickPanelLayout': quickPanelLayout.name,
    'startPage': startPage.name,
    'numberPrecision': numberPrecision.name,
    'locale': locale.name,
  };

  static AppSettings fromJson(Object? source) {
    if (source is! Map) return defaults;
    const fallback = AppSettings.defaults;
    return AppSettings(
      themeMode: _enumByName(
        AppThemeMode.values,
        source['themeMode'],
        fallback.themeMode,
      ),
      monetEnabled: _bool(source['monetEnabled'], fallback.monetEnabled),
      intensity: _enumByName(
        ExpressiveIntensity.values,
        source['intensity'],
        fallback.intensity,
      ),
      seedPalette: _enumByName(
        SeedPalette.values,
        source['seedPalette'],
        fallback.seedPalette,
      ),
      monetStyle: _enumByName(
        MonetStyle.values,
        source['monetStyle'],
        fallback.monetStyle,
      ),
      monetContrast: _enumByName(
        MonetContrast.values,
        source['monetContrast'],
        fallback.monetContrast,
      ),
      cornerStyle: _enumByName(
        CornerStyle.values,
        source['cornerStyle'],
        fallback.cornerStyle,
      ),
      textScale: _double(
        source['textScale'],
        fallback.textScale,
      ).clamp(0.85, 1.45).toDouble(),
      boldText: _bool(source['boldText'], fallback.boldText),
      highContrast: _bool(source['highContrast'], fallback.highContrast),
      largeTouchTargets: _bool(
        source['largeTouchTargets'],
        fallback.largeTouchTargets,
      ),
      showTooltips: _bool(source['showTooltips'], fallback.showTooltips),
      motionSpeed: _enumByName(
        MotionSpeed.values,
        source['motionSpeed'],
        fallback.motionSpeed,
      ),
      reduceMotion: _enumByName(
        ReduceMotionPreference.values,
        source['reduceMotion'],
        fallback.reduceMotion,
      ),
      plotResolution: _enumByName(
        PlotResolution.values,
        source['plotResolution'],
        fallback.plotResolution,
      ),
      adaptiveSampling: _bool(
        source['adaptiveSampling'],
        fallback.adaptiveSampling,
      ),
      autoResample: _bool(source['autoResample'], fallback.autoResample),
      curveThickness: _double(
        source['curveThickness'],
        fallback.curveThickness,
      ).clamp(1.0, 5.0).toDouble(),
      showGrid: _bool(source['showGrid'], fallback.showGrid),
      showAxisLabels: _bool(source['showAxisLabels'], fallback.showAxisLabels),
      animatePlotDraw: _bool(
        source['animatePlotDraw'],
        fallback.animatePlotDraw,
      ),
      plotBackground: _enumByName(
        PlotBackgroundStyle.values,
        source['plotBackground'],
        fallback.plotBackground,
      ),
      meshDensity: _enumByName(
        MeshDensity.values,
        source['meshDensity'],
        fallback.meshDensity,
      ),
      tapToMark: _bool(source['tapToMark'], fallback.tapToMark),
      doubleTapZoom: _bool(source['doubleTapZoom'], fallback.doubleTapZoom),
      haptics: _bool(source['haptics'], fallback.haptics),
      autoEvaluate: _bool(source['autoEvaluate'], fallback.autoEvaluate),
      keyboardShortcuts: _bool(
        source['keyboardShortcuts'],
        fallback.keyboardShortcuts,
      ),
      confirmReset: _bool(source['confirmReset'], fallback.confirmReset),
      historyLimit: _int(
        source['historyLimit'],
        fallback.historyLimit,
      ).clamp(10, 500).toInt(),
      autoSaveHistory: _bool(
        source['autoSaveHistory'],
        fallback.autoSaveHistory,
      ),
      quickPanelLayout: _enumByName(
        QuickPanelLayout.values,
        source['quickPanelLayout'],
        fallback.quickPanelLayout,
      ),
      startPage: _enumByName(
        StartPage.values,
        source['startPage'],
        fallback.startPage,
      ),
      numberPrecision: _enumByName(
        NumberPrecision.values,
        source['numberPrecision'],
        fallback.numberPrecision,
      ),
      locale: _enumByName(AppLocale.values, source['locale'], fallback.locale),
    );
  }

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static double _double(Object? value, double fallback) =>
      value is num && value.isFinite ? value.toDouble() : fallback;

  static int _int(Object? value, int fallback) =>
      value is num && value.isFinite ? value.toInt() : fallback;

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    if (name is String) {
      for (final value in values) {
        if (value.name == name) return value;
      }
    }
    return fallback;
  }
}

/// Settings loaded before the first frame (cold-start route selection).
///
/// `main()` reads the persisted record once so the shell can open on the user's
/// chosen start page without a visible redirect. Tests and embeddings that do
/// not override this provider fall back to the defaults and restore
/// asynchronously as before.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults,
);

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Maps the persisted start-page preference onto a route.
String routeForStartPage(StartPage page) => switch (page) {
  StartPage.home => '/home',
  StartPage.plotting => '/plotting',
  StartPage.history => '/history',
};

/// Riverpod controller that restores and persists [AppSettings].
///
/// Storage is best-effort, mirroring the history repository: Web private mode
/// and restricted desktop profiles may reject writes, in which case the
/// in-memory settings keep working for the current session. Writes are debounced
/// so dragging a slider does not hit the platform channel on every frame.
class AppSettingsController extends Notifier<AppSettings> {
  late Future<void> _ready;
  bool _hasLocalChanges = false;
  Timer? _persistTimer;

  @override
  AppSettings build() {
    final initial = ref.watch(initialSettingsProvider);
    final seeded = !identical(initial, AppSettings.defaults);
    _ready = seeded ? Future<void>.value() : _restore();
    ref.onDispose(() => _persistTimer?.cancel());
    return initial;
  }

  /// Applies a new settings record and schedules persistence.
  void set(AppSettings next) {
    _hasLocalChanges = true;
    state = next;
    _schedulePersist();
  }

  /// Applies a transformation to the current settings.
  void update(AppSettings Function(AppSettings current) transform) {
    set(transform(state));
  }

  void setThemeMode(AppThemeMode mode) =>
      update((current) => current.copyWith(themeMode: mode));

  void setMonetEnabled(bool enabled) =>
      update((current) => current.copyWith(monetEnabled: enabled));

  void setIntensity(ExpressiveIntensity intensity) =>
      update((current) => current.copyWith(intensity: intensity));

  void setSeedPalette(SeedPalette palette) =>
      update((current) => current.copyWith(seedPalette: palette));

  void setMonetStyle(MonetStyle style) =>
      update((current) => current.copyWith(monetStyle: style));

  void setMonetContrast(MonetContrast contrast) =>
      update((current) => current.copyWith(monetContrast: contrast));

  void resetToDefaults() => set(AppSettings.defaults);

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(milliseconds: 220),
      () => unawaited(_persist()),
    );
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_settingsStorageKey);
      if (encoded == null || _hasLocalChanges) return;
      final decoded = jsonDecode(encoded);
      if (!_hasLocalChanges) state = AppSettings.fromJson(decoded);
    } catch (_) {
      // Corrupt or unavailable storage must never prevent the calculator from
      // starting; the default settings remain the fallback.
    }
  }

  Future<void> _persist() async {
    try {
      await _ready;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _settingsStorageKey,
        jsonEncode(state.toJson()),
      );
    } catch (_) {
      // Best-effort persistence only.
    }
  }
}
