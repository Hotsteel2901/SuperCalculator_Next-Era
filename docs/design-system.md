# Material 3 Expressive design system

The app is built directly on Material 3 Expressive. Flutter stable now ships Material as
a standalone package (`package:material_ui`), which is what the app imports instead of
`package:flutter/material.dart`; that package provides the Expressive component variants
used here:

- `StyleVariant.material3Expressive` on the elevated, filled and icon-button themes,
- `ButtonSizeVariant` / `ButtonShapeVariant` / `IconButtonWidthVariant` for expressive
  button metrics,
- `MaterialShapeBorder` + `MaterialShapes` as shape-morphing targets,
- `FadeForwardsPageTransitionsBuilder` for the M3E page transition.

Expressive additions that have no single global switch are implemented as
`SuperCalcDesignTokens`, a `ThemeExtension`. Tokens cover layout breakpoints, spacing,
control minimum sizes, corner shapes (rounded or squircle), plot surface behavior, spring
descriptions and motion durations. Widgets must consume tokens rather than adding one-off
colors, dimensions or animation timings.

Springs are real `SpringSimulation`s (`fastSpring`, `settleSpring`,
`emphasizedSpring`), not durations with curves, so presses, reveals and page transitions
overshoot and settle the way the Expressive guidance describes. Every motion path honours
the reduced-motion contract: when the platform disables animations (or the user forces
it), springs collapse to instant state changes and draw-in animations are skipped.

## Settings surface

`AppSettings` is a single persisted record (`version: 2`) with 35 fields. Every field is
consumed by a concrete widget, so the Settings page never exposes a switch that does
nothing:

| Group | Fields |
| --- | --- |
| Appearance | theme mode, Material You, seed palette, palette style, contrast, expressive intensity, corner style, text scale, bold text, high contrast, large touch targets, tooltips |
| Motion | motion speed, reduced motion (system/reduce/allow), plot draw-in animation |
| Plotting | sampling budget, adaptive sampling, auto resample, curve thickness, grid, tick labels, tap-to-mark, double-tap zoom, background, mesh density |
| Input | quick-panel layout, haptics, auto-evaluate, keyboard shortcuts, confirm on reset, number precision, start page |
| Data & language | history limit, auto-record, clear history, app language |

Settings are written with a 220 ms debounce, and `main()` reads the persisted record
before the first frame so the shell can open directly on the configured start page.

## Quick input panel

The symbol panel is a separate, reusable editor surface rather than a row of buttons:

- 70+ symbols across 10 groups with bilingual labels, descriptions and search keywords;
  favourites, recents and usage counts persist per device,
- selection-aware insertion (wrapping, automatic bracket closing, caret placement),
  undo/redo history and long-press repeat backspace,
- arrow-key grid navigation, Enter to insert, `Ctrl/⌘+Z`/`Y` for undo/redo and
  `Ctrl/⌘+F` for search,
- three presentations (bottom sheet, side panel, dialog) chosen by the quick-panel
  layout setting or by window width, with large-touch-target support.

## Plotting

`FunctionPlotPainter` draws every mode over the full sampled domain:

- `y = f(x)` and multi-curve plots use adaptive sampling and extend asymptotes to the
  plot edge with Liang–Barsky clipping, so `tan(x)` has continuous branches instead of
  gaps,
- implicit (`f(x, y) = 0`) and contour plots use marching squares, producing continuous
  iso-lines rather than scattered dots,
- parametric and polar curves refine on chord deviation, and the viewport is fitted to
  the whole curve with a locked aspect ratio so circles stay circular,
- 3D surfaces are depth-sorted, shaded quads over a base grid, normalised to the sampled
  bounds,
- paths are cached per viewport/size, so panning and zooming do not rebuild geometry, and
  the draw-in animation only runs when the samples actually change.

The history page, the result cards and the plot toolbar all read the same settings
(history limit, auto-record, number precision, curve thickness) rather than hard-coding
their own values.

## Brand and launcher icons

The "Next Era" brand is a bold white sigma (sum) glyph on a warm rose → orange →
amber diagonal gradient with two sparkles.
`flutter/assets/branding/supercalculator-mark.svg` is the source mark; every platform icon
(Web/PWA including maskable variants, the Windows `.ico`, iOS, macOS, Linux and the
Android legacy PNGs) is generated from the same geometry. The Android adaptive icon ships
separate background, foreground and **monochrome** layers, so Android 13+ themed icons
recolour the mark with the user's Material You palette.

## Launch animation

Three layers cooperate, each handing over to the next:

1. **Android 12+** — `windowSplashScreenAnimatedIcon` points at
   `res/drawable/sc_splash_icon.xml`, an `AnimatedVectorDrawable` that settles the mark
   from 0.86 scale and draws the plotted curve in 620 ms (the platform caps the icon
   animation at 1000 ms). Android 11 and older use the static layer-list
   `launch_background`.
2. **Web** — `web/index.html` paints the same mark with CSS/SVG before Flutter loads and
   fades it out on the `flutter-first-frame` event.
3. **In-app** — `LaunchGate` morphs a circle into the app's squircle, sweeps a sheen
   across the mark and hands over after ≈1.08 s (180 ms fade when reduced motion is on).

The platform folders are generated by `tool/bootstrap_flutter_platforms.sh`, which
re-applies the Android launch artwork through `tool/apply_launch_art.py` after
`flutter create`; `python3 tool/apply_launch_art.py --check` verifies the result in CI.

## Android dynamic color (Monet)

On Android 12+ the `dynamic_color` plugin supplies the system wallpaper palette. The app
reads the *core palette* directly (`getCorePalette()`, falling back to
`getAccentColor()`), which keeps one seed per wallpaper instead of several unrelated
harmonised colours, then regenerates the `ColorScheme` locally with the selected
`DynamicSchemeVariant` and contrast level. Schemes are cached (LRU, 8 entries) so theme
rebuilds do not re-run the colour maths.

When the platform exposes no dynamic palette the switch reports itself as unavailable and
the seeded palette (eight hand-tuned seeds) is used instead.

## Accessibility

Every action has a semantic label, plots expose a textual summary, curves carry both a
colour and a stroke style so they are not distinguished by colour alone, text scaling is
applied on top of the platform value, and reduced motion is handled by the shared motion
policy described above.
