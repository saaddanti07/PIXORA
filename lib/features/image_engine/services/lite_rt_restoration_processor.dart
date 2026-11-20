import 'dart:async';
import 'dart:io';

import 'package:pixora/features/image_engine/interfaces/image_restoration_service.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/interfaces/progress_aware_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/model_registry.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

/// Old-photo restoration delivered by the bundled Real-ESRGAN model.
///
/// This class holds no pixels: it validates the request, applies the device
/// policy, asks the native engine to do the work and translates the outcome into
/// the engine-agnostic [ImageProcessingResult] the rest of PIXORA already speaks.
class LiteRtRestorationProcessor
    implements ImageRestorationService, ProgressAwareProcessor {
  LiteRtRestorationProcessor({
    required NativeEngineChannel channel,
    required EngineCapabilities capabilities,
    required ProcessingPolicy policy,
    Future<Directory> Function()? outputDirectory,
    DateTime Function()? clock,
  })  : _channel = channel,
        _capabilities = capabilities,
        _policy = policy,
        _outputDirectory = outputDirectory ?? _defaultOutputDirectory,
        _clock = clock ?? DateTime.now {
    _progressSubscription = channel.progress.listen(_events.add);
  }

  final NativeEngineChannel _channel;
  final EngineCapabilities _capabilities;
  final ProcessingPolicy _policy;
  final Future<Directory> Function() _outputDirectory;
  final DateTime Function() _clock;

  final StreamController<EngineProgress> _events =
      StreamController<EngineProgress>.broadcast();
  StreamSubscription<EngineProgress>? _progressSubscription;
  String? _activeJobId;

  @override
  Stream<EngineProgress> get progress => _events.stream;

  @override
  Future<void> cancelActiveJob() async {
    final String? jobId = _activeJobId;
    if (jobId != null) {
      await _channel.cancel(jobId);
    }
  }

  /// Releases the progress relay. The processor is rebuilt on next app start.
  void dispose() {
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _events.close();
  }

  @override
  ProcessingToolId get toolId => ProcessingToolId.oldPhotoRestoration;

  @override
  ModelAvailability get availability => _capabilities.modelAvailable
      ? ModelAvailability.bundled
      : ModelAvailability.unavailable;

  @override
  List<ModelSpec> get models => <ModelSpec>[ModelRegistry.restoration];

  ProcessingPolicy get policy => _policy;

  @override
  Future<ImageProcessingResult> restore(ImageProcessingRequest request) async {
    if (!_capabilities.modelAvailable) {
      return ImageProcessingResult.failed(
        'The restoration model is not bundled in this build.',
      );
    }
    final File source = File(request.sourcePath);
    if (!await source.exists()) {
      return ImageProcessingResult.failed('The selected photo is no longer available.');
    }

    final String jobId = 'restore-${_clock().microsecondsSinceEpoch}';
    final String outputPath = await _allocateOutputPath('restored');
    _activeJobId = jobId;
    try {
      final NativeProcessingOutcome outcome = await _channel.restore(
        jobId: jobId,
        sourcePath: request.sourcePath,
        outputPath: outputPath,
        maxInputPixels: _policy.maxInputPixels,
        maxOutputDimension: request.maxOutputDimension ?? _policy.maxOutputDimension,
        halo: _policy.halo,
      );
      return ImageProcessingResult(
        status: ImageProcessingStatus.succeeded,
        outputPath: outcome.outputPath,
        modelId: _capabilities.modelId,
        duration: outcome.duration,
      );
    } on NativeEngineException catch (error) {
      if (error.isCancelled) {
        return const ImageProcessingResult.cancelled();
      }
      return ImageProcessingResult.failed(_describe(error));
    } on Object catch (error) {
      return ImageProcessingResult.failed(error.toString());
    } finally {
      _activeJobId = null;
    }
  }

  @override
  Future<ImageProcessingResult> process(ImageProcessingRequest request) =>
      restore(request);

  String _describe(NativeEngineException error) {
    if (error.isUnavailable) {
      return 'The on-device engine is not available in this build.';
    }
    if (error.isBusy) {
      return 'Another photo is still being processed.';
    }
    return error.message.isEmpty ? 'Processing failed.' : error.message;
  }

  Future<String> _allocateOutputPath(String suffix) async {
    final Directory base = await _outputDirectory();
    final Directory target = Directory('${base.path}${Platform.pathSeparator}restorations');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    final String stamp = _clock().millisecondsSinceEpoch.toString();
    return '${target.path}${Platform.pathSeparator}pixora_${stamp}_$suffix.jpg';
  }

  /// Application documents directory on Android; a temp directory elsewhere.
  static Future<Directory> _defaultOutputDirectory() async {
    final Directory temporary = Directory.systemTemp;
    final Directory output = Directory('${temporary.path}${Platform.pathSeparator}pixora');
    if (!await output.exists()) {
      await output.create(recursive: true);
    }
    return output;
  }
}
