import 'package:flutter/foundation.dart';
import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/utilities/image_format.dart';

/// A photo the user selected from the device and that has been validated
/// locally: it exists, it is a supported format, and it is small enough to
/// preview safely.
///
/// Only the file path is kept — PIXORA never copies, uploads or re-encodes the
/// user's original file during Phase 01.
@immutable
class PickedImage {
  const PickedImage({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.format,
    this.dimensions,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final ImageFormat format;
  final ImageDimensions? dimensions;

  bool get hasDimensions => dimensions != null;

  /// Aspect ratio used to size the preview frame, defaulting to 4:3 when the
  /// header could not be parsed.
  double get aspectRatio => dimensions?.aspectRatio ?? 4 / 3;

  @override
  bool operator ==(Object other) =>
      other is PickedImage &&
      other.path == path &&
      other.fileName == fileName &&
      other.sizeBytes == sizeBytes &&
      other.format == format &&
      other.dimensions == dimensions;

  @override
  int get hashCode => Object.hash(path, fileName, sizeBytes, format, dimensions);

  @override
  String toString() => 'PickedImage($fileName, $sizeBytes bytes)';
}
