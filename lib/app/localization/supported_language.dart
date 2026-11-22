import 'package:flutter/widgets.dart';

/// The three languages PIXORA ships in Phase 01.
///
/// [nativeName] is deliberately not translated: language pickers always show
/// each language in its own script so users can recognise it immediately.
enum SupportedLanguage {
  english(code: 'en', nativeName: 'English', locale: Locale('en'), isRtl: false),
  arabic(code: 'ar', nativeName: 'العربية', locale: Locale('ar'), isRtl: true),
  french(code: 'fr', nativeName: 'Français', locale: Locale('fr'), isRtl: false);

  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.locale,
    required this.isRtl,
  });

  final String code;
  final String nativeName;
  final Locale locale;
  final bool isRtl;

  /// Resolves a stored language code, defaulting to English.
  static SupportedLanguage fromCode(String? code) {
    for (final SupportedLanguage language in values) {
      if (language.code == code) {
        return language;
      }
    }
    return english;
  }

  static SupportedLanguage fromLocale(Locale locale) =>
      fromCode(locale.languageCode);
}
