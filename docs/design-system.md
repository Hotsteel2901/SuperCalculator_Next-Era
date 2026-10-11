# Material 3 Expressive design system

The app uses Flutter stable Material 3 APIs and the checked-in `DynamicSchemeVariant.expressive`
color scheme variant. Flutter does not provide a single stable global Expressive theme
switch, so application-specific Expressive additions are implemented as
`SuperCalcDesignTokens`, a `ThemeExtension`.

Tokens cover layout breakpoints, spacing, control minimum sizes, corner shapes, plot
surface behavior and motion durations. Widgets must consume tokens rather than adding
one-off colors, dimensions or animation timings.

The Settings page exposes three appearance controls for the whole shell:

- **Theme** — follow system, always light, or always dark, persisted with
  `shared_preferences` through the `AppSettings` controller.
- **Material You dynamic color (Monet)** — when the platform supplies a dynamic
  palette (Android 12+, macOS/Windows/Linux accent color via `dynamic_color`), the
  system `ColorScheme` replaces the seeded scheme. The switch reports itself as
  unavailable elsewhere instead of silently doing nothing.
- **Expressive intensity** — `Foundational`, `Excellent` and `Transformative` map to
  the `tonalSpot`, `expressive` and `vibrant` scheme variants and to the shape/motion
  token sets, keeping the accessibility contract identical at every level.

The About page surfaces the author, both the GitHub and Codeberg repositories and the
AGPL-3.0-or-later license, with copy-to-clipboard fallbacks when a link cannot open.

Accessibility is part of the component contract: every action has a semantic label,
plots expose a textual summary and data table path, curves are not distinguished only
by color, and reduced-motion behavior is handled by the shared motion policy.
