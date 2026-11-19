import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/app.dart';
import 'package:pixora/app/bootstrap.dart';
import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/core/storage/in_memory_key_value_store.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/settings/data/settings_repository.dart';

/// A picker double that never touches a platform channel.
class FakeImagePickerService implements ImagePickerService {
  FakeImagePickerService({this.path, this.failure, this.onPick});

  /// Path returned when the user "picks" a photo.
  final String? path;

  /// Failure thrown instead of returning a path.
  final ImagePickerFailure? failure;

  /// Optional hook for dynamic behaviour (for example returning a new path on
  /// the second call).
  final String? Function()? onPick;

  int callCount = 0;

  @override
  Future<String?> pickImagePath() async {
    callCount++;
    if (failure != null) {
      throw ImagePickerException(failure!);
    }
    if (onPick != null) {
      return onPick!();
    }
    return path;
  }
}

/// Everything a test needs to drive the app and inspect what was persisted.
class TestHarness {
  const TestHarness({required this.bootstrap, required this.store});

  final PixoraBootstrap bootstrap;
  final InMemoryKeyValueStore store;
}

/// Builds the composition root with in-memory storage.
TestHarness createTestHarness({
  Map<String, String> storedValues = const <String, String>{},
  ImagePickerService? picker,
}) {
  final InMemoryKeyValueStore store =
      InMemoryKeyValueStore(initialValues: storedValues);
  final SettingsRepository settingsRepository = SettingsRepository(store);
  final PixoraBootstrap bootstrap = PixoraBootstrap(
    settingsController: SettingsController(
      repository: settingsRepository,
      initialSettings: settingsRepository.load(),
    ),
    imagePickerService: picker ?? FakeImagePickerService(),
    historyRepository: HistoryRepository(store),
  );
  return TestHarness(bootstrap: bootstrap, store: store);
}

/// Pumps PIXORA with fake services and returns the harness.
Future<TestHarness> pumpPixoraApp(
  WidgetTester tester, {
  Map<String, String> storedValues = const <String, String>{},
  ImagePickerService? picker,
}) async {
  final TestHarness harness =
      createTestHarness(storedValues: storedValues, picker: picker);
  await tester.pumpWidget(PixoraApp(bootstrap: harness.bootstrap));
  await tester.pumpAndSettle();
  return harness;
}
