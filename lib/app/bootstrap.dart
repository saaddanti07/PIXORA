import 'dart:io';

import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/core/storage/key_value_store.dart';
import 'package:pixora/core/storage/shared_preferences_store.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/services/classical_enhancement_processor.dart';
import 'package:pixora/features/image_engine/services/image_engine_registry.dart';
import 'package:pixora/features/image_engine/services/lite_rt_restoration_processor.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';
import 'package:pixora/features/image_picker/services/device_image_picker_service.dart';
import 'package:pixora/features/settings/data/settings_repository.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// Composition root: builds every long-lived service once, before the first
/// frame, and hands them to the widget tree.
///
/// Tests construct a bootstrap with an [InMemoryKeyValueStore] and a fake
/// [ImagePickerService], which is why the constructor is public. They get the
/// empty engine registry by default, so a widget test can never accidentally
/// invoke a platform engine that does not exist.
class PixoraBootstrap {
  const PixoraBootstrap({
    required this.settingsController,
    required this.imagePickerService,
    required this.historyRepository,
    this.engineRegistry = const ImageEngineRegistry.empty(),
    this.capabilities = EngineCapabilities.unavailable,
    this.processingPolicy = ProcessingPolicy.conservative,
  });

  final SettingsController settingsController;
  final ImagePickerService imagePickerService;
  final HistoryRepository historyRepository;

  /// The processors this build can actually run.
  final ImageEngineRegistry engineRegistry;

  /// What the device reported at start-up (RAM, cores, model presence).
  final EngineCapabilities capabilities;

  /// The limits the Smart AI Engine derived from [capabilities].
  final ProcessingPolicy processingPolicy;

  /// Wires the production implementations.
  static Future<PixoraBootstrap> create() async {
    final KeyValueStore store = await SharedPreferencesStore.open();
    final SettingsRepository settingsRepository = SettingsRepository(store);
    final AppSettings settings = settingsRepository.load();

    final NativeEngineChannel channel = NativeEngineChannel();
    final EngineCapabilities capabilities = await channel.capabilities();
    final ProcessingPolicy policy = ProcessingPolicy.forDevice(capabilities);
    final Directory? filesDirectory = await channel.filesDirectory();

    Future<Directory> outputDirectory() async {
      if (filesDirectory != null) {
        return filesDirectory;
      }
      final Directory fallback =
          Directory('${Directory.systemTemp.path}${Platform.pathSeparator}pixora');
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback;
    }

    return PixoraBootstrap(
      settingsController: SettingsController(
        repository: settingsRepository,
        initialSettings: settings,
      ),
      imagePickerService: DeviceImagePickerService(),
      historyRepository: HistoryRepository(store),
      capabilities: capabilities,
      processingPolicy: policy,
      engineRegistry: ImageEngineRegistry(<PixoraImageProcessor>[
        LiteRtRestorationProcessor(
          channel: channel,
          capabilities: capabilities,
          policy: policy,
          outputDirectory: outputDirectory,
        ),
        ClassicalEnhancementProcessor(
          channel: channel,
          policy: policy,
          outputDirectory: outputDirectory,
        ),
      ]),
    );
  }
}
