import 'package:pixora/features/image_engine/models/device_capability_profile.dart';
import 'package:pixora/features/image_engine/services/device_capability_profiler.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

/// The real Smart AI Engine profiler.
///
/// It reports what the platform says — total and currently available RAM, the
/// CPU count, the system's own low-RAM flag and (from the model metadata) whether
/// the bundled network can run at all. It never invents a number: if the native
/// side cannot answer, it falls back to [EngineCapabilities.unavailable] and the
/// caller is expected to take the classical path.
class AndroidDeviceCapabilityProfiler implements DeviceCapabilityProfiler {
  const AndroidDeviceCapabilityProfiler(this._channel);

  final NativeEngineChannel _channel;

  @override
  Future<DeviceCapabilityProfile> profile() async {
    final EngineCapabilities capabilities = await _channel.capabilities();
    return DeviceCapabilityProfile(
      totalRamBytes: capabilities.totalRamBytes,
      availableRamBytes: capabilities.availableRamBytes,
      cpuCoreCount: capabilities.cpuCores,
      supportsGpuAcceleration: capabilities.supportsGpuAcceleration,
      isLowRamDevice: capabilities.isLowRamDevice,
    );
  }
}
