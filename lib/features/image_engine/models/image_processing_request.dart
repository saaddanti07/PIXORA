import 'package:flutter/foundation.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';

/// A request to process one local image with one tool.
///
/// Only a local path is passed around — PIXORA never uploads images, so the
/// engine has no concept of a network source.
@immutable
class ImageProcessingRequest {
  const ImageProcessingRequest({
    required this.sourcePath,
    required this.tool,
    this.options = const <String, Object?>{},
    this.maxOutputDimension,
  });

  final String sourcePath;
  final ProcessingToolId tool;

  /// Tool specific settings (strength, palette, scale factor, ...).
  final Map<String, Object?> options;

  /// Upper bound for the output edge, used to protect low-RAM devices.
  final int? maxOutputDimension;
}
