import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/core/storage/in_memory_key_value_store.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/settings/data/settings_repository.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

void main() {
  test('an empty store yields the documented defaults', () {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final AppSettings settings = SettingsRepository(store).load();

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.language, SupportedLanguage.english);
    expect(settings, AppSettings.defaults);
  });

  test('unknown stored values fall back instead of crashing', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(
      initialValues: <String, String>{
        PreferencesKeys.themeMode: 'neon',
        PreferencesKeys.language: 'xx',
      },
    );
    final AppSettings settings = SettingsRepository(store).load();

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.language, SupportedLanguage.english);
  });

  test('theme and language survive an app restart', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final SettingsRepository repository = SettingsRepository(store);
    final SettingsController controller = SettingsController(
      repository: repository,
      initialSettings: repository.load(),
    );

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setLanguage(SupportedLanguage.arabic);

    // A restart means a brand new repository + controller over the same store.
    final SettingsRepository restartedRepository = SettingsRepository(store);
    final SettingsController restarted = SettingsController(
      repository: restartedRepository,
      initialSettings: restartedRepository.load(),
    );

    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.language, SupportedLanguage.arabic);
    expect(restarted.locale.languageCode, 'ar');
    expect(store.read(PreferencesKeys.themeMode), 'dark');
    expect(store.read(PreferencesKeys.language), 'ar');
  });

  test('the controller notifies listeners only when a value changes', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final SettingsRepository repository = SettingsRepository(store);
    final SettingsController controller = SettingsController(
      repository: repository,
      initialSettings: repository.load(),
    );

    int notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.light);
    await controller.setThemeMode(ThemeMode.light);
    await controller.setLanguage(SupportedLanguage.french);
    await controller.setLanguage(SupportedLanguage.french);

    expect(notifications, 2);
  });

  test('every supported language maps to a locale and direction', () {
    expect(SupportedLanguage.values.length, 3);
    expect(SupportedLanguage.english.locale, const Locale('en'));
    expect(SupportedLanguage.arabic.locale, const Locale('ar'));
    expect(SupportedLanguage.french.locale, const Locale('fr'));
    expect(SupportedLanguage.arabic.isRtl, isTrue);
    expect(SupportedLanguage.french.isRtl, isFalse);
    expect(SupportedLanguage.fromCode('fr'), SupportedLanguage.french);
    expect(SupportedLanguage.fromCode(null), SupportedLanguage.english);
  });
}
