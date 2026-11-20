import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the native engine reports about this device and this build.
///
/// Every value comes from the platform (Android `ActivityManager`, the runtime,
/// the bundled model's metadata). Nothing here is estimated in Dart.
@immutable
class EngineCapabilities {
  const EngineCapabilities({
    required this.modelAvailable,
    required this.modelId,
    required this.backend,
    required this.scale,
    required this.tileSize,
    required this.supportsGpuAcceleration,
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.imageBudgetBytes,
    required this.cpuCores,
    required this.inferenceThreads,
    required this.isLowRamDevice,
    required this.thermalStatus,
  });

  /// The state of a build without the native engine (tests, desktop, or an APK
  /// built without the model): nothing is claimed, nothing can run.
  static const EngineCapabilities unavailable = EngineCapabilities(
    modelAvailable: false,
    modelId: 'real_esrgan_general_x4v3',
    backend: 'litert-cpu',
    scale: 4,
    tileSize: 128,
    supportsGpuAcceleration: false,
    totalRamBytes: 0,
    availableRamBytes: 0,
    imageBudgetBytes: 0,
    cpuCores: 0,
    inferenceThreads: 0,
    isLowRamDevice: true,
    thermalStatus: 0,
  );

  final bool modelAvailable;
  final String modelId;
  final String backend;
  final int scale;
  final int tileSize;
  final bool supportsGpuAcceleration;
  final int totalRamBytes;
  final int availableRamBytes;
  final int imageBudgetBytes;
  final int cpuCores;
  final int inferenceThreads;
  final bool isLowRamDevice;
  final int thermalStatus;

  bool get isSupported => modelAvailable && totalRamBytes > 0;

  factory EngineCapabilities.fromMap(Map<Object?, Object?> map) {
    int readInt(String key, [int fallback = 0]) {
      final Object? value = map[key];
      return value is int ? value : fallback;
    }

    bool readBool(String key, [bool fallback = false]) {
      final Object? value = map[key];
      return value is bool ? value : fallback;
    }

    String readString(String key, [String fallback = '']) {
      final Object? value = map[key];
      return value is String ? value : fallback;
    }

    return EngineCapabilities(
      modelAvailable: readBool('modelAvailable'),
      modelId: readString('modelId', 'real_esrgan_general_x4v3'),
      backend: readString('backend', 'litert-cpu'),
      scale: readInt('scale', 4),
      tileSize: readInt('tileSize', 128),
      supportsGpuAcceleration: readBool('supportsGpuAcceleration'),
      totalRamBytes: readInt('totalRamBytes'),
      availableRamBytes: readInt('availableRamBytes'),
      imageBudgetBytes: readInt('imageBudgetBytes'),
      cpuCores: readInt('cpuCores'),
      inferenceThreads: readInt('inferenceThreads'),
      isLowRamDevice: readBool('isLowRamDevice', true),
      thermalStatus: readInt('thermalStatus'),
    );
  }

  EngineCapabilities copyWith({bool? modelAvailable}) => EngineCapabilities(
        modelAvailable: modelAvailable ?? this.modelAvailable,
        modelId: modelId,
        backend: backend,
        scale: scale,
        tileSize: tileSize,
        supportsGpuAcceleration: supportsGpuAcceleration,
        totalRamBytes: totalRamBytes,
        availableRamBytes: availableRamBytes,
        imageBudgetBytes: imageBudgetBytes,
        cpuCores: cpuCores,
        inferenceThreads: inferenceThreads,
        isLowRamDevice: isLowRamDevice,
        thermalStatus: thermalStatus,
      );
}

/// One progress event pushed by the native engine, once per processed tile.
@immutable
class EngineProgress {
  const EngineProgress({
    required this.jobId,
    required this.completedTiles,
    required this.totalTiles,
    required this.elapsedMs,
    required this.etaMs,
  });

  final String jobId;
  final int completedTiles;
  final int totalTiles;
  final int elapsedMs;

  /// Negative while the native side cannot estimate it yet.
  final int etaMs;

  double get fraction =>
      totalTiles <= 0 ? 0 : (completedTiles / totalTiles).clamp(0.0, 1.0);

  Duration get elapsed => Duration(milliseconds: elapsedMs);

  Duration? get estimatedRemaining =>
      etaMs < 0 ? null : Duration(milliseconds: etaMs);

  factory EngineProgress.fromMap(Map<Object?, Object?> map) => EngineProgress(
        jobId: map['jobId'] is String ? map['jobId']! as String : '',
        completedTiles: map['completedTiles'] is int ? map['completedTiles']! as int : 0,
        totalTiles: map['totalTiles'] is int ? map['totalTiles']! as int : 0,
        elapsedMs: map['elapsedMs'] is int ? map['elapsedMs']! as int : 0,
        etaMs: map['etaMs'] is int ? map['etaMs']! as int : -1,
      );
}

/// What the native side actually did, in its own words.
@immutable
class NativeProcessingOutcome {
  const NativeProcessingOutcome({
    required this.outputPath,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.workingWidth,
    required this.workingHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.tiles,
    required this.durationMs,
    required this.downscaled,
    required this.usedAi,
  });

  final String outputPath;
  final int sourceWidth;
  final int sourceHeight;
  final int workingWidth;
  final int workingHeight;
  final int outputWidth;
  final int outputHeight;
  final int tiles;
  final int durationMs;
  final bool downscaled;
  final bool usedAi;

