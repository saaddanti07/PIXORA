import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Improves clarity, sharpness and resolution of a photo.
///
/// Planned implementations: a super-resolution model for capable devices and a
/// fast classical enhancement pipeline (unsharp mask, contrast, denoise) for
/// low-RAM devices such as the Redmi 9.
abstract interface class ImageEnhancementService
    implements PixoraImageProcessor {
  Future<ImageProcessingResult> enhance(ImageProcessingRequest request);
}
