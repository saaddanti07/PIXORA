import 'package:flutter/material.dart';
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/features/settings/data/settings_repository.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// Owns the user's theme and language choices.
///
/// Changes are applied immediately (the app rebuilds) and then persisted, so a
/// selection is never lost even if the process is killed right after a tap.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    required AppSettings initialSettings,
  })  : _repository = repository,
        _settings = initialSettings;

  final SettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  ThemeMode get themeMode => _settings.themeMode;

  SupportedLanguage get language => _settings.language;

  Locale get locale => _settings.language.locale;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _settings.themeMode) {
      return;
    }
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _repository.save(_settings);
  }

  Future<void> setLanguage(SupportedLanguage language) async {
    if (language == _settings.language) {
      return;
    }
    _settings = _settings.copyWith(language: language);
    notifyListeners();
    await _repository.save(_settings);
  }
}
