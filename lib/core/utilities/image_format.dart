import 'dart:io';
import 'dart:typed_data';

/// Image formats PIXORA can open locally.
enum ImageFormat {
  jpeg,
  png,
  webp,
  gif,
  unknown;

  bool get isSupported => this != ImageFormat.unknown;
}

/// Detects the real image format from the file signature instead of trusting
/// the file extension, so a renamed or truncated file is rejected politely
/// instead of crashing the preview.
abstract final class ImageFormatDetector {
  /// Number of leading bytes read from disk for detection.
  static const int headerLength = 12;

  static ImageFormat fromBytes(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return ImageFormat.png;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ImageFormat.jpeg;
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return ImageFormat.gif;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return ImageFormat.webp;
    }
    return ImageFormat.unknown;
  }

  /// Reads only the first [headerLength] bytes of [file].
  static Future<ImageFormat> fromFile(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final Uint8List header = await handle.read(headerLength);
      return fromBytes(header);
    } on FileSystemException {
      return ImageFormat.unknown;
    } finally {
      await handle?.close();
    }
  }
}
