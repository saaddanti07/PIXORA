import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/theme/app_theme.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/storage/preferences_keys.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('choosing Dark applies and persists the dark theme',
      (WidgetTester tester) async {
    final TestHarness harness = await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(harness.bootstrap.settingsController.themeMode, ThemeMode.dark);
    expect(harness.store.read(PreferencesKeys.themeMode), 'dark');

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final BuildContext context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('choosing Light overrides the platform brightness',
      (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpPixoraApp(tester);
    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('a saved dark theme is restored on start',
      (WidgetTester tester) async {
    await pumpPixoraApp(
      tester,
      storedValues: <String, String>{PreferencesKeys.themeMode: 'dark'},
    );

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final BuildContext context = tester.element(find.text('Restore Your Memories'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  test('both themes expose the PIXORA palette extension', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().extension<PixoraPalette>(), isNotNull);
    expect(AppTheme.dark().extension<PixoraPalette>(), isNotNull);
    expect(AppTheme.light().colorScheme.primary, isNot(AppTheme.dark().colorScheme.primary));
  });
}
