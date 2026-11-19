import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/core/storage/preferences_keys.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('switching to French applies immediately and is persisted',
      (WidgetTester tester) async {
    final TestHarness harness = await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(harness.bootstrap.settingsController.language,
        SupportedLanguage.french);
    expect(harness.store.read(PreferencesKeys.language), 'fr');
    expect(find.text('Réglages'), findsWidgets);
    expect(find.text('Restaurez vos souvenirs'), findsOneWidget);
  });

  testWidgets('switching to Arabic produces a right-to-left interface',
      (WidgetTester tester) async {
    final TestHarness harness = await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(harness.bootstrap.settingsController.language,
        SupportedLanguage.arabic);
    expect(harness.store.read(PreferencesKeys.language), 'ar');

    final BuildContext context = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(context), TextDirection.rtl);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));

    expect(find.text('الإعدادات'), findsWidgets);
    expect(find.text('أعِد ذكرياتك إلى الحياة'), findsOneWidget);
  });

  testWidgets('switching back to English restores left-to-right layout',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.ltr,
    );
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('a saved language is restored on start',
      (WidgetTester tester) async {
    await pumpPixoraApp(
      tester,
      storedValues: <String, String>{PreferencesKeys.language: 'fr'},
    );

    expect(find.text('Bienvenue dans PIXORA'), findsOneWidget);
    expect(find.text('Choisir une photo'), findsOneWidget);
  });
}
