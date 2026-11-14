import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/settings/app_settings.dart';

const _settingsStorageKey = 'supercalculator.next_era.settings.v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The persisted settings are read before the first frame so the app can open
  // directly on the user's start page and paint with the right palette instead
  // of flashing the defaults. Failure is non-fatal: the async restore in
  // AppSettingsController remains the fallback.
  var initialSettings = AppSettings.defaults;
  try {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_settingsStorageKey);
    if (encoded != null) {
      initialSettings = AppSettings.fromJson(jsonDecode(encoded));
    }
  } catch (_) {
    // Restricted storage (private browsing, locked profile) keeps defaults.
  }

  // Edge-to-edge on Android keeps the expressive surfaces under the system
  // bars; other platforms ignore these calls.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(initialSettings)],
      child: const SuperCalculatorApp(),
    ),
  );
}
