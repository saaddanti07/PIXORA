import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/core/services/image_picker_service.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('a denied photo permission is explained to the user',
      (WidgetTester tester) async {
    await pumpPixoraApp(
      tester,
      picker: FakeImagePickerService(
        failure: ImagePickerFailure.permissionDenied,
      ),
    );

    await tester.tap(find.text('Choose a Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('needs access to your photos'), findsOneWidget);
    // The hero card returns to its idle state.
    expect(find.text('Choose a Photo'), findsOneWidget);
  });

  testWidgets('cancelling the picker leaves the user on Home',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.text('Choose a Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Restore Your Memories'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
