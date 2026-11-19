import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/theme/app_colors.dart';
import 'package:pixora/core/storage/preferences_keys.dart';

import '../helpers/test_harness.dart';

/// Regression tests for the settings that a real device reported as "changing
/// them does nothing".
///
/// They differ from the original tests in three ways, because those three gaps
/// are exactly what let the bug through:
///   * the language is switched in **every** language and asserted on **every**
///     tab, not just on the Settings screen;
///   * the theme is asserted through the rendered colours of the shell, not
///     only through the `MaterialApp.themeMode` field;
///   * a "restart" is simulated by building a second app over the same stored
///     preferences, instead of trusting the controller in memory.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav_settings')));
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _tapOption(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

BuildContext _shellContext(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar));

void main() {
  group('language switching', () {
    testWidgets('French is applied to every tab, not just Settings',
        (WidgetTester tester) async {
      final TestHarness harness = await pumpPixoraApp(tester);
      await _openSettings(tester);

      await _tapOption(tester, 'language_option_fr');

      // Settings itself.
      expect(find.text('Réglages'), findsWidgets);
      expect(find.text('Apparence'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);

      // The navigation bar, which lives outside the Settings screen.
      expect(find.text('Accueil'), findsWidgets);
      expect(find.text('Historique'), findsWidgets);

      // Home.
      await _tapTab(tester, 'nav_home');
      expect(find.text('Restaurez vos souvenirs'), findsOneWidget);
      expect(find.text('Choisir une photo'), findsOneWidget);

      // History.
      await _tapTab(tester, 'nav_history');
      expect(find.text('Aucune photo traitée'), findsOneWidget);
      expect(find.text('Créer quelque chose'), findsOneWidget);

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('fr'));
      expect(Directionality.of(_shellContext(tester)), TextDirection.ltr);
      expect(harness.store.read(PreferencesKeys.language), 'fr');
    });

    testWidgets('Arabic is applied to every tab and flips the layout to RTL',
        (WidgetTester tester) async {
      final TestHarness harness = await pumpPixoraApp(tester);
      await _openSettings(tester);

      await _tapOption(tester, 'language_option_ar');

      expect(find.text('الإعدادات'), findsWidgets);
      expect(find.text('المظهر'), findsOneWidget);
      expect(Directionality.of(_shellContext(tester)), TextDirection.rtl);

      await _tapTab(tester, 'nav_home');
      expect(find.text('أعِد ذكرياتك إلى الحياة'), findsOneWidget);
      expect(find.text('اختر صورة'), findsOneWidget);
      // RTL survives the tab change and reaches the screen content.
      expect(
        Directionality.of(tester.element(find.text('اختر صورة'))),
        TextDirection.rtl,
      );

      await _tapTab(tester, 'nav_history');
      expect(find.text('لا توجد صور معالجة بعد'), findsOneWidget);

      expect(harness.store.read(PreferencesKeys.language), 'ar');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('ar'),
      );
    });

    testWidgets('English, Arabic and French can be cycled in place',
        (WidgetTester tester) async {
      await pumpPixoraApp(tester);
      await _openSettings(tester);

      await _tapOption(tester, 'language_option_ar');
      expect(find.text('الإعدادات'), findsWidgets);
      expect(Directionality.of(_shellContext(tester)), TextDirection.rtl);

      await _tapOption(tester, 'language_option_fr');
      expect(find.text('Réglages'), findsWidgets);
      expect(Directionality.of(_shellContext(tester)), TextDirection.ltr);

      await _tapOption(tester, 'language_option_en');
      expect(find.text('Settings'), findsWidgets);
      expect(Directionality.of(_shellContext(tester)), TextDirection.ltr);

      // Nothing was lost on the way back: Home is English again.
      await _tapTab(tester, 'nav_home');
      expect(find.text('Restore Your Memories'), findsOneWidget);
    });

    testWidgets('the chosen language survives a restart',
        (WidgetTester tester) async {
      final TestHarness harness = await pumpPixoraApp(tester);
      await _openSettings(tester);
      await _tapOption(tester, 'language_option_ar');

      // A restart: the widget tree is thrown away and rebuilt from storage.
      final Map<String, String> persisted = harness.store.values;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpPixoraApp(tester, storedValues: persisted);

      expect(find.text('أعِد ذكرياتك إلى الحياة'), findsOneWidget);
      expect(Directionality.of(_shellContext(tester)), TextDirection.rtl);
    });
  });

  group('theme switching', () {
    testWidgets('Dark repaints the whole app with dark colours',
        (WidgetTester tester) async {
      final TestHarness harness = await pumpPixoraApp(tester);
      await _openSettings(tester);

      await _tapOption(tester, 'theme_option_dark');

      final ThemeData settingsTheme = Theme.of(_shellContext(tester));
      expect(settingsTheme.brightness, Brightness.dark);
      expect(settingsTheme.scaffoldBackgroundColor, AppColors.darkBackground);

      await _tapTab(tester, 'nav_home');
      final ThemeData homeTheme = Theme.of(tester.element(find.text('PIXORA').first));
      expect(homeTheme.brightness, Brightness.dark);
      expect(homeTheme.scaffoldBackgroundColor, AppColors.darkBackground);
      // Cards follow the palette, not a hardcoded colour.
      expect(homeTheme.colorScheme.surface, AppColors.darkSurface);

      expect(harness.store.read(PreferencesKeys.themeMode), 'dark');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('Light overrides a device that is in dark mode',
        (WidgetTester tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpPixoraApp(tester);
      await _openSettings(tester);

      // System follows the platform while it is the selected mode.
      expect(Theme.of(_shellContext(tester)).brightness, Brightness.dark);

      await _tapOption(tester, 'theme_option_light');

      final ThemeData theme = Theme.of(_shellContext(tester));
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);

      await _tapTab(tester, 'nav_home');
      expect(
        Theme.of(tester.element(find.text('PIXORA').first)).brightness,
        Brightness.light,
      );
    });

    testWidgets('System follows the device when it changes and returns to Dark',
        (WidgetTester tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpPixoraApp(tester);
      await _openSettings(tester);

      await _tapOption(tester, 'theme_option_system');
      expect(Theme.of(_shellContext(tester)).brightness, Brightness.light);

      // MIUI switches the whole phone to dark in the evening.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(Theme.of(_shellContext(tester)).brightness, Brightness.dark);

      await _tapOption(tester, 'theme_option_dark');
      await _tapTab(tester, 'nav_home');
      expect(
        Theme.of(tester.element(find.text('PIXORA').first)).brightness,
        Brightness.dark,
      );
    });

    testWidgets('the chosen theme survives a restart',
        (WidgetTester tester) async {
      final TestHarness harness = await pumpPixoraApp(tester);
      await _openSettings(tester);
      await _tapOption(tester, 'theme_option_dark');

      final Map<String, String> persisted = harness.store.values;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpPixoraApp(tester, storedValues: persisted);

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.text('PIXORA').first)).brightness,
        Brightness.dark,
      );
    });
  });

  testWidgets('language and theme are remembered independently',
      (WidgetTester tester) async {
    final TestHarness harness = await pumpPixoraApp(tester);
    await _openSettings(tester);

    await _tapOption(tester, 'theme_option_dark');
    await _tapOption(tester, 'language_option_fr');

    final Map<String, String> persisted = harness.store.values;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpPixoraApp(tester, storedValues: persisted);

    expect(find.text('Restaurez vos souvenirs'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('PIXORA').first)).brightness,
      Brightness.dark,
    );
  });
}
