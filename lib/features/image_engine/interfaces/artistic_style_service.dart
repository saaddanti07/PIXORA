import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Artistic transformations: anime style, painterly effects, creative filters.
abstract interface class ArtisticStyleService implements PixoraImageProcessor {
  Future<ImageProcessingResult> stylize(ImageProcessingRequest request);
}
