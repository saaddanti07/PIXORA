import 'package:flutter/foundation.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

/// How much work the Smart AI Engine allows on this device.
///
/// The numbers are derived from the Phase 02 audit and are deliberately
/// conservative: the expensive part of restoration is linear in the number of
/// pixels the network sees, and a Helio G35-class phone has to stay under a
/// 90-second budget for a small photo. A device that reports more RAM and a
/// healthy memory situation is allowed to produce a larger image.
enum ProcessingTier {
  /// No neural network at all: classical enhancement only.
  classicalOnly,

  /// Low-RAM device (or the system says so): smallest working resolution.
  conservative,

  /// The expected Redmi 9 case.
  balanced,

  /// Comfortable devices.
  generous,
}

@immutable
class ProcessingPolicy {
  const ProcessingPolicy({
    required this.tier,
    required this.maxInputPixels,
    required this.maxOutputDimension,
    required this.halo,
  });

  /// Pixels handed to the network in one job.
  final int maxInputPixels;

  /// Longest edge of the produced image.
  final int maxOutputDimension;

  /// Context strip around every tile, in working pixels.
  final int halo;

  final ProcessingTier tier;

  bool get allowsAi => tier != ProcessingTier.classicalOnly;

  /// Working resolution for a photo of [width] × [height], never above the
  /// source (the network performs the upscale itself).
  ({int width, int height}) workingSizeFor(int width, int height, int scale) {
    if (width <= 0 || height <= 0) {
      return (width: 0, height: 0);
    }
    final int longEdge = width > height ? width : height;
    final int maxLong = maxOutputDimension ~/ scale;
    double factor = 1;
    if (longEdge > maxLong) {
      factor = maxLong / longEdge;
    }
    final double pixels = width * height * factor * factor;
    if (pixels > maxInputPixels) {
      factor *= _sqrt(maxInputPixels / pixels);
    }
    final int workingWidth = (width * factor).round().clamp(1, width).toInt();
    final int workingHeight = (height * factor).round().clamp(1, height).toInt();
    return (width: workingWidth, height: workingHeight);
  }

  /// Number of tiles a working image of the given size needs.
  int tileCountFor({required int workingWidth, required int workingHeight, required int tileSize}) {
    final int stride = tileSize - 2 * halo;
    if (stride <= 0 || workingWidth <= 0 || workingHeight <= 0) {
      return 0;
    }
    final int columns = (workingWidth + stride - 1) ~/ stride;
    final int rows = (workingHeight + stride - 1) ~/ stride;
    return columns * rows;
  }

  static ProcessingPolicy forDevice(EngineCapabilities capabilities) {
    if (!capabilities.modelAvailable) {
      return const ProcessingPolicy(
        tier: ProcessingTier.classicalOnly,
        maxInputPixels: 0,
        maxOutputDimension: 2048,
        halo: 16,
      );
    }
    final int total = capabilities.totalRamBytes;
    if (capabilities.isLowRamDevice || (total > 0 && total < 2500 * 1024 * 1024)) {
      return const ProcessingPolicy(
        tier: ProcessingTier.conservative,
        maxInputPixels: 500000,
        maxOutputDimension: 1536,
        halo: 16,
      );
    }
    if (total > 0 && total < 3500 * 1024 * 1024) {
      return const ProcessingPolicy(
        tier: ProcessingTier.balanced,
        maxInputPixels: 750000,
        maxOutputDimension: 2048,
        halo: 16,
      );
    }
    return const ProcessingPolicy(
      tier: ProcessingTier.generous,
      maxInputPixels: 1200000,
      maxOutputDimension: 2560,
      halo: 16,
    );
  }

  /// Test/dev default that matches the conservative target device.
  static const ProcessingPolicy conservative = ProcessingPolicy(
    tier: ProcessingTier.balanced,
    maxInputPixels: 750000,
    maxOutputDimension: 2048,
    halo: 16,
  );

  static double _sqrt(double value) {
    if (value <= 0) {
      return 0;
    }
    double guess = value;
    for (int i = 0; i < 24; i++) {
      guess = 0.5 * (guess + value / guess);
    }
    return guess;
  }
}
