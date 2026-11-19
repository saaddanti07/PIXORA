import 'package:pixora/features/image_engine/models/device_capability_profile.dart';

/// Will measure the device (RAM, CPU, GPU, thermals) so the Smart AI Engine can
/// pick between lightweight and full models.
abstract interface class DeviceCapabilityProfiler {
  Future<DeviceCapabilityProfile> profile();
}

/// Phase 01 placeholder.
///
/// It deliberately implements no detection and never returns invented numbers:
/// calling it is a programming error until the real profiler lands in a later
/// phase.
class UnavailableDeviceCapabilityProfiler implements DeviceCapabilityProfiler {
  const UnavailableDeviceCapabilityProfiler();

  @override
  Future<DeviceCapabilityProfile> profile() {
    throw UnsupportedError(
      'Device capability profiling is not implemented in Phase 01.',
    );
  }
}
