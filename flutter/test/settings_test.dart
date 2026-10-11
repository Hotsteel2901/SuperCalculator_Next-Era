import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supercalculator_next_era/app/theme/app_theme.dart';
import 'package:supercalculator_next_era/app/theme/design_tokens.dart';
import 'package:supercalculator_next_era/core/settings/app_settings.dart';
import 'package:supercalculator_next_era/features/settings/about_page.dart';
import 'package:supercalculator_next_era/features/settings/settings_page.dart';
import 'package:supercalculator_next_era/l10n/generated/app_localizations.dart';

const _settingsStorageKey = 'supercalculator.next_era.settings.v1';

Widget _host(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings JSON round-trips every field', () {
    const settings = AppSettings(
      themeMode: AppThemeMode.dark,
      monetEnabled: true,
      intensity: ExpressiveIntensity.transformative,
    );
    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())),
    );
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.monetEnabled, isTrue);
    expect(restored.intensity, ExpressiveIntensity.transformative);
  });

  test('settings fall back to defaults for unknown or corrupt values', () {
    expect(AppSettings.fromJson(null).themeMode, AppThemeMode.system);
    final restored = AppSettings.fromJson(<String, Object?>{
      'themeMode': 'nonsense',
      'monetEnabled': 'yes',
      'intensity': 42,
    });
    expect(restored.themeMode, AppThemeMode.system);
    expect(restored.monetEnabled, isFalse);
    expect(restored.intensity, ExpressiveIntensity.excellent);
  });

  test('settings controller restores persisted values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _settingsStorageKey: jsonEncode(<String, Object>{
        'themeMode': 'dark',
        'monetEnabled': true,
        'intensity': 'foundational',
      }),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider);
    await pumpEventQueue();

    final restored = container.read(appSettingsProvider);
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.monetEnabled, isTrue);
    expect(restored.intensity, ExpressiveIntensity.foundational);
  });

  test('settings controller persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).setMonetEnabled(true);
    container
        .read(appSettingsProvider.notifier)
        .setThemeMode(AppThemeMode.light);
    await pumpEventQueue();

    final preferences = await SharedPreferences.getInstance();
    final decoded = jsonDecode(
      preferences.getString(_settingsStorageKey)!,
    ) as Map<String, dynamic>;
    expect(decoded['monetEnabled'], isTrue);
    expect(decoded['themeMode'], 'light');
  });

  test('expressive intensity changes the shape tokens', () {
    final foundational = buildAppTheme(
      Brightness.light,
      intensity: ExpressiveIntensity.foundational,
    ).extension<SuperCalcDesignTokens>()!;
    final transformative = buildAppTheme(
      Brightness.light,
      intensity: ExpressiveIntensity.transformative,
    ).extension<SuperCalcDesignTokens>()!;
    expect(transformative.cornerLarge, greaterThan(foundational.cornerLarge));
  });

  testWidgets('settings page switches the theme mode', (tester) async {
    await tester.pumpWidget(_host(const SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Expressive intensity'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appSettingsProvider).themeMode, AppThemeMode.dark);
  });

  testWidgets(
    'about page shows the author, both repositories and the license',
    (tester) async {
      await tester.pumpWidget(_host(const AboutPage()));
      await tester.pumpAndSettle();

      expect(find.text('Hotsteel2901 · GitHub'), findsOneWidget);
      expect(find.text('Hotsteel2901 · Codeberg'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Codeberg'), findsOneWidget);
      expect(
        find.textContaining('github.com/Hotsteel2901/SuperCalculator_Next-Era'),
        findsOneWidget,
      );
      expect(
        find.textContaining('codeberg.org/hotsteel/SuperCalculator_Next-Era'),
        findsOneWidget,
      );
      expect(find.textContaining('Affero'), findsOneWidget);
    },
  );
}
