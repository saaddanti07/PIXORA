import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';

/// Common contract for every on-device processing capability.
///
/// Implementations are added in later phases (LiteRT interpreters, traditional
/// algorithms, ...). Phase 01 ships no implementation at all, so no feature can
/// pretend to have processed an image.
abstract interface class PixoraImageProcessor {
  /// Which capability this processor provides.
  ProcessingToolId get toolId;

  /// Whether the processor can run on this build.
  ModelAvailability get availability;

  /// The models behind the processor, if any.
  List<ModelSpec> get models;

  /// Runs the processor on a local image.
  Future<ImageProcessingResult> process(ImageProcessingRequest request);
}
