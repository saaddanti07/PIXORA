import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/core/utilities/image_format.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = createTempDirectory();
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  ImageSelectionController controllerFor(
    ImagePickerService picker, {
    int? maxBytes,
    int? maxPixels,
  }) {
    return ImageSelectionController(
      picker: picker,
      maxBytes: maxBytes ?? 40 * 1024 * 1024,
      maxPixels: maxPixels ?? 48 * 1000 * 1000,
    );
  }

  test('a cancelled pick returns null', () async {
    final ImageSelectionController controller =
        controllerFor(FakeImagePickerService());

    expect(await controller.pickImage(), isNull);
  });

  test('a picked photo is validated and described locally', () async {
    final File file = writeTempFile(
      directory,
      'holiday.png',
      pngHeader(width: 1200, height: 900),
    );
    final ImageSelectionController controller = controllerFor(
      FakeImagePickerService(path: file.path),
    );

    final PickedImage? image = await controller.pickImage();

    expect(image, isNotNull);
    expect(image!.fileName, 'holiday.png');
    expect(image.format, ImageFormat.png);
    expect(image.dimensions!.width, 1200);
    expect(image.dimensions!.height, 900);
    expect(image.sizeBytes, file.lengthSync());
  });

  test('a non image file is rejected as unsupported', () async {
    final File file = writeTempFile(directory, 'notes.png', 'not an image'.codeUnits);
    final ImageSelectionController controller =
        controllerFor(FakeImagePickerService(path: file.path));

    await expectLater(
      controller.pickImage(),
      throwsA(
        isA<ImageSelectionException>().having(
          (ImageSelectionException error) => error.kind,
          'kind',
          ImageSelectionErrorKind.unsupportedFormat,
        ),
      ),
    );
  });

  test('an oversized file is rejected before it is decoded', () async {
    final File file = writeTempFile(
      directory,
      'huge.jpg',
      List<int>.filled(4096, 0x41)..setAll(0, jpegHeader()),
    );
    final ImageSelectionController controller =
        controllerFor(FakeImagePickerService(path: file.path), maxBytes: 1024);

    await expectLater(
      controller.pickImage(),
      throwsA(
        isA<ImageSelectionException>().having(
          (ImageSelectionException error) => error.kind,
          'kind',
          ImageSelectionErrorKind.imageTooLarge,
        ),
      ),
    );
  });

  test('an image with too many pixels is rejected', () async {
    final File file = writeTempFile(
      directory,
      'poster.png',
      pngHeader(width: 9000, height: 9000),
    );
    final ImageSelectionController controller = controllerFor(
      FakeImagePickerService(path: file.path),
      maxPixels: 10 * 1000 * 1000,
    );

    await expectLater(
      controller.pickImage(),
      throwsA(
        isA<ImageSelectionException>().having(
          (ImageSelectionException error) => error.kind,
          'kind',
          ImageSelectionErrorKind.imageTooLarge,
        ),
      ),
    );
  });

  test('a missing file is reported as unreadable', () async {
    final ImageSelectionController controller = controllerFor(
      FakeImagePickerService(path: '${directory.path}/gone.png'),
    );

    await expectLater(
      controller.pickImage(),
      throwsA(
        isA<ImageSelectionException>().having(
          (ImageSelectionException error) => error.kind,
          'kind',
          ImageSelectionErrorKind.fileUnreadable,
        ),
      ),
    );
  });

  test('picker failures are mapped to UI actionable kinds', () async {
    Future<ImageSelectionErrorKind> kindFor(ImagePickerFailure failure) async {
      final ImageSelectionController controller = controllerFor(
        FakeImagePickerService(failure: failure),
      );
      try {
        await controller.pickImage();
      } on ImageSelectionException catch (error) {
        return error.kind;
      }
      fail('expected an ImageSelectionException');
    }

    expect(
      await kindFor(ImagePickerFailure.permissionDenied),
      ImageSelectionErrorKind.permissionDenied,
    );
    expect(
      await kindFor(ImagePickerFailure.unavailable),
      ImageSelectionErrorKind.pickerUnavailable,
    );
    expect(
      await kindFor(ImagePickerFailure.unsupportedFormat),
      ImageSelectionErrorKind.unsupportedFormat,
    );
    expect(
      await kindFor(ImagePickerFailure.unknown),
      ImageSelectionErrorKind.unknown,
    );
  });
}
