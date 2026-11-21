import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/history/data/history_image_archiver.dart';

void main() {
  test('copies the exact original to a persistent app-private sibling directory', () async {
    final Directory root = await Directory.systemTemp.createTemp('pixora_archiver');
    addTearDown(() async { if (await root.exists()) await root.delete(recursive: true); });
    final File source = File('${root.path}/source.jpg')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final File output = File('${root.path}/restorations/result.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[9, 8, 7]);

    final String archived = await const AppPrivateHistoryImageArchiver().archiveOriginal(
      sourcePath: source.path,
      outputPath: output.path,
      fileName: 'source.jpg',
      entryId: 'unique-id',
    );

    expect(File(archived).readAsBytesSync(), <int>[1, 2, 3, 4]);
    expect(archived, contains('history_sources'));
  });

  test('refuses to archive unless both original and output exist', () async {
    final Directory root = await Directory.systemTemp.createTemp('pixora_archiver_missing');
    addTearDown(() async { if (await root.exists()) await root.delete(recursive: true); });
    final File source = File('${root.path}/source.jpg')..writeAsBytesSync(<int>[1]);
    await expectLater(
      const AppPrivateHistoryImageArchiver().archiveOriginal(
        sourcePath: source.path,
        outputPath: '${root.path}/missing.jpg',
        fileName: 'source.jpg',
        entryId: 'missing',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
