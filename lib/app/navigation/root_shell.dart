import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/screens/history_screen.dart';
import 'package:pixora/features/home/screens/home_screen.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';
import 'package:pixora/features/settings/screens/settings_screen.dart';

/// Bottom navigation shell: Home, History and Settings.
///
/// An [IndexedStack] keeps each tab's scroll position and state alive, so
/// moving between tabs is instant and never re-loads data.
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

class _RootShellState extends State<RootShell> {
  static const int _homeIndex = 0;
  static const int _historyIndex = 1;
  static const int _settingsIndex = 2;

  late final ImageSelectionController _selectionController =
      ImageSelectionController(picker: widget.imagePickerService);

  int _index = _homeIndex;

  void _select(int index) {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _index,
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
        selectedIndex: _index,
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
