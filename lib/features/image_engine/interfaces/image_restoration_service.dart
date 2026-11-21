import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Repairs old, damaged or faded photographs (scratches, creases, fading).
///
/// Planned implementation: a Real-ESRGAN style restoration network executed
/// with Google LiteRT, selected by the Smart AI Engine according to device RAM
/// and image size.
abstract interface class ImageRestorationService
    implements PixoraImageProcessor {
  Future<ImageProcessingResult> restore(ImageProcessingRequest request);
}
