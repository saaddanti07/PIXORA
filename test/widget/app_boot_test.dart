import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('PIXORA starts on Home with branding, hero and navigation',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    expect(find.text('PIXORA'), findsWidgets);
    expect(find.text('Welcome to PIXORA'), findsOneWidget);
    expect(find.text('Restore Your Memories'), findsOneWidget);
    expect(find.text('Choose a Photo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // The tool catalogue is reachable by scrolling and is flagged honestly.
    await tester.scrollUntilVisible(
      find.text('Pixel Art'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pixel Art'), findsOneWidget);
    expect(find.text('Coming soon'), findsWidgets);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('default preferences are English and system theme',
      (WidgetTester tester) async {
    final TestHarness harness = await pumpPixoraApp(tester);

    expect(harness.bootstrap.settingsController.settings, AppSettings.defaults);
    expect(
      harness.bootstrap.settingsController.language,
      SupportedLanguage.english,
    );
    expect(harness.bootstrap.settingsController.themeMode, ThemeMode.system);
  });

  testWidgets('the engine registry ships with no processors (no fake AI)',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    // Tapping a tool opens an honest explanation, never a processing screen.
    await tester.scrollUntilVisible(
      find.text('AI Photo Enhancement'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Photo Enhancement'));
    await tester.pumpAndSettle();

    expect(find.text('In development'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('In development'), findsNothing);
  });
}
