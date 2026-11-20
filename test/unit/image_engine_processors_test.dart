import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/classical_enhancement_processor.dart';
import 'package:pixora/features/image_engine/services/lite_rt_restoration_processor.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

const MethodChannel _channel = MethodChannel('pixora/engine-processors');

EngineCapabilities _capabilities({bool modelAvailable = true}) => EngineCapabilities(
      modelAvailable: modelAvailable,
      modelId: 'real_esrgan_general_x4v3',
      backend: 'litert-cpu',
      scale: 4,
      tileSize: 128,
      supportsGpuAcceleration: false,
      totalRamBytes: 3 * 1024 * 1024 * 1024,
      availableRamBytes: 1024 * 1024 * 1024,
      imageBudgetBytes: 64 * 1024 * 1024,
      cpuCores: 8,
      inferenceThreads: 4,
      isLowRamDevice: false,
      thermalStatus: 0,
    );

Map<String, Object?> _outcome(String path, {bool usedAi = true}) => <String, Object?>{
      'outputPath': path,
      'sourceWidth': 640,
      'sourceHeight': 480,
      'workingWidth': 512,
      'workingHeight': 384,
      'outputWidth': 2048,
      'outputHeight': 1536,
      'tiles': usedAi ? 24 : 0,
      'durationMs': 42000,
      'downscaled': true,
      'usedAi': usedAi,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory temp;
  late File source;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pixora_processors');
    source = File('${temp.path}/old_photo.jpg')..writeAsBytesSync(<int>[1, 2, 3]);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_channel, null);
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  group('LiteRtRestorationProcessor', () {
    test('reports itself as bundled when the model is present', () {
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final LiteRtRestorationProcessor processor = LiteRtRestorationProcessor(
        channel: channel,
        capabilities: _capabilities(),
        policy: ProcessingPolicy.conservative,
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      expect(processor.toolId, ProcessingToolId.oldPhotoRestoration);
      expect(processor.availability, ModelAvailability.bundled);
      expect(processor.models.single.id, 'real_esrgan_general_x4v3');
    });

    test('refuses to run when the model is not bundled', () async {
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final LiteRtRestorationProcessor processor = LiteRtRestorationProcessor(
        channel: channel,
        capabilities: _capabilities(modelAvailable: false),
        policy: ProcessingPolicy.forDevice(_capabilities(modelAvailable: false)),
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      expect(processor.availability, ModelAvailability.unavailable);
      final ImageProcessingResult result = await processor.restore(
        ImageProcessingRequest(
          sourcePath: source.path,
          tool: ProcessingToolId.oldPhotoRestoration,
        ),
      );
      expect(result.status, ImageProcessingStatus.failed);
    });

    test('maps a native success to a bundle-agnostic result', () async {
      Map<Object?, Object?>? arguments;
      messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
        arguments = call.arguments as Map<Object?, Object?>;
        return _outcome(arguments!['outputPath']! as String);
      });
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final LiteRtRestorationProcessor processor = LiteRtRestorationProcessor(
        channel: channel,
        capabilities: _capabilities(),
        policy: ProcessingPolicy.conservative,
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      final ImageProcessingResult result = await processor.restore(
        ImageProcessingRequest(
          sourcePath: source.path,
          tool: ProcessingToolId.oldPhotoRestoration,
          maxOutputDimension: 1536,
        ),
      );

      expect(result.status, ImageProcessingStatus.succeeded);
      expect(result.modelId, 'real_esrgan_general_x4v3');
      expect(result.outputPath, isNotNull);
      expect(result.outputPath!, endsWith('.jpg'));
      expect(result.duration, const Duration(milliseconds: 42000));
      expect(arguments?['maxOutputDimension'], 1536);
      expect(arguments?['maxInputPixels'], 750000);
      expect(arguments?['halo'], 16);
    });

    test('a cancelled job is reported as cancelled, not as a failure', () async {
      final Completer<Map<Object?, Object?>> pending =
          Completer<Map<Object?, Object?>>();
      String? cancelledJob;
      bool restoreStarted = false;
      messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
        if (call.method == 'cancel') {
          cancelledJob = (call.arguments as Map<Object?, Object?>)['jobId'] as String?;
          return true;
        }
        restoreStarted = true;
        return pending.future;
      });
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final LiteRtRestorationProcessor processor = LiteRtRestorationProcessor(
        channel: channel,
        capabilities: _capabilities(),
        policy: ProcessingPolicy.conservative,
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      final Future<ImageProcessingResult> running = processor.restore(
        ImageProcessingRequest(
          sourcePath: source.path,
          tool: ProcessingToolId.oldPhotoRestoration,
        ),
      );
      // Wait until the job has really reached the engine: the processor checks
      // the source file first, so this is not synchronous.
      for (int i = 0; i < 100 && !restoreStarted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(restoreStarted, isTrue);
      await processor.cancelActiveJob();
      expect(cancelledJob, isNotNull);
      pending.completeError(PlatformException(code: 'cancelled'));

      final ImageProcessingResult result = await running;
      expect(result.status, ImageProcessingStatus.cancelled);
      expect(result.outputPath, isNull);
    });

    test('a missing source file fails without touching the engine', () async {
      bool called = false;
      messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
        called = true;
        return _outcome('/tmp/never.jpg');
      });
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final LiteRtRestorationProcessor processor = LiteRtRestorationProcessor(
        channel: channel,
        capabilities: _capabilities(),
        policy: ProcessingPolicy.conservative,
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      final ImageProcessingResult result = await processor.restore(
        ImageProcessingRequest(
          sourcePath: '${temp.path}/does_not_exist.jpg',
          tool: ProcessingToolId.oldPhotoRestoration,
        ),
      );

      expect(result.status, ImageProcessingStatus.failed);
      expect(called, isFalse);
    });
  });

  group('ClassicalEnhancementProcessor', () {
    test('is always available and never claims to be AI', () async {
      messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
        final Map<Object?, Object?> arguments = call.arguments as Map<Object?, Object?>;
        return _outcome(arguments['outputPath']! as String, usedAi: false);
      });
      final NativeEngineChannel channel = NativeEngineChannel(channel: _channel);
      final ClassicalEnhancementProcessor processor = ClassicalEnhancementProcessor(
        channel: channel,
        policy: ProcessingPolicy.conservative,
        outputDirectory: () async => temp,
      );
      addTearDown(() {
        processor.dispose();
        channel.dispose();
      });

      expect(processor.toolId, ProcessingToolId.photoEnhancement);
      expect(processor.availability, ModelAvailability.bundled);
      expect(processor.models.single.backend, InferenceBackend.nativeAlgorithm);

      final ImageProcessingResult result = await processor.enhance(
        ImageProcessingRequest(
          sourcePath: source.path,
          tool: ProcessingToolId.photoEnhancement,
        ),
      );
      expect(result.status, ImageProcessingStatus.succeeded);
      expect(result.modelId, 'classical_enhance');
    });
  });
}
