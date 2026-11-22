import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

const MethodChannel _channel = MethodChannel('pixora/engine-test');

Map<String, Object?> _capabilitiesPayload({
  bool modelAvailable = true,
  int totalRamBytes = 3 * 1024 * 1024 * 1024,
}) {
  return <String, Object?>{
    'modelAvailable': modelAvailable,
    'modelId': 'real_esrgan_general_x4v3',
    'backend': 'litert-cpu',
    'scale': 4,
    'tileSize': 128,
    'supportsGpuAcceleration': false,
    'totalRamBytes': totalRamBytes,
    'availableRamBytes': 1200 * 1024 * 1024,
    'imageBudgetBytes': 96 * 1024 * 1024,
    'cpuCores': 8,
    'inferenceThreads': 4,
    'isLowRamDevice': false,
    'thermalStatus': 0,
  };
}

Map<String, Object?> _outcomePayload({int durationMs = 42000}) {
  return <String, Object?>{
    'outputPath': '/data/user/0/com.pixora.app/files/pixora_x.jpg',
    'sourceWidth': 640,
    'sourceHeight': 480,
    'workingWidth': 512,
    'workingHeight': 384,
    'outputWidth': 2048,
    'outputHeight': 1536,
    'tiles': 24,
    'durationMs': durationMs,
    'downscaled': true,
    'usedAi': true,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('capabilities are parsed from the platform, not guessed', () async {
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      expect(call.method, 'capabilities');
      return _capabilitiesPayload();
    });
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    final EngineCapabilities capabilities = await engine.capabilities();

    expect(capabilities.modelAvailable, isTrue);
    expect(capabilities.scale, 4);
    expect(capabilities.tileSize, 128);
    expect(capabilities.totalRamBytes, 3 * 1024 * 1024 * 1024);
    expect(capabilities.inferenceThreads, 4);
    expect(capabilities.isSupported, isTrue);
  });

  test('a build without the native engine reports nothing available', () async {
    // No mock handler at all: exactly what a widget test or a desktop build sees.
    final NativeEngineChannel engine =
        NativeEngineChannel(channel: const MethodChannel('pixora/missing'));
    addTearDown(engine.dispose);

    final EngineCapabilities capabilities = await engine.capabilities();

    expect(capabilities.modelAvailable, isFalse);
    expect(capabilities.isSupported, isFalse);
    expect(await engine.filesDirectory(), isNull);
  });

  test('restore forwards the device policy and returns the real outcome', () async {
    Map<Object?, Object?>? received;
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      expect(call.method, 'restore');
      received = call.arguments as Map<Object?, Object?>;
      return _outcomePayload();
    });
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    final NativeProcessingOutcome outcome = await engine.restore(
      jobId: 'job-1',
      sourcePath: '/photos/old.jpg',
      outputPath: '/out/restored.jpg',
      maxInputPixels: 750000,
      maxOutputDimension: 2048,
      halo: 16,
    );

    expect(received?['sourcePath'], '/photos/old.jpg');
    expect(received?['maxInputPixels'], 750000);
    expect(received?['maxOutputDimension'], 2048);
    expect(received?['halo'], 16);
    expect(outcome.outputWidth, 2048);
    expect(outcome.outputHeight, 1536);
    expect(outcome.tiles, 24);
    expect(outcome.usedAi, isTrue);
    expect(outcome.downscaled, isTrue);
    expect(outcome.duration, const Duration(milliseconds: 42000));
  });

  test('a cancelled job becomes a typed, recognisable exception', () async {
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      throw PlatformException(code: 'cancelled', message: 'cancelled by user');
    });
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    await expectLater(
      engine.restore(
        jobId: 'job-2',
        sourcePath: '/photos/old.jpg',
        outputPath: '/out/restored.jpg',
      ),
      throwsA(
        isA<NativeEngineException>()
            .having((NativeEngineException e) => e.isCancelled, 'isCancelled', isTrue),
      ),
    );
  });

  test('a failed conversion surfaces the engine message', () async {
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      throw PlatformException(code: 'failed', message: 'out of memory');
    });
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    await expectLater(
      engine.restore(
        jobId: 'job-3',
        sourcePath: '/photos/old.jpg',
        outputPath: '/out/restored.jpg',
      ),
      throwsA(
        isA<NativeEngineException>()
            .having((NativeEngineException e) => e.message, 'message', 'out of memory'),
      ),
    );
  });

  test('progress events pushed by the engine reach the Dart stream', () async {
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async => null);
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    final Future<EngineProgress> first = engine.progress.first;
    await messenger.handlePlatformMessage(
      'pixora/engine-test',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onProgress', <String, Object?>{
          'jobId': 'job-9',
          'completedTiles': 6,
          'totalTiles': 24,
          'elapsedMs': 9000,
          'etaMs': 27000,
        }),
      ),
      (ByteData? _) {},
    );

    final EngineProgress progress = await first;
    expect(progress.jobId, 'job-9');
    expect(progress.completedTiles, 6);
    expect(progress.totalTiles, 24);
    expect(progress.fraction, 0.25);
    expect(progress.estimatedRemaining, const Duration(milliseconds: 27000));
  });

  test('cancel is best effort and never throws', () async {
    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      throw PlatformException(code: 'failed', message: 'gone');
    });
    final NativeEngineChannel engine = NativeEngineChannel(channel: _channel);
    addTearDown(engine.dispose);

    expect(await engine.cancel('job-1'), isFalse);
    await engine.setKeepScreenOn(true); // must not throw either
  });
}
