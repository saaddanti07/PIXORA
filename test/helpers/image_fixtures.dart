import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A real, decodable 1x1 PNG, used when a widget test needs an actual image.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/'
  'q842iQAAAABJRU5ErkJggg==',
);

/// Minimal PNG header (signature + IHDR) carrying the requested dimensions.
Uint8List pngHeader({int width = 800, int height = 600}) {
  final BytesBuilder builder = BytesBuilder();
  builder.add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  builder.add(<int>[0x00, 0x00, 0x00, 0x0D]);
  builder.add('IHDR'.codeUnits);
  builder.add(<int>[
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
  ]);
  builder.add(<int>[0x08, 0x06, 0x00, 0x00, 0x00]);
  return builder.toBytes();
}

/// Minimal JPEG header: SOI, an APP0 segment, then a baseline SOF0 segment.
Uint8List jpegHeader({int width = 1024, int height = 768}) {
  final BytesBuilder builder = BytesBuilder();
  builder.add(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  builder.add(List<int>.filled(14, 0));
  builder.add(<int>[0xFF, 0xC0, 0x00, 0x11, 0x08]);
  builder.add(<int>[(height >> 8) & 0xFF, height & 0xFF]);
  builder.add(<int>[(width >> 8) & 0xFF, width & 0xFF]);
  builder.add(List<int>.filled(10, 0));
  return builder.toBytes();
}

/// Minimal WebP (VP8X extended) header carrying an explicit canvas size.
Uint8List webpVp8xHeader({int width = 640, int height = 480}) {
  final BytesBuilder builder = BytesBuilder();
  builder.add('RIFF'.codeUnits);
  builder.add(<int>[0x00, 0x00, 0x00, 0x00]);
  builder.add('WEBP'.codeUnits);
  builder.add('VP8X'.codeUnits);
  builder.add(<int>[0x0A, 0x00, 0x00, 0x00]);
  builder.add(<int>[0x00, 0x00, 0x00, 0x00]);
  final int canvasWidth = width - 1;
  final int canvasHeight = height - 1;
  builder.add(<int>[
    canvasWidth & 0xFF,
    (canvasWidth >> 8) & 0xFF,
    (canvasWidth >> 16) & 0xFF,
    canvasHeight & 0xFF,
    (canvasHeight >> 8) & 0xFF,
    (canvasHeight >> 16) & 0xFF,
  ]);
  return builder.toBytes();
}

/// Minimal GIF header carrying the logical screen size.
Uint8List gifHeader({int width = 320, int height = 240}) {
  final BytesBuilder builder = BytesBuilder();
  builder.add('GIF89a'.codeUnits);
  builder.add(<int>[width & 0xFF, (width >> 8) & 0xFF]);
  builder.add(<int>[height & 0xFF, (height >> 8) & 0xFF]);
  builder.add(<int>[0x00, 0x00, 0x00]);
  return builder.toBytes();
}

/// Creates an isolated directory for a test.
Directory createTempDirectory() =>
    Directory.systemTemp.createTempSync('pixora_test_');

/// Writes [bytes] into [directory] under [name].
File writeTempFile(Directory directory, String name, List<int> bytes) {
  final File file = File('${directory.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(bytes);
  return file;
}
