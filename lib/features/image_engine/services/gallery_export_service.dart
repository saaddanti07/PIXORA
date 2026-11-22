import 'package:flutter/services.dart';

abstract interface class GalleryExportService {
  /// Returns only after Android has published the MediaStore entry.
  Future<Uri> saveRestoredImage({required String path, required String displayName});
}

class AndroidGalleryExportService implements GalleryExportService {
  const AndroidGalleryExportService({
    MethodChannel channel = const MethodChannel('pixora/engine'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<Uri> saveRestoredImage({required String path, required String displayName}) async {
    final String? raw = await _channel.invokeMethod<String>(
      'saveToGallery',
      <String, Object?>{'sourcePath': path, 'displayName': displayName},
    );
    final Uri? uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Android did not return a published gallery URI.');
    }
    return uri;
  }
}
