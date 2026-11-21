import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Restores natural facial detail in portraits and group photos.
///
/// Planned implementation: GFPGAN (or a lighter face-restoration network) after
/// on-device face localisation.
abstract interface class FaceEnhancementService
    implements PixoraImageProcessor {
  Future<ImageProcessingResult> enhanceFace(ImageProcessingRequest request);
}
