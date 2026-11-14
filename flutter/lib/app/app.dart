import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings/app_settings.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localization.dart';
import 'launch/launch_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/monet.dart';

class SuperCalculatorApp extends ConsumerStatefulWidget {
  const SuperCalculatorApp({super.key});

  @override
  ConsumerState<SuperCalculatorApp> createState() => _SuperCalculatorAppState();
}

class _SuperCalculatorAppState extends ConsumerState<SuperCalculatorApp>
    with WidgetsBindingObserver {
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;
  AppSettings? _themeSettings;
  Color? _themeSeed;
  bool _themeReduceMotion = false;

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createAppRouter(
      initialLocation: routeForStartPage(
        ref.read(initialSettingsProvider).startPage,
      ),
    );
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

  /// Theme assembly is memoized because `ThemeData` walks every component
  /// theme and `ColorScheme.fromSeed` runs a full HCT pass. Rebuilding the app
  /// for an unrelated provider change must not repeat that work.
  (ThemeData, ThemeData) _themesFor(
    AppSettings settings,
    Color? seed,
    bool reduceMotion,
  ) {
    final cachedLight = _lightTheme;
    final cachedDark = _darkTheme;
    final reusable =
        cachedLight != null &&
        cachedDark != null &&
        identical(settings, _themeSettings) &&
        seed == _themeSeed &&
        reduceMotion == _themeReduceMotion;
    if (reusable) return (cachedLight, cachedDark);
    final light = buildAppTheme(
      Brightness.light,
      intensity: settings.intensity,
      settings: settings,
      dynamicSeed: seed,
      platformReduceMotion: reduceMotion,
    );
    final dark = buildAppTheme(
      Brightness.dark,
      intensity: settings.intensity,
      settings: settings,
      dynamicSeed: seed,
      platformReduceMotion: reduceMotion,
    );
    _lightTheme = light;
    _darkTheme = dark;
    _themeSettings = settings;
    _themeSeed = seed;
    _themeReduceMotion = reduceMotion;
    return (light, dark);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final seeds = ref.watch(monetSeedsProvider);
    final platformReduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final reduceMotion = settings.shouldReduceMotion(platformReduceMotion);
    final dynamicSeed = settings.monetEnabled ? seeds.asData?.value.seedColor : null;
    final (light, dark) = _themesFor(settings, dynamicSeed, reduceMotion);

    return MaterialApp.router(
      title: 'SuperCalculator - Next Era',
      theme: light,
      darkTheme: dark,
      themeMode: settings.themeMode.themeMode,
      themeAnimationDuration: reduceMotion
          ? Duration.zero
          : settings.motionSpeed == MotionSpeed.lively
          ? const Duration(milliseconds: 380)
          : const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: _router,
      locale: settings.locale.locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        final effectiveScale = (systemScale * settings.effectiveTextScale)
            .clamp(0.8, 2.0)
            .toDouble();
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(effectiveScale),
          ),
          child: LaunchGate(
            reduceMotion: reduceMotion,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
