import 'dart:io';

/// Validates both files and stores a private byte-for-byte original copy for
/// restart-safe before/after history. Gallery export is deliberately separate.
abstract interface class HistoryImageArchiver {
  Future<String> archiveOriginal({
    required String sourcePath,
    required String outputPath,
    required String fileName,
    required String entryId,
  });
}

class AppPrivateHistoryImageArchiver implements HistoryImageArchiver {
  const AppPrivateHistoryImageArchiver();

  @override
  Future<String> archiveOriginal({
    required String sourcePath,
    required String outputPath,
    required String fileName,
    required String entryId,
  }) async {
    final File source = File(sourcePath);
    final File output = File(outputPath);
    if (source.absolute.path == output.absolute.path ||
        !await source.exists() || await source.length() <= 0 ||
        !await output.exists() || await output.length() <= 0) {
      throw const FileSystemException('Original and processed image files must both exist.');
    }
    final Directory archive = Directory('${output.parent.path}${Platform.pathSeparator}history_sources');
    await archive.create(recursive: true);
    final String extension = fileName.contains('.') ? '.${fileName.split('.').last}' : '.img';
    final String destination = '${archive.path}${Platform.pathSeparator}pixora_${entryId}_original$extension';
    await source.copy(destination);
    return destination;
  }
}
