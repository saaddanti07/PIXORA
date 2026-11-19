import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_theme.dart';
import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/utilities/image_format.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/screens/image_preview_screen.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';

import '../helpers/image_fixtures.dart';

PickedImage _image({
  String fileName = 'beach.png',
  int width = 800,
  int height = 600,
}) {
  final Directory directory = createTempDirectory();
  final File file = writeTempFile(directory, fileName, tinyPng);
  return PickedImage(
    path: file.path,
    fileName: fileName,
    sizeBytes: 2048,
    format: ImageFormat.png,
    dimensions: ImageDimensions(width: width, height: height),
  );
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required PickedImage image,
  required Future<PickedImage?> Function() onPickAnother,
}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ImagePreviewScreen(image: image, onPickAnother: onPickAnother),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('preview shows real, local photo details', (WidgetTester tester) async {
    await _pumpPreview(
      tester,
      image: _image(),
      onPickAnother: () async => null,
    );

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('beach.png'), findsOneWidget);
    expect(find.text('800 × 600'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('Stored only on this device'), findsOneWidget);
    expect(find.textContaining('upcoming update'), findsOneWidget);
    expect(find.text('Choose another photo'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });

  testWidgets('choosing another photo updates the preview',
      (WidgetTester tester) async {
    await _pumpPreview(
      tester,
      image: _image(),
      onPickAnother: () async => _image(
        fileName: 'mountain.jpg',
        width: 1200,
        height: 1600,
      ),
    );

    await tester.tap(find.text('Choose another photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('mountain.jpg'), findsOneWidget);
    expect(find.text('1200 × 1600'), findsOneWidget);
    expect(find.text('beach.png'), findsNothing);
  });

  testWidgets('a cancelled re-pick keeps the current photo',
      (WidgetTester tester) async {
    await _pumpPreview(
      tester,
      image: _image(),
      onPickAnother: () async => null,
    );

    await tester.tap(find.text('Choose another photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('beach.png'), findsOneWidget);
  });

  testWidgets('picker errors are reported as a localized message',
      (WidgetTester tester) async {
    await _pumpPreview(
      tester,
      image: _image(),
      onPickAnother: () async => throw const ImageSelectionException(
        ImageSelectionErrorKind.permissionDenied,
      ),
    );

    await tester.tap(find.text('Choose another photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('needs access to your photos'), findsOneWidget);
  });

  testWidgets('the close action returns to the previous screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => ImagePreviewScreen(
                      image: _image(),
                      onPickAnother: () async => null,
                    ),
                  ),
                ),
                child: const Text('open preview'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open preview'));
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsNothing);
    expect(find.text('open preview'), findsOneWidget);
  });
}
