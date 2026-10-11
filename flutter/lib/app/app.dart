import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_settings.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SuperCalculatorApp extends ConsumerStatefulWidget {
  const SuperCalculatorApp({super.key});

  @override
  ConsumerState<SuperCalculatorApp> createState() => _SuperCalculatorAppState();
}

class _SuperCalculatorAppState extends ConsumerState<SuperCalculatorApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Reduced-motion and other accessibility features can change while the app
    // is running; rebuild so the theme transition honors the latest value.
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useMonet =
            settings.monetEnabled &&
            lightDynamic != null &&
            darkDynamic != null;
        return MaterialApp.router(
          title: 'SuperCalculator - Next Era',
          theme: buildAppTheme(
            Brightness.light,
            intensity: settings.intensity,
            colorScheme: useMonet ? lightDynamic : null,
          ),
          darkTheme: buildAppTheme(
            Brightness.dark,
            intensity: settings.intensity,
            colorScheme: useMonet ? darkDynamic : null,
          ),
          themeMode: settings.themeMode.themeMode,
          themeAnimationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          routerConfig: appRouter,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
