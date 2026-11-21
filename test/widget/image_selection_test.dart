import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/image_picker/screens/image_preview_screen.dart';
import 'package:pixora/features/image_picker/widgets/photo_preview_frame.dart';

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

/// Regression tests for the device-reported selection problems:
///   * the picked photo never reached the preview;
///   * replacing a photo showed the previous picture again;
///   * a pick lost to an activity destruction was never delivered.
///
/// They assert on the *actual image provider* used by the preview, so a cached
/// or stale bitmap cannot pass as success.

/// Lets a pick run to completion.
///
/// The picker validates the photo with real, asynchronous file I/O
/// (`exists` → `length` → signature → header), so the fake test clock cannot
/// drive it on its own: each real I/O call has to finish in real time before
/// the next `await` in the chain can even start. Alternating real time with
/// frames walks the whole chain, then the route transition is fast-forwarded.
Future<void> _settlePick(WidgetTester tester) async {
  for (int round = 0; round < 16; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

/// The file the preview is really displaying.
FileImage _previewedFile(WidgetTester tester) {
  final Image image = tester.widget<Image>(find.byType(Image));
  final ImageProvider<Object> provider = image.image;
  if (provider is ResizeImage) {
    return provider.imageProvider as FileImage;
  }
  return provider as FileImage;
}

void main() {
  late Directory directory;

  setUp(() {
    directory = createTempDirectory();
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  testWidgets('a selected photo really opens in the preview',
      (WidgetTester tester) async {
    final File photo = writeTempFile(
      directory,
      'beach.png',
      pngHeader(width: 800, height: 600),
    );
    await pumpPixoraApp(
      tester,
      picker: FakeImagePickerService(path: photo.path),
    );

    await tester.tap(find.text('Choose a Photo'));
    await _settlePick(tester);

    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('beach.png'), findsOneWidget);
    expect(find.text('800 × 600'), findsOneWidget);
    expect(_previewedFile(tester).file.path, photo.path);
  });

  testWidgets('choosing another photo replaces the previewed bitmap',
      (WidgetTester tester) async {
    final File first = writeTempFile(
      directory,
      'beach.png',
      pngHeader(width: 800, height: 600),
    );
    final File second = writeTempFile(
      directory,
      'mountain.png',
      pngHeader(width: 1200, height: 1600),
    );

    int picks = 0;
    await pumpPixoraApp(
      tester,
      picker: FakeImagePickerService(
        onPick: () {
          picks++;
          return picks == 1 ? first.path : second.path;
        },
      ),
    );

    await tester.tap(find.text('Choose a Photo'));
    await _settlePick(tester);
    expect(_previewedFile(tester).file.path, first.path);

    await tester.tap(find.text('Choose another photo'));
    await _settlePick(tester);

    expect(find.text('mountain.png'), findsOneWidget);
    expect(find.text('1200 × 1600'), findsOneWidget);
    expect(find.text('beach.png'), findsNothing);

    // The preview is showing the new file, not a cached frame of the old one.
    expect(_previewedFile(tester).file.path, second.path);
    expect(
      find.byKey(ValueKey<String>(second.path)),
      findsOneWidget,
      reason: 'the frame must be rebuilt for the new photo',
    );
    // And it never falls back to the previous bitmap while decoding.
    expect(tester.widget<Image>(find.byType(Image)).gaplessPlayback, isFalse);
  });

  testWidgets('cancelling the second pick keeps the first photo',
      (WidgetTester tester) async {
    final File first = writeTempFile(
      directory,
      'beach.png',
      pngHeader(width: 800, height: 600),
    );

    int picks = 0;
    await pumpPixoraApp(
      tester,
      picker: FakeImagePickerService(
        onPick: () {
          picks++;
          return picks == 1 ? first.path : null;
        },
      ),
    );

    await tester.tap(find.text('Choose a Photo'));
    await _settlePick(tester);
    expect(_previewedFile(tester).file.path, first.path);

    await tester.tap(find.text('Choose another photo'));
    await _settlePick(tester);

    expect(find.text('beach.png'), findsOneWidget);
    expect(_previewedFile(tester).file.path, first.path);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('cancelling the first pick leaves the user on Home',
      (WidgetTester tester) async {
    await pumpPixoraApp(tester);

    await tester.tap(find.text('Choose a Photo'));
    await _settlePick(tester);

    expect(find.byType(ImagePreviewScreen), findsNothing);
    expect(find.text('Restore Your Memories'), findsOneWidget);
  });

  testWidgets('a photo kept by Android after an activity kill is delivered',
      (WidgetTester tester) async {
    final File recovered = writeTempFile(
      directory,
      'recovered.png',
      pngHeader(width: 1024, height: 768),
    );

    final FakeImagePickerService picker =
        FakeImagePickerService(lostPath: recovered.path);
    await pumpPixoraApp(tester, picker: picker);
    await _settlePick(tester);
    await _settlePick(tester);

    expect(picker.lostCallCount, greaterThan(0));
    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    expect(find.text('recovered.png'), findsOneWidget);
    expect(_previewedFile(tester).file.path, recovered.path);
  });

  testWidgets('an unusable recovered photo does not block the app',
      (WidgetTester tester) async {
    final FakeImagePickerService picker = FakeImagePickerService(
      lostPath: '${directory.path}/deleted.png',
    );
    await pumpPixoraApp(tester, picker: picker);
    await _settlePick(tester);
    await _settlePick(tester);

    expect(find.byType(ImagePreviewScreen), findsNothing);
    expect(find.text('Restore Your Memories'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the preview keeps the language and the direction',
      (WidgetTester tester) async {
    final File photo = writeTempFile(
      directory,
      'beach.png',
      pngHeader(width: 800, height: 600),
    );
    final TestHarness harness = await pumpPixoraApp(
      tester,
      picker: FakeImagePickerService(path: photo.path),
      storedValues: <String, String>{PreferencesKeys.language: 'ar'},
    );

    await tester.tap(find.text('اختر صورة'));
    await _settlePick(tester);

    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    expect(find.text('معاينة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(PhotoPreviewFrame))),
      TextDirection.rtl,
    );
    expect(harness.bootstrap.settingsController.language.code, 'ar');
  });
}
