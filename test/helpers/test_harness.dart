import 'package:flutter/material.dart';
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
  FakeImagePickerService({
    this.path,
    this.failure,
    this.onPick,
    this.lostPath,
    this.lostFailure,
  });

  /// Path returned when the user "picks" a photo.
  final String? path;

  /// Failure thrown instead of returning a path.
  final ImagePickerFailure? failure;

  /// Optional hook for dynamic behaviour (for example returning a new path on
  /// the second call).
  final String? Function()? onPick;

  /// Photo Android kept after destroying the activity while the picker was in
  /// the foreground, i.e. what `retrieveLostData` would return on a device.
  final String? lostPath;

  /// Failure reported instead of a recovered photo.
  final ImagePickerFailure? lostFailure;

  int callCount = 0;
  int lostCallCount = 0;

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

  @override
  Future<String?> retrieveLostImagePath() async {
    lostCallCount++;
    if (lostFailure != null) {
      throw ImagePickerException(lostFailure!);
    }
    return lostPath;
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

/// A viewport tall enough to hold a whole screen, so widget tests assert on
/// content instead of on scroll offsets. Layout tests opt out and set a real
/// phone size instead.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Scrolls a settings option into view before tapping it.
Future<void> tapOption(WidgetTester tester, String label) async {
  final Finder finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pumps PIXORA with fake services and returns the harness.
Future<TestHarness> pumpPixoraApp(
  WidgetTester tester, {
  Map<String, String> storedValues = const <String, String>{},
  ImagePickerService? picker,
  bool useTallScreen = true,
}) async {
  if (useTallScreen) {
    useTallViewport(tester);
  }
  final TestHarness harness =
      createTestHarness(storedValues: storedValues, picker: picker);
  await tester.pumpWidget(PixoraApp(bootstrap: harness.bootstrap));
  await tester.pumpAndSettle();
  return harness;
}
