import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/device_capability_profiler.dart';
import 'package:pixora/features/image_engine/services/image_engine_registry.dart';
import 'package:pixora/features/image_engine/services/model_registry.dart';

void main() {
  test('Phase 01 ships no processing capability at all', () {
    const ImageEngineRegistry registry = ImageEngineRegistry.empty();

    expect(registry.isEmpty, isTrue);
    expect(registry.processors, isEmpty);
    for (final ProcessingToolId tool in ProcessingToolId.values) {
      expect(registry.isAvailable(tool), isFalse);
      expect(registry.processorFor(tool), isNull);
    }
  });

  test('every planned model is marked as planned, never as available', () {
    expect(ModelRegistry.planned, isNotEmpty);
    for (final ModelSpec model in ModelRegistry.planned) {
      expect(model.availability, ModelAvailability.planned);
      // No unverified download sizes are advertised to users.
      expect(model.approximateSizeBytes, isNull);
    }
  });

  test('the device profiler refuses to invent hardware numbers', () {
    const UnavailableDeviceCapabilityProfiler profiler =
        UnavailableDeviceCapabilityProfiler();

    expect(() => profiler.profile(), throwsUnsupportedError);
  });
}
