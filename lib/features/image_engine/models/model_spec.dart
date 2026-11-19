import 'package:flutter/foundation.dart';

/// How a model is executed on the device.
enum InferenceBackend {
  /// Google LiteRT (formerly TensorFlow Lite) interpreter.
  liteRt,

  /// ONNX Runtime Mobile.
  onnxRuntime,

  /// Hand-written Dart/FFI image algorithms (no neural network).
  nativeAlgorithm,
}

/// Whether a model can be used on this build.
enum ModelAvailability {
  /// Designed and evaluated, but not integrated yet (Phase 01 state).
  planned,

  /// Shipped inside the APK.
  bundled,

  /// Requires a one-off download in a later phase.
  downloadable,

  /// Present on the device but unusable here (for example unsupported ops).
  unavailable,
}

/// Descriptor of a model PIXORA is designed around.
///
/// [purpose] is developer documentation, not user-facing copy: user-facing
/// descriptions are localized when the feature actually ships.
@immutable
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.name,
    required this.purpose,
    required this.backend,
    required this.availability,
    this.requiresDownload = false,
    this.approximateSizeBytes,
    this.notes,
  });

  final String id;
  final String name;
  final String purpose;
  final InferenceBackend backend;
  final ModelAvailability availability;

  /// Whether the model would have to be fetched before it can run.
  final bool requiresDownload;

  /// Left `null` until the model is benchmarked on real target hardware, so
  /// PIXORA never shows users a number it has not verified.
  final int? approximateSizeBytes;

  final String? notes;
}
