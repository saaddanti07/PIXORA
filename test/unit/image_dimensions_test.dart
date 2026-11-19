import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/utilities/byte_format.dart';
import 'package:pixora/core/utilities/image_dimensions_reader.dart';
import 'package:pixora/core/utilities/image_format.dart';

import '../helpers/image_fixtures.dart';

void main() {
  group('ImageFormatDetector', () {
    test('recognises supported formats from their signature', () {
      expect(ImageFormatDetector.fromBytes(pngHeader()), ImageFormat.png);
      expect(ImageFormatDetector.fromBytes(jpegHeader()), ImageFormat.jpeg);
      expect(ImageFormatDetector.fromBytes(webpVp8xHeader()), ImageFormat.webp);
      expect(ImageFormatDetector.fromBytes(gifHeader()), ImageFormat.gif);
    });

    test('rejects data that is not an image', () {
      expect(
        ImageFormatDetector.fromBytes(Uint8List.fromList('hello world!'.codeUnits)),
        ImageFormat.unknown,
      );
      expect(ImageFormat.unknown.isSupported, isFalse);
    });
  });

  group('ImageDimensionsReader', () {
    test('reads PNG dimensions from the IHDR chunk', () {
      final ImageDimensions? dimensions =
          ImageDimensionsReader.parse(pngHeader(width: 1920, height: 1080));

      expect(dimensions, const ImageDimensions(width: 1920, height: 1080));
      expect(dimensions!.pixelCount, 1920 * 1080);
    });

    test('reads JPEG dimensions from the start-of-frame marker', () {
      expect(
        ImageDimensionsReader.parse(jpegHeader(width: 1024, height: 768)),
        const ImageDimensions(width: 1024, height: 768),
      );
    });

    test('reads WebP extended canvas dimensions', () {
      expect(
        ImageDimensionsReader.parse(webpVp8xHeader(width: 640, height: 480)),
        const ImageDimensions(width: 640, height: 480),
      );
    });

    test('reads GIF logical screen dimensions', () {
      expect(
        ImageDimensionsReader.parse(gifHeader(width: 320, height: 240)),
        const ImageDimensions(width: 320, height: 240),
      );
    });

    test('returns null for unknown or truncated data', () {
      expect(ImageDimensionsReader.parse(Uint8List(0)), isNull);
      expect(
        ImageDimensionsReader.parse(Uint8List.fromList(<int>[1, 2, 3])),
        isNull,
      );
      expect(
        ImageDimensionsReader.parse(
          Uint8List.fromList(pngHeader().sublist(0, 20)),
        ),
        isNull,
      );
    });

    test('reads dimensions of a file without decoding the bitmap', () async {
      final Directory directory = createTempDirectory();
      addTearDown(() => directory.deleteSync(recursive: true));
      final File file =
          writeTempFile(directory, 'photo.png', pngHeader(width: 3000, height: 2000));

      final ImageDimensions? dimensions =
          await const ImageDimensionsReader().read(file);

      expect(dimensions, const ImageDimensions(width: 3000, height: 2000));
    });

    test('a missing file yields null instead of throwing', () async {
      final Directory directory = createTempDirectory();
      addTearDown(() => directory.deleteSync(recursive: true));

      final ImageDimensions? dimensions = await const ImageDimensionsReader()
          .read(File('${directory.path}/missing.png'));

      expect(dimensions, isNull);
    });
  });

  group('formatBytes', () {
    test('formats byte counts into readable units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(120 * 1024 * 1024), '120 MB');
    });
  });
}
