import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/core/storage/key_value_store.dart';
import 'package:pixora/core/storage/shared_preferences_store.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/image_picker/services/device_image_picker_service.dart';
import 'package:pixora/features/settings/data/settings_repository.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// Composition root: builds every long-lived service once, before the first
/// frame, and hands them to the widget tree.
///
/// Tests construct a bootstrap with an [InMemoryKeyValueStore] and a fake
/// [ImagePickerService], which is why the constructor is public.
class PixoraBootstrap {
  const PixoraBootstrap({
    required this.settingsController,
    required this.imagePickerService,
    required this.historyRepository,
  });

  final SettingsController settingsController;
  final ImagePickerService imagePickerService;
  final HistoryRepository historyRepository;

  /// Wires the production implementations.
  static Future<PixoraBootstrap> create() async {
    final KeyValueStore store = await SharedPreferencesStore.open();
    final SettingsRepository settingsRepository = SettingsRepository(store);
    final AppSettings settings = settingsRepository.load();
    return PixoraBootstrap(
      settingsController: SettingsController(
        repository: settingsRepository,
        initialSettings: settings,
      ),
      imagePickerService: DeviceImagePickerService(),
      historyRepository: HistoryRepository(store),
    );
  }
}
