import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';

/// The processors that are actually available in this build.
///
/// Phase 01 registers none. That is the point: nothing in the UI can call a
/// processor, so no screen can ever present a fake result. Later phases add
/// real processors here and the home catalogue lights up automatically.
class ImageEngineRegistry {
  const ImageEngineRegistry(this._processors);

  /// The Phase 01 registry: no models, no processors.
  const ImageEngineRegistry.empty() : _processors = const <PixoraImageProcessor>[];

  final List<PixoraImageProcessor> _processors;

  List<PixoraImageProcessor> get processors =>
      List<PixoraImageProcessor>.unmodifiable(_processors);

  bool get isEmpty => _processors.isEmpty;

  PixoraImageProcessor? processorFor(ProcessingToolId tool) {
    for (final PixoraImageProcessor processor in _processors) {
      if (processor.toolId == tool) {
        return processor;
      }
    }
    return null;
  }

  bool isAvailable(ProcessingToolId tool) => processorFor(tool) != null;
}
