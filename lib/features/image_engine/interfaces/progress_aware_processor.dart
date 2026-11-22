import 'package:pixora/features/image_engine/services/native_engine_channel.dart';

/// Implemented by processors that can report tile-level progress and be
/// cancelled while they run.
///
/// It is a separate interface rather than part of [PixoraImageProcessor] because
/// only real, long-running engines have anything to report: a future pure-Dart
/// tool with no tiles should not have to fake a progress stream.
abstract interface class ProgressAwareProcessor {
  /// Progress events for the job currently running (or the next one).
  Stream<EngineProgress> get progress;

  /// Asks the engine to stop at the next tile boundary. Safe to call twice.
  Future<void> cancelActiveJob();
}
