import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

EngineCapabilities capabilities({
  bool modelAvailable = true,
  int totalRamBytes = 4 * 1024 * 1024 * 1024,
  bool isLowRamDevice = false,
}) {
  return EngineCapabilities(
    modelAvailable: modelAvailable,
    modelId: 'real_esrgan_general_x4v3',
    backend: 'litert-cpu',
    scale: 4,
    tileSize: 128,
    supportsGpuAcceleration: false,
    totalRamBytes: totalRamBytes,
    availableRamBytes: totalRamBytes ~/ 2,
    imageBudgetBytes: 64 * 1024 * 1024,
    cpuCores: 8,
    inferenceThreads: 4,
    isLowRamDevice: isLowRamDevice,
    thermalStatus: 0,
  );
}

void main() {
  group('tier selection', () {
    test('no model means classical only', () {
      final ProcessingPolicy policy =
          ProcessingPolicy.forDevice(capabilities(modelAvailable: false));
      expect(policy.tier, ProcessingTier.classicalOnly);
      expect(policy.allowsAi, isFalse);
      // The classical path still gets a usable output ceiling.
      expect(policy.maxOutputDimension, greaterThanOrEqualTo(1536));
    });

    test('a system-declared low-RAM device is treated conservatively', () {
      final ProcessingPolicy policy = ProcessingPolicy.forDevice(
        capabilities(totalRamBytes: 3 * 1024 * 1024 * 1024, isLowRamDevice: true),
      );
      expect(policy.tier, ProcessingTier.conservative);
      expect(policy.maxOutputDimension, 1536);
    });

    test('2 GB of RAM is conservative whatever the system flag says', () {
      final ProcessingPolicy policy = ProcessingPolicy.forDevice(
        capabilities(totalRamBytes: 2 * 1024 * 1024 * 1024),
      );
      expect(policy.tier, ProcessingTier.conservative);
    });

    test('the Redmi 9 class lands in the balanced tier', () {
      final ProcessingPolicy policy = ProcessingPolicy.forDevice(
        capabilities(totalRamBytes: 3 * 1024 * 1024 * 1024),
      );
      expect(policy.tier, ProcessingTier.balanced);
      // 2048 output / scale 4 = 512 px working long edge: 24 tiles for 640x480.
      expect(policy.maxOutputDimension, 2048);
      expect(policy.halo, 16);
    });

    test('a comfortable device is allowed a larger result', () {
      final ProcessingPolicy policy = ProcessingPolicy.forDevice(
        capabilities(totalRamBytes: 6 * 1024 * 1024 * 1024),
      );
      expect(policy.tier, ProcessingTier.generous);
      expect(policy.maxOutputDimension, 2560);
    });
  });

  group('working resolution', () {
    const ProcessingPolicy policy = ProcessingPolicy.conservative;

    test('a 640x480 photo is processed whole and never enlarged', () {
      final ({int height, int width}) size =
          policy.workingSizeFor(640, 480, 4);
      // 2048/4 = 512 cap: the long edge is reduced to 512, aspect preserved.
      expect(size.width, 512);
      expect(size.height, 384);
    });

    test('a small photo keeps its native resolution', () {
      final ({int height, int width}) size =
          policy.workingSizeFor(320, 240, 4);
      expect(size.width, 320);
      expect(size.height, 240);
    });

    test('a 12 MP photo is reduced by both ceilings', () {
      final ({int height, int width}) size =
          policy.workingSizeFor(4032, 3024, 4);
      expect(size.width, lessThanOrEqualTo(512));
      expect(size.height, lessThanOrEqualTo(512));
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
      // Aspect ratio is preserved within a pixel.
      final double sourceRatio = 4032 / 3024;
      final double workingRatio = size.width / size.height;
      expect((sourceRatio - workingRatio).abs(), lessThan(0.02));
    });

    test('the AI input budget is respected as well', () {
      const ProcessingPolicy tiny = ProcessingPolicy(
        tier: ProcessingTier.conservative,
        maxInputPixels: 100000,
        maxOutputDimension: 2048,
        halo: 16,
      );
      final ({int height, int width}) size = tiny.workingSizeFor(2000, 2000, 4);
      expect(size.width * size.height, lessThanOrEqualTo(100000));
    });

    test('degenerate sizes do not throw', () {
      expect(policy.workingSizeFor(0, 0, 4), (width: 0, height: 0));
    });
  });

  group('tile budgeting', () {
    const ProcessingPolicy policy = ProcessingPolicy.conservative;

    test('512x384 needs 24 tiles with a 16 px halo', () {
      expect(
        policy.tileCountFor(workingWidth: 512, workingHeight: 384, tileSize: 128),
        24,
      );
    });

    test('the 640x480 target stays inside the 90 second budget', () {
      // 24 tiles at the conservative per-tile estimate (1.3-2.8 s) is at most
      // 68 s, which is why the balanced policy is the shipping default.
      final int tiles =
          policy.tileCountFor(workingWidth: 512, workingHeight: 384, tileSize: 128);
      expect(tiles * 2.8, lessThan(90));
    });

    test('a zero halo produces the naive count', () {
      const ProcessingPolicy noHalo = ProcessingPolicy(
        tier: ProcessingTier.balanced,
        maxInputPixels: 750000,
        maxOutputDimension: 2048,
        halo: 0,
      );
      // 512/128 = 4 columns, 384/128 = 3 rows.
      expect(
        noHalo.tileCountFor(workingWidth: 512, workingHeight: 384, tileSize: 128),
        12,
      );
    });

    test('invalid input returns zero rather than dividing by zero', () {
      expect(
        policy.tileCountFor(workingWidth: 0, workingHeight: 0, tileSize: 128),
        0,
      );
      // A halo that eats the whole tile leaves no stride to advance by.
      expect(
        policy.tileCountFor(workingWidth: 256, workingHeight: 256, tileSize: 32),
        0,
      );
    });
  });
}
