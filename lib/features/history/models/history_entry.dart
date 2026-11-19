import 'package:flutter/foundation.dart';

/// One processed photo.
///
/// Phase 01 only defines and persists the record shape: no processing pipeline
/// exists yet, so the list stays empty. Phase 02 writes real results here.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.imagePath,
    required this.processedAt,
    this.toolId,
  });

  final String id;
  final String fileName;

  /// Local path of the result. PIXORA never stores image bytes in preferences.
  final String imagePath;
  final DateTime processedAt;
  final String? toolId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fileName': fileName,
        'imagePath': imagePath,
        'processedAt': processedAt.toIso8601String(),
        'toolId': toolId,
      };

  /// Returns `null` for malformed records instead of throwing, so one bad
  /// record can never break the whole history list.
  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? fileName = json['fileName'];
    final Object? imagePath = json['imagePath'];
    final Object? processedAt = json['processedAt'];
    if (id is! String || fileName is! String || imagePath is! String) {
      return null;
    }
    if (processedAt is! String) {
      return null;
    }
    final DateTime? timestamp = DateTime.tryParse(processedAt);
    if (timestamp == null) {
      return null;
    }
    final Object? toolId = json['toolId'];
    return HistoryEntry(
      id: id,
      fileName: fileName,
      imagePath: imagePath,
      processedAt: timestamp,
      toolId: toolId is String ? toolId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry && other.id == id && other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(id, imagePath);
}
