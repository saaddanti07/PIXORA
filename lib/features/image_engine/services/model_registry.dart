import 'package:pixora/features/image_engine/models/model_spec.dart';

/// Catalogue of the on-device models PIXORA is designed around.
///
/// Phase 01 downloads and bundles nothing: every entry is
/// [ModelAvailability.planned] and no size is claimed, because the models still
/// have to be benchmarked on the target Redmi 9 before any number is shown to
/// users.
abstract final class ModelRegistry {
  static const List<ModelSpec> planned = <ModelSpec>[
    ModelSpec(
      id: 'real_esrgan_general',
      name: 'Real-ESRGAN (general)',
      purpose: 'Super-resolution and detail recovery for old or soft photos.',
      backend: InferenceBackend.liteRt,
      availability: ModelAvailability.planned,
      requiresDownload: true,
      notes: 'Candidate for restoration and enhancement; needs a quantised '
          'variant to fit low-RAM devices.',
    ),
    ModelSpec(
      id: 'gfpgan_face',
      name: 'GFPGAN',
      purpose: 'Facial detail restoration.',
      backend: InferenceBackend.liteRt,
      availability: ModelAvailability.planned,
      requiresDownload: true,
      notes: 'Run on detected face crops only, to bound memory use.',
    ),
    ModelSpec(
      id: 'colorization_net',
      name: 'Colorization network',
      purpose: 'Automatic colourisation of black and white photographs.',
      backend: InferenceBackend.liteRt,
      availability: ModelAvailability.planned,
      requiresDownload: true,
    ),
    ModelSpec(
      id: 'style_transfer_net',
      name: 'Style transfer network',
      purpose: 'Anime and artistic style transformations.',
      backend: InferenceBackend.liteRt,
      availability: ModelAvailability.planned,
      requiresDownload: true,
    ),
    ModelSpec(
      id: 'classical_enhance',
      name: 'Classical enhancement pipeline',
      purpose: 'Sharpening, contrast and denoise without a neural network.',
      backend: InferenceBackend.nativeAlgorithm,
      availability: ModelAvailability.planned,
      notes: 'No download required; the fallback for low-end devices.',
    ),
    ModelSpec(
      id: 'pixel_art_sampler',
      name: 'Pixel art sampler',
      purpose: 'Palette quantisation and grid sampling for pixel art.',
      backend: InferenceBackend.nativeAlgorithm,
      availability: ModelAvailability.planned,
      notes: 'Pure Dart implementation; no model download.',
    ),
  ];
}
