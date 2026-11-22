import 'dart:io';
import 'dart:typed_data';

import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/utilities/image_format.dart';

/// Reads image dimensions straight from the file header.
///
/// Decoding the header instead of the bitmap matters on low-RAM phones: a
/// 12 MP photo would otherwise allocate ~48 MB just to learn its size. Only
/// the first [scanBytes] of the file are ever read.
class ImageDimensionsReader {
  const ImageDimensionsReader({this.scanBytes = 64 * 1024});

  /// Maximum number of bytes read from the beginning of the file.
  final int scanBytes;

  /// Returns the dimensions of [file], or `null` if they cannot be read.
  Future<ImageDimensions?> read(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final Uint8List bytes = await handle.read(scanBytes);
      return parse(bytes);
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  /// Parses dimensions from the leading bytes of a supported image file.
  static ImageDimensions? parse(Uint8List bytes) {
    if (bytes.length < 12) {
      return null;
    }
    switch (ImageFormatDetector.fromBytes(bytes)) {
      case ImageFormat.png:
        if (bytes.length < 24) {
          return null;
        }
        return ImageDimensions(
          width: _uint32BigEndian(bytes, 16),
          height: _uint32BigEndian(bytes, 20),
        );
      case ImageFormat.gif:
        if (bytes.length < 10) {
          return null;
        }
        return ImageDimensions(
          width: bytes[6] | (bytes[7] << 8),
          height: bytes[8] | (bytes[9] << 8),
        );
      case ImageFormat.jpeg:
        return _parseJpeg(bytes);
      case ImageFormat.webp:
        return _parseWebp(bytes);
      case ImageFormat.unknown:
        return null;
    }
  }

  static ImageDimensions? _parseJpeg(Uint8List bytes) {
    int offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }
      final int marker = bytes[offset + 1];
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }
      final int length = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (length < 2) {
        return null;
      }
      final bool isStartOfFrame = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isStartOfFrame) {
        if (offset + 9 > bytes.length) {
          return null;
        }
        return ImageDimensions(
          width: (bytes[offset + 7] << 8) | bytes[offset + 8],
          height: (bytes[offset + 5] << 8) | bytes[offset + 6],
        );
      }
      offset += 2 + length;
    }
    return null;
  }

  static ImageDimensions? _parseWebp(Uint8List bytes) {
    if (bytes.length < 30) {
      return null;
    }
    final String chunk = String.fromCharCodes(bytes.sublist(12, 16));
    switch (chunk) {
      case 'VP8X':
        return ImageDimensions(
          width: 1 + _uint24LittleEndian(bytes, 24),
          height: 1 + _uint24LittleEndian(bytes, 27),
        );
      case 'VP8 ':
        if (bytes[23] != 0x9D || bytes[24] != 0x01 || bytes[25] != 0x2A) {
          return null;
        }
        return ImageDimensions(
          width: (bytes[26] | (bytes[27] << 8)) & 0x3FFF,
          height: (bytes[28] | (bytes[29] << 8)) & 0x3FFF,
        );
      case 'VP8L':
        if (bytes[20] != 0x2F) {
          return null;
        }
        final int bits = bytes[21] |
            (bytes[22] << 8) |
            (bytes[23] << 16) |
            (bytes[24] << 24);
        return ImageDimensions(
          width: (bits & 0x3FFF) + 1,
          height: ((bits >> 14) & 0x3FFF) + 1,
        );
      default:
        return null;
    }
  }

  static int _uint32BigEndian(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static int _uint24LittleEndian(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
}
