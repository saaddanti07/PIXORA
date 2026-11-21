import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';

/// Converts a photo into pixel art.
///
/// Planned implementation: traditional image processing (downsampling plus a
/// limited palette) rather than a neural network, which keeps it fast and
/// available offline on every device.
abstract interface class PixelArtService implements PixoraImageProcessor {
  Future<ImageProcessingResult> convert(ImageProcessingRequest request);
}
