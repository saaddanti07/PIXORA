import 'package:flutter/foundation.dart';

/// Pixel dimensions of an image.
@immutable
class ImageDimensions {
  const ImageDimensions({required this.width, required this.height});

  final int width;
  final int height;

  int get pixelCount => width * height;

  double get aspectRatio => height == 0 ? 1 : width / height;

  bool get isLandscape => width >= height;

  @override
  bool operator ==(Object other) =>
      other is ImageDimensions && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'ImageDimensions($width x $height)';
}
