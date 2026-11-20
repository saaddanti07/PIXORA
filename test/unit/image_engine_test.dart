import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/device_capability_profiler.dart';
import 'package:pixora/features/image_engine/services/image_engine_registry.dart';
import 'package:pixora/features/image_engine/services/model_registry.dart';

void main() {
  test('the empty registry still offers nothing at all', () {
    const ImageEngineRegistry registry = ImageEngineRegistry.empty();

    expect(registry.isEmpty, isTrue);
    expect(registry.processors, isEmpty);
    for (final ProcessingToolId tool in ProcessingToolId.values) {
      expect(registry.isAvailable(tool), isFalse);
      expect(registry.processorFor(tool), isNull);
    }
  });

  test('models that are not shipped stay planned and claim no size', () {
    expect(ModelRegistry.planned, isNotEmpty);
    for (final ModelSpec model in ModelRegistry.planned) {
      expect(model.availability, ModelAvailability.planned);
      // No unverified download sizes are advertised to users.
      expect(model.approximateSizeBytes, isNull);
      // Anything neural has to be fetched; a pure Dart algorithm does not.
      if (model.backend != InferenceBackend.nativeAlgorithm) {
        expect(model.requiresDownload, isTrue);
      }
    }
  });

  test('shipped models are bundled, offline and carry a measured size', () {
    expect(ModelRegistry.bundled, hasLength(2));
    for (final ModelSpec model in ModelRegistry.bundled) {
      expect(model.availability, ModelAvailability.bundled);
      expect(model.requiresDownload, isFalse);
    }

    final ModelSpec restoration = ModelRegistry.restoration;
    expect(restoration.backend, InferenceBackend.liteRt);
    expect(restoration.id, 'real_esrgan_general_x4v3');
    // The real artefact is between 4 and 8 MiB; a null or invented number
    // here means the conversion pipeline and this constant have drifted apart.
    expect(restoration.approximateSizeBytes, isNotNull);
    expect(restoration.approximateSizeBytes!, greaterThan(4000000));
    expect(restoration.approximateSizeBytes!, lessThan(8000000));

    final ModelSpec classical = ModelRegistry.classicalEnhancement;
    expect(classical.backend, InferenceBackend.nativeAlgorithm);
    expect(classical.approximateSizeBytes, isNull);
  });

  test('the catalogue contains every model exactly once', () {
    final Set<String> ids =
        ModelRegistry.catalogue.map((ModelSpec model) => model.id).toSet();
    expect(ids, hasLength(ModelRegistry.catalogue.length));
    expect(ModelRegistry.catalogue.length,
        ModelRegistry.bundled.length + ModelRegistry.planned.length);
    expect(ModelRegistry.byId('real_esrgan_general_x4v3'), isNotNull);
    expect(ModelRegistry.byId('does_not_exist'), isNull);
  });

  test('the Phase 01 profiler still refuses to invent hardware numbers', () {
    const UnavailableDeviceCapabilityProfiler profiler =
        UnavailableDeviceCapabilityProfiler();

    expect(() => profiler.profile(), throwsUnsupportedError);
  });
}
