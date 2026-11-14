import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_settings.dart';

/// Where the dynamic seed color came from.
enum MonetSource {
  /// Android 12+ wallpaper palette (Material You).
  wallpaper,

  /// Platform accent color (macOS, Windows, GTK desktops).
  accent,

  /// A built-in seed palette, used on Web and when the platform exposes no
  /// system color.
  seed,
}

/// A resolved seed color plus the source that produced it.
@immutable
class MonetSeeds {
  const MonetSeeds(this.seedColor, this.source);

  final Color seedColor;
  final MonetSource source;

  bool get isSystem => source != MonetSource.seed;
}

/// Loads the platform palette once per session.
///
/// Material You exposes a full tonal palette on Android; desktop platforms
/// expose an accent color. Reading the palette directly (instead of the
/// pre-built `ColorScheme`s from `dynamic_color`) lets the theme regenerate the
/// scheme with the user's chosen Expressive variant and contrast level, which
/// keeps wallpaper-derived colors recognizable while still honouring the
/// Material 3 Expressive controls.
Future<MonetSeeds> _loadSystemSeeds(SeedPalette fallback) async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) {
      // Tone 50 is the most chromatic anchor and survives both light and dark
      // regeneration without drifting toward grey.
      final seed = palette.primary.get(50);
      return MonetSeeds(Color(seed), MonetSource.wallpaper);
    }
  } catch (_) {
    // Unsupported platform or a missing plugin: fall through to the accent.
  }
  try {
    final accent = await DynamicColorPlugin.getAccentColor();
    if (accent != null) {
      return MonetSeeds(_ensureChroma(accent), MonetSource.accent);
    }
  } catch (_) {
    // Same best-effort contract as above.
  }
  return MonetSeeds(fallback.seedColor, MonetSource.seed);
}

/// Some desktop accents are almost neutral; nudging them toward a usable
/// chroma keeps generated schemes from looking like plain grey.
Color _ensureChroma(Color color) {
  final hsv = HSVColor.fromColor(color);
  if (hsv.saturation >= 0.18) return color;
  return hsv
      .withSaturation(0.35)
      .withValue(hsv.value.clamp(0.35, 0.8).toDouble())
      .toColor();
}

final monetSeedsProvider = FutureProvider<MonetSeeds>((ref) async {
  final palette = ref.watch(
    appSettingsProvider.select((AppSettings settings) => settings.seedPalette),
  );
  return _loadSystemSeeds(palette);
});

/// Maps the user's style preference onto the Material color utilities variant.
DynamicSchemeVariant schemeVariantFor(MonetStyle style) => switch (style) {
  MonetStyle.tonalSpot => DynamicSchemeVariant.tonalSpot,
  MonetStyle.vibrant => DynamicSchemeVariant.vibrant,
  MonetStyle.expressive => DynamicSchemeVariant.expressive,
  MonetStyle.neutral => DynamicSchemeVariant.neutral,
  MonetStyle.monochrome => DynamicSchemeVariant.monochrome,
};

/// Builds a Material 3 Expressive color scheme.
///
/// When dynamic color is enabled and the platform provided a seed, that seed is
/// used; otherwise the built-in palette is used. The seed is de-duplicated
/// through a small cache because `ColorScheme.fromSeed` performs a full
/// HCT/quantizer pass and is far too expensive to run on every rebuild.
ColorScheme buildColorScheme({
  required Brightness brightness,
  required Color seedColor,
  required MonetStyle style,
  required double contrastLevel,
}) {
  final key = (
    brightness,
    seedColor.toARGB32(),
    style,
    (contrastLevel * 100).round(),
  );
  final cached = _schemeCache[key];
  if (cached != null) return cached;
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: schemeVariantFor(style),
    // The generator clamps to [-1, 1]; high contrast sits at the upper end.
    contrastLevel: contrastLevel.clamp(-1.0, 1.0).toDouble(),
  );
  if (_schemeCache.length > 8) {
    _schemeCache.remove(_schemeCache.keys.first);
  }
  _schemeCache[key] = scheme;
  return scheme;
}

final Map<(Brightness, int, MonetStyle, int), ColorScheme> _schemeCache =
    <(Brightness, int, MonetStyle, int), ColorScheme>{};

/// A set of expressive accent colors derived from the scheme, used for plot
/// series so curves never rely on hard-coded hues.
class PlotPalette {
  const PlotPalette(this.colors);

  final List<Color> colors;

  static PlotPalette fromScheme(ColorScheme scheme) {
    final base = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
    ];
    return PlotPalette(
      base
          .map((color) => _readableOnSurface(color, scheme))
          .toList(growable: false),
    );
  }

  Color at(int index) => colors[index % colors.length];

  /// Lifts extremely pale container colors so a 2px curve stays visible on the
  /// light surface.
  static Color _readableOnSurface(Color color, ColorScheme scheme) {
    final hsv = HSVColor.fromColor(color);
    if (hsv.value > 0.82) {
      return hsv
          .withValue(math.max(0.55, hsv.value - 0.25))
          .withSaturation(math.max(hsv.saturation, 0.4))
          .toColor();
    }
    return color;
  }
}
