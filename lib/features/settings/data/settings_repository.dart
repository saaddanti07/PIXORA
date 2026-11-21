import 'package:flutter/material.dart' show ThemeMode;
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/core/storage/key_value_store.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// Reads and writes [AppSettings] through the local [KeyValueStore].
class SettingsRepository {
  SettingsRepository(this._store);

  final KeyValueStore _store;

  AppSettings load() {
    return AppSettings(
      themeMode: _themeModeFromName(_store.read(PreferencesKeys.themeMode)),
      language: SupportedLanguage.fromCode(_store.read(PreferencesKeys.language)),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _store.write(PreferencesKeys.themeMode, settings.themeMode.name);
    await _store.write(PreferencesKeys.language, settings.language.code);
  }

  static ThemeMode _themeModeFromName(String? name) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return ThemeMode.system;
  }
}
