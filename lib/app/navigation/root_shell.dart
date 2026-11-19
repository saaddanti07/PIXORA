import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/screens/history_screen.dart';
import 'package:pixora/features/home/screens/home_screen.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/screens/image_preview_screen.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';
import 'package:pixora/features/settings/screens/settings_screen.dart';

/// Bottom navigation shell: Home, History and Settings.
///
/// An [IndexedStack] keeps each tab's scroll position and state alive, so
/// moving between tabs is instant and never re-loads data. The selected tab is
/// restorable, so Android can bring the user back to where they were after the
/// process is killed in the background.
class RootShell extends StatefulWidget {
  const RootShell({
    required this.imagePickerService,
    required this.historyRepository,
    super.key,
  });

  final ImagePickerService imagePickerService;
  final HistoryRepository historyRepository;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with RestorationMixin<RootShell>, WidgetsBindingObserver {
  static const int _homeIndex = 0;
  static const int _historyIndex = 1;
  static const int _settingsIndex = 2;

  /// Restorable so the tab survives process death (`restartAndRestore` in
  /// tests, "Don't keep activities" and low-memory kills on the device).
  final RestorableInt _selectedTab = RestorableInt(_homeIndex);

  late final ImageSelectionController _selectionController =
      ImageSelectionController(picker: widget.imagePickerService);

  /// Guards against re-entrant recovery when several lifecycle events arrive
  /// before the first one finishes, which would otherwise push the preview
  /// twice.
  bool _isRecoveringPhoto = false;

  @override
  String get restorationId => 'root_shell';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedTab, 'selected_tab');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android may have kept the photo from a picker session that outlived our
    // activity; collect it as soon as the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _recoverLostPhoto();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recoverLostPhoto();
    }
  }

  /// Delivers a photo the system kept while our activity was destroyed.
  ///
  /// Without this the user picks an image, Android reclaims the app while the
  /// gallery is in front, and they come back to an empty Home screen with no
  /// explanation — the classic "the picker does nothing on my phone" report.
  Future<void> _recoverLostPhoto() async {
    if (_isRecoveringPhoto || !mounted) {
      return;
    }
    _isRecoveringPhoto = true;
    try {
      final PickedImage? image = await _selectionController.recoverLostImage();
      if (!mounted || image == null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ImagePreviewScreen(
            image: image,
            onPickAnother: _selectionController.pickImage,
          ),
        ),
      );
    } on ImageSelectionException {
      // The recovered file is unusable (moved, deleted, unsupported). The user
      // can simply pick again from Home; never block the app for this.
    } finally {
      _isRecoveringPhoto = false;
    }
  }

  void _select(int index) {
    if (index == _selectedTab.value) {
      return;
    }
    setState(() => _selectedTab.value = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _selectedTab.value,
        children: <Widget>[
          HomeScreen(
            historyRepository: widget.historyRepository,
            selectionController: _selectionController,
            onOpenSettings: () => _select(_settingsIndex),
            onOpenHistory: () => _select(_historyIndex),
          ),
          HistoryScreen(
            repository: widget.historyRepository,
            onStartRestoration: () => _select(_homeIndex),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab.value,
        onDestinationSelected: _select,
        destinations: <Widget>[
          NavigationDestination(
            key: const Key('nav_home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            key: const Key('nav_history'),
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            key: const Key('nav_settings'),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
