import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/supported_language.dart';

import '../helpers/test_harness.dart';

/// The Redmi 9 renders at roughly 360 x 780 dp. Every screen is exercised at
/// that size in all three languages, including right-to-left Arabic, so layout
/// overflows surface here instead of on the device.
void _useRedmi9Viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _scrollThrough(WidgetTester tester, Finder scrollView) async {
  await tester.drag(scrollView, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.drag(scrollView, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.drag(scrollView, const Offset(0, 400));
  await tester.drag(scrollView, const Offset(0, 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all tabs render on a 360 dp phone in every language',
      (WidgetTester tester) async {
    _useRedmi9Viewport(tester);

    final TestHarness harness = await pumpPixoraApp(tester, useTallScreen: false);

    for (final SupportedLanguage language in SupportedLanguage.values) {
      await harness.bootstrap.settingsController.setLanguage(language);
      await tester.pumpAndSettle();

      // Home
      await tester.tap(find.byKey(const Key('nav_home')));
      await tester.pumpAndSettle();
      await _scrollThrough(tester, find.byType(Scrollable).last);

      // History
      await tester.tap(find.byKey(const Key('nav_history')));
      await tester.pumpAndSettle();

      // Settings (scrolls through appearance, language, privacy, about)
      await tester.tap(find.byKey(const Key('nav_settings')));
      await tester.pumpAndSettle();
      await _scrollThrough(tester, find.byType(Scrollable).last);

      expect(tester.takeException(), isNull);
    }
  });
}
