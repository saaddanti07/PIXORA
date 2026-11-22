import 'package:pixora/features/image_engine/models/model_spec.dart';

/// Catalogue of the on-device models PIXORA is designed around.
///
/// Two entries are real in Phase 02: the bundled Real-ESRGAN restoration model
/// and the classical enhancement pipeline. Everything else is still
/// [ModelAvailability.planned] and stays that way until it is proven on target
/// hardware — no size, speed or quality claim is made for a model that has not
/// been measured.
abstract final class ModelRegistry {
  /// `realesr-general-x4v3` (SRVGGNetCompact), converted to LiteRT by
  /// `tool/convert_model.py` from the official BSD-3-Clause weights and bundled
  /// inside the APK.
  static const ModelSpec restoration = ModelSpec(
    id: 'real_esrgan_general_x4v3',
    name: 'Real-ESRGAN general x4v3',
    purpose: 'Super-resolution and detail recovery for old, soft or faded photos.',
    backend: InferenceBackend.liteRt,
    availability: ModelAvailability.bundled,
    requiresDownload: false,
    approximateSizeBytes: restorationModelBytes,
    notes: 'SRVGGNetCompact, 1.21 M parameters, BSD-3-Clause. Runs in 128x128 '
        'tiles on CPU/XNNPACK through LiteRT; bundled, so no network is ever '
        'needed.',
  );

  /// Classical enhancement: no weights, no download, works on every device.
  static const ModelSpec classicalEnhancement = ModelSpec(
    id: 'classical_enhance',
    name: 'Classical enhancement pipeline',
    purpose: 'Levels, saturation and unsharp mask without a neural network.',
    backend: InferenceBackend.nativeAlgorithm,
    availability: ModelAvailability.bundled,
    requiresDownload: false,
    notes: 'No model file. The Fast Enhancement path and the automatic fallback '
        'for photos outside the AI budget.',
  );

  /// Models that exist on paper and are not shipped.
  static const List<ModelSpec> planned = <ModelSpec>[
    ModelSpec(
      id: 'gfpgan_face',
      name: 'GFPGAN',
      purpose: 'Facial detail restoration.',
      backend: InferenceBackend.liteRt,
      availability: ModelAvailability.planned,
      requiresDownload: true,
      notes: 'Deferred: ~348 MB weights and third-party licence components. '
          'Run on detected face crops only, on devices with far more RAM.',
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
      notes: 'Real-CUGAN (MIT) is the current candidate for the anime style.',
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

  /// Models that run in this build, in the order the UI may offer them.
  static const List<ModelSpec> bundled = <ModelSpec>[
    restoration,
    classicalEnhancement,
  ];

  /// Everything PIXORA is designed around.
  static const List<ModelSpec> catalogue = <ModelSpec>[
    restoration,
    classicalEnhancement,
    ...planned,
  ];

  /// Exact size of the bundled `.tflite` file, as measured by the conversion
  /// pipeline. Kept in sync by hand with `models/report.json`; the CI job fails
  /// if the APK does not contain a model with this digest.
  static const int restorationModelBytes = 4910280;

  static ModelSpec? byId(String id) {
    for (final ModelSpec spec in catalogue) {
      if (spec.id == id) {
        return spec;
      }
    }
    return null;
  }
}
