import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Persisted appearance settings for the whole application shell.
///
/// These are intentionally limited to display preferences so the record can be
/// serialized to a small JSON map and restored without a schema migration step.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.monetEnabled = false,
    this.intensity = ExpressiveIntensity.excellent,
  });

  /// Whether the theme follows the system, is always light, or always dark.
  final AppThemeMode themeMode;

  /// Whether Material You dynamic color (Monet) should be used when the
  /// platform provides it.
  final bool monetEnabled;

  /// The Material 3 Expressive intensity applied to the design tokens and the
  /// seeded color scheme variant.
  final ExpressiveIntensity intensity;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? monetEnabled,
    ExpressiveIntensity? intensity,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      monetEnabled: monetEnabled ?? this.monetEnabled,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'themeMode': themeMode.name,
    'monetEnabled': monetEnabled,
    'intensity': intensity.name,
  };

  static AppSettings fromJson(Object? source) {
    if (source is! Map) return const AppSettings();
    return AppSettings(
      themeMode: _themeModeFromName(source['themeMode']),
      monetEnabled: source['monetEnabled'] is bool
          ? source['monetEnabled'] as bool
          : false,
      intensity: _intensityFromName(source['intensity']),
    );
  }

  static AppThemeMode _themeModeFromName(Object? value) {
    for (final mode in AppThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return AppThemeMode.system;
  }

  static ExpressiveIntensity _intensityFromName(Object? value) {
    for (final intensity in ExpressiveIntensity.values) {
      if (intensity.name == value) return intensity;
    }
    return ExpressiveIntensity.excellent;
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Riverpod controller that restores and persists [AppSettings].
///
/// Storage is best-effort, mirroring the history repository: Web private mode
/// and restricted desktop profiles may reject writes, in which case the
/// in-memory settings keep working for the current session.
class AppSettingsController extends Notifier<AppSettings> {
  late Future<void> _ready;
  bool _hasLocalChanges = false;

  @override
  AppSettings build() {
    _ready = _restore();
    return const AppSettings();
  }

  void setThemeMode(AppThemeMode mode) {
    if (state.themeMode == mode) return;
    _hasLocalChanges = true;
    state = state.copyWith(themeMode: mode);
    unawaited(_persist());
  }

  void setMonetEnabled(bool enabled) {
    if (state.monetEnabled == enabled) return;
    _hasLocalChanges = true;
    state = state.copyWith(monetEnabled: enabled);
    unawaited(_persist());
  }

  void setIntensity(ExpressiveIntensity intensity) {
    if (state.intensity == intensity) return;
    _hasLocalChanges = true;
    state = state.copyWith(intensity: intensity);
    unawaited(_persist());
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
