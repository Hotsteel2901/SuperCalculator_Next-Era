import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';

/// Appearance and about settings for the whole application.
///
/// The page is intentionally platform-neutral: theme mode and expressive
/// intensity always apply, while the Material You dynamic color (Monet) switch
/// reports itself as unavailable when the current platform does not provide a
/// dynamic palette.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return FeaturePageFrame(
      title: l10n.settings,
      icon: Icons.settings,
      subtitle: l10n.settingsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FeatureCard(
            title: l10n.appearance,
            icon: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SectionLabel(text: l10n.themeMode),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<AppThemeMode>(
                    segments: <ButtonSegment<AppThemeMode>>[
                      ButtonSegment<AppThemeMode>(
                        value: AppThemeMode.system,
                        label: Text(l10n.themeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment<AppThemeMode>(
                        value: AppThemeMode.light,
                        label: Text(l10n.themeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment<AppThemeMode>(
                        value: AppThemeMode.dark,
                        label: Text(l10n.themeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: <AppThemeMode>{settings.themeMode},
                    onSelectionChanged: (Set<AppThemeMode> selection) {
                      controller.setThemeMode(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DynamicColorBuilder(
                  builder:
                      (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                        final supported =
                            lightDynamic != null && darkDynamic != null;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.wallpaper_outlined),
                          title: Text(l10n.monetTitle),
                          subtitle: Text(
                            supported
                                ? l10n.monetDescription
                                : l10n.monetUnavailable,
                          ),
                          value: supported && settings.monetEnabled,
                          onChanged: supported
                              ? (bool value) =>
                                    controller.setMonetEnabled(value)
                              : null,
                        );
                      },
                ),
                const SizedBox(height: 12),
                _SectionLabel(text: l10n.expressiveIntensity),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _IntensityChip(
                      label: l10n.intensityFoundational,
                      selected:
                          settings.intensity ==
                          ExpressiveIntensity.foundational,
                      onSelected: () => controller.setIntensity(
                        ExpressiveIntensity.foundational,
                      ),
                    ),
                    _IntensityChip(
                      label: l10n.intensityExcellent,
                      selected:
                          settings.intensity == ExpressiveIntensity.excellent,
                      onSelected: () => controller.setIntensity(
                        ExpressiveIntensity.excellent,
                      ),
                    ),
                    _IntensityChip(
                      label: l10n.intensityTransformative,
                      selected:
                          settings.intensity ==
                          ExpressiveIntensity.transformative,
                      onSelected: () => controller.setIntensity(
                        ExpressiveIntensity.transformative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _intensityDescription(l10n, settings.intensity),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FeatureCard(
            title: l10n.about,
            icon: Icons.info_outline,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calculate_outlined),
              title: Text(l10n.appTitle),
              subtitle: Text(l10n.aboutTagline),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/about'),
            ),
          ),
        ],
      ),
    );
  }

  String _intensityDescription(
    AppLocalizations l10n,
    ExpressiveIntensity intensity,
  ) {
    return switch (intensity) {
      ExpressiveIntensity.foundational => l10n.intensityFoundationalDescription,
      ExpressiveIntensity.excellent => l10n.intensityExcellentDescription,
      ExpressiveIntensity.transformative =>
        l10n.intensityTransformativeDescription,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) => onSelected(),
    );
  }
}
