import 'package:flutter/material.dart';
import 'package:pixora/app/localization/supported_language.dart';

/// Persisted user preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = SupportedLanguage.english,
  });

  final ThemeMode themeMode;
  final SupportedLanguage language;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({ThemeMode? themeMode, SupportedLanguage? language}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.language == language;

  @override
  int get hashCode => Object.hash(themeMode, language);
}
