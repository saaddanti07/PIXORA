import 'dart:async';
import 'dart:io';

import 'package:pixora/features/image_engine/interfaces/image_enhancement_service.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/interfaces/progress_aware_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/model_registry.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

/// "Fast enhancement": classical image processing, no neural network.
///
/// It exists for the cases the AI path must not pretend to handle — photographs
/// far larger than the AI working budget, devices where the model is missing,
/// and users who want a quick, predictable result. Everywhere it appears in the
/// UI it is labelled as classical, never as AI.
class ClassicalEnhancementProcessor
    implements ImageEnhancementService, ProgressAwareProcessor {
  ClassicalEnhancementProcessor({
    required NativeEngineChannel channel,
    required ProcessingPolicy policy,
    Future<Directory> Function()? outputDirectory,
    DateTime Function()? clock,
  })  : _channel = channel,
        _policy = policy,
        _outputDirectory = outputDirectory ?? _defaultOutputDirectory,
        _clock = clock ?? DateTime.now;

  final NativeEngineChannel _channel;
  final ProcessingPolicy _policy;
  final Future<Directory> Function() _outputDirectory;
  final DateTime Function() _clock;

  /// Classical enhancement is a single fast pass, so there is nothing to report
  /// mid-flight; the stream exists to satisfy the shared contract.
  final StreamController<EngineProgress> _events =
      StreamController<EngineProgress>.broadcast();
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

  void dispose() {
    _events.close();
  }

  @override
  ProcessingToolId get toolId => ProcessingToolId.photoEnhancement;

  @override
  ModelAvailability get availability => ModelAvailability.bundled;

  @override
  List<ModelSpec> get models => <ModelSpec>[ModelRegistry.classicalEnhancement];

  @override
  Future<ImageProcessingResult> enhance(ImageProcessingRequest request) async {
    final File source = File(request.sourcePath);
    if (!await source.exists()) {
      return ImageProcessingResult.failed('The selected photo is no longer available.');
    }
    final String jobId = 'enhance-${_clock().microsecondsSinceEpoch}';
    final String outputPath = await _allocateOutputPath('enhanced');
    _activeJobId = jobId;
    try {
      final NativeProcessingOutcome outcome = await _channel.enhance(
        jobId: jobId,
        sourcePath: request.sourcePath,
        outputPath: outputPath,
        maxOutputDimension: request.maxOutputDimension ?? _policy.maxOutputDimension,
      );
      return ImageProcessingResult(
        status: ImageProcessingStatus.succeeded,
        outputPath: outcome.outputPath,
        modelId: ModelRegistry.classicalEnhancement.id,
        duration: outcome.duration,
        sourceWidth: outcome.sourceWidth,
        sourceHeight: outcome.sourceHeight,
        outputWidth: outcome.outputWidth,
        outputHeight: outcome.outputHeight,
      );
    } on NativeEngineException catch (error) {
      if (error.isCancelled) {
        return const ImageProcessingResult.cancelled();
      }
      return ImageProcessingResult.failed(
        error.message.isEmpty ? 'Enhancement failed.' : error.message,
      );
    } on Object catch (error) {
      return ImageProcessingResult.failed(error.toString());
    } finally {
      _activeJobId = null;
    }
  }

  @override
  Future<ImageProcessingResult> process(ImageProcessingRequest request) =>
      enhance(request);

  Future<String> _allocateOutputPath(String suffix) async {
    final Directory base = await _outputDirectory();
    final Directory target = Directory('${base.path}${Platform.pathSeparator}enhancements');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    final String stamp = _clock().microsecondsSinceEpoch.toString();
    String candidate = '${target.path}${Platform.pathSeparator}pixora_${stamp}_$suffix.jpg';
    var collision = 0;
    while (await File(candidate).exists()) {
      collision++;
      candidate = '${target.path}${Platform.pathSeparator}pixora_${stamp}_${suffix}_$collision.jpg';
    }
    return candidate;
  }

  static Future<Directory> _defaultOutputDirectory() async {
    final Directory output =
        Directory('${Directory.systemTemp.path}${Platform.pathSeparator}pixora');
    if (!await output.exists()) {
      await output.create(recursive: true);
    }
    return output;
  }
}
