import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/image_engine/services/gallery_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('test/pixora-gallery');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns only the published MediaStore URI and forwards the local path', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      received = call;
      return 'content://media/external/images/media/41';
    });
    final service = AndroidGalleryExportService(channel: channel);

    final Uri saved = await service.saveRestoredImage(
      path: '/private/restored.jpg',
      displayName: 'PIXORA_42.jpg',
    );

    expect(saved.scheme, 'content');
    expect(received?.method, 'saveToGallery');
    expect(received?.arguments, <String, Object?>{
      'sourcePath': '/private/restored.jpg',
      'displayName': 'PIXORA_42.jpg',
    });
  });

  test('rejects an empty success response instead of claiming it was saved', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final service = AndroidGalleryExportService(channel: channel);
    await expectLater(
      service.saveRestoredImage(path: '/private/out.jpg', displayName: 'PIXORA.jpg'),
      throwsFormatException,
    );
  });
}
