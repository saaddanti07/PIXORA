import 'package:flutter/foundation.dart';

/// What the Smart AI Engine will measure about a device before choosing a
/// model variant.
///
/// Phase 01 only defines the shape of this data. Nothing measures real
/// hardware yet — see [DeviceCapabilityProfiler].
@immutable
class DeviceCapabilityProfile {
  const DeviceCapabilityProfile({
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.cpuCoreCount,
    required this.supportsGpuAcceleration,
    required this.isLowRamDevice,
  });

  final int totalRamBytes;
  final int availableRamBytes;
  final int cpuCoreCount;
  final bool supportsGpuAcceleration;
  final bool isLowRamDevice;

  /// Rough ceiling for a single decoded bitmap, used later to decide between a
  /// lightweight and a full model.
  int get imageMemoryBudgetBytes => (availableRamBytes * 0.35).round();
}
