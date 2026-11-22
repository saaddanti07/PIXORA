import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('bottom navigation moves between Home, History and Settings',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    expect(_selectedTabIndex(tester), 0);

    await tester.tap(find.byKey(const Key('nav_history')));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 1);
    expect(find.text('No processed photos yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 2);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_home')));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 0);
  });

  testWidgets('home header shortcut opens Settings',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(_selectedTabIndex(tester), 2);
    expect(find.text('Your privacy'), findsOneWidget);
  });

  testWidgets('the open tab survives a process restart', (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_settings')));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 2);

    // Android killing the app in the background and restoring it later.
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_selectedTabIndex(tester), 2);
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('history empty state sends the user back to Home',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.byKey(const Key('nav_history')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create something'));
    await tester.pumpAndSettle();

    expect(_selectedTabIndex(tester), 0);
  });
}

int _selectedTabIndex(WidgetTester tester) {
  final IndexedStack stack = tester.widget<IndexedStack>(
    find.byType(IndexedStack),
  );
  return stack.index ?? 0;
}
