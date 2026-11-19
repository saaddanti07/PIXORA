import 'package:flutter/foundation.dart';

/// Outcome of one processing run.
enum ImageProcessingStatus { succeeded, failed, cancelled }

/// Result of an on-device processing run.
@immutable
class ImageProcessingResult {
  const ImageProcessingResult({
    required this.status,
    this.outputPath,
    this.modelId,
    this.duration = Duration.zero,
    this.failureReason,
  });

  factory ImageProcessingResult.failed(String reason) => ImageProcessingResult(
        status: ImageProcessingStatus.failed,
        failureReason: reason,
      );

  const ImageProcessingResult.cancelled()
      : status = ImageProcessingStatus.cancelled,
        outputPath = null,
        modelId = null,
        duration = Duration.zero,
        failureReason = null;

  final ImageProcessingStatus status;

  /// Local path of the produced image. Always on the device.
  final String? outputPath;

  /// Identifier of the model or algorithm that produced the result.
  final String? modelId;
  final Duration duration;
  final String? failureReason;

  bool get isSuccess => status == ImageProcessingStatus.succeeded;
}