  Duration get duration => Duration(milliseconds: durationMs);

  factory NativeProcessingOutcome.fromMap(Map<Object?, Object?> map) {
    int readInt(String key) => map[key] is int ? map[key]! as int : 0;
    bool readBool(String key) => map[key] is bool && map[key]! as bool;
    return NativeProcessingOutcome(
      outputPath: map['outputPath'] is String ? map['outputPath']! as String : '',
      sourceWidth: readInt('sourceWidth'),
      sourceHeight: readInt('sourceHeight'),
      workingWidth: readInt('workingWidth'),
      workingHeight: readInt('workingHeight'),
      outputWidth: readInt('outputWidth'),
      outputHeight: readInt('outputHeight'),
      tiles: readInt('tiles'),
      durationMs: readInt('durationMs'),
      downscaled: readBool('downscaled'),
      usedAi: readBool('usedAi'),
    );
  }
}

/// A failure reported by the native engine.
class NativeEngineException implements Exception {
  const NativeEngineException(this.code, this.message);

  final String code;
  final String message;

  bool get isCancelled => code == 'cancelled';
  bool get isBusy => code == 'busy';
  bool get isUnavailable => code == 'unavailable';

  @override
  String toString() => 'NativeEngineException($code): $message';
}

/// Typed wrapper around the single `pixora/engine` platform channel.
///
/// The channel carries paths, numbers and progress events only — image data
/// never crosses it, which is what keeps a 2048×2048 result from being copied
/// between Kotlin and Dart.
class NativeEngineChannel {
  NativeEngineChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const String channelName = 'pixora/engine';

  final MethodChannel _channel;
  final StreamController<EngineProgress> _progress =
      StreamController<EngineProgress>.broadcast();

  Stream<EngineProgress> get progress => _progress.stream;

  Future<EngineCapabilities> capabilities() async {
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('capabilities');
      if (raw == null) {
        return EngineCapabilities.unavailable;
      }
      return EngineCapabilities.fromMap(raw);
    } on MissingPluginException {
      return EngineCapabilities.unavailable;
    } on PlatformException {
      return EngineCapabilities.unavailable;
    }
  }

  Future<NativeProcessingOutcome> restore({
    required String jobId,
    required String sourcePath,
    required String outputPath,
    int? maxInputPixels,
    int? maxOutputDimension,
    int? halo,
    int jpegQuality = 95,
  }) async {
    final Map<Object?, Object?>? raw = await _invoke<Map<Object?, Object?>>(
      'restore',
      <String, Object?>{
        'jobId': jobId,
        'sourcePath': sourcePath,
        'outputPath': outputPath,
        if (maxInputPixels != null) 'maxInputPixels': maxInputPixels,
        if (maxOutputDimension != null) 'maxOutputDimension': maxOutputDimension,
        if (halo != null) 'halo': halo,
        'jpegQuality': jpegQuality,
      },
    );
    if (raw == null) {
      throw const NativeEngineException('failed', 'The engine returned nothing.');
    }
    return NativeProcessingOutcome.fromMap(raw);
  }

  Future<NativeProcessingOutcome> enhance({
    required String jobId,
    required String sourcePath,
    required String outputPath,
    int? maxOutputDimension,
    int jpegQuality = 95,
  }) async {
    final Map<Object?, Object?>? raw = await _invoke<Map<Object?, Object?>>(
      'enhance',
      <String, Object?>{
        'jobId': jobId,
        'sourcePath': sourcePath,
        'outputPath': outputPath,
        if (maxOutputDimension != null) 'maxOutputDimension': maxOutputDimension,
        'jpegQuality': jpegQuality,
      },
    );
    if (raw == null) {
      throw const NativeEngineException('failed', 'The engine returned nothing.');
    }
    return NativeProcessingOutcome.fromMap(raw);
  }

  Future<bool> cancel(String jobId) async {
    try {
      final bool? cancelled =
          await _channel.invokeMethod<bool>('cancel', <String, Object?>{'jobId': jobId});
      return cancelled ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The app's private files directory, where processed photos are kept.
  ///
  /// Returns null when the native side cannot answer (tests, unsupported
  /// platforms), in which case the callers fall back to a temporary directory.
  Future<Directory?> filesDirectory() async {
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('paths');
      final Object? filesDir = raw?['filesDir'];
      if (filesDir is String && filesDir.isNotEmpty) {
        final Directory directory = Directory(filesDir);
        if (await directory.exists()) {
          return directory;
        }
      }
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    return null;
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setKeepScreenOn',
        <String, Object?>{'enabled': enabled},
      );
    } on PlatformException {
      // Cosmetic only.
    } on MissingPluginException {
      // Cosmetic only.
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _progress.close();
  }

  Future<T?> _invoke<T>(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw NativeEngineException(error.code, error.message ?? error.code);
    } on MissingPluginException {
      throw const NativeEngineException(
        'unavailable',
        'The on-device engine is not present in this build.',
      );
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onProgress') {
      final Object? arguments = call.arguments;
      if (arguments is Map<Object?, Object?>) {
        _progress.add(EngineProgress.fromMap(arguments));
      }
    }
    return null;
  }
}
