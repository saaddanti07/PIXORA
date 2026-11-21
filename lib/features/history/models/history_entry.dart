import 'package:flutter/foundation.dart';

/// Durable metadata for one completed local processing operation.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.imagePath,
    required this.processedAt,
    this.originalPath,
    this.methodId,
    this.durationMs = 0,
    this.originalWidth,
    this.originalHeight,
    this.outputWidth,
    this.outputHeight,
    this.toolId,
  });

  final String id;
  final String fileName;

  /// Kept as the historical field name; this is the restored/enhanced image.
  final String imagePath;
  final String? originalPath;
  final DateTime processedAt;
  final String? methodId;
  final int durationMs;
  final int? originalWidth;
  final int? originalHeight;
  final int? outputWidth;
  final int? outputHeight;
  final String? toolId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fileName': fileName,
        'imagePath': imagePath,
        'originalPath': originalPath,
        'processedAt': processedAt.toIso8601String(),
        'methodId': methodId,
        'durationMs': durationMs,
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'outputWidth': outputWidth,
        'outputHeight': outputHeight,
        'toolId': toolId,
      };

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? fileName = json['fileName'];
    final Object? imagePath = json['imagePath'];
    final Object? processedAt = json['processedAt'];
    if (id is! String || fileName is! String || imagePath is! String ||
        processedAt is! String) return null;
    final DateTime? timestamp = DateTime.tryParse(processedAt);
    if (timestamp == null) return null;
    int? optionalInt(String key) => json[key] is int ? json[key] as int : null;
    final Object? original = json['originalPath'];
    final Object? method = json['methodId'];
    final Object? tool = json['toolId'];
    return HistoryEntry(
      id: id,
      fileName: fileName,
      imagePath: imagePath,
      originalPath: original is String ? original : null,
      processedAt: timestamp,
      methodId: method is String ? method : null,
      durationMs: optionalInt('durationMs') ?? 0,
      originalWidth: optionalInt('originalWidth'),
      originalHeight: optionalInt('originalHeight'),
      outputWidth: optionalInt('outputWidth'),
      outputHeight: optionalInt('outputHeight'),
      toolId: tool is String ? tool : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry && other.id == id && other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(id, imagePath);
}
