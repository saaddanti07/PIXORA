import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Adds plausible colour to black and white photographs.
abstract interface class ColorizationService implements PixoraImageProcessor {
  Future<ImageProcessingResult> colorize(ImageProcessingRequest request);
}
